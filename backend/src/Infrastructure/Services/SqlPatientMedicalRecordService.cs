using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientMedicalRecordService : IPatientMedicalRecordService
{
    private readonly string _connectionString;

    public SqlPatientMedicalRecordService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<PatientMedicalRecordDto>> ListByPatientAsync(
        int patientDataId,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT
    [lPatientMedicalRecordId],
    [lPatientDataId],
    [lRecordTypeId],
    [RecordName],
    [FileURL],
    [ReportDate],
    [Comments],
    [UploadedOn],
    [lUploadedById],
    [IsActive]
FROM [PatientMedicalRecord]
WHERE [lPatientDataId] = @patientDataId AND [IsActive] = 1
ORDER BY [UploadedOn] DESC";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@patientDataId", patientDataId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var list = new List<PatientMedicalRecordDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(Map(reader));
        }

        return list;
    }

    public async Task<int> InsertAsync(
        int patientDataId,
        int recordTypeId,
        string recordName,
        string fileUrl,
        DateTime reportDate,
        string? comments,
        int uploadedByAppUserId,
        CancellationToken cancellationToken)
    {
        var uploadedOn = DateTime.UtcNow;
        var reportUtc = reportDate.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(reportDate, DateTimeKind.Utc)
            : reportDate.ToUniversalTime();

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string insertSql = @"
INSERT INTO [PatientMedicalRecord]
    ([lPatientDataId], [lRecordTypeId], [RecordName], [FileURL], [ReportDate], [Comments], [UploadedOn], [lUploadedById], [IsActive])
OUTPUT INSERTED.[lPatientMedicalRecordId]
VALUES
    (@patientDataId, @recordTypeId, @recordName, @fileUrl, @reportDate, @comments, @uploadedOn, @uploadedById, 1)";

        await using var command = new SqlCommand(insertSql, connection);
        command.Parameters.AddWithValue("@patientDataId", patientDataId);
        command.Parameters.AddWithValue("@recordTypeId", recordTypeId);
        command.Parameters.AddWithValue("@recordName", recordName.Trim());
        command.Parameters.AddWithValue("@fileUrl", fileUrl);
        command.Parameters.AddWithValue("@reportDate", reportUtc);
        command.Parameters.AddWithValue("@comments", (object?)comments?.Trim() ?? DBNull.Value);
        command.Parameters.AddWithValue("@uploadedOn", uploadedOn);
        command.Parameters.AddWithValue("@uploadedById", uploadedByAppUserId);

        var inserted = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(inserted);
    }

    public async Task<string?> GetFileUrlAsync(
        int recordId,
        int patientDataId,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT TOP 1 [FileURL]
FROM [PatientMedicalRecord]
WHERE [lPatientMedicalRecordId] = @recordId
  AND [lPatientDataId] = @patientDataId
  AND [IsActive] = 1";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@recordId", recordId);
        command.Parameters.AddWithValue("@patientDataId", patientDataId);

        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : result.ToString();
    }

    private static PatientMedicalRecordDto Map(SqlDataReader reader)
    {
        return new PatientMedicalRecordDto
        {
            PatientMedicalRecordId = Convert.ToInt32(reader["lPatientMedicalRecordId"]),
            PatientDataId = Convert.ToInt32(reader["lPatientDataId"]),
            RecordTypeId = Convert.ToInt32(reader["lRecordTypeId"]),
            RecordName = reader["RecordName"]?.ToString() ?? string.Empty,
            FileUrl = reader["FileURL"]?.ToString() ?? string.Empty,
            ReportDate = reader["ReportDate"] is DateTime rd ? DateTime.SpecifyKind(rd, DateTimeKind.Utc) : default,
            Comments = reader["Comments"] is DBNull ? null : reader["Comments"]?.ToString(),
            UploadedOn = reader["UploadedOn"] is DateTime uo ? DateTime.SpecifyKind(uo, DateTimeKind.Utc) : default,
            UploadedById = Convert.ToInt32(reader["lUploadedById"]),
            IsActive = Convert.ToBoolean(reader["IsActive"])
        };
    }
}
