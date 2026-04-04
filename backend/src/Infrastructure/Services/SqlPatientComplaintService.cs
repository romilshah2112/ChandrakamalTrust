using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientComplaintService : IPatientComplaintService
{
    private readonly string _connectionString;

    public SqlPatientComplaintService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<PatientComplaintDto>> ListByPatientAsync(int patientDataId, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT pc.[lPatientComplaintId], pc.[lPatientDataId], pc.[Symptoms],
       ISNULL(s.[lSeverityId], 0) AS [SeverityId],
       ISNULL(pc.[Severity], '') AS [Severity],
       pc.[InsertedOn], pc.[lEnteredById], pc.[IsActive]
FROM [PatientComplaint] pc
LEFT JOIN [Severity] s ON LOWER(LTRIM(RTRIM(s.[Name]))) = LOWER(LTRIM(RTRIM(pc.[Severity])))
WHERE pc.[lPatientDataId] = @patientDataId
  AND pc.[IsActive] = 1
ORDER BY pc.[InsertedOn] DESC, pc.[lPatientComplaintId] DESC";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@patientDataId", patientDataId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<PatientComplaintDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(Map(reader));
        }

        return list;
    }

    public async Task<int?> GetPatientDataIdByComplaintIdAsync(int patientComplaintId, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 [lPatientDataId]
FROM [PatientComplaint]
WHERE [lPatientComplaintId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", patientComplaintId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : Convert.ToInt32(result);
    }

    public async Task<int> CreateAsync(SavePatientComplaintRequest request, int enteredByAppUserId, CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO [PatientComplaint]([lPatientDataId], [Symptoms], [Severity], [InsertedOn], [lEnteredById], [IsActive])
OUTPUT INSERTED.[lPatientComplaintId]
VALUES(@patientDataId, @symptoms, @severity, @insertedOn, @enteredById, @isActive)";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await EnsurePatientExistsAsync(con, request.PatientDataId, cancellationToken);
        var severityName = await ResolveSeverityNameAsync(con, request.SeverityId, cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        Bind(cmd, request, severityName);
        cmd.Parameters.AddWithValue("@insertedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@enteredById", enteredByAppUserId);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task<bool> UpdateAsync(int patientComplaintId, SavePatientComplaintRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientComplaint]
SET [Symptoms] = @symptoms,
    [Severity] = @severity,
    [IsActive] = @isActive
WHERE [lPatientComplaintId] = @id
  AND [lPatientDataId] = @patientDataId";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await EnsurePatientExistsAsync(con, request.PatientDataId, cancellationToken);
        var severityName = await ResolveSeverityNameAsync(con, request.SeverityId, cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        Bind(cmd, request, severityName);
        cmd.Parameters.AddWithValue("@id", patientComplaintId);
        var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);
        return rows > 0;
    }

    public async Task<bool> DeleteAsync(int patientComplaintId, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientComplaint]
SET [IsActive] = 0
WHERE [lPatientComplaintId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", patientComplaintId);
        var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);
        return rows > 0;
    }

    private static void Bind(SqlCommand cmd, SavePatientComplaintRequest request, string severityName)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@symptoms", request.Symptoms);
        cmd.Parameters.AddWithValue("@severity", severityName);
        cmd.Parameters.AddWithValue("@isActive", request.IsActive);
    }

    private static async Task EnsurePatientExistsAsync(SqlConnection con, int patientDataId, CancellationToken cancellationToken)
    {
        const string sql = "SELECT COUNT(1) FROM [patientdata] WHERE [lPatientDataId] = @patientDataId";
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@patientDataId", patientDataId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        if (Convert.ToInt32(result) <= 0)
        {
            throw new InvalidOperationException("Patient not found.");
        }
    }

    private static async Task<string> ResolveSeverityNameAsync(SqlConnection con, int severityId, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 [Name]
FROM [Severity]
WHERE [lSeverityId] = @severityId";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@severityId", severityId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        var name = result?.ToString();
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new InvalidOperationException("Severity not found.");
        }

        return name;
    }

    private static PatientComplaintDto Map(SqlDataReader reader)
    {
        return new PatientComplaintDto
        {
            PatientComplaintId = SafeInt(reader["lPatientComplaintId"]),
            PatientDataId = SafeInt(reader["lPatientDataId"]),
            Symptoms = reader["Symptoms"]?.ToString() ?? string.Empty,
            SeverityId = SafeInt(reader["SeverityId"]),
            Severity = reader["Severity"]?.ToString() ?? string.Empty,
            InsertedOn = reader["InsertedOn"] is DateTime dt ? dt : DateTime.MinValue,
            EnteredById = SafeInt(reader["lEnteredById"]),
            IsActive = SafeBool(reader["IsActive"]),
        };
    }

    private static int SafeInt(object? value) => value is null or DBNull ? 0 : Convert.ToInt32(value);
    private static bool SafeBool(object? value) => value is not null and not DBNull && Convert.ToBoolean(value);
}
