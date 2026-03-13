using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlMasterDataService : IMasterDataService
{
    private readonly string _connectionString;

    public SqlMasterDataService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<ClinicDto>> ListClinicsAsync(CancellationToken cancellationToken)
    {
        const string sql = @"SELECT [lClinicId],[ClinicName],[Address],[City],[Zip],[State],[lCountryId],[Phone],[Email],[Photo],[IsActive] FROM [Clinic] ORDER BY [ClinicName]";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<ClinicDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new ClinicDto
            {
                ClinicId = SafeInt(reader["lClinicId"]),
                ClinicName = reader["ClinicName"]?.ToString() ?? string.Empty,
                Address = reader["Address"]?.ToString() ?? string.Empty,
                City = reader["City"]?.ToString() ?? string.Empty,
                Zip = reader["Zip"]?.ToString() ?? string.Empty,
                State = reader["State"]?.ToString() ?? string.Empty,
                CountryId = SafeInt(reader["lCountryId"]),
                Phone = SafeLong(reader["Phone"]),
                Email = reader["Email"]?.ToString() ?? string.Empty,
                Photo = reader["Photo"]?.ToString() ?? string.Empty,
                IsActive = SafeBool(reader["IsActive"])
            });
        }
        return list;
    }

    public async Task<int> CreateClinicAsync(SaveClinicRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"INSERT INTO [Clinic]([ClinicName],[Address],[City],[Zip],[State],[lCountryId],[Phone],[Email],[Photo],[InsertedOn],[UpdatedOn],[IsActive]) OUTPUT INSERTED.[lClinicId] VALUES(@name,@addr,@city,@zip,@state,@country,@phone,@email,@photo,@ins,@upd,@active)";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindClinic(cmd, request);
        cmd.Parameters.AddWithValue("@ins", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@upd", DateTime.UtcNow);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateClinicAsync(int clinicId, SaveClinicRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [Clinic] SET [ClinicName]=@name,[Address]=@addr,[City]=@city,[Zip]=@zip,[State]=@state,[lCountryId]=@country,[Phone]=@phone,[Email]=@email,[Photo]=@photo,[UpdatedOn]=@upd,[IsActive]=@active WHERE [lClinicId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindClinic(cmd, request);
        cmd.Parameters.AddWithValue("@upd", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@id", clinicId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteClinicAsync(int clinicId, CancellationToken cancellationToken)
    {
        const string dependencySql = @"
SELECT TOP 1 1
FROM [DoctorProfile]
WHERE [lClinicId] = @id AND ([IsActive] = 1 OR [IsActive] = 'true')";

        const string sql = @"UPDATE [Clinic] SET [IsActive]=0,[UpdatedOn]=@upd WHERE [lClinicId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        await using (var dependencyCmd = new SqlCommand(dependencySql, con))
        {
            dependencyCmd.Parameters.AddWithValue("@id", clinicId);
            var hasDependency = await dependencyCmd.ExecuteScalarAsync(cancellationToken);
            if (hasDependency is not null)
            {
                throw new InvalidOperationException("Cannot delete clinic because active doctor profiles are linked to it.");
            }
        }

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@upd", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@id", clinicId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<DoctorProfileDto>> ListDoctorProfilesAsync(CancellationToken cancellationToken)
    {
        const string sql = @"SELECT [lDoctorProfileId],[DoctorName],[DoctorDegree],[DoctorStream],[lClinicId],[DoctorCity],[lCountryId],[Phone],[Email],[Gender],[Photo],[IsActive],[lAppUserId] FROM [DoctorProfile] ORDER BY [DoctorName]";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<DoctorProfileDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new DoctorProfileDto
            {
                DoctorProfileId = SafeInt(reader["lDoctorProfileId"]),
                DoctorName = reader["DoctorName"]?.ToString() ?? string.Empty,
                DoctorDegree = reader["DoctorDegree"]?.ToString() ?? string.Empty,
                DoctorStream = reader["DoctorStream"]?.ToString() ?? string.Empty,
                ClinicId = SafeInt(reader["lClinicId"]),
                DoctorCity = reader["DoctorCity"]?.ToString() ?? string.Empty,
                CountryId = SafeInt(reader["lCountryId"]),
                Phone = SafeLong(reader["Phone"]),
                Email = reader["Email"]?.ToString() ?? string.Empty,
                Gender = reader["Gender"]?.ToString() ?? string.Empty,
                Photo = reader["Photo"]?.ToString() ?? string.Empty,
                IsActive = SafeBool(reader["IsActive"]),
                AppUserId = SafeInt(reader["lAppUserId"])
            });
        }
        return list;
    }

    public async Task<int?> GetDoctorProfileIdByAppUserIdAsync(int appUserId, CancellationToken cancellationToken)
    {
        const string sql = @"SELECT TOP 1 [lDoctorProfileId] FROM [DoctorProfile] WHERE [lAppUserId] = @appUserId AND [IsActive] = 1";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@appUserId", appUserId);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        return result is null or DBNull ? null : Convert.ToInt32(result);
    }

    public async Task<int> CreateDoctorProfileAsync(SaveDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"INSERT INTO [DoctorProfile]([DoctorName],[DoctorDegree],[DoctorStream],[lClinicId],[DoctorCity],[lCountryId],[Phone],[Email],[Gender],[Photo],[InsertedOn],[UpdatedOn],[IsActive],[lAppUserId]) OUTPUT INSERTED.[lDoctorProfileId] VALUES(@name,@deg,@stream,@clinic,@city,@country,@phone,@email,@gender,@photo,@ins,@upd,@active,@appUserId)";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindDoctor(cmd, request);
        cmd.Parameters.AddWithValue("@ins", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@upd", DateTime.UtcNow);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateDoctorProfileAsync(int doctorProfileId, SaveDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [DoctorProfile] SET [DoctorName]=@name,[DoctorDegree]=@deg,[DoctorStream]=@stream,[lClinicId]=@clinic,[DoctorCity]=@city,[lCountryId]=@country,[Phone]=@phone,[Email]=@email,[Gender]=@gender,[Photo]=@photo,[UpdatedOn]=@upd,[IsActive]=@active,[lAppUserId]=@appUserId WHERE [lDoctorProfileId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindDoctor(cmd, request);
        cmd.Parameters.AddWithValue("@upd", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@id", doctorProfileId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteDoctorProfileAsync(int doctorProfileId, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [DoctorProfile] SET [IsActive]=0,[UpdatedOn]=@upd WHERE [lDoctorProfileId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@upd", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@id", doctorProfileId);

        try
        {
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            throw new InvalidOperationException("Cannot delete doctor profile because linked records exist.", ex);
        }
    }

    public async Task<IReadOnlyList<StaffDto>> ListStaffAsync(CancellationToken cancellationToken)
    {
        const string sql = @"SELECT [lStaffId],[Name],[Qualification],[Mobile],[Email],[Gender],[Address],[Photo],[lEnteredById],[lAppUserId],[IsActive] FROM [Staff] ORDER BY [Name]";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<StaffDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new StaffDto
            {
                StaffId = SafeInt(reader["lStaffId"]),
                Name = reader["Name"]?.ToString() ?? string.Empty,
                Qualification = reader["Qualification"]?.ToString() ?? string.Empty,
                Mobile = SafeLong(reader["Mobile"]),
                Email = reader["Email"]?.ToString() ?? string.Empty,
                Gender = reader["Gender"]?.ToString() ?? string.Empty,
                Address = reader["Address"]?.ToString() ?? string.Empty,
                Photo = reader["Photo"]?.ToString() ?? string.Empty,
                EnteredById = SafeInt(reader["lEnteredById"]),
                AppUserId = SafeInt(reader["lAppUserId"]),
                IsActive = SafeBool(reader["IsActive"])
            });
        }
        return list;
    }

    public async Task<int> CreateStaffAsync(SaveStaffRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"INSERT INTO [Staff]([Name],[Qualification],[Mobile],[Email],[Gender],[Address],[Photo],[InsertedOn],[lEnteredById],[lAppUserId],[IsActive]) OUTPUT INSERTED.[lStaffId] VALUES(@name,@qual,@mobile,@email,@gender,@addr,@photo,@ins,@enteredBy,@appUserId,@active)";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindStaff(cmd, request);
        cmd.Parameters.AddWithValue("@ins", DateTime.UtcNow.Date);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateStaffAsync(int staffId, SaveStaffRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [Staff] SET [Name]=@name,[Qualification]=@qual,[Mobile]=@mobile,[Email]=@email,[Gender]=@gender,[Address]=@addr,[Photo]=@photo,[lEnteredById]=@enteredBy,[lAppUserId]=@appUserId,[IsActive]=@active WHERE [lStaffId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindStaff(cmd, request);
        cmd.Parameters.AddWithValue("@id", staffId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteStaffAsync(int staffId, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [Staff] SET [IsActive]=0 WHERE [lStaffId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", staffId);

        try
        {
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            throw new InvalidOperationException("Cannot delete staff because linked records exist.", ex);
        }
    }

    public async Task<IReadOnlyList<ClinicScheduleDto>> ListClinicSchedulesAsync(CancellationToken cancellationToken)
    {
        const string sql = @"SELECT [lScheduleId],[lClinicId],[DayOfWeek],[OpenTime],[CloseTime],[IsClosed],[lAppUserId] FROM [ClinicSchedule] ORDER BY [lClinicId],[DayOfWeek],[lScheduleId]";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<ClinicScheduleDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new ClinicScheduleDto
            {
                ScheduleId = SafeInt(reader["lScheduleId"]),
                ClinicId = SafeInt(reader["lClinicId"]),
                DayOfWeek = SafeInt(reader["DayOfWeek"]),
                OpenTime = SafeTimeString(reader["OpenTime"]),
                CloseTime = SafeTimeString(reader["CloseTime"]),
                IsClosed = SafeBool(reader["IsClosed"]),
                AppUserId = SafeInt(reader["lAppUserId"])
            });
        }
        return list;
    }

    public async Task<int> CreateClinicScheduleAsync(SaveClinicScheduleRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"INSERT INTO [ClinicSchedule]([lClinicId],[DayOfWeek],[OpenTime],[CloseTime],[IsClosed],[CreatedDate],[lAppUserId]) OUTPUT INSERTED.[lScheduleId] VALUES(@clinicId,@dayOfWeek,@openTime,@closeTime,@isClosed,@createdDate,@appUserId)";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindClinicSchedule(cmd, request, includeCreatedDate: true);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateClinicScheduleAsync(int scheduleId, SaveClinicScheduleRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [ClinicSchedule] SET [lClinicId]=@clinicId,[DayOfWeek]=@dayOfWeek,[OpenTime]=@openTime,[CloseTime]=@closeTime,[IsClosed]=@isClosed,[lAppUserId]=@appUserId WHERE [lScheduleId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindClinicSchedule(cmd, request, includeCreatedDate: false);
        cmd.Parameters.AddWithValue("@id", scheduleId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteClinicScheduleAsync(int scheduleId, CancellationToken cancellationToken)
    {
        const string sql = @"DELETE FROM [ClinicSchedule] WHERE [lScheduleId]=@id";
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", scheduleId);
        try
        {
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            throw new InvalidOperationException("Cannot delete clinic schedule because linked records exist.", ex);
        }
    }

    private static void BindClinic(SqlCommand cmd, SaveClinicRequest request)
    {
        cmd.Parameters.AddWithValue("@name", request.ClinicName);
        cmd.Parameters.AddWithValue("@addr", request.Address);
        cmd.Parameters.AddWithValue("@city", request.City);
        cmd.Parameters.AddWithValue("@zip", request.Zip);
        cmd.Parameters.AddWithValue("@state", request.State);
        cmd.Parameters.AddWithValue("@country", request.CountryId);
        cmd.Parameters.AddWithValue("@phone", request.Phone);
        cmd.Parameters.AddWithValue("@email", request.Email);
        cmd.Parameters.AddWithValue("@photo", (object?)request.Photo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@active", request.IsActive);
    }

    private static void BindDoctor(SqlCommand cmd, SaveDoctorProfileRequest request)
    {
        cmd.Parameters.AddWithValue("@name", request.DoctorName);
        cmd.Parameters.AddWithValue("@deg", request.DoctorDegree);
        cmd.Parameters.AddWithValue("@stream", request.DoctorStream);
        cmd.Parameters.AddWithValue("@clinic", request.ClinicId);
        cmd.Parameters.AddWithValue("@city", request.DoctorCity);
        cmd.Parameters.AddWithValue("@country", request.CountryId);
        cmd.Parameters.AddWithValue("@phone", request.Phone);
        cmd.Parameters.AddWithValue("@email", request.Email);
        cmd.Parameters.AddWithValue("@gender", request.Gender);
        cmd.Parameters.AddWithValue("@photo", (object?)request.Photo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@active", request.IsActive);
        cmd.Parameters.AddWithValue("@appUserId", request.AppUserId);
    }

    private static void BindStaff(SqlCommand cmd, SaveStaffRequest request)
    {
        cmd.Parameters.AddWithValue("@name", request.Name);
        cmd.Parameters.AddWithValue("@qual", request.Qualification);
        cmd.Parameters.AddWithValue("@mobile", request.Mobile);
        cmd.Parameters.AddWithValue("@email", request.Email);
        cmd.Parameters.AddWithValue("@gender", request.Gender);
        cmd.Parameters.AddWithValue("@addr", request.Address);
        cmd.Parameters.AddWithValue("@photo", (object?)request.Photo ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@enteredBy", request.EnteredById);
        cmd.Parameters.AddWithValue("@appUserId", request.AppUserId);
        cmd.Parameters.AddWithValue("@active", request.IsActive);
    }

    private static void BindClinicSchedule(SqlCommand cmd, SaveClinicScheduleRequest request, bool includeCreatedDate)
    {
        cmd.Parameters.AddWithValue("@clinicId", request.ClinicId);
        cmd.Parameters.AddWithValue("@dayOfWeek", request.DayOfWeek);
        cmd.Parameters.AddWithValue("@openTime", ParseTimeOrDbNull(request.OpenTime));
        cmd.Parameters.AddWithValue("@closeTime", ParseTimeOrDbNull(request.CloseTime));
        cmd.Parameters.AddWithValue("@isClosed", request.IsClosed);
        cmd.Parameters.AddWithValue("@appUserId", request.AppUserId <= 0 ? DBNull.Value : request.AppUserId);
        if (includeCreatedDate)
        {
            cmd.Parameters.AddWithValue("@createdDate", DateTime.UtcNow);
        }
    }

    private static int SafeInt(object value) => value is DBNull ? 0 : Convert.ToInt32(value);
    private static long SafeLong(object value) => value is DBNull ? 0L : Convert.ToInt64(value);
    private static string? SafeTimeString(object value)
    {
        if (value is DBNull)
        {
            return null;
        }

        if (value is TimeSpan timeSpan)
        {
            return timeSpan.ToString(@"hh\:mm\:ss");
        }

        return value.ToString();
    }

    private static object ParseTimeOrDbNull(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return DBNull.Value;
        }

        return TimeSpan.TryParse(value, out var parsed) ? parsed : DBNull.Value;
    }

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
