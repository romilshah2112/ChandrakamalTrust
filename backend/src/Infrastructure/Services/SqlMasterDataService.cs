using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlMasterDataService : IMasterDataService
{
    private static readonly string[] InvoiceTypeIdCandidates = ["lInvoiceTypeId", "InvoiceTypeId", "Id"];
    private static readonly string[] InvoiceTypeNameCandidates = ["InvoiceTypeName", "InvType", "InvoiceType", "TypeName", "Name"];
    private static readonly string[] DescriptionCandidates = ["Description", "Details", "Remarks"];
    private static readonly string[] ChargesCandidates = ["Charges", "Charge", "Amount", "Price"];
    private static readonly string[] IsActiveCandidates = ["IsActive", "Active", "IsEnabled"];
    private static readonly string[] InsertedOnCandidates = ["InsertedOn", "CreatedDate", "CreatedOn"];
    private static readonly string[] UpdatedOnCandidates = ["UpdatedOn", "ModifiedOn", "UpdatedDate"];
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
        const string sql = @"INSERT INTO [DoctorProfile]([DoctorName],[DoctorDegree],[DoctorStream],[lClinicId],[DoctorCity],[lCountryId],[Phone],[Email],[Gender],[Photo],[InsertedOn],[UpdatedOn],[IsActive],[lAppUserId]) OUTPUT INSERTED.[lDoctorProfileId] VALUES(@name,@deg,@stream,@clinic,@city,@country,@phone,@email,@gender,@photo,@ins,@upd,@active,NULL)";
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
        const string sql = @"UPDATE [DoctorProfile] SET [DoctorName]=@name,[DoctorDegree]=@deg,[DoctorStream]=@stream,[lClinicId]=@clinic,[DoctorCity]=@city,[lCountryId]=@country,[Phone]=@phone,[Email]=@email,[Gender]=@gender,[Photo]=@photo,[UpdatedOn]=@upd,[IsActive]=@active WHERE [lDoctorProfileId]=@id";
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
        const string sql = @"INSERT INTO [Staff]([Name],[Qualification],[Mobile],[Email],[Gender],[Address],[Photo],[InsertedOn],[lEnteredById],[lAppUserId],[IsActive]) OUTPUT INSERTED.[lStaffId] VALUES(@name,@qual,@mobile,@email,@gender,@addr,@photo,@ins,@enteredBy,NULL,@active)";
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
        const string sql = @"UPDATE [Staff] SET [Name]=@name,[Qualification]=@qual,[Mobile]=@mobile,[Email]=@email,[Gender]=@gender,[Address]=@addr,[Photo]=@photo,[lEnteredById]=@enteredBy,[IsActive]=@active WHERE [lStaffId]=@id";
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
        const string sql = @"
SELECT
    cs.[lScheduleId],
    cs.[lClinicId],
    cs.[DayOfWeek],
    cs.[OpenTime],
    cs.[CloseTime],
    cs.[IsClosed],
    cs.[lAppUserId],
    LTRIM(RTRIM(
        COALESCE(au.[FirstName], '') +
        CASE
            WHEN au.[LastName] IS NULL OR au.[LastName] = '' THEN ''
            ELSE ' ' + au.[LastName]
        END
    )) AS [AppUserName]
FROM [ClinicSchedule] cs
LEFT JOIN [AppUser] au ON au.[lAppUserId] = cs.[lAppUserId]
ORDER BY cs.[lClinicId],cs.[DayOfWeek],cs.[lScheduleId]";
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
                AppUserId = SafeInt(reader["lAppUserId"]),
                AppUserName = reader["AppUserName"]?.ToString() ?? string.Empty
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

    public async Task<IReadOnlyList<InvoiceTypeDto>> ListInvoiceTypesAsync(CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var columns = await GetColumnsAsync(con, "InvoiceType", cancellationToken);
        var idColumn = ResolveFirst(columns, InvoiceTypeIdCandidates)
            ?? throw new InvalidOperationException("InvoiceType id column not found.");
        var nameColumn = ResolveFirst(columns, InvoiceTypeNameCandidates)
            ?? throw new InvalidOperationException("InvoiceType name column not found.");
        var descriptionColumn = ResolveFirst(columns, DescriptionCandidates);
        var chargesColumn = ResolveFirst(columns, ChargesCandidates);
        var isActiveColumn = ResolveFirst(columns, IsActiveCandidates);

        var sql = $@"
SELECT
    CAST([{idColumn}] AS int) AS [InvoiceTypeId],
    CAST([{nameColumn}] AS nvarchar(200)) AS [InvoiceTypeName],
    {(descriptionColumn is null ? "CAST('' AS nvarchar(500))" : $"ISNULL(CAST([{descriptionColumn}] AS nvarchar(500)), '')")} AS [Description],
    {(chargesColumn is null ? "CAST(0 AS float)" : $"CAST(ISNULL([{chargesColumn}], 0) AS float)")} AS [Charges],
    {(isActiveColumn is null
        ? "CAST(1 AS bit)"
        : $@"CASE
    WHEN [{isActiveColumn}] IS NULL THEN CAST(1 AS bit)
    WHEN TRY_CONVERT(int, [{isActiveColumn}]) IS NOT NULL
        THEN CASE WHEN TRY_CONVERT(int, [{isActiveColumn}]) = 0 THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END
    WHEN LOWER(LTRIM(RTRIM(CAST([{isActiveColumn}] AS nvarchar(20))))) IN ('true', 'yes', 'y', 'active')
        THEN CAST(1 AS bit)
    ELSE CAST(0 AS bit)
END")} AS [IsActive]
FROM [InvoiceType]
ORDER BY [{nameColumn}]";

        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<InvoiceTypeDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new InvoiceTypeDto
            {
                InvoiceTypeId = SafeInt(reader["InvoiceTypeId"]),
                InvoiceTypeName = reader["InvoiceTypeName"]?.ToString() ?? string.Empty,
                Description = reader["Description"]?.ToString() ?? string.Empty,
                Charges = SafeDouble(reader["Charges"]),
                IsActive = SafeBool(reader["IsActive"])
            });
        }

        return list;
    }

    public async Task<int> CreateInvoiceTypeAsync(SaveInvoiceTypeRequest request, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var columns = await GetColumnsAsync(con, "InvoiceType", cancellationToken);
        var idColumn = ResolveFirst(columns, InvoiceTypeIdCandidates)
            ?? throw new InvalidOperationException("InvoiceType id column not found.");
        var nameColumn = ResolveFirst(columns, InvoiceTypeNameCandidates)
            ?? throw new InvalidOperationException("InvoiceType name column not found.");
        var descriptionColumn = ResolveFirst(columns, DescriptionCandidates);
        var chargesColumn = ResolveFirst(columns, ChargesCandidates);
        var isActiveColumn = ResolveFirst(columns, IsActiveCandidates);
        var insertedOnColumn = ResolveFirst(columns, InsertedOnCandidates);
        var updatedOnColumn = ResolveFirst(columns, UpdatedOnCandidates);

        var insertColumns = new List<string> {$"[{nameColumn}]"};
        var insertValues = new List<string> {"@name"};

        if (descriptionColumn is not null)
        {
            insertColumns.Add($"[{descriptionColumn}]");
            insertValues.Add("@description");
        }
        if (chargesColumn is not null)
        {
            insertColumns.Add($"[{chargesColumn}]");
            insertValues.Add("@charges");
        }
        if (isActiveColumn is not null)
        {
            insertColumns.Add($"[{isActiveColumn}]");
            insertValues.Add("@isActive");
        }
        if (insertedOnColumn is not null)
        {
            insertColumns.Add($"[{insertedOnColumn}]");
            insertValues.Add("@insertedOn");
        }
        if (updatedOnColumn is not null)
        {
            insertColumns.Add($"[{updatedOnColumn}]");
            insertValues.Add("@updatedOn");
        }

        var sql = $@"
INSERT INTO [InvoiceType]({string.Join(",", insertColumns)})
OUTPUT INSERTED.[{idColumn}]
VALUES({string.Join(",", insertValues)})";

        await using var cmd = new SqlCommand(sql, con);
        BindInvoiceType(
            cmd,
            request,
            includeInsertedOn: insertedOnColumn is not null,
            includeUpdatedOn: updatedOnColumn is not null,
            includeIsActive: isActiveColumn is not null,
            includeDescription: descriptionColumn is not null,
            includeCharges: chargesColumn is not null);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateInvoiceTypeAsync(int invoiceTypeId, SaveInvoiceTypeRequest request, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var columns = await GetColumnsAsync(con, "InvoiceType", cancellationToken);
        var idColumn = ResolveFirst(columns, InvoiceTypeIdCandidates)
            ?? throw new InvalidOperationException("InvoiceType id column not found.");
        var nameColumn = ResolveFirst(columns, InvoiceTypeNameCandidates)
            ?? throw new InvalidOperationException("InvoiceType name column not found.");
        var descriptionColumn = ResolveFirst(columns, DescriptionCandidates);
        var chargesColumn = ResolveFirst(columns, ChargesCandidates);
        var isActiveColumn = ResolveFirst(columns, IsActiveCandidates);
        var updatedOnColumn = ResolveFirst(columns, UpdatedOnCandidates);

        var sets = new List<string> {$"[{nameColumn}] = @name"};
        if (descriptionColumn is not null)
        {
            sets.Add($"[{descriptionColumn}] = @description");
        }
        if (chargesColumn is not null)
        {
            sets.Add($"[{chargesColumn}] = @charges");
        }
        if (isActiveColumn is not null)
        {
            sets.Add($"[{isActiveColumn}] = @isActive");
        }
        if (updatedOnColumn is not null)
        {
            sets.Add($"[{updatedOnColumn}] = @updatedOn");
        }

        var sql = $@"UPDATE [InvoiceType] SET {string.Join(",", sets)} WHERE [{idColumn}] = @id";
        await using var cmd = new SqlCommand(sql, con);
        BindInvoiceType(
            cmd,
            request,
            includeInsertedOn: false,
            includeUpdatedOn: updatedOnColumn is not null,
            includeIsActive: isActiveColumn is not null,
            includeDescription: descriptionColumn is not null,
            includeCharges: chargesColumn is not null);
        cmd.Parameters.AddWithValue("@id", invoiceTypeId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteInvoiceTypeAsync(int invoiceTypeId, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var columns = await GetColumnsAsync(con, "InvoiceType", cancellationToken);
        var idColumn = ResolveFirst(columns, InvoiceTypeIdCandidates)
            ?? throw new InvalidOperationException("InvoiceType id column not found.");
        var isActiveColumn = ResolveFirst(columns, IsActiveCandidates);
        var updatedOnColumn = ResolveFirst(columns, UpdatedOnCandidates);

        var sql = isActiveColumn is not null
            ? $@"UPDATE [InvoiceType] SET [{isActiveColumn}] = 0{(updatedOnColumn is not null ? $", [{updatedOnColumn}] = @updatedOn" : string.Empty)} WHERE [{idColumn}] = @id"
            : $@"DELETE FROM [InvoiceType] WHERE [{idColumn}] = @id";

        await using var cmd = new SqlCommand(sql, con);
        if (updatedOnColumn is not null && isActiveColumn is not null)
        {
            cmd.Parameters.AddWithValue("@updatedOn", DateTime.UtcNow);
        }
        cmd.Parameters.AddWithValue("@id", invoiceTypeId);

        try
        {
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            throw new InvalidOperationException("Cannot delete invoice type because linked records exist.", ex);
        }
    }

    public async Task<IReadOnlyList<HealthCampDto>> ListHealthCampsAsync(CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [lHealthCampId], [CampName], [CampDate], [Location], [Organizer], [Description], [lReferenceTypeId], [IsActive], [CreatedOn]
FROM [HealthCamp]
ORDER BY [CampDate] DESC, [lHealthCampId] DESC";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<HealthCampDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new HealthCampDto
            {
                HealthCampId = SafeInt(reader["lHealthCampId"]),
                CampName = reader["CampName"]?.ToString() ?? string.Empty,
                CampDate = SafeDateTime(reader["CampDate"]),
                Location = reader["Location"]?.ToString() ?? string.Empty,
                Organizer = reader["Organizer"]?.ToString() ?? string.Empty,
                Description = reader["Description"]?.ToString() ?? string.Empty,
                ReferenceTypeId = SafeInt(reader["lReferenceTypeId"]),
                IsActive = SafeBool(reader["IsActive"]),
                CreatedOn = SafeDateTime(reader["CreatedOn"])
            });
        }

        return list;
    }

    public async Task<int> CreateHealthCampAsync(SaveHealthCampRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"
INSERT INTO [HealthCamp]([CampName], [CampDate], [Location], [Organizer], [Description], [lReferenceTypeId], [IsActive], [CreatedOn])
OUTPUT INSERTED.[lHealthCampId]
VALUES(@campName, @campDate, @location, @organizer, @description, @referenceTypeId, @isActive, @createdOn)";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindHealthCamp(cmd, request);
        cmd.Parameters.AddWithValue("@createdOn", DateTime.UtcNow);
        var id = await cmd.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(id);
    }

    public async Task UpdateHealthCampAsync(int healthCampId, SaveHealthCampRequest request, CancellationToken cancellationToken)
    {
        const string sql = @"
UPDATE [HealthCamp]
SET [CampName] = @campName,
    [CampDate] = @campDate,
    [Location] = @location,
    [Organizer] = @organizer,
    [Description] = @description,
    [lReferenceTypeId] = @referenceTypeId,
    [IsActive] = @isActive
WHERE [lHealthCampId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        BindHealthCamp(cmd, request);
        cmd.Parameters.AddWithValue("@id", healthCampId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task DeleteHealthCampAsync(int healthCampId, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [HealthCamp] SET [IsActive] = 0 WHERE [lHealthCampId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", healthCampId);

        try
        {
            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            throw new InvalidOperationException("Cannot delete health camp because linked records exist.", ex);
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

    private static void BindInvoiceType(
        SqlCommand cmd,
        SaveInvoiceTypeRequest request,
        bool includeInsertedOn,
        bool includeUpdatedOn,
        bool includeIsActive,
        bool includeDescription,
        bool includeCharges)
    {
        cmd.Parameters.AddWithValue("@name", request.InvoiceTypeName);
        if (includeDescription)
        {
            cmd.Parameters.AddWithValue("@description", (object?)request.Description ?? DBNull.Value);
        }
        if (includeCharges)
        {
            cmd.Parameters.AddWithValue("@charges", request.Charges);
        }
        if (includeIsActive)
        {
            cmd.Parameters.AddWithValue("@isActive", request.IsActive);
        }
        if (includeInsertedOn)
        {
            cmd.Parameters.AddWithValue("@insertedOn", DateTime.UtcNow);
        }
        if (includeUpdatedOn)
        {
            cmd.Parameters.AddWithValue("@updatedOn", DateTime.UtcNow);
        }
    }

    private static void BindHealthCamp(SqlCommand cmd, SaveHealthCampRequest request)
    {
        cmd.Parameters.AddWithValue("@campName", request.CampName);
        cmd.Parameters.AddWithValue("@campDate", request.CampDate.Date);
        cmd.Parameters.AddWithValue("@location", request.Location);
        cmd.Parameters.AddWithValue("@organizer", request.Organizer);
        cmd.Parameters.AddWithValue("@description", (object?)request.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@referenceTypeId", request.ReferenceTypeId);
        cmd.Parameters.AddWithValue("@isActive", request.IsActive);
    }

    private static string? ResolveFirst(HashSet<string> columns, IReadOnlyList<string> candidates)
        => candidates.FirstOrDefault(columns.Contains);

    private static async Task<HashSet<string>> GetColumnsAsync(
        SqlConnection connection,
        string tableName,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @tableName";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@tableName", tableName);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(reader.GetString(0));
        }

        return result;
    }

    private static int SafeInt(object value) => value is DBNull ? 0 : Convert.ToInt32(value);
    private static double SafeDouble(object value) => value is DBNull ? 0d : Convert.ToDouble(value);
    private static long SafeLong(object value) => value is DBNull ? 0L : Convert.ToInt64(value);
    private static DateTime SafeDateTime(object value) => value is DBNull ? DateTime.MinValue : Convert.ToDateTime(value);
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
