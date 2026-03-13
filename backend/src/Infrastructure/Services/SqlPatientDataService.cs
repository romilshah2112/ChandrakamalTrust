using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientDataService : IPatientDataService
{
    private readonly string _connectionString;
    private readonly IPasswordCryptoService _passwordCryptoService;
    private readonly IImageStorageService _imageStorageService;

    public SqlPatientDataService(
        IConfiguration configuration,
        IPasswordCryptoService passwordCryptoService,
        IImageStorageService imageStorageService)
    {
        _passwordCryptoService = passwordCryptoService;
        _imageStorageService = imageStorageService;
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<int> CreateAsync(PatientDataCreateRequest request, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var imageName = await ResolveImageNameAsync(request, cancellationToken);

        const string sql = @"
INSERT INTO [patientdata]
    ([FirstName], [LastName], [MobileNo], [Email], [Address], [Gender], [City], [BirthDate], [CreatedDate],
     [Password], [ImageName], [lAppUserId], [lReferenceTypeId], [ReferenceName], [IsActive])
OUTPUT INSERTED.[lPatientDataId]
VALUES
    (@firstName, @lastName, @mobileNo, @email, @address, @gender, @city, @birthDate, @createdDate,
     @password, @imageName, @appUserId, @referenceTypeId, @referenceName, @isActive)";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@firstName", request.FirstName);
        command.Parameters.AddWithValue("@lastName", request.LastName);
        command.Parameters.AddWithValue("@mobileNo", request.MobileNo);
        command.Parameters.AddWithValue("@email", request.Email);
        command.Parameters.AddWithValue("@address", request.Address);
        command.Parameters.AddWithValue("@gender", request.Gender);
        command.Parameters.AddWithValue("@city", request.City);
        command.Parameters.AddWithValue("@birthDate", request.BirthDate.ToDateTime(TimeOnly.MinValue));
        command.Parameters.AddWithValue("@createdDate", DateTime.UtcNow.Date);
        command.Parameters.AddWithValue("@password", _passwordCryptoService.Encrypt(request.Password));
        command.Parameters.AddWithValue("@imageName", (object?)imageName ?? DBNull.Value);
        command.Parameters.AddWithValue("@appUserId", request.AppUserId);
        command.Parameters.AddWithValue("@referenceTypeId", request.ReferenceTypeId);
        command.Parameters.AddWithValue("@referenceName", request.ReferenceName);
        command.Parameters.AddWithValue("@isActive", true);

        var insertedId = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(insertedId);
    }

    public async Task<PatientDataResponse?> GetByAppUserIdAsync(int appUserId, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT TOP 1
    [lPatientDataId], [FirstName], [LastName], [MobileNo], [Email], [Address], [Gender], [City],
    [BirthDate], [CreatedDate], [ImageName], [lAppUserId], [lReferenceTypeId], [ReferenceName], [IsActive]
FROM [patientdata]
WHERE [lAppUserId] = @appUserId
ORDER BY [CreatedDate] DESC, [lPatientDataId] DESC";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@appUserId", appUserId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new PatientDataResponse
        {
            PatientDataId = reader.GetInt32(0),
            FirstName = reader["FirstName"]?.ToString() ?? string.Empty,
            LastName = reader["LastName"]?.ToString() ?? string.Empty,
            MobileNo = Convert.ToInt64(reader["MobileNo"]),
            Email = reader["Email"]?.ToString() ?? string.Empty,
            Address = reader["Address"]?.ToString() ?? string.Empty,
            Gender = reader["Gender"]?.ToString() ?? string.Empty,
            City = reader["City"]?.ToString() ?? string.Empty,
            BirthDate = DateOnly.FromDateTime(Convert.ToDateTime(reader["BirthDate"])),
            CreatedDate = DateOnly.FromDateTime(Convert.ToDateTime(reader["CreatedDate"])),
            ImageName = reader["ImageName"]?.ToString() ?? string.Empty,
            AppUserId = Convert.ToInt32(reader["lAppUserId"]),
            ReferenceTypeId = Convert.ToInt32(reader["lReferenceTypeId"]),
            ReferenceName = reader["ReferenceName"]?.ToString() ?? string.Empty,
            IsActive = Convert.ToBoolean(reader["IsActive"])
        };
    }

    public async Task<IReadOnlyList<PatientListItemResponse>> ListAsync(string? query, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT
    [lPatientDataId], [FirstName], [LastName], [MobileNo], [Email], [IsActive]
FROM [patientdata]
WHERE (@query IS NULL OR @query = ''
    OR [FirstName] LIKE '%' + @query + '%'
    OR [LastName] LIKE '%' + @query + '%'
    OR [Email] LIKE '%' + @query + '%'
    OR CAST([MobileNo] AS nvarchar(30)) LIKE '%' + @query + '%')
ORDER BY [CreatedDate] DESC, [lPatientDataId] DESC";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@query", (object?)query ?? DBNull.Value);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var items = new List<PatientListItemResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new PatientListItemResponse
            {
                PatientDataId = reader.GetInt32(0),
                FirstName = reader["FirstName"]?.ToString() ?? string.Empty,
                LastName = reader["LastName"]?.ToString() ?? string.Empty,
                MobileNo = Convert.ToInt64(reader["MobileNo"]),
                Email = reader["Email"]?.ToString() ?? string.Empty,
                IsActive = Convert.ToBoolean(reader["IsActive"])
            });
        }

        return items;
    }

    public async Task<PatientDataResponse?> GetByIdAsync(int patientDataId, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT
    [lPatientDataId], [FirstName], [LastName], [MobileNo], [Email], [Address], [Gender], [City],
    [BirthDate], [CreatedDate], [ImageName], [lAppUserId], [lReferenceTypeId], [ReferenceName], [IsActive]
FROM [patientdata]
WHERE [lPatientDataId] = @patientDataId";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@patientDataId", patientDataId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new PatientDataResponse
        {
            PatientDataId = reader.GetInt32(0),
            FirstName = reader["FirstName"]?.ToString() ?? string.Empty,
            LastName = reader["LastName"]?.ToString() ?? string.Empty,
            MobileNo = Convert.ToInt64(reader["MobileNo"]),
            Email = reader["Email"]?.ToString() ?? string.Empty,
            Address = reader["Address"]?.ToString() ?? string.Empty,
            Gender = reader["Gender"]?.ToString() ?? string.Empty,
            City = reader["City"]?.ToString() ?? string.Empty,
            BirthDate = DateOnly.FromDateTime(Convert.ToDateTime(reader["BirthDate"])),
            CreatedDate = DateOnly.FromDateTime(Convert.ToDateTime(reader["CreatedDate"])),
            ImageName = reader["ImageName"]?.ToString() ?? string.Empty,
            AppUserId = Convert.ToInt32(reader["lAppUserId"]),
            ReferenceTypeId = Convert.ToInt32(reader["lReferenceTypeId"]),
            ReferenceName = reader["ReferenceName"]?.ToString() ?? string.Empty,
            IsActive = Convert.ToBoolean(reader["IsActive"])
        };
    }

    public async Task<bool> UpdateMyContactAsync(int appUserId, PatientContactUpdateRequest request, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
UPDATE [patientdata] SET
    [MobileNo] = @mobileNo,
    [Email] = @email,
    [Address] = @address,
    [City] = @city
WHERE [lPatientDataId] = (
    SELECT TOP 1 [lPatientDataId] FROM [patientdata]
    WHERE [lAppUserId] = @appUserId
    ORDER BY [CreatedDate] DESC, [lPatientDataId] DESC
)";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@appUserId", appUserId);
        command.Parameters.AddWithValue("@mobileNo", request.MobileNo);
        command.Parameters.AddWithValue("@email", request.Email);
        command.Parameters.AddWithValue("@address", request.Address);
        command.Parameters.AddWithValue("@city", request.City);

        var rows = await command.ExecuteNonQueryAsync(cancellationToken);
        return rows > 0;
    }

    public async Task<bool> UpdateAsync(int patientDataId, PatientDataUpdateRequest request, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var imageName = await ResolveImageNameAsync(
            request.ImageName,
            request.ImageBase64,
            request.ImageFileName,
            request.ImageContentType,
            cancellationToken);

        const string sql = @"
UPDATE [patientdata] SET
    [FirstName] = @firstName,
    [LastName] = @lastName,
    [MobileNo] = @mobileNo,
    [Email] = @email,
    [Address] = @address,
    [Gender] = @gender,
    [City] = @city,
    [BirthDate] = @birthDate,
    [ImageName] = @imageName,
    [lReferenceTypeId] = @referenceTypeId,
    [ReferenceName] = @referenceName,
    [IsActive] = @isActive
WHERE [lPatientDataId] = @patientDataId";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@patientDataId", patientDataId);
        command.Parameters.AddWithValue("@firstName", request.FirstName);
        command.Parameters.AddWithValue("@lastName", request.LastName);
        command.Parameters.AddWithValue("@mobileNo", request.MobileNo);
        command.Parameters.AddWithValue("@email", request.Email);
        command.Parameters.AddWithValue("@address", request.Address);
        command.Parameters.AddWithValue("@gender", request.Gender);
        command.Parameters.AddWithValue("@city", request.City);
        command.Parameters.AddWithValue("@birthDate", request.BirthDate.ToDateTime(TimeOnly.MinValue));
        command.Parameters.AddWithValue("@imageName", (object?)imageName ?? DBNull.Value);
        command.Parameters.AddWithValue("@referenceTypeId", request.ReferenceTypeId);
        command.Parameters.AddWithValue("@referenceName", request.ReferenceName);
        command.Parameters.AddWithValue("@isActive", request.IsActive);

        var rows = await command.ExecuteNonQueryAsync(cancellationToken);
        return rows > 0;
    }

    public async Task<(bool Deleted, string? BlockReason)> TryDeleteAsync(int patientDataId, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string checkSql = @"
SELECT COUNT(1) FROM [PatientAppointment]
WHERE [lPatientDataId] = @patientDataId";

        await using (var checkCmd = new SqlCommand(checkSql, connection))
        {
            checkCmd.Parameters.AddWithValue("@patientDataId", patientDataId);
            var count = Convert.ToInt32(await checkCmd.ExecuteScalarAsync(cancellationToken));
            if (count > 0)
            {
                return (false, "Cannot delete patient: they have existing appointments.");
            }
        }

        const string deleteSql = "DELETE FROM [patientdata] WHERE [lPatientDataId] = @patientDataId";
        await using var deleteCmd = new SqlCommand(deleteSql, connection);
        deleteCmd.Parameters.AddWithValue("@patientDataId", patientDataId);
        await deleteCmd.ExecuteNonQueryAsync(cancellationToken);
        return (true, null);
    }

    private async Task<string?> ResolveImageNameAsync(
        PatientDataCreateRequest request,
        CancellationToken cancellationToken)
    {
        return await ResolveImageNameAsync(
            request.ImageName,
            request.ImageBase64,
            request.ImageFileName,
            request.ImageContentType,
            cancellationToken);
    }

    private async Task<string?> ResolveImageNameAsync(
        string? currentImageName,
        string? imageBase64,
        string? imageFileName,
        string? imageContentType,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(imageBase64))
        {
            return currentImageName;
        }

        try
        {
            var bytes = Convert.FromBase64String(imageBase64);
            var fileName = string.IsNullOrWhiteSpace(imageFileName)
                ? "patient-profile.jpg"
                : imageFileName;
            var contentType = string.IsNullOrWhiteSpace(imageContentType)
                ? "image/jpeg"
                : imageContentType;

            return await _imageStorageService.UploadPatientProfileAsync(
                bytes,
                fileName,
                contentType,
                cancellationToken);
        }
        catch (FormatException)
        {
            throw new InvalidOperationException("Patient image is not a valid base64 payload.");
        }
    }
}
