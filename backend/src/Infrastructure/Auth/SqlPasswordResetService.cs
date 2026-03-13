using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class SqlPasswordResetService : IPasswordResetService
{
    private const int TokenExpirationMinutes = 60;
    private static readonly string[] AppUserIdCandidates = ["lAppUserId", "AppUserId", "UserId", "Id"];
    private static readonly string[] EmailCandidates = ["EmailAddress", "Email"];
    private static readonly string[] PasswordCandidates = ["PasswordHash", "Password", "Passcode", "UserPassword"];

    private readonly string _connectionString;
    private readonly IPasswordCryptoService _passwordCryptoService;
    private readonly IEmailService _emailService;

    public SqlPasswordResetService(
        IConfiguration configuration,
        IPasswordCryptoService passwordCryptoService,
        IEmailService emailService)
    {
        _passwordCryptoService = passwordCryptoService;
        _emailService = emailService;
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found.");
    }

    public async Task RequestPasswordResetAsync(string emailAddress, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(emailAddress))
        {
            return;
        }

        var normalizedEmail = emailAddress.Trim();
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var (appUserId, emailColumn) = await ResolveAppUserIdByEmailAsync(connection, normalizedEmail, cancellationToken);
        if (appUserId is null)
        {
            return;
        }

        var token = Guid.NewGuid().ToString("N");
        var expiresAt = DateTime.UtcNow.AddMinutes(TokenExpirationMinutes);

        await EnsurePasswordResetTokenTableAsync(connection, cancellationToken);

        await using var deleteCommand = new SqlCommand("DELETE FROM [PasswordResetToken] WHERE [AppUserId] = @appUserId", connection);
        deleteCommand.Parameters.AddWithValue("@appUserId", appUserId.Value);
        await deleteCommand.ExecuteNonQueryAsync(cancellationToken);

        await using var insertCommand = new SqlCommand(
            "INSERT INTO [PasswordResetToken] ([Token], [AppUserId], [ExpiresAtUtc]) VALUES (@token, @appUserId, @expiresAt)",
            connection);
        insertCommand.Parameters.AddWithValue("@token", token);
        insertCommand.Parameters.AddWithValue("@appUserId", appUserId.Value);
        insertCommand.Parameters.AddWithValue("@expiresAt", expiresAt);
        await insertCommand.ExecuteNonQueryAsync(cancellationToken);

        await _emailService.SendPasswordResetEmailAsync(normalizedEmail, token, cancellationToken);
    }

    public async Task<bool> ResetPasswordAsync(string token, string newPassword, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(newPassword))
        {
            return false;
        }

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await EnsurePasswordResetTokenTableAsync(connection, cancellationToken);

        int? appUserId;
        await using (var selectCommand = new SqlCommand(@"
            SELECT [AppUserId] FROM [PasswordResetToken]
            WHERE [Token] = @token AND [ExpiresAtUtc] > @now",
            connection))
        {
            selectCommand.Parameters.AddWithValue("@token", token);
            selectCommand.Parameters.AddWithValue("@now", DateTime.UtcNow);
            var result = await selectCommand.ExecuteScalarAsync(cancellationToken);
            appUserId = result is not null ? Convert.ToInt32(result) : null;
        }

        if (appUserId is null)
        {
            return false;
        }

        var appUserColumns = await GetColumnsAsync(connection, "AppUser", cancellationToken);
        var appUserIdColumn = ResolveFirst(appUserColumns, AppUserIdCandidates);
        var passwordColumn = ResolveFirst(appUserColumns, PasswordCandidates);

        if (appUserIdColumn is null || passwordColumn is null)
        {
            return false;
        }

        var hashedPassword = _passwordCryptoService.Encrypt(newPassword);

        await using var updateCommand = new SqlCommand($@"
            UPDATE [AppUser] SET [{passwordColumn}] = @password WHERE [{appUserIdColumn}] = @appUserId;
            DELETE FROM [PasswordResetToken] WHERE [AppUserId] = @appUserId;",
            connection);
        updateCommand.Parameters.AddWithValue("@password", hashedPassword);
        updateCommand.Parameters.AddWithValue("@appUserId", appUserId.Value);
        await updateCommand.ExecuteNonQueryAsync(cancellationToken);

        return true;
    }

    private async Task<(int? AppUserId, string? EmailColumn)> ResolveAppUserIdByEmailAsync(
        SqlConnection connection,
        string email,
        CancellationToken cancellationToken)
    {
        var appUserColumns = await GetColumnsAsync(connection, "AppUser", cancellationToken);
        var appUserIdColumn = ResolveFirst(appUserColumns, AppUserIdCandidates);
        var emailColumn = ResolveFirst(appUserColumns, EmailCandidates);

        if (appUserIdColumn is null || emailColumn is null)
        {
            return (null, null);
        }

        await using var command = new SqlCommand(
            $"SELECT [{appUserIdColumn}] FROM [AppUser] WHERE [{emailColumn}] = @email",
            connection);
        command.Parameters.AddWithValue("@email", email);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is not null ? (Convert.ToInt32(result), emailColumn) : (null, null);
    }

    private static async Task EnsurePasswordResetTokenTableAsync(SqlConnection connection, CancellationToken cancellationToken)
    {
        const string createTableSql = @"
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PasswordResetToken')
            CREATE TABLE [PasswordResetToken] (
                [Token] nvarchar(64) NOT NULL PRIMARY KEY,
                [AppUserId] int NOT NULL,
                [ExpiresAtUtc] datetime2 NOT NULL
            );";
        await using var command = new SqlCommand(createTableSql, connection);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static string? ResolveFirst(HashSet<string> columns, string[] candidates)
    {
        return candidates.FirstOrDefault(columns.Contains);
    }

    private static async Task<HashSet<string>> GetColumnsAsync(SqlConnection connection, string tableName, CancellationToken cancellationToken)
    {
        const string sql = @"
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @tableName";
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
}
