using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;
using UglyToad.PdfPig;
using UglyToad.PdfPig.Content;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientRecordDetailService : IPatientRecordDetailService
{
    private static readonly Regex PatientNameRegex = new(
        @"(?im)\b(?:patient\s*name|name)\b\s*[:\-]?\s*([A-Za-z][A-Za-z .]{2,80})",
        RegexOptions.Compiled);

    private readonly string _connectionString;
    private readonly string? _googleVisionApiKey;

    /// <summary>
    /// Minimum distinct word count that qualifies extracted PDF text as real (non-empty/non-garbled).
    /// </summary>
    private const int MinMeaningfulWordCount = 8;

    public SqlPatientRecordDetailService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");

        _googleVisionApiKey = configuration["GoogleVision:ApiKey"];
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

    // ─── Text extraction ──────────────────────────────────────────────────────

    private async Task<string> ExtractTextAsync(
        byte[] fileBytes,
        string contentType,
        CancellationToken cancellationToken)
    {
        var normalizedType = GetContentTypeOrDefault(contentType).ToLowerInvariant();

        if (normalizedType.Contains("pdf"))
        {
            // Fast path: extract embedded text directly — works for virtually all
            // digital lab reports without any cloud API call.
            var pdfText = ExtractTextFromPdf(fileBytes);
            if (CountWords(pdfText) >= MinMeaningfulWordCount)
            {
                return pdfText;
            }
            // If the PDF is a scanned document, PdfPig returns no/few words.
            // Fall through to image OCR below.
        }

        // Image / scanned-PDF path — requires Google Cloud Vision API.
        if (string.IsNullOrWhiteSpace(_googleVisionApiKey))
        {
            throw new InvalidOperationException(
                "This document appears to be a scanned image. " +
                "Configure GoogleVision:ApiKey to enable image OCR, " +
                "or enter the values manually.");
        }

        return await ExtractTextWithGoogleVisionAsync(fileBytes, normalizedType, cancellationToken);
    }

    // ─── PdfPig: digital-PDF text extraction ─────────────────────────────────

    private static string ExtractTextFromPdf(byte[] fileBytes)
    {
        try
        {
            using var document = PdfDocument.Open(fileBytes, new ParsingOptions { UseLenientParsing = true });

            var sb = new StringBuilder();
            foreach (var page in document.GetPages())
            {
                var words = page.GetWords().ToList();
                if (words.Count == 0)
                {
                    continue;
                }

                // Group by approximate vertical position to reconstruct reading-order lines.
                var lineGroups = words
                    .GroupBy(w => (int)Math.Round(w.BoundingBox.Bottom / 3.0) * 3)
                    .OrderByDescending(g => g.Key);

                foreach (var group in lineGroups)
                {
                    var lineText = string.Join(" ",
                        group.OrderBy(w => w.BoundingBox.Left).Select(w => w.Text));
                    if (!string.IsNullOrWhiteSpace(lineText))
                    {
                        sb.AppendLine(lineText);
                    }
                }

                sb.AppendLine();
            }

            return sb.ToString().Trim();
        }
        catch
        {
            return string.Empty;
        }
    }

    private static int CountWords(string text) =>
        text.Split([' ', '\t', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries).Length;

    // ─── Google Cloud Vision: image / scanned-document OCR ───────────────────

    private const string GoogleVisionAnnotateUrl =
        "https://vision.googleapis.com/v1/images:annotate";
    private const string GoogleVisionFilesUrl =
        "https://vision.googleapis.com/v1/files:annotate";

    /// <summary>
    /// Sends the document to Google Cloud Vision DOCUMENT_TEXT_DETECTION and
    /// returns all extracted text.
    /// <para>
    /// PDFs are submitted via the <c>files:annotate</c> endpoint (supports up
    /// to 5 pages synchronously, which covers virtually all medical lab reports).
    /// Images use the standard <c>images:annotate</c> endpoint.
    /// </para>
    /// </summary>
    private async Task<string> ExtractTextWithGoogleVisionAsync(
        byte[] fileBytes,
        string normalizedContentType,
        CancellationToken cancellationToken)
    {
        var isPdf = normalizedContentType.Contains("pdf");
        var base64Content = Convert.ToBase64String(fileBytes);

        string requestJson;
        string url;

        if (isPdf)
        {
            // files:annotate — processes up to 5 pages in a single synchronous call.
            url = $"{GoogleVisionFilesUrl}?key={_googleVisionApiKey}";
            requestJson = JsonSerializer.Serialize(new
            {
                requests = new[]
                {
                    new
                    {
                        inputConfig = new
                        {
                            content = base64Content,
                            mimeType = "application/pdf"
                        },
                        features = new[]
                        {
                            new { type = "DOCUMENT_TEXT_DETECTION" }
                        },
                        pages = new[] { 1, 2, 3, 4, 5 }
                    }
                }
            });
        }
        else
        {
            // images:annotate — works for JPEG, PNG, BMP, TIFF, WEBP, etc.
            url = $"{GoogleVisionAnnotateUrl}?key={_googleVisionApiKey}";
            requestJson = JsonSerializer.Serialize(new
            {
                requests = new[]
                {
                    new
                    {
                        image = new { content = base64Content },
                        features = new[]
                        {
                            new { type = "DOCUMENT_TEXT_DETECTION" }
                        }
                    }
                }
            });
        }

        using var httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
        using var httpContent = new StringContent(requestJson, Encoding.UTF8, "application/json");

        var response = await httpClient.PostAsync(url, httpContent, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"Google Cloud Vision API failed ({(int)response.StatusCode}): {responseBody}");
        }

        return ParseGoogleVisionResponse(responseBody, isPdf);
    }

    private static string ParseGoogleVisionResponse(string json, bool isPdf)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        if (!root.TryGetProperty("responses", out var outerResponses))
        {
            return string.Empty;
        }

        var parts = new List<string>();

        foreach (var outerResponse in outerResponses.EnumerateArray())
        {
            if (isPdf)
            {
                // files:annotate wraps page results in a nested "responses" array.
                if (outerResponse.TryGetProperty("responses", out var pageResponses))
                {
                    foreach (var pageResponse in pageResponses.EnumerateArray())
                    {
                        var text = ReadFullTextAnnotation(pageResponse);
                        if (!string.IsNullOrWhiteSpace(text))
                        {
                            parts.Add(text);
                        }
                    }
                }
            }
            else
            {
                // images:annotate — fullTextAnnotation is directly on the response.
                var text = ReadFullTextAnnotation(outerResponse);
                if (!string.IsNullOrWhiteSpace(text))
                {
                    parts.Add(text);
                }
            }
        }

        return string.Join(Environment.NewLine, parts).Trim();
    }

    private static string ReadFullTextAnnotation(JsonElement element)
    {
        if (element.TryGetProperty("fullTextAnnotation", out var fta) &&
            fta.TryGetProperty("text", out var textProp))
        {
            return textProp.GetString() ?? string.Empty;
        }

        return string.Empty;
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
