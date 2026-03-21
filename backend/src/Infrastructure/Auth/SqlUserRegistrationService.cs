using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Application.Models;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class SqlUserRegistrationService : IUserRegistrationService
{
    private readonly string _connectionString;
    private readonly IPasswordCryptoService _passwordCryptoService;

    public SqlUserRegistrationService(IConfiguration configuration, IPasswordCryptoService passwordCryptoService)
    {
        _passwordCryptoService = passwordCryptoService;
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<int> RegisterAsync(AppUserRegistrationInput input, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        var normalizedEmailAddress = input.EmailAddress.Trim();

        const string existsSql = @"
SELECT TOP 1 1
FROM [AppUser]
WHERE [MobileNumber] = @mobileNumber
   OR LOWER(LTRIM(RTRIM(ISNULL([EmailAddress], '')))) = @emailAddress";

        await using (var existsCommand = new SqlCommand(existsSql, connection, (SqlTransaction)transaction))
        {
            existsCommand.Parameters.AddWithValue("@mobileNumber", input.MobileNumber);
            existsCommand.Parameters.AddWithValue("@emailAddress", normalizedEmailAddress.ToLowerInvariant());
            var exists = await existsCommand.ExecuteScalarAsync(cancellationToken);
            if (exists is not null)
            {
                throw new InvalidOperationException(
                    "User already exists. Please click forgot password to retrieve the password.");
            }
        }

        var roleName = await ResolveRoleNameAsync(connection, (SqlTransaction)transaction, input.UserRoleId, cancellationToken);
        if (string.IsNullOrWhiteSpace(roleName))
        {
            throw new ArgumentException("Selected role is invalid.");
        }

        var linkedRecord = await ResolveLinkedRecordAsync(
            connection,
            (SqlTransaction)transaction,
            roleName,
            input.MobileNumber,
            normalizedEmailAddress,
            cancellationToken);

        if (linkedRecord is null)
        {
            throw new ArgumentException(GetMissingRoleMessage(roleName));
        }

        if (linkedRecord.Value.AppUserId > 0)
        {
            throw new InvalidOperationException(
                "User already exists. Please click forgot password to retrieve the password.");
        }

        const string insertSql = @"
INSERT INTO [AppUser]
    ([FirstName], [LastName], [MobileNumber], [EmailAddress], [Password], [lUserRoleId], [IsEnabled], [IsLogin])
OUTPUT INSERTED.[lAppUserId]
VALUES
    (@firstName, @lastName, @mobileNumber, @emailAddress, @password, @userRoleId, @isEnabled, @isLogin)";

        await using var command = new SqlCommand(insertSql, connection, (SqlTransaction)transaction);
        command.Parameters.AddWithValue("@firstName", input.FirstName);
        command.Parameters.AddWithValue("@lastName", input.LastName);
        command.Parameters.AddWithValue("@mobileNumber", input.MobileNumber);
        command.Parameters.AddWithValue("@emailAddress", normalizedEmailAddress);
        command.Parameters.AddWithValue("@password", _passwordCryptoService.Encrypt(input.Password));
        command.Parameters.AddWithValue("@userRoleId", input.UserRoleId);
        command.Parameters.AddWithValue("@isEnabled", 1);
        command.Parameters.AddWithValue("@isLogin", false);

        var insertedId = await command.ExecuteScalarAsync(cancellationToken);
        var appUserId = Convert.ToInt32(insertedId);

        await LinkAppUserAsync(
            connection,
            (SqlTransaction)transaction,
            linkedRecord.Value.TableName,
            linkedRecord.Value.RecordId,
            appUserId,
            cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return appUserId;
    }

    private static async Task<string?> ResolveRoleNameAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int userRoleId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT TOP 1 CAST([RoleName] AS nvarchar(100))
FROM [UserRole]
WHERE [lUserRoleId] = @userRoleId";

        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@userRoleId", userRoleId);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value?.ToString();
    }

    private static async Task<(string TableName, int RecordId, int AppUserId)?> ResolveLinkedRecordAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string roleName,
        long mobileNumber,
        string emailAddress,
        CancellationToken cancellationToken)
    {
        var normalizedRole = roleName.Trim();

        if (normalizedRole.Equals("Doctor", StringComparison.OrdinalIgnoreCase))
        {
            return await FindLinkedRecordAsync(
                connection,
                transaction,
                tableName: "DoctorProfile",
                idColumn: "lDoctorProfileId",
                mobileColumn: "Phone",
                emailColumn: "Email",
                mobileNumber,
                emailAddress,
                cancellationToken);
        }

        if (normalizedRole.Equals("Receptionist", StringComparison.OrdinalIgnoreCase))
        {
            return await FindLinkedRecordAsync(
                connection,
                transaction,
                tableName: "Staff",
                idColumn: "lStaffId",
                mobileColumn: "Mobile",
                emailColumn: "Email",
                mobileNumber,
                emailAddress,
                cancellationToken);
        }

        if (normalizedRole.Equals("Patient", StringComparison.OrdinalIgnoreCase))
        {
            return await FindLinkedRecordAsync(
                connection,
                transaction,
                tableName: "patientdata",
                idColumn: "lPatientDataId",
                mobileColumn: "MobileNo",
                emailColumn: "Email",
                mobileNumber,
                emailAddress,
                cancellationToken);
        }

        throw new ArgumentException("Sign up is supported only for Patient, Doctor, or Receptionist.");
    }

    private static async Task<(string TableName, int RecordId, int AppUserId)?> FindLinkedRecordAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string tableName,
        string idColumn,
        string mobileColumn,
        string emailColumn,
        long mobileNumber,
        string emailAddress,
        CancellationToken cancellationToken)
    {
        var normalizedEmail = emailAddress.Trim().ToLowerInvariant();
        var sql = $@"
SELECT TOP 1
    CAST([{idColumn}] AS int) AS [RecordId],
    ISNULL(CAST([lAppUserId] AS int), 0) AS [AppUserId]
FROM [{tableName}]
WHERE CAST([{mobileColumn}] AS bigint) = @mobileNumber
   OR LOWER(LTRIM(RTRIM(ISNULL([{emailColumn}], '')))) = @emailAddress
ORDER BY CASE WHEN ISNULL([lAppUserId], 0) <= 0 THEN 0 ELSE 1 END,
         CAST([{idColumn}] AS int)";

        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@mobileNumber", mobileNumber);
        command.Parameters.AddWithValue("@emailAddress", normalizedEmail);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return (tableName, reader.GetInt32(0), reader.GetInt32(1));
    }

    private static async Task LinkAppUserAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string tableName,
        int recordId,
        int appUserId,
        CancellationToken cancellationToken)
    {
        var idColumn = tableName switch
        {
            "DoctorProfile" => "lDoctorProfileId",
            "Staff" => "lStaffId",
            "patientdata" => "lPatientDataId",
            _ => throw new InvalidOperationException($"Unsupported link table {tableName}.")
        };

        var sql = $@"UPDATE [{tableName}] SET [lAppUserId] = @appUserId WHERE [{idColumn}] = @recordId";
        await using var command = new SqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("@appUserId", appUserId);
        command.Parameters.AddWithValue("@recordId", recordId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static string GetMissingRoleMessage(string roleName)
    {
        if (roleName.Equals("Doctor", StringComparison.OrdinalIgnoreCase))
        {
            return "Doctor profile not found. Please ensure the doctor already exists in DoctorProfile with matching phone or email.";
        }

        if (roleName.Equals("Receptionist", StringComparison.OrdinalIgnoreCase))
        {
            return "Receptionist record not found. Please ensure the user already exists in Staff with matching phone or email.";
        }

        if (roleName.Equals("Patient", StringComparison.OrdinalIgnoreCase))
        {
            return "Patient record not found. Please ensure the patient already exists in PatientData with matching phone or email.";
        }

        return "Eligible record not found for sign up.";
    }
}
