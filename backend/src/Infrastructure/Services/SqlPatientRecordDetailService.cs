using System.Globalization;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientRecordDetailService : IPatientRecordDetailService
{
    private static readonly Regex PatientNameRegex = new(
        @"(?im)\b(?:patient\s*name|name)\b\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,80})",
        RegexOptions.Compiled);

    private readonly string _connectionString;
    private readonly string _ocrProvider;
    private readonly string _ocrApiKey;
    private readonly string _ocrApiUrl;
    private const int FreePlanFileSizeLimitBytes = 1_000_000;
    private const int FreePlanPdfPageLimit = 3;

    public SqlPatientRecordDetailService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");

        var ocrSection = configuration.GetSection("Ocr");
        _ocrProvider = ocrSection["OCRPath"] ?? string.Empty;
        _ocrApiKey = ocrSection["APIKey"] ?? string.Empty;
        _ocrApiUrl = ocrSection["ApiUrl"] ?? "https://api.ocr.space/parse/image";
    }

    public async Task<IReadOnlyList<PatientRecordDetailDto>> ExtractPreviewAsync(
        byte[] fileBytes,
        string contentType,
        string fallbackPatientName,
        DateTime reportDateTime,
        CancellationToken cancellationToken)
    {
        var text = await ExtractTextAsync(fileBytes, contentType, cancellationToken);
        if (string.IsNullOrWhiteSpace(text))
        {
            return [];
        }

        var keywords = await LoadKeywordsAsync(cancellationToken);
        if (keywords.Count == 0)
        {
            return [];
        }

        var lines = text
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(NormalizeWhitespace)
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var patientName = ExtractPatientName(text, fallbackPatientName);
        return ExtractReadings(lines, keywords, patientName, reportDateTime);
    }

    public async Task SaveAsync(
        int patientMedicalRecordId,
        string patientNameInRecord,
        IReadOnlyList<SavePatientRecordDetailItemRequest> details,
        CancellationToken cancellationToken)
    {
        var normalizedDetails = details
            .Where(detail => detail.RecordKeywordId > 0)
            .GroupBy(detail => detail.RecordKeywordId)
            .Select(group => group.Last())
            .ToList();

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string deleteSql = @"
DELETE FROM [PatientRecordDetail]
WHERE [lPatientMedicalRecordId] = @patientMedicalRecordId";

        await using (var deleteCommand = new SqlCommand(deleteSql, connection, (SqlTransaction)transaction))
        {
            deleteCommand.Parameters.AddWithValue("@patientMedicalRecordId", patientMedicalRecordId);
            await deleteCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        if (normalizedDetails.Count > 0)
        {
            const string insertSql = @"
INSERT INTO [PatientRecordDetail]
    ([lPatientMedicalRecordId], [PatientNameInRecord], [lRecordKeywordId], [ReadingValue], [ReportDateTime])
VALUES
    (@patientMedicalRecordId, @patientNameInRecord, @recordKeywordId, @readingValue, @reportDateTime)";

            foreach (var detail in normalizedDetails)
            {
                await using var insertCommand = new SqlCommand(insertSql, connection, (SqlTransaction)transaction);
                insertCommand.Parameters.AddWithValue("@patientMedicalRecordId", patientMedicalRecordId);
                insertCommand.Parameters.AddWithValue("@patientNameInRecord", NormalizeWhitespace(patientNameInRecord));
                insertCommand.Parameters.AddWithValue("@recordKeywordId", detail.RecordKeywordId);
                insertCommand.Parameters.AddWithValue("@readingValue", detail.ReadingValue);
                insertCommand.Parameters.AddWithValue("@reportDateTime", detail.ReportDateTime.Kind == DateTimeKind.Unspecified
                    ? DateTime.SpecifyKind(detail.ReportDateTime, DateTimeKind.Utc)
                    : detail.ReportDateTime.ToUniversalTime());
                await insertCommand.ExecuteNonQueryAsync(cancellationToken);
            }
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<PatientRecordDetailDto>> ListByMedicalRecordAsync(
        int patientMedicalRecordId,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT
    d.[lPatientRecordDetailId],
    d.[lPatientMedicalRecordId],
    d.[PatientNameInRecord],
    d.[lRecordKeywordId],
    rk.[Keyword],
    rk.[Description],
    d.[ReadingValue],
    rk.[IdealLower],
    rk.[IdealUpper],
    d.[ReportDateTime]
FROM [PatientRecordDetail] d
INNER JOIN [RecordKeyword] rk
    ON rk.[lRecordKeywordId] = d.[lRecordKeywordId]
WHERE d.[lPatientMedicalRecordId] = @patientMedicalRecordId
ORDER BY rk.[Keyword]";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@patientMedicalRecordId", patientMedicalRecordId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var results = new List<PatientRecordDetailDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            results.Add(MapDto(reader));
        }

        return results;
    }

    private async Task<string> ExtractTextAsync(
        byte[] fileBytes,
        string contentType,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(_ocrProvider, "OCR.Space", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Unsupported OCR provider. Set Ocr:OCRPath to OCR.Space.");
        }

        if (string.IsNullOrWhiteSpace(_ocrApiKey))
        {
            throw new InvalidOperationException(
                "OCR preview requires Ocr:APIKey to be configured.");
        }

        var normalizedContentType = GetContentTypeOrDefault(contentType);
        var ocrBytes = fileBytes;
        if (normalizedContentType.Contains("pdf", StringComparison.OrdinalIgnoreCase))
        {
            ocrBytes = TrimPdfToFirstPages(fileBytes, FreePlanPdfPageLimit);
        }

        if (ocrBytes.Length > FreePlanFileSizeLimitBytes)
        {
            throw new InvalidOperationException(
                "OCR.Space free plan supports files up to 1 MB. The OCR input still exceeds that limit even after restricting PDF OCR to the first 3 pages.");
        }

        using var httpClient = new HttpClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, _ocrApiUrl);
        request.Headers.Add("apikey", _ocrApiKey);

        using var form = new MultipartFormDataContent();
        form.Add(new StringContent("eng"), "language");
        form.Add(new StringContent("false"), "isOverlayRequired");
        form.Add(new StringContent("2"), "OCREngine");
        form.Add(new StringContent("true"), "scale");
        form.Add(new StringContent("true"), "detectOrientation");
        form.Add(new StringContent("true"), "isTable");
        form.Add(new StringContent(GetOcrSpaceFileType(normalizedContentType)), "filetype");

        var fileContent = new ByteArrayContent(ocrBytes);
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse(normalizedContentType);
        form.Add(fileContent, "file", GetFileName(normalizedContentType));

        request.Content = form;

        using var response = await httpClient.SendAsync(request, cancellationToken);
        var responseText = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"OCR.Space request failed with {(int)response.StatusCode}: {responseText}");
        }

        return ParseOcrSpaceText(responseText);
    }

    private static string ParseOcrSpaceText(string responseText)
    {
        using var document = JsonDocument.Parse(responseText);
        var root = document.RootElement;

        if (root.TryGetProperty("IsErroredOnProcessing", out var isErroredElement) &&
            isErroredElement.ValueKind == JsonValueKind.True)
        {
            var errorMessage = TryReadStringArray(root, "ErrorMessage");
            var errorDetails = root.TryGetProperty("ErrorDetails", out var detailsElement)
                ? detailsElement.ToString()
                : string.Empty;
            var combinedError = string.Join(" ", new[] { errorMessage, errorDetails }
                .Where(value => !string.IsNullOrWhiteSpace(value)));

            throw new InvalidOperationException(
                string.IsNullOrWhiteSpace(combinedError)
                    ? "OCR.Space could not process the document."
                    : combinedError);
        }

        if (!root.TryGetProperty("ParsedResults", out var parsedResults) ||
            parsedResults.ValueKind != JsonValueKind.Array)
        {
            return string.Empty;
        }

        var textParts = new List<string>();
        foreach (var parsedResult in parsedResults.EnumerateArray())
        {
            if (parsedResult.TryGetProperty("ParsedText", out var parsedTextElement))
            {
                var parsedText = parsedTextElement.GetString();
                if (!string.IsNullOrWhiteSpace(parsedText))
                {
                    textParts.Add(parsedText);
                }
            }
        }

        return string.Join(Environment.NewLine, textParts).Trim();
    }

    private async Task<IReadOnlyList<RecordKeywordDefinition>> LoadKeywordsAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT
    rk.[lRecordKeywordId],
    rk.[Keyword],
    rk.[Description],
    rk.[IdealLower],
    rk.[IdealUpper],
    a.[AliasName]
FROM [RecordKeyword] rk
LEFT JOIN [Alias] a
    ON a.[lDataEntityId] = 4
   AND a.[lInstanceId] = rk.[lRecordKeywordId]
   AND a.[IsActive] = 1
WHERE rk.[IsActive] = 1
ORDER BY rk.[lRecordKeywordId]";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var map = new Dictionary<int, RecordKeywordDefinition>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var id = Convert.ToInt32(reader["lRecordKeywordId"]);
            if (!map.TryGetValue(id, out var definition))
            {
                definition = new RecordKeywordDefinition(
                    id,
                    reader["Keyword"]?.ToString() ?? string.Empty,
                    reader["Description"]?.ToString() ?? string.Empty,
                    reader["IdealLower"] is DBNull ? null : Convert.ToDouble(reader["IdealLower"], CultureInfo.InvariantCulture),
                    reader["IdealUpper"] is DBNull ? null : Convert.ToDouble(reader["IdealUpper"], CultureInfo.InvariantCulture),
                    []);
                map[id] = definition;
            }

            var alias = reader["AliasName"]?.ToString();
            if (!string.IsNullOrWhiteSpace(alias))
            {
                definition.Aliases.Add(alias.Trim());
            }
        }

        foreach (var definition in map.Values)
        {
            if (!definition.Aliases.Contains(definition.Keyword, StringComparer.OrdinalIgnoreCase))
            {
                definition.Aliases.Add(definition.Keyword);
            }
        }

        return map.Values.ToList();
    }

    private static IReadOnlyList<PatientRecordDetailDto> ExtractReadings(
        IReadOnlyList<string> lines,
        IReadOnlyList<RecordKeywordDefinition> keywords,
        string patientNameInRecord,
        DateTime reportDateTime)
    {
        var results = new List<PatientRecordDetailDto>();

        foreach (var keyword in keywords)
        {
            double? matchedValue = null;
            foreach (var alias in keyword.Aliases
                         .Where(alias => !string.IsNullOrWhiteSpace(alias))
                         .OrderByDescending(alias => alias.Length))
            {
                var value = FindReading(lines, alias);
                if (value is not null)
                {
                    matchedValue = value.Value;
                    break;
                }
            }

            if (matchedValue is null)
            {
                continue;
            }

            results.Add(new PatientRecordDetailDto
            {
                PatientRecordDetailId = 0,
                PatientMedicalRecordId = 0,
                PatientNameInRecord = patientNameInRecord,
                RecordKeywordId = keyword.RecordKeywordId,
                Keyword = keyword.Keyword,
                Description = keyword.Description,
                ReadingValue = matchedValue.Value,
                IdealLower = keyword.IdealLower,
                IdealUpper = keyword.IdealUpper,
                ReportDateTime = reportDateTime.Kind == DateTimeKind.Unspecified
                    ? DateTime.SpecifyKind(reportDateTime, DateTimeKind.Utc)
                    : reportDateTime.ToUniversalTime()
            });
        }

        return results;
    }

    private static double? FindReading(IReadOnlyList<string> lines, string alias)
    {
        var normalizedAlias = NormalizeForMatch(alias);
        if (string.IsNullOrWhiteSpace(normalizedAlias))
        {
            return null;
        }

        for (var index = 0; index < lines.Count; index++)
        {
            var currentLine = lines[index];
            var normalizedCurrentLine = NormalizeForMatch(currentLine);

            if (!ContainsAlias(normalizedCurrentLine, normalizedAlias))
            {
                continue;
            }

            var candidates = new List<string> { currentLine };
            if (index + 1 < lines.Count)
            {
                candidates.Add(lines[index + 1]);
                candidates.Add($"{currentLine} {lines[index + 1]}");
            }

            foreach (var candidate in candidates)
            {
                var value = TryExtractReadingValue(candidate, alias);
                if (value is not null)
                {
                    return value.Value;
                }
            }
        }

        return null;
    }

    private static double? TryExtractReadingValue(string text, string alias)
    {
        var escapedAlias = Regex.Escape(alias.Trim());
        var inlinePattern = new Regex(
            $@"(?i)\b{escapedAlias}\b[^\r\n\d+-]{{0,40}}([<>]?\s*-?\d+(?:\.\d+)?)",
            RegexOptions.Compiled);

        var inlineMatch = inlinePattern.Match(text);
        if (inlineMatch.Success)
        {
            var inlineValue = ParseNumericText(inlineMatch.Groups[1].Value);
            if (inlineValue is not null)
            {
                return inlineValue.Value;
            }
        }

        var trailingNumbers = Regex.Matches(
            text,
            @"(?<![A-Za-z0-9])([<>]?\s*-?\d+(?:\.\d+)?)(?![A-Za-z])",
            RegexOptions.Compiled);

        foreach (Match match in trailingNumbers)
        {
            var value = ParseNumericText(match.Groups[1].Value);
            if (value is not null)
            {
                return value.Value;
            }
        }

        return null;
    }

    private static double? ParseNumericText(string numericText)
    {
        var cleaned = numericText
            .Replace("<", string.Empty, StringComparison.Ordinal)
            .Replace(">", string.Empty, StringComparison.Ordinal)
            .Replace(",", string.Empty, StringComparison.Ordinal)
            .Trim();

        if (double.TryParse(
                cleaned,
                NumberStyles.Float | NumberStyles.AllowLeadingSign,
                CultureInfo.InvariantCulture,
                out var value))
        {
            return value;
        }

        return null;
    }

    private static bool ContainsAlias(string normalizedLine, string normalizedAlias)
    {
        if (normalizedLine.Contains(normalizedAlias, StringComparison.Ordinal))
        {
            return true;
        }

        var aliasWithoutSpaces = normalizedAlias.Replace(" ", string.Empty, StringComparison.Ordinal);
        var lineWithoutSpaces = normalizedLine.Replace(" ", string.Empty, StringComparison.Ordinal);
        return lineWithoutSpaces.Contains(aliasWithoutSpaces, StringComparison.Ordinal);
    }

    private static string NormalizeForMatch(string value)
    {
        var normalized = NormalizeWhitespace(value).ToLowerInvariant();
        normalized = Regex.Replace(normalized, @"[^a-z0-9.\-/% ]", " ");
        return NormalizeWhitespace(normalized);
    }

    private static string ExtractPatientName(string text, string fallbackPatientName)
    {
        var match = PatientNameRegex.Match(text);
        if (match.Success)
        {
            return NormalizeWhitespace(match.Groups[1].Value);
        }

        return NormalizeWhitespace(fallbackPatientName);
    }

    private static string NormalizeWhitespace(string value)
    {
        return Regex.Replace(value ?? string.Empty, @"\s+", " ").Trim();
    }

    private static string GetContentTypeOrDefault(string? contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return "application/octet-stream";
        }

        return contentType.Trim();
    }

    private static string GetFileName(string? contentType)
    {
        var normalizedType = GetContentTypeOrDefault(contentType).ToLowerInvariant();
        if (normalizedType.Contains("pdf", StringComparison.Ordinal))
        {
            return "report.pdf";
        }

        if (normalizedType.Contains("png", StringComparison.Ordinal))
        {
            return "report.png";
        }

        if (normalizedType.Contains("bmp", StringComparison.Ordinal))
        {
            return "report.bmp";
        }

        return "report.jpg";
    }

    private static string GetOcrSpaceFileType(string? contentType)
    {
        var normalizedType = GetContentTypeOrDefault(contentType).ToLowerInvariant();
        if (normalizedType.Contains("pdf", StringComparison.Ordinal))
        {
            return "PDF";
        }

        if (normalizedType.Contains("png", StringComparison.Ordinal))
        {
            return "PNG";
        }

        if (normalizedType.Contains("bmp", StringComparison.Ordinal))
        {
            return "BMP";
        }

        return "JPG";
    }

    private static byte[] TrimPdfToFirstPages(byte[] fileBytes, int pageLimit)
    {
        try
        {
            using var inputStream = new MemoryStream(fileBytes, writable: false);
            using var inputDocument = PdfReader.Open(inputStream, PdfDocumentOpenMode.Import);

            if (inputDocument.PageCount <= pageLimit)
            {
                return fileBytes;
            }

            using var outputDocument = new PdfDocument();
            var pagesToCopy = Math.Min(pageLimit, inputDocument.PageCount);
            for (var i = 0; i < pagesToCopy; i++)
            {
                outputDocument.AddPage(inputDocument.Pages[i]);
            }

            using var outputStream = new MemoryStream();
            outputDocument.Save(outputStream, false);
            return outputStream.ToArray();
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                $"Could not limit the PDF to the first {pageLimit} pages for OCR. {ex.Message}");
        }
    }

    private static string TryReadStringArray(JsonElement root, string propertyName)
    {
        if (!root.TryGetProperty(propertyName, out var element))
        {
            return string.Empty;
        }

        return element.ValueKind switch
        {
            JsonValueKind.String => element.GetString() ?? string.Empty,
            JsonValueKind.Array => string.Join(" ", element.EnumerateArray()
                .Select(item => item.GetString())
                .Where(value => !string.IsNullOrWhiteSpace(value))),
            _ => element.ToString()
        };
    }

    private static PatientRecordDetailDto MapDto(SqlDataReader reader)
    {
        return new PatientRecordDetailDto
        {
            PatientRecordDetailId = Convert.ToInt32(reader["lPatientRecordDetailId"]),
            PatientMedicalRecordId = Convert.ToInt32(reader["lPatientMedicalRecordId"]),
            PatientNameInRecord = reader["PatientNameInRecord"]?.ToString() ?? string.Empty,
            RecordKeywordId = Convert.ToInt32(reader["lRecordKeywordId"]),
            Keyword = reader["Keyword"]?.ToString() ?? string.Empty,
            Description = reader["Description"]?.ToString() ?? string.Empty,
            ReadingValue = Convert.ToDouble(reader["ReadingValue"], CultureInfo.InvariantCulture),
            IdealLower = reader["IdealLower"] is DBNull ? null : Convert.ToDouble(reader["IdealLower"], CultureInfo.InvariantCulture),
            IdealUpper = reader["IdealUpper"] is DBNull ? null : Convert.ToDouble(reader["IdealUpper"], CultureInfo.InvariantCulture),
            ReportDateTime = reader["ReportDateTime"] is DateTime dt ? dt : default
        };
    }

    private sealed record RecordKeywordDefinition(
        int RecordKeywordId,
        string Keyword,
        string Description,
        double? IdealLower,
        double? IdealUpper,
        List<string> Aliases);
}
