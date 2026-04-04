using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientVitalsService : IPatientVitalsService
{
    private readonly string _connectionString;

    public SqlPatientVitalsService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<PatientVitalsDto>> ListByPatientAsync(int patientDataId, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [lPatientVitalsId], [lPatientDataId], [BPSys], [BPDys], [BloodSugar], [Pulse], [WeightKG], [InsertedOn], [InsertedBy], [HeightCMS], [IsActive]
FROM [PatientVitals]
WHERE [lPatientDataId] = @patientDataId
  AND [IsActive] = 1
ORDER BY [InsertedOn] DESC, [lPatientVitalsId] DESC";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@patientDataId", patientDataId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<PatientVitalsDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(Map(reader));
        }

        return list;
    }

    public async Task<int?> GetPatientDataIdByVitalsIdAsync(int patientVitalsId, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 [lPatientDataId]
FROM [PatientVitals]
WHERE [lPatientVitalsId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", patientVitalsId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : Convert.ToInt32(result);
    }

    public async Task<int> CreateAsync(SavePatientVitalsRequest request, int insertedByAppUserId, CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO [PatientVitals]([lPatientDataId], [BPSys], [BPDys], [BloodSugar], [Pulse], [WeightKG], [InsertedOn], [InsertedBy], [HeightCMS], [IsActive])
OUTPUT INSERTED.[lPatientVitalsId]
VALUES(@patientDataId, @bpSys, @bpDys, @bloodSugar, @pulse, @weightKg, @insertedOn, @insertedBy, @heightCms, @isActive)";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await EnsurePatientExistsAsync(con, request.PatientDataId, cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        Bind(cmd, request);
        cmd.Parameters.AddWithValue("@insertedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@insertedBy", insertedByAppUserId);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task<bool> UpdateAsync(int patientVitalsId, SavePatientVitalsRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientVitals]
SET [BPSys] = @bpSys,
    [BPDys] = @bpDys,
    [BloodSugar] = @bloodSugar,
    [Pulse] = @pulse,
    [WeightKG] = @weightKg,
    [HeightCMS] = @heightCms,
    [IsActive] = @isActive
WHERE [lPatientVitalsId] = @id
  AND [lPatientDataId] = @patientDataId";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await EnsurePatientExistsAsync(con, request.PatientDataId, cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        Bind(cmd, request);
        cmd.Parameters.AddWithValue("@id", patientVitalsId);
        var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);
        return rows > 0;
    }

    public async Task<bool> DeleteAsync(int patientVitalsId, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientVitals]
SET [IsActive] = 0
WHERE [lPatientVitalsId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", patientVitalsId);
        var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);
        return rows > 0;
    }

    private static void Bind(SqlCommand cmd, SavePatientVitalsRequest request)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@bpSys", request.BPSys);
        cmd.Parameters.AddWithValue("@bpDys", request.BPDys);
        cmd.Parameters.AddWithValue("@bloodSugar", request.BloodSugar);
        cmd.Parameters.AddWithValue("@pulse", request.Pulse);
        cmd.Parameters.AddWithValue("@weightKg", request.WeightKG);
        cmd.Parameters.AddWithValue("@heightCms", request.HeightCMS);
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

    private static PatientVitalsDto Map(SqlDataReader reader)
    {
        return new PatientVitalsDto
        {
            PatientVitalsId = SafeInt(reader["lPatientVitalsId"]),
            PatientDataId = SafeInt(reader["lPatientDataId"]),
            BPSys = SafeInt(reader["BPSys"]),
            BPDys = SafeInt(reader["BPDys"]),
            BloodSugar = SafeInt(reader["BloodSugar"]),
            Pulse = SafeInt(reader["Pulse"]),
            WeightKG = SafeInt(reader["WeightKG"]),
            HeightCMS = SafeInt(reader["HeightCMS"]),
            InsertedOn = reader["InsertedOn"] is DateTime dt ? dt : DateTime.MinValue,
            InsertedBy = SafeInt(reader["InsertedBy"]),
            IsActive = SafeBool(reader["IsActive"])
        };
    }

    private static int SafeInt(object? value)
    {
        if (value is null or DBNull)
        {
            return 0;
        }

        return Convert.ToInt32(value);
    }

    private static bool SafeBool(object? value)
    {
        if (value is null or DBNull)
        {
            return false;
        }

        return Convert.ToBoolean(value);
    }
}
