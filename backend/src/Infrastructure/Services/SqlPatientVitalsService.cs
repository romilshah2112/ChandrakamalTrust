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
SELECT
    vs.[lPatientVitalSignsId] AS [lPatientVitalsId],
    vs.[lPatientDataId],
    vs.[BPSys],
    vs.[BPDys],
    ISNULL(bs.[BloodSugar], 0) AS [BloodSugar],
    ISNULL(bs.[SugarType], '') AS [SugarType],
    vs.[Pulse],
    ISNULL(bm.[WeightKG], 0) AS [WeightKG],
    ISNULL(bm.[HeightCMS], 0) AS [HeightCMS],
    ISNULL(bm.[BMI], 0) AS [BMI],
    vs.[MeasuredOn] AS [InsertedOn],
    vs.[InsertedBy],
    vs.[IsActive]
FROM [PatientVitalSigns] vs
OUTER APPLY (
    SELECT TOP 1 [WeightKG], [HeightCMS], [BMI]
    FROM [PatientBodyMeasurement] bm
    WHERE bm.[lPatientDataId] = vs.[lPatientDataId]
      AND bm.[MeasuredOn] = vs.[MeasuredOn]
      AND ISNULL(bm.[IsActive], 1) = 1
    ORDER BY bm.[lPatientBodyMeasurementId] DESC
) bm
OUTER APPLY (
    SELECT TOP 1 [BloodSugar], [SugarType]
    FROM [PatientBloodSugar] bs
    WHERE bs.[lPatientDataId] = vs.[lPatientDataId]
      AND bs.[MeasuredOn] = vs.[MeasuredOn]
      AND ISNULL(bs.[IsActive], 1) = 1
    ORDER BY bs.[lPatientBloodSugarId] DESC
) bs
WHERE vs.[lPatientDataId] = @patientDataId
  AND ISNULL(vs.[IsActive], 1) = 1
ORDER BY vs.[MeasuredOn] DESC, vs.[lPatientVitalSignsId] DESC";

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
FROM [PatientVitalSigns]
WHERE [lPatientVitalSignsId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", patientVitalsId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : Convert.ToInt32(result);
    }

    public async Task<int> CreateAsync(SavePatientVitalsRequest request, int insertedByAppUserId, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await EnsurePatientExistsAsync(con, request.PatientDataId, cancellationToken);
        await using var tx = await con.BeginTransactionAsync(cancellationToken);

        try
        {
            var measuredOn = request.MeasuredOn == default
                ? DateTime.UtcNow
                : request.MeasuredOn.ToUniversalTime();
            var vitalSignsId = await InsertVitalSignsAsync(con, (SqlTransaction)tx, request, insertedByAppUserId, measuredOn, cancellationToken);
            // Insert only the groups provided
            if (request.WeightKG > 0 || request.HeightCMS > 0)
            {
                await InsertBodyMeasurementAsync(con, (SqlTransaction)tx, request, insertedByAppUserId, measuredOn, cancellationToken);
            }

            if (request.BloodSugar > 0)
            {
                await InsertBloodSugarAsync(con, (SqlTransaction)tx, request, insertedByAppUserId, measuredOn, cancellationToken);
            }
            await tx.CommitAsync(cancellationToken);
            return vitalSignsId;
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task<bool> UpdateAsync(int patientVitalsId, SavePatientVitalsRequest request, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await EnsurePatientExistsAsync(con, request.PatientDataId, cancellationToken);

        var existing = await GetExistingVitalSignsAsync(con, patientVitalsId, cancellationToken);
        if (existing is null || existing.Value.PatientDataId != request.PatientDataId)
        {
            return false;
        }

        var newMeasuredOn = request.MeasuredOn == default
            ? existing.Value.MeasuredOn
            : request.MeasuredOn.ToUniversalTime();

        await using var tx = await con.BeginTransactionAsync(cancellationToken);
        try
        {
            if (newMeasuredOn != existing.Value.MeasuredOn)
            {
                await UpdateBodyMeasurementMeasuredOnAsync(
                    con,
                    (SqlTransaction)tx,
                    request.PatientDataId,
                    existing.Value.MeasuredOn,
                    newMeasuredOn,
                    cancellationToken);
                await UpdateBloodSugarMeasuredOnAsync(
                    con,
                    (SqlTransaction)tx,
                    request.PatientDataId,
                    existing.Value.MeasuredOn,
                    newMeasuredOn,
                    cancellationToken);
            }

            const string vitalSql = @"
UPDATE [PatientVitalSigns]
SET [BPSys] = @bpSys,
    [BPDys] = @bpDys,
    [Pulse] = @pulse,
    [MeasuredOn] = @measuredOn,
    [IsActive] = @isActive
WHERE [lPatientVitalSignsId] = @id
  AND [lPatientDataId] = @patientDataId";

            await using (var cmd = new SqlCommand(vitalSql, con, (SqlTransaction)tx))
            {
                cmd.Parameters.AddWithValue("@id", patientVitalsId);
                BindVitalSigns(cmd, request);
                cmd.Parameters.AddWithValue("@measuredOn", newMeasuredOn);
                await cmd.ExecuteNonQueryAsync(cancellationToken);
            }

            // Upsert only groups that were provided in the request
            if (request.WeightKG > 0 || request.HeightCMS > 0)
            {
                await UpsertBodyMeasurementAsync(con, (SqlTransaction)tx, request, existing.Value.InsertedBy, newMeasuredOn, cancellationToken);
            }

            if (request.BloodSugar > 0)
            {
                await UpsertBloodSugarAsync(con, (SqlTransaction)tx, request, existing.Value.InsertedBy, newMeasuredOn, cancellationToken);
            }
            await tx.CommitAsync(cancellationToken);
            return true;
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task<bool> DeleteAsync(int patientVitalsId, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var existing = await GetExistingVitalSignsAsync(con, patientVitalsId, cancellationToken);
        if (existing is null)
        {
            return false;
        }

        await using var tx = await con.BeginTransactionAsync(cancellationToken);
        try
        {
            const string vitalSql = @"UPDATE [PatientVitalSigns] SET [IsActive] = 0 WHERE [lPatientVitalSignsId] = @id";
            await using (var cmd = new SqlCommand(vitalSql, con, (SqlTransaction)tx))
            {
                cmd.Parameters.AddWithValue("@id", patientVitalsId);
                await cmd.ExecuteNonQueryAsync(cancellationToken);
            }

            const string bodySql = @"
UPDATE [PatientBodyMeasurement]
SET [IsActive] = 0
WHERE [lPatientDataId] = @patientDataId
  AND [MeasuredOn] = @measuredOn";
            await using (var cmd = new SqlCommand(bodySql, con, (SqlTransaction)tx))
            {
                cmd.Parameters.AddWithValue("@patientDataId", existing.Value.PatientDataId);
                cmd.Parameters.AddWithValue("@measuredOn", existing.Value.MeasuredOn);
                await cmd.ExecuteNonQueryAsync(cancellationToken);
            }

            const string sugarSql = @"
UPDATE [PatientBloodSugar]
SET [IsActive] = 0
WHERE [lPatientDataId] = @patientDataId
  AND [MeasuredOn] = @measuredOn";
            await using (var cmd = new SqlCommand(sugarSql, con, (SqlTransaction)tx))
            {
                cmd.Parameters.AddWithValue("@patientDataId", existing.Value.PatientDataId);
                cmd.Parameters.AddWithValue("@measuredOn", existing.Value.MeasuredOn);
                await cmd.ExecuteNonQueryAsync(cancellationToken);
            }

            await tx.CommitAsync(cancellationToken);
            return true;
        }
        catch
        {
            await tx.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static async Task<int> InsertVitalSignsAsync(
        SqlConnection con,
        SqlTransaction tx,
        SavePatientVitalsRequest request,
        int insertedBy,
        DateTime measuredOn,
        CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO [PatientVitalSigns]([lPatientDataId], [BPSys], [BPDys], [Pulse], [MeasuredOn], [InsertedBy], [IsActive])
OUTPUT INSERTED.[lPatientVitalSignsId]
VALUES(@patientDataId, @bpSys, @bpDys, @pulse, @measuredOn, @insertedBy, @isActive)";

        await using var cmd = new SqlCommand(sql, con, tx);
        BindVitalSigns(cmd, request);
        cmd.Parameters.AddWithValue("@measuredOn", measuredOn);
        cmd.Parameters.AddWithValue("@insertedBy", insertedBy);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    private static async Task InsertBodyMeasurementAsync(
        SqlConnection con,
        SqlTransaction tx,
        SavePatientVitalsRequest request,
        int insertedBy,
        DateTime measuredOn,
        CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO [PatientBodyMeasurement]([lPatientDataId], [HeightCMS], [WeightKG], [BMI], [MeasuredOn], [InsertedBy], [IsActive])
VALUES(@patientDataId, @heightCms, @weightKg, @bmi, @measuredOn, @insertedBy, @isActive)";

        await using var cmd = new SqlCommand(sql, con, tx);
        BindBodyMeasurement(cmd, request);
        cmd.Parameters.AddWithValue("@measuredOn", measuredOn);
        cmd.Parameters.AddWithValue("@insertedBy", insertedBy);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task InsertBloodSugarAsync(
        SqlConnection con,
        SqlTransaction tx,
        SavePatientVitalsRequest request,
        int insertedBy,
        DateTime measuredOn,
        CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO [PatientBloodSugar]([lPatientDataId], [BloodSugar], [SugarType], [MeasuredOn], [InsertedBy], [IsActive])
VALUES(@patientDataId, @bloodSugar, @sugarType, @measuredOn, @insertedBy, @isActive)";

        await using var cmd = new SqlCommand(sql, con, tx);
        BindBloodSugar(cmd, request);
        cmd.Parameters.AddWithValue("@measuredOn", measuredOn);
        cmd.Parameters.AddWithValue("@insertedBy", insertedBy);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task UpsertBodyMeasurementAsync(
        SqlConnection con,
        SqlTransaction tx,
        SavePatientVitalsRequest request,
        int insertedBy,
        DateTime measuredOn,
        CancellationToken cancellationToken)
    {
        const string updateSql = @"
UPDATE [PatientBodyMeasurement]
SET [HeightCMS] = @heightCms,
    [WeightKG] = @weightKg,
    [BMI] = @bmi,
    [IsActive] = @isActive
WHERE [lPatientBodyMeasurementId] = (
    SELECT TOP 1 [lPatientBodyMeasurementId]
    FROM [PatientBodyMeasurement]
    WHERE [lPatientDataId] = @patientDataId
      AND [MeasuredOn] = @measuredOn
    ORDER BY [lPatientBodyMeasurementId] DESC
)";

        await using (var cmd = new SqlCommand(updateSql, con, tx))
        {
            BindBodyMeasurement(cmd, request);
            cmd.Parameters.AddWithValue("@measuredOn", measuredOn);
            var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);
            if (rows > 0)
            {
                return;
            }
        }

        await InsertBodyMeasurementAsync(con, tx, request, insertedBy, measuredOn, cancellationToken);
    }

    private static async Task UpsertBloodSugarAsync(
        SqlConnection con,
        SqlTransaction tx,
        SavePatientVitalsRequest request,
        int insertedBy,
        DateTime measuredOn,
        CancellationToken cancellationToken)
    {
        const string updateSql = @"
UPDATE [PatientBloodSugar]
SET [BloodSugar] = @bloodSugar,
    [SugarType] = @sugarType,
    [IsActive] = @isActive
WHERE [lPatientBloodSugarId] = (
    SELECT TOP 1 [lPatientBloodSugarId]
    FROM [PatientBloodSugar]
    WHERE [lPatientDataId] = @patientDataId
      AND [MeasuredOn] = @measuredOn
    ORDER BY [lPatientBloodSugarId] DESC
)";

        await using (var cmd = new SqlCommand(updateSql, con, tx))
        {
            BindBloodSugar(cmd, request);
            cmd.Parameters.AddWithValue("@measuredOn", measuredOn);
            var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);
            if (rows > 0)
            {
                return;
            }
        }

        await InsertBloodSugarAsync(con, tx, request, insertedBy, measuredOn, cancellationToken);
    }

    private static async Task UpdateBodyMeasurementMeasuredOnAsync(
        SqlConnection con,
        SqlTransaction tx,
        int patientDataId,
        DateTime oldMeasuredOn,
        DateTime newMeasuredOn,
        CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientBodyMeasurement]
SET [MeasuredOn] = @newMeasuredOn
WHERE [lPatientDataId] = @patientDataId
  AND [MeasuredOn] = @oldMeasuredOn";

        await using var cmd = new SqlCommand(sql, con, tx);
        cmd.Parameters.AddWithValue("@patientDataId", patientDataId);
        cmd.Parameters.AddWithValue("@oldMeasuredOn", oldMeasuredOn);
        cmd.Parameters.AddWithValue("@newMeasuredOn", newMeasuredOn);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task UpdateBloodSugarMeasuredOnAsync(
        SqlConnection con,
        SqlTransaction tx,
        int patientDataId,
        DateTime oldMeasuredOn,
        DateTime newMeasuredOn,
        CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientBloodSugar]
SET [MeasuredOn] = @newMeasuredOn
WHERE [lPatientDataId] = @patientDataId
  AND [MeasuredOn] = @oldMeasuredOn";

        await using var cmd = new SqlCommand(sql, con, tx);
        cmd.Parameters.AddWithValue("@patientDataId", patientDataId);
        cmd.Parameters.AddWithValue("@oldMeasuredOn", oldMeasuredOn);
        cmd.Parameters.AddWithValue("@newMeasuredOn", newMeasuredOn);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<(int PatientDataId, DateTime MeasuredOn, int InsertedBy)?> GetExistingVitalSignsAsync(
        SqlConnection con,
        int patientVitalsId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 [lPatientDataId], [MeasuredOn], [InsertedBy]
FROM [PatientVitalSigns]
WHERE [lPatientVitalSignsId] = @id";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", patientVitalsId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return (
            SafeInt(reader["lPatientDataId"]),
            SafeDateTime(reader["MeasuredOn"]),
            SafeInt(reader["InsertedBy"]));
    }

    private static void BindVitalSigns(SqlCommand cmd, SavePatientVitalsRequest request)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@bpSys", request.BPSys);
        cmd.Parameters.AddWithValue("@bpDys", request.BPDys);
        cmd.Parameters.AddWithValue("@pulse", request.Pulse);
        cmd.Parameters.AddWithValue("@isActive", request.IsActive);
    }

    private static void BindBodyMeasurement(SqlCommand cmd, SavePatientVitalsRequest request)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@heightCms", request.HeightCMS);
        cmd.Parameters.AddWithValue("@weightKg", request.WeightKG);
        cmd.Parameters.AddWithValue("@bmi", CalculateBmi(request.HeightCMS, request.WeightKG));
        cmd.Parameters.AddWithValue("@isActive", request.IsActive);
    }

    private static void BindBloodSugar(SqlCommand cmd, SavePatientVitalsRequest request)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@bloodSugar", request.BloodSugar);
        cmd.Parameters.AddWithValue("@sugarType", string.IsNullOrWhiteSpace(request.SugarType) ? "Random" : request.SugarType.Trim());
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
            BloodSugar = SafeDouble(reader["BloodSugar"]),
            SugarType = reader["SugarType"]?.ToString() ?? string.Empty,
            Pulse = SafeInt(reader["Pulse"]),
            WeightKG = SafeDouble(reader["WeightKG"]),
            HeightCMS = SafeDouble(reader["HeightCMS"]),
            BMI = SafeDouble(reader["BMI"]),
            InsertedOn = SafeDateTime(reader["InsertedOn"]),
            InsertedBy = SafeInt(reader["InsertedBy"]),
            IsActive = SafeBool(reader["IsActive"])
        };
    }

    private static double CalculateBmi(double heightCms, double weightKg)
    {
        if (heightCms <= 0 || weightKg <= 0)
        {
            return 0;
        }

        var heightMeters = heightCms / 100d;
        return Math.Round(weightKg / (heightMeters * heightMeters), 2);
    }

    private static int SafeInt(object? value)
    {
        if (value is null or DBNull)
        {
            return 0;
        }

        return Convert.ToInt32(value);
    }

    private static double SafeDouble(object? value)
    {
        if (value is null or DBNull)
        {
            return 0;
        }

        return Convert.ToDouble(value);
    }

    private static DateTime SafeDateTime(object? value)
    {
        if (value is null or DBNull)
        {
            return DateTime.MinValue;
        }

        return Convert.ToDateTime(value);
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
