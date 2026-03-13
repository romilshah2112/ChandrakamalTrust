using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Appointments;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlPatientAppointmentService : IPatientAppointmentService
{
    private static readonly string[] AppUserIdCandidates = ["lAppUserId", "AppUserId", "UserId", "Id"];
    private readonly string _connectionString;

    public SqlPatientAppointmentService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<AppointmentStatusLookupDto>> ListStatusesAsync(CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [lAppointmentStatusId], [AppointmentStatus], [Description]
FROM [AppointmentStatus]
ORDER BY [lAppointmentStatusId]";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<AppointmentStatusLookupDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AppointmentStatusLookupDto
            {
                AppointmentStatusId = SafeInt(reader["lAppointmentStatusId"]),
                AppointmentStatus = reader["AppointmentStatus"]?.ToString() ?? string.Empty,
                Description = reader["Description"]?.ToString() ?? string.Empty
            });
        }

        return list;
    }

    public async Task<IReadOnlyList<AppointmentTypeDto>> ListAppointmentTypesAsync(CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [lAppointmentTypeId], [AppointmentTypeName], [ReminderHoursBefore], [FollowUpReminderHoursAfter], [Description]
FROM [AppointmentType]
ORDER BY [lAppointmentTypeId]";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<AppointmentTypeDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AppointmentTypeDto
            {
                AppointmentTypeId = SafeInt(reader["lAppointmentTypeId"]),
                AppointmentTypeName = reader["AppointmentTypeName"]?.ToString() ?? string.Empty,
                ReminderHoursBefore = SafeInt(reader["ReminderHoursBefore"]),
                FollowUpReminderHoursAfter = SafeInt(reader["FollowUpReminderHoursAfter"]),
                Description = reader["Description"]?.ToString()
            });
        }

        return list;
    }

    public async Task<IReadOnlyList<PatientAppointmentDto>> ListAsync(
        DateTime? from,
        DateTime? to,
        int? clinicId,
        int appUserId,
        string role,
        CancellationToken cancellationToken)
    {
        var isPatientRole = role.Contains("patient", StringComparison.OrdinalIgnoreCase);

        const string sql = @"
SELECT
    pa.[lPatientAppointmentId],
    pa.[lPatientDataId],
    ISNULL(pd.[FirstName], '') + CASE WHEN pd.[LastName] IS NULL OR pd.[LastName] = '' THEN '' ELSE ' ' + pd.[LastName] END AS [PatientName],
    pa.[lDoctorProfileId],
    ISNULL(dp.[DoctorName], '') AS [DoctorName],
    pa.[lClinicId],
    ISNULL(c.[ClinicName], '') AS [ClinicName],
    pa.[StartTime],
    pa.[EndTime],
    pa.[lAppointmentStatusId],
    pa.[lAppointmentTypeId],
    at.[AppointmentTypeName],
    pa.[IsNotified],
    pa.[IsActive],
    pa.[InsertedOn],
    pa.[UpdatedOn],
    pa.[lEnteredById]
FROM [PatientAppointment] pa
LEFT JOIN [patientdata] pd ON pd.[lPatientDataId] = pa.[lPatientDataId]
LEFT JOIN [DoctorProfile] dp ON dp.[lDoctorProfileId] = pa.[lDoctorProfileId]
LEFT JOIN [Clinic] c ON c.[lClinicId] = pa.[lClinicId]
LEFT JOIN [AppointmentType] at ON at.[lAppointmentTypeId] = pa.[lAppointmentTypeId]
WHERE
    (@from IS NULL OR pa.[StartTime] >= @from)
    AND (@to IS NULL OR pa.[StartTime] <= @to)
    AND (@clinicId IS NULL OR pa.[lClinicId] = @clinicId)
    AND pa.[IsActive] = 1
    AND (
        @isPatientRole = 0
        OR pa.[lPatientDataId] IN (
            SELECT [lPatientDataId] FROM [patientdata] WHERE [lAppUserId] = @appUserId
        )
    )
ORDER BY pa.[StartTime] ASC, pa.[lPatientAppointmentId] ASC";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@from", (object?)from ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@to", (object?)to ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@clinicId", (object?)clinicId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@appUserId", appUserId);
        cmd.Parameters.AddWithValue("@isPatientRole", isPatientRole ? 1 : 0);

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<PatientAppointmentDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new PatientAppointmentDto
            {
                PatientAppointmentId = SafeInt(reader["lPatientAppointmentId"]),
                PatientDataId = SafeInt(reader["lPatientDataId"]),
                PatientName = reader["PatientName"]?.ToString() ?? string.Empty,
                DoctorProfileId = SafeInt(reader["lDoctorProfileId"]),
                DoctorName = reader["DoctorName"]?.ToString() ?? string.Empty,
                ClinicId = SafeInt(reader["lClinicId"]),
                ClinicName = reader["ClinicName"]?.ToString() ?? string.Empty,
                StartTime = SafeDateTime(reader["StartTime"]),
                EndTime = SafeDateTime(reader["EndTime"]),
                AppointmentStatusId = SafeInt(reader["lAppointmentStatusId"]),
                AppointmentTypeId = reader["lAppointmentTypeId"] is DBNull or null ? null : SafeInt(reader["lAppointmentTypeId"]),
                AppointmentTypeName = reader["AppointmentTypeName"]?.ToString(),
                IsNotified = SafeInt(reader["IsNotified"]),
                IsActive = SafeBool(reader["IsActive"]),
                InsertedOn = SafeNullableDateTime(reader["InsertedOn"]),
                UpdatedOn = SafeNullableDateTime(reader["UpdatedOn"]),
                EnteredById = SafeInt(reader["lEnteredById"])
            });
        }

        return list;
    }

    public async Task<int> CreateAsync(
        SavePatientAppointmentRequest request,
        int enteredById,
        string username,
        CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var resolvedAppUserId = await ResolveCanonicalAppUserIdAsync(
            con,
            enteredById,
            username,
            cancellationToken);
        var appUserFkColumns = await ResolvePatientAppointmentAppUserFkColumnsAsync(
            con,
            cancellationToken);
        await EnsureWithinClinicScheduleAsync(
            con,
            request.ClinicId,
            request.StartTime,
            request.EndTime,
            cancellationToken);
        await EnsureNoDoctorOverlapAsync(
            con,
            request.DoctorProfileId,
            request.StartTime,
            request.EndTime,
            null,
            cancellationToken);

        var sql = @"
INSERT INTO [PatientAppointment]
    ([lPatientDataId], [lDoctorProfileId], [lClinicId], [StartTime], [EndTime], [lAppointmentStatusId], [lAppointmentTypeId], [IsNotified], [IsActive], [InsertedOn], [UpdatedOn], [lEnteredById]";
        foreach (var fkColumn in appUserFkColumns)
        {
            if (!string.Equals(fkColumn, "lEnteredById", StringComparison.OrdinalIgnoreCase))
            {
                sql += $", [{fkColumn}]";
            }
        }

        sql += @")
OUTPUT INSERTED.[lPatientAppointmentId]
VALUES
    (@patientDataId, @doctorProfileId, @clinicId, @startTime, @endTime, @appointmentStatusId, @appointmentTypeId, @isNotified, @isActive, @insertedOn, @updatedOn, @enteredById";
        foreach (var fkColumn in appUserFkColumns)
        {
            if (!string.Equals(fkColumn, "lEnteredById", StringComparison.OrdinalIgnoreCase))
            {
                sql += $", @appUserFk_{fkColumn}";
            }
        }
        sql += ")";

        await using var cmd = new SqlCommand(sql, con);
        BindAppointment(cmd, request, resolvedAppUserId);
        foreach (var fkColumn in appUserFkColumns)
        {
            if (!string.Equals(fkColumn, "lEnteredById", StringComparison.OrdinalIgnoreCase))
            {
                cmd.Parameters.AddWithValue($"@appUserFk_{fkColumn}", resolvedAppUserId);
            }
        }
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateAsync(
        int patientAppointmentId,
        SavePatientAppointmentRequest request,
        int enteredById,
        string username,
        CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var resolvedAppUserId = await ResolveCanonicalAppUserIdAsync(
            con,
            enteredById,
            username,
            cancellationToken);
        var appUserFkColumns = await ResolvePatientAppointmentAppUserFkColumnsAsync(
            con,
            cancellationToken);
        await EnsureWithinClinicScheduleAsync(
            con,
            request.ClinicId,
            request.StartTime,
            request.EndTime,
            cancellationToken);
        await EnsureNoDoctorOverlapAsync(
            con,
            request.DoctorProfileId,
            request.StartTime,
            request.EndTime,
            patientAppointmentId,
            cancellationToken);

        var sql = @"
UPDATE [PatientAppointment]
SET
    [lPatientDataId] = @patientDataId,
    [lDoctorProfileId] = @doctorProfileId,
    [lClinicId] = @clinicId,
    [StartTime] = @startTime,
    [EndTime] = @endTime,
    [lAppointmentStatusId] = @appointmentStatusId,
    [lAppointmentTypeId] = @appointmentTypeId,
    [IsNotified] = @isNotified,
    [IsActive] = @isActive,
    [UpdatedOn] = @updatedOn,
    [lEnteredById] = @enteredById";
        foreach (var fkColumn in appUserFkColumns)
        {
            if (!string.Equals(fkColumn, "lEnteredById", StringComparison.OrdinalIgnoreCase))
            {
                sql += $", [{fkColumn}] = @appUserFk_{fkColumn}";
            }
        }

        sql += @"
WHERE [lPatientAppointmentId] = @appointmentId";

        await using var cmd = new SqlCommand(sql, con);
        BindAppointment(cmd, request, resolvedAppUserId);
        foreach (var fkColumn in appUserFkColumns)
        {
            if (!string.Equals(fkColumn, "lEnteredById", StringComparison.OrdinalIgnoreCase))
            {
                cmd.Parameters.AddWithValue($"@appUserFk_{fkColumn}", resolvedAppUserId);
            }
        }
        cmd.Parameters.AddWithValue("@appointmentId", patientAppointmentId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteAsync(int patientAppointmentId, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientAppointment]
SET [IsActive] = 0, [UpdatedOn] = @updatedOn
WHERE [lPatientAppointmentId] = @appointmentId";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@updatedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@appointmentId", patientAppointmentId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<AppointmentReminderCandidateDto>> ListDueForReminderAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    pa.[lPatientAppointmentId],
    pa.[lPatientDataId],
    ISNULL(pd.[FirstName], '') + CASE WHEN pd.[LastName] IS NULL OR pd.[LastName] = '' THEN '' ELSE ' ' + pd.[LastName] END AS [PatientName],
    ISNULL(pd.[Email], '') AS [PatientEmail],
    pa.[lDoctorProfileId],
    ISNULL(dp.[DoctorName], '') AS [DoctorName],
    pa.[lClinicId],
    ISNULL(c.[ClinicName], '') AS [ClinicName],
    pa.[StartTime],
    pa.[EndTime],
    pa.[lAppointmentTypeId],
    at.[AppointmentTypeName],
    ISNULL(at.[ReminderHoursBefore], 24) AS [ReminderHoursBefore],
    ISNULL(at.[FollowUpReminderHoursAfter], 0) AS [FollowUpReminderHoursAfter]
FROM [PatientAppointment] pa
LEFT JOIN [patientdata] pd ON pd.[lPatientDataId] = pa.[lPatientDataId]
LEFT JOIN [DoctorProfile] dp ON dp.[lDoctorProfileId] = pa.[lDoctorProfileId]
LEFT JOIN [Clinic] c ON c.[lClinicId] = pa.[lClinicId]
LEFT JOIN [AppointmentType] at ON at.[lAppointmentTypeId] = pa.[lAppointmentTypeId]
WHERE
    pa.[IsActive] = 1
    AND ISNULL(pa.[IsNotified], 0) = 0
    AND pa.[StartTime] > @nowUtc
    AND pa.[StartTime] <= DATEADD(hour, ISNULL(at.[ReminderHoursBefore], 24), @nowUtc)
ORDER BY pa.[StartTime] ASC";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@nowUtc", nowUtc);

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<AppointmentReminderCandidateDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AppointmentReminderCandidateDto
            {
                PatientAppointmentId = SafeInt(reader["lPatientAppointmentId"]),
                PatientDataId = SafeInt(reader["lPatientDataId"]),
                PatientName = reader["PatientName"]?.ToString() ?? string.Empty,
                PatientEmail = reader["PatientEmail"]?.ToString() ?? string.Empty,
                DoctorProfileId = SafeInt(reader["lDoctorProfileId"]),
                DoctorName = reader["DoctorName"]?.ToString() ?? string.Empty,
                ClinicId = SafeInt(reader["lClinicId"]),
                ClinicName = reader["ClinicName"]?.ToString() ?? string.Empty,
                StartTime = SafeDateTime(reader["StartTime"]),
                EndTime = SafeDateTime(reader["EndTime"]),
                AppointmentTypeId = reader["lAppointmentTypeId"] is DBNull or null ? null : SafeInt(reader["lAppointmentTypeId"]),
                AppointmentTypeName = reader["AppointmentTypeName"]?.ToString(),
                ReminderHoursBefore = SafeInt(reader["ReminderHoursBefore"]),
                FollowUpReminderHoursAfter = SafeInt(reader["FollowUpReminderHoursAfter"])
            });
        }

        return list;
    }

    public async Task SetNotifiedAsync(int patientAppointmentId, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientAppointment]
SET [IsNotified] = 1, [UpdatedOn] = @updatedOn
WHERE [lPatientAppointmentId] = @appointmentId";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@updatedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@appointmentId", patientAppointmentId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<AppointmentReminderCandidateDto>> ListDueForFollowUpReminderAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    pa.[lPatientAppointmentId],
    pa.[lPatientDataId],
    ISNULL(pd.[FirstName], '') + CASE WHEN pd.[LastName] IS NULL OR pd.[LastName] = '' THEN '' ELSE ' ' + pd.[LastName] END AS [PatientName],
    ISNULL(pd.[Email], '') AS [PatientEmail],
    pa.[lDoctorProfileId],
    ISNULL(dp.[DoctorName], '') AS [DoctorName],
    pa.[lClinicId],
    ISNULL(c.[ClinicName], '') AS [ClinicName],
    pa.[StartTime],
    pa.[EndTime],
    pa.[lAppointmentTypeId],
    at.[AppointmentTypeName],
    ISNULL(at.[ReminderHoursBefore], 24) AS [ReminderHoursBefore],
    ISNULL(at.[FollowUpReminderHoursAfter], 0) AS [FollowUpReminderHoursAfter]
FROM [PatientAppointment] pa
LEFT JOIN [patientdata] pd ON pd.[lPatientDataId] = pa.[lPatientDataId]
LEFT JOIN [DoctorProfile] dp ON dp.[lDoctorProfileId] = pa.[lDoctorProfileId]
LEFT JOIN [Clinic] c ON c.[lClinicId] = pa.[lClinicId]
LEFT JOIN [AppointmentType] at ON at.[lAppointmentTypeId] = pa.[lAppointmentTypeId]
WHERE
    pa.[IsActive] = 1
    AND ISNULL(pa.[ReminderSent], 0) = 0
    AND ISNULL(at.[FollowUpReminderHoursAfter], 0) > 0
    AND pa.[EndTime] <= DATEADD(hour, -ISNULL(at.[FollowUpReminderHoursAfter], 0), @nowUtc)
    AND pa.[EndTime] >= DATEADD(hour, -ISNULL(at.[FollowUpReminderHoursAfter], 0) - 24, @nowUtc)
ORDER BY pa.[EndTime] ASC";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@nowUtc", nowUtc);

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<AppointmentReminderCandidateDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new AppointmentReminderCandidateDto
            {
                PatientAppointmentId = SafeInt(reader["lPatientAppointmentId"]),
                PatientDataId = SafeInt(reader["lPatientDataId"]),
                PatientName = reader["PatientName"]?.ToString() ?? string.Empty,
                PatientEmail = reader["PatientEmail"]?.ToString() ?? string.Empty,
                DoctorProfileId = SafeInt(reader["lDoctorProfileId"]),
                DoctorName = reader["DoctorName"]?.ToString() ?? string.Empty,
                ClinicId = SafeInt(reader["lClinicId"]),
                ClinicName = reader["ClinicName"]?.ToString() ?? string.Empty,
                StartTime = SafeDateTime(reader["StartTime"]),
                EndTime = SafeDateTime(reader["EndTime"]),
                AppointmentTypeId = reader["lAppointmentTypeId"] is DBNull or null ? null : SafeInt(reader["lAppointmentTypeId"]),
                AppointmentTypeName = reader["AppointmentTypeName"]?.ToString(),
                ReminderHoursBefore = SafeInt(reader["ReminderHoursBefore"]),
                FollowUpReminderHoursAfter = SafeInt(reader["FollowUpReminderHoursAfter"])
            });
        }

        return list;
    }

    public async Task SetFollowUpReminderSentAsync(int patientAppointmentId, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [PatientAppointment]
SET [ReminderSent] = 1, [UpdatedOn] = @updatedOn
WHERE [lPatientAppointmentId] = @appointmentId";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@updatedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@appointmentId", patientAppointmentId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static void BindAppointment(
        SqlCommand cmd,
        SavePatientAppointmentRequest request,
        int enteredById)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@doctorProfileId", request.DoctorProfileId);
        cmd.Parameters.AddWithValue("@clinicId", request.ClinicId);
        cmd.Parameters.AddWithValue("@startTime", request.StartTime);
        cmd.Parameters.AddWithValue("@endTime", request.EndTime);
        cmd.Parameters.AddWithValue("@appointmentStatusId", request.AppointmentStatusId);
        cmd.Parameters.AddWithValue("@appointmentTypeId", (object?)request.AppointmentTypeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@isNotified", request.IsNotified);
        cmd.Parameters.AddWithValue("@isActive", request.IsActive);
        cmd.Parameters.AddWithValue("@insertedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@updatedOn", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@enteredById", enteredById);
    }

    private static async Task<List<string>> ResolvePatientAppointmentAppUserFkColumnsAsync(
        SqlConnection con,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT c.[name] AS [ColumnName]
FROM sys.foreign_key_columns fkc
INNER JOIN sys.tables parent_table ON parent_table.[object_id] = fkc.[parent_object_id]
INNER JOIN sys.columns c ON c.[object_id] = fkc.[parent_object_id] AND c.[column_id] = fkc.[parent_column_id]
INNER JOIN sys.tables ref_table ON ref_table.[object_id] = fkc.[referenced_object_id]
WHERE parent_table.[name] = 'PatientAppointment'
  AND ref_table.[name] = 'AppUser'";

        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var columns = new List<string>();
        while (await reader.ReadAsync(cancellationToken))
        {
            columns.Add(reader["ColumnName"]?.ToString() ?? string.Empty);
        }

        return columns.Where(c => !string.IsNullOrWhiteSpace(c)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static async Task<int> ResolveCanonicalAppUserIdAsync(
        SqlConnection con,
        int tokenAppUserId,
        string username,
        CancellationToken cancellationToken)
    {
        if (tokenAppUserId <= 0)
        {
            throw new InvalidOperationException("Logged in AppUser is not valid for appointment entry.");
        }

        var existingColumns = await GetColumnsAsync(con, "AppUser", cancellationToken);
        var predicateColumns = AppUserIdCandidates.Where(existingColumns.Contains).ToList();
        if (predicateColumns.Count == 0)
        {
            throw new InvalidOperationException("No supported AppUser key column found.");
        }

        var targetColumn = existingColumns.Contains("lAppUserId")
            ? "lAppUserId"
            : predicateColumns[0];

        var predicates = string.Join(" OR ", predicateColumns.Select(c => $"CAST([{c}] AS int) = @id"));
        var sql = $@"
SELECT TOP 1 CAST([{targetColumn}] AS int)
FROM [AppUser]
WHERE {predicates}";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", tokenAppUserId);
        var existing = await cmd.ExecuteScalarAsync(cancellationToken);
        if (existing is not null)
        {
            return Convert.ToInt32(existing);
        }

        if (!string.IsNullOrWhiteSpace(username))
        {
            var loginColumns = new List<string>();
            if (existingColumns.Contains("MobileNumber"))
            {
                loginColumns.Add("CAST([MobileNumber] AS nvarchar(50)) = @username");
            }
            if (existingColumns.Contains("EmailAddress"))
            {
                loginColumns.Add("[EmailAddress] = @username");
            }
            if (existingColumns.Contains("Email"))
            {
                loginColumns.Add("[Email] = @username");
            }

            if (loginColumns.Count > 0)
            {
                var usernameSql = $@"
SELECT TOP 1 CAST([{targetColumn}] AS int)
FROM [AppUser]
WHERE {string.Join(" OR ", loginColumns)}";

                await using var usernameCmd = new SqlCommand(usernameSql, con);
                usernameCmd.Parameters.AddWithValue("@username", username);
                var usernameHit = await usernameCmd.ExecuteScalarAsync(cancellationToken);
                if (usernameHit is not null)
                {
                    return Convert.ToInt32(usernameHit);
                }
            }
        }

        throw new InvalidOperationException(
            $"Logged in AppUser is not valid for appointment entry. Token {tokenAppUserId}");
    }

    private static async Task<HashSet<string>> GetColumnsAsync(
        SqlConnection con,
        string tableName,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [COLUMN_NAME]
FROM INFORMATION_SCHEMA.COLUMNS
WHERE [TABLE_NAME] = @tableName";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@tableName", tableName);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var columns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken))
        {
            columns.Add(reader.GetString(0));
        }

        return columns;
    }

    private static async Task EnsureWithinClinicScheduleAsync(
        SqlConnection con,
        int clinicId,
        DateTime startTime,
        DateTime endTime,
        CancellationToken cancellationToken)
    {
        var localStart = startTime.Kind == DateTimeKind.Utc ? startTime.ToLocalTime() : startTime;
        var localEnd = endTime.Kind == DateTimeKind.Utc ? endTime.ToLocalTime() : endTime;

        if (localStart.Date != localEnd.Date)
        {
            throw new InvalidOperationException("Appointment must start and end on the same date.");
        }

        const string sql = @"
SELECT TOP 1 [DayOfWeek], [OpenTime], [CloseTime], [IsClosed]
FROM [ClinicSchedule]
WHERE [lClinicId] = @clinicId AND [DayOfWeek] = @dayOfWeek";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@clinicId", clinicId);
        cmd.Parameters.AddWithValue("@dayOfWeek", DayOfWeekToSchedule(localStart.DayOfWeek));

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException("Clinic schedule is not configured for the selected day.");
        }

        var isClosed = SafeBool(reader["IsClosed"]);
        if (isClosed)
        {
            throw new InvalidOperationException("Selected clinic is closed on this day.");
        }

        var openTime = reader["OpenTime"] is DBNull ? (TimeSpan?)null : (TimeSpan)reader["OpenTime"];
        var closeTime = reader["CloseTime"] is DBNull ? (TimeSpan?)null : (TimeSpan)reader["CloseTime"];

        if (openTime is null || closeTime is null)
        {
            throw new InvalidOperationException("Clinic open/close time is not configured for the selected day.");
        }

        var startTod = localStart.TimeOfDay;
        var endTod = localEnd.TimeOfDay;
        if (startTod < openTime.Value || endTod > closeTime.Value)
        {
            throw new InvalidOperationException($"Appointment time must be within clinic schedule ({openTime:hh\\:mm}-{closeTime:hh\\:mm}).");
        }
    }

    private static int DayOfWeekToSchedule(DayOfWeek dayOfWeek)
        => dayOfWeek switch
        {
            DayOfWeek.Monday => 1,
            DayOfWeek.Tuesday => 2,
            DayOfWeek.Wednesday => 3,
            DayOfWeek.Thursday => 4,
            DayOfWeek.Friday => 5,
            DayOfWeek.Saturday => 6,
            DayOfWeek.Sunday => 7,
            _ => 0
        };
    private static async Task EnsureNoDoctorOverlapAsync(
        SqlConnection con,
        int doctorProfileId,
        DateTime startTime,
        DateTime endTime,
        int? excludeAppointmentId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 1
FROM [PatientAppointment]
WHERE [lDoctorProfileId] = @doctorProfileId
  AND [IsActive] = 1
  AND (@excludeAppointmentId IS NULL OR [lPatientAppointmentId] <> @excludeAppointmentId)
  AND [StartTime] < @newEndTime
  AND [EndTime] > @newStartTime";

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@doctorProfileId", doctorProfileId);
        cmd.Parameters.AddWithValue("@newStartTime", startTime);
        cmd.Parameters.AddWithValue("@newEndTime", endTime);
        cmd.Parameters.AddWithValue("@excludeAppointmentId", (object?)excludeAppointmentId ?? DBNull.Value);

        var overlap = await cmd.ExecuteScalarAsync(cancellationToken);
        if (overlap is not null)
        {
            throw new InvalidOperationException("This doctor already has an overlapping appointment in the selected time range.");
        }
    }

    private static int SafeInt(object value) => value is DBNull ? 0 : Convert.ToInt32(value);
    private static DateTime SafeDateTime(object value) => value is DBNull ? DateTime.MinValue : Convert.ToDateTime(value);
    private static DateTime? SafeNullableDateTime(object value) => value is DBNull ? null : Convert.ToDateTime(value);
    private static bool SafeBool(object value)
    {
        if (value is DBNull)
        {
            return false;
        }

        if (value is bool b)
        {
            return b;
        }

        var text = value.ToString();
        if (string.Equals(text, "true", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }
        if (string.Equals(text, "false", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return Convert.ToInt32(value) != 0;
    }
}


