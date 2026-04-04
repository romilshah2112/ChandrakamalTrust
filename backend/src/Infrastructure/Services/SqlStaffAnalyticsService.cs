using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlStaffAnalyticsService : IStaffAnalyticsService
{
    private const int HealthCampReferenceTypeId = 6;

    private readonly string _connectionString;

    public SqlStaffAnalyticsService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<StaffDashboardAnalyticsDto> GetDashboardAsync(CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var patientsByGender = await LoadPatientsByGenderAsync(con, cancellationToken);
        var patientsByAgeGroup = await LoadPatientsByAgeGroupAsync(con, cancellationToken);
        var patientsByCity = await LoadPatientsByCityAsync(con, cancellationToken);
        var patientsByBPSystolicRange = await LoadPatientsByVitalsRangeAsync(
            con,
            "BPSys",
            cancellationToken);
        var patientsByBPDiastolicRange = await LoadPatientsByVitalsRangeAsync(
            con,
            "BPDys",
            cancellationToken);
        var patientsByBloodSugarRange = await LoadPatientsByVitalsRangeAsync(
            con,
            "BloodSugar",
            cancellationToken);

        return new StaffDashboardAnalyticsDto
        {
            PatientsByGender = patientsByGender,
            PatientsByAgeGroup = patientsByAgeGroup,
            PatientsByCity = patientsByCity,
            PatientsByBPSystolicRange = patientsByBPSystolicRange,
            PatientsByBPDiastolicRange = patientsByBPDiastolicRange,
            PatientsByBloodSugarRange = patientsByBloodSugarRange,
        };
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPatientsByGenderAsync(
        SqlConnection con,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    CASE
        WHEN pd.[Gender] IS NULL OR LTRIM(RTRIM(pd.[Gender])) = '' THEN 'Unknown'
        ELSE LTRIM(RTRIM(pd.[Gender]))
    END AS [Label],
    COUNT(1) AS [Value]
FROM [patientdata] pd
WHERE ISNULL(pd.[IsActive], 1) = 1
  AND pd.[lReferenceTypeId] = @healthCampReferenceTypeId
GROUP BY
    CASE
        WHEN pd.[Gender] IS NULL OR LTRIM(RTRIM(pd.[Gender])) = '' THEN 'Unknown'
        ELSE LTRIM(RTRIM(pd.[Gender]))
    END
ORDER BY [Label]";

        return await LoadPointsAsync(con, sql, cancellationToken);
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPatientsByAgeGroupAsync(
        SqlConnection con,
        CancellationToken cancellationToken)
    {
        const string sql = @"
WITH PatientAges AS (
    SELECT
        CASE
            WHEN pd.[BirthDate] IS NULL THEN 'Unknown'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) < 18 THEN '0-17'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) BETWEEN 18 AND 30 THEN '18-30'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) BETWEEN 31 AND 45 THEN '31-45'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) BETWEEN 46 AND 60 THEN '46-60'
            ELSE '60+'
        END AS [Label]
    FROM [patientdata] pd
    WHERE ISNULL(pd.[IsActive], 1) = 1
      AND pd.[lReferenceTypeId] = @healthCampReferenceTypeId
)
SELECT [Label], COUNT(1) AS [Value]
FROM PatientAges
GROUP BY [Label]";

        var points = await LoadPointsAsync(con, sql, cancellationToken);
        var orderedLabels = new[] { "0-17", "18-30", "31-45", "46-60", "60+", "Unknown" };
        return orderedLabels
            .Select(label => points.FirstOrDefault(point => point.Label == label) ?? new AnalyticsPointDto { Label = label, Value = 0 })
            .ToList();
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPatientsByCityAsync(
        SqlConnection con,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    CASE
        WHEN pd.[City] IS NULL OR LTRIM(RTRIM(pd.[City])) = '' THEN 'Unknown'
        ELSE LTRIM(RTRIM(pd.[City]))
    END AS [Label],
    COUNT(1) AS [Value]
FROM [patientdata] pd
WHERE ISNULL(pd.[IsActive], 1) = 1
  AND pd.[lReferenceTypeId] = @healthCampReferenceTypeId
GROUP BY
    CASE
        WHEN pd.[City] IS NULL OR LTRIM(RTRIM(pd.[City])) = '' THEN 'Unknown'
        ELSE LTRIM(RTRIM(pd.[City]))
    END
ORDER BY [Value] DESC, [Label]";

        return await LoadPointsAsync(con, sql, cancellationToken);
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPatientsByVitalsRangeAsync(
        SqlConnection con,
        string metricColumn,
        CancellationToken cancellationToken)
    {
        var sql = $@"
WITH RankedVitals AS (
    SELECT
        pv.[lPatientDataId],
        pv.[{metricColumn}] AS [MetricValue],
        ROW_NUMBER() OVER (
            PARTITION BY pv.[lPatientDataId]
            ORDER BY pv.[InsertedOn] DESC, pv.[lPatientVitalsId] DESC
        ) AS [RowNum]
    FROM [PatientVitals] pv
    INNER JOIN [patientdata] pd ON pd.[lPatientDataId] = pv.[lPatientDataId]
    WHERE ISNULL(pd.[IsActive], 1) = 1
      AND pd.[lReferenceTypeId] = @healthCampReferenceTypeId
      AND ISNULL(pv.[IsActive], 1) = 1
),
Bucketed AS (
    SELECT
        CASE
            WHEN [MetricValue] < 80 THEN '< 80'
            WHEN [MetricValue] >= 80 AND [MetricValue] < 100 THEN '80 - 100'
            WHEN [MetricValue] >= 100 AND [MetricValue] < 120 THEN '100 - 120'
            WHEN [MetricValue] >= 120 AND [MetricValue] < 140 THEN '120 - 140'
            WHEN [MetricValue] >= 140 AND [MetricValue] <= 160 THEN '140 - 160'
            WHEN [MetricValue] > 160 THEN '> 160'
            ELSE 'Unknown'
        END AS [Label]
    FROM RankedVitals
    WHERE [RowNum] = 1
)
SELECT [Label], COUNT(1) AS [Value]
FROM Bucketed
GROUP BY [Label]";

        var points = await LoadPointsAsync(con, sql, cancellationToken);
        var orderedLabels = new[] { "< 80", "80 - 100", "100 - 120", "120 - 140", "140 - 160", "> 160", "Unknown" };
        return orderedLabels
            .Select(label => points.FirstOrDefault(point => point.Label == label) ?? new AnalyticsPointDto { Label = label, Value = 0 })
            .ToList();
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPointsAsync(
        SqlConnection con,
        string sql,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@healthCampReferenceTypeId", HealthCampReferenceTypeId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<AnalyticsPointDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AnalyticsPointDto
            {
                Label = reader["Label"]?.ToString() ?? string.Empty,
                Value = reader["Value"] is DBNull ? 0d : Convert.ToDouble(reader["Value"]),
            });
        }

        return list;
    }
}
