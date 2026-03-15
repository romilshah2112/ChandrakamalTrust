using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlDoctorAnalyticsService : IDoctorAnalyticsService
{
    private readonly string _connectionString;

    public SqlDoctorAnalyticsService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<DoctorDashboardAnalyticsDto> GetDashboardAsync(
        int appUserId,
        string roleName,
        CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var isDoctor = roleName.Contains("doctor", StringComparison.OrdinalIgnoreCase);
        var doctorProfileId = await ResolveDoctorProfileIdAsync(con, appUserId, cancellationToken);
        if (isDoctor && doctorProfileId <= 0)
        {
            return new DoctorDashboardAnalyticsDto();
        }

        var today = DateTime.Today;
        var tomorrow = today.AddDays(1);
        var weekStart = StartOfWeek(today, DayOfWeek.Monday);
        var weekEndExclusive = weekStart.AddDays(7);
        var monthStart = new DateTime(today.Year, today.Month, 1);
        var monthEndExclusive = monthStart.AddMonths(1);

        var todayAppointments = await LoadTodayAppointmentsAsync(con, today, tomorrow, doctorProfileId, cancellationToken);
        var patientsByGender = await LoadPatientsByGenderAsync(con, doctorProfileId, cancellationToken);
        var patientsByAgeGroup = await LoadPatientsByAgeGroupAsync(con, doctorProfileId, cancellationToken);
        var revenueForDay = await LoadRevenueForDayAsync(con, today, tomorrow, doctorProfileId, cancellationToken);
        var revenueByWeek = await LoadRevenueByWeekAsync(con, weekStart, weekEndExclusive, doctorProfileId, cancellationToken);
        var revenueByMonth = await LoadRevenueByMonthAsync(con, monthStart, monthEndExclusive, doctorProfileId, cancellationToken);

        return new DoctorDashboardAnalyticsDto
        {
            TodayAppointments = todayAppointments,
            PatientsByGender = patientsByGender,
            PatientsByAgeGroup = patientsByAgeGroup,
            RevenueForDay = revenueForDay,
            RevenueByWeek = revenueByWeek,
            RevenueByMonth = revenueByMonth,
        };
    }

    private static async Task<int> ResolveDoctorProfileIdAsync(
        SqlConnection con,
        int appUserId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 [lDoctorProfileId]
FROM [DoctorProfile]
WHERE [lAppUserId] = @appUserId
  AND ISNULL([IsActive], 1) = 1";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@appUserId", appUserId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? 0 : Convert.ToInt32(result);
    }

    private static async Task<IReadOnlyList<DoctorAppointmentSummaryDto>> LoadTodayAppointmentsAsync(
        SqlConnection con,
        DateTime from,
        DateTime toExclusive,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    ISNULL(pd.[FirstName], '') + CASE WHEN pd.[LastName] IS NULL OR pd.[LastName] = '' THEN '' ELSE ' ' + pd.[LastName] END AS [PatientName],
    pa.[StartTime],
    pa.[EndTime],
    ISNULL(c.[ClinicName], '') AS [ClinicName]
FROM [PatientAppointment] pa
LEFT JOIN [patientdata] pd ON pd.[lPatientDataId] = pa.[lPatientDataId]
LEFT JOIN [Clinic] c ON c.[lClinicId] = pa.[lClinicId]
WHERE ISNULL(pa.[IsActive], 1) = 1
  AND pa.[StartTime] >= @from
  AND pa.[StartTime] < @toExclusive
  AND (@doctorProfileId = 0 OR pa.[lDoctorProfileId] = @doctorProfileId)
ORDER BY pa.[StartTime] ASC";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@from", from);
        cmd.Parameters.AddWithValue("@toExclusive", toExclusive);
        cmd.Parameters.AddWithValue("@doctorProfileId", doctorProfileId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<DoctorAppointmentSummaryDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new DoctorAppointmentSummaryDto
            {
                PatientName = reader["PatientName"]?.ToString() ?? string.Empty,
                StartTime = SafeDateTime(reader["StartTime"]),
                EndTime = SafeDateTime(reader["EndTime"]),
                ClinicName = reader["ClinicName"]?.ToString() ?? string.Empty,
            });
        }

        return list;
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPatientsByGenderAsync(
        SqlConnection con,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    CASE
        WHEN pd.[Gender] IS NULL OR LTRIM(RTRIM(pd.[Gender])) = '' THEN 'Unknown'
        ELSE LTRIM(RTRIM(pd.[Gender]))
    END AS [Label],
    COUNT(DISTINCT pd.[lPatientDataId]) AS [Value]
FROM [PatientAppointment] pa
INNER JOIN [patientdata] pd ON pd.[lPatientDataId] = pa.[lPatientDataId]
WHERE ISNULL(pa.[IsActive], 1) = 1
  AND (@doctorProfileId = 0 OR pa.[lDoctorProfileId] = @doctorProfileId)
GROUP BY
    CASE
        WHEN pd.[Gender] IS NULL OR LTRIM(RTRIM(pd.[Gender])) = '' THEN 'Unknown'
        ELSE LTRIM(RTRIM(pd.[Gender]))
    END
ORDER BY [Label]";

        return await LoadPointsAsync(con, sql, doctorProfileId, cancellationToken);
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPatientsByAgeGroupAsync(
        SqlConnection con,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
WITH PatientAges AS (
    SELECT DISTINCT
        pd.[lPatientDataId],
        CASE
            WHEN pd.[BirthDate] IS NULL THEN 'Unknown'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) < 18 THEN '0-17'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) BETWEEN 18 AND 30 THEN '18-30'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) BETWEEN 31 AND 45 THEN '31-45'
            WHEN DATEDIFF(YEAR, pd.[BirthDate], GETDATE()) BETWEEN 46 AND 60 THEN '46-60'
            ELSE '60+'
        END AS [Label]
    FROM [PatientAppointment] pa
    INNER JOIN [patientdata] pd ON pd.[lPatientDataId] = pa.[lPatientDataId]
    WHERE ISNULL(pa.[IsActive], 1) = 1
      AND (@doctorProfileId = 0 OR pa.[lDoctorProfileId] = @doctorProfileId)
)
SELECT [Label], COUNT(1) AS [Value]
FROM PatientAges
GROUP BY [Label]";

        var points = await LoadPointsAsync(con, sql, doctorProfileId, cancellationToken);
        var orderedLabels = new[] { "0-17", "18-30", "31-45", "46-60", "60+", "Unknown" };
        return orderedLabels
            .Select(label => points.FirstOrDefault(point => point.Label == label) ?? new AnalyticsPointDto { Label = label, Value = 0 })
            .ToList();
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadRevenueForDayAsync(
        SqlConnection con,
        DateTime from,
        DateTime toExclusive,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    ISNULL(it.[InvType], 'Other') AS [Label],
    SUM(ISNULL(id.[InvoiceAmount], 0) - ISNULL(id.[Deduction], 0)) AS [Value]
FROM [InvoiceMaster] im
INNER JOIN [InvoiceDetail] id ON id.[lInvoiceMasterId] = im.[lInvoiceMasterId]
LEFT JOIN [InvoiceType] it ON it.[lInvoiceTypeId] = id.[lInvoiceTypeId]
WHERE ISNULL(im.[IsActive], 1) = 1
  AND im.[InvoiceDate] >= @from
  AND im.[InvoiceDate] < @toExclusive
  AND (@doctorProfileId = 0 OR im.[lDoctorProfileId] = @doctorProfileId)
GROUP BY ISNULL(it.[InvType], 'Other')
ORDER BY [Value] DESC";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@from", from);
        cmd.Parameters.AddWithValue("@toExclusive", toExclusive);
        cmd.Parameters.AddWithValue("@doctorProfileId", doctorProfileId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<AnalyticsPointDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AnalyticsPointDto
            {
                Label = reader["Label"]?.ToString() ?? string.Empty,
                Value = SafeDouble(reader["Value"]),
            });
        }

        return list;
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadRevenueByWeekAsync(
        SqlConnection con,
        DateTime weekStart,
        DateTime weekEndExclusive,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    CAST(im.[InvoiceDate] AS date) AS [BucketDate],
    SUM(ISNULL(id.[InvoiceAmount], 0) - ISNULL(id.[Deduction], 0)) AS [Value]
FROM [InvoiceMaster] im
INNER JOIN [InvoiceDetail] id ON id.[lInvoiceMasterId] = im.[lInvoiceMasterId]
WHERE ISNULL(im.[IsActive], 1) = 1
  AND im.[InvoiceDate] >= @from
  AND im.[InvoiceDate] < @toExclusive
  AND (@doctorProfileId = 0 OR im.[lDoctorProfileId] = @doctorProfileId)
GROUP BY CAST(im.[InvoiceDate] AS date)";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@from", weekStart);
        cmd.Parameters.AddWithValue("@toExclusive", weekEndExclusive);
        cmd.Parameters.AddWithValue("@doctorProfileId", doctorProfileId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var map = new Dictionary<DateTime, double>();
        while (await reader.ReadAsync(cancellationToken))
        {
            map[SafeDateTime(reader["BucketDate"]).Date] = SafeDouble(reader["Value"]);
        }

        return Enumerable.Range(0, 7)
            .Select(index =>
            {
                var date = weekStart.AddDays(index).Date;
                return new AnalyticsPointDto
                {
                    Label = date.ToString("ddd"),
                    Value = map.TryGetValue(date, out var value) ? value : 0,
                };
            })
            .ToList();
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadRevenueByMonthAsync(
        SqlConnection con,
        DateTime monthStart,
        DateTime monthEndExclusive,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    ((DATEPART(DAY, im.[InvoiceDate]) - 1) / 7) + 1 AS [WeekIndex],
    SUM(ISNULL(id.[InvoiceAmount], 0) - ISNULL(id.[Deduction], 0)) AS [Value]
FROM [InvoiceMaster] im
INNER JOIN [InvoiceDetail] id ON id.[lInvoiceMasterId] = im.[lInvoiceMasterId]
WHERE ISNULL(im.[IsActive], 1) = 1
  AND im.[InvoiceDate] >= @from
  AND im.[InvoiceDate] < @toExclusive
  AND (@doctorProfileId = 0 OR im.[lDoctorProfileId] = @doctorProfileId)
GROUP BY ((DATEPART(DAY, im.[InvoiceDate]) - 1) / 7) + 1";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@from", monthStart);
        cmd.Parameters.AddWithValue("@toExclusive", monthEndExclusive);
        cmd.Parameters.AddWithValue("@doctorProfileId", doctorProfileId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var map = new Dictionary<int, double>();
        while (await reader.ReadAsync(cancellationToken))
        {
            map[SafeInt(reader["WeekIndex"])] = SafeDouble(reader["Value"]);
        }

        var totalWeeks = ((DateTime.DaysInMonth(monthStart.Year, monthStart.Month) - 1) / 7) + 1;
        return Enumerable.Range(1, totalWeeks)
            .Select(index => new AnalyticsPointDto
            {
                Label = $"W{index}",
                Value = map.TryGetValue(index, out var value) ? value : 0,
            })
            .ToList();
    }

    private static async Task<IReadOnlyList<AnalyticsPointDto>> LoadPointsAsync(
        SqlConnection con,
        string sql,
        int doctorProfileId,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@doctorProfileId", doctorProfileId);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<AnalyticsPointDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AnalyticsPointDto
            {
                Label = reader["Label"]?.ToString() ?? string.Empty,
                Value = SafeDouble(reader["Value"]),
            });
        }

        return list;
    }

    private static DateTime StartOfWeek(DateTime date, DayOfWeek startOfWeek)
    {
        var diff = (7 + (date.DayOfWeek - startOfWeek)) % 7;
        return date.Date.AddDays(-diff);
    }

    private static int SafeInt(object value) => value is DBNull ? 0 : Convert.ToInt32(value);
    private static double SafeDouble(object value) => value is DBNull ? 0d : Convert.ToDouble(value);
    private static DateTime SafeDateTime(object value) => value is DBNull ? DateTime.MinValue : Convert.ToDateTime(value);
}
