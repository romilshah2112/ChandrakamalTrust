using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Application.Models;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class SqlAppUserAuthService : IUserAuthService
{
    private static readonly string[] AppUserIdCandidates = ["lAppUserId", "AppUserId", "UserId", "Id"];
    private static readonly string[] UsernameCandidates = ["MobileNumber", "EmailAddress", "UserName", "Username", "LoginId", "Email"];
    private static readonly string[] PasswordCandidates = ["PasswordHash", "Password", "Passcode", "UserPassword"];
    private static readonly string[] RoleCandidates = ["Role", "RoleName", "UserRole"];
    private static readonly string[] IsActiveCandidates = ["IsEnabled", "IsActive", "Active"];
    private static readonly string[] IsDeletedCandidates = ["IsDeleted", "Deleted"];
    private static readonly string[] AppUserRoleFkCandidates = ["lUserRoleId", "UserRoleId", "RoleId", "FkUserRoleId"];
    private static readonly string[] UserRolePkCandidates = ["lUserRoleId", "UserRoleId", "RoleId", "Id"];
    private static readonly string[] UserRoleNameCandidates = ["RoleName", "Name", "Role", "UserRole"];
    private static readonly string[] MobileCandidates = ["MobileNumber"];
    private static readonly string[] EmailCandidates = ["EmailAddress", "Email"];

    private readonly string _connectionString;
    private readonly IPasswordCryptoService _passwordCryptoService;

    public SqlAppUserAuthService(IConfiguration configuration, IPasswordCryptoService passwordCryptoService)
    {
        _passwordCryptoService = passwordCryptoService;
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<AppUserAuthResult?> AuthenticateAsync(string username, string password, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var appUserColumns = await GetColumnsAsync(connection, "AppUser", cancellationToken);

        var usernameColumn = ResolveFirst(appUserColumns, UsernameCandidates);
        var appUserIdColumn = ResolveFirst(appUserColumns, AppUserIdCandidates);
        var passwordColumn = ResolveFirst(appUserColumns, PasswordCandidates);
        var mobileColumn = ResolveFirst(appUserColumns, MobileCandidates);
        var emailColumn = ResolveFirst(appUserColumns, EmailCandidates);

        if ((usernameColumn is null && mobileColumn is null && emailColumn is null) || passwordColumn is null || appUserIdColumn is null)
        {
            return null;
        }

        var roleColumn = ResolveFirst(appUserColumns, RoleCandidates);
        var isActiveColumn = ResolveFirst(appUserColumns, IsActiveCandidates);
        var isDeletedColumn = ResolveFirst(appUserColumns, IsDeletedCandidates);
        var appUserRoleFkColumn = ResolveFirst(appUserColumns, AppUserRoleFkCandidates);

        var userRoleColumns = await GetColumnsAsync(connection, "UserRole", cancellationToken);
        var userRolePkColumn = ResolveFirst(userRoleColumns, UserRolePkCandidates);
        var userRoleNameColumn = ResolveFirst(userRoleColumns, UserRoleNameCandidates);

        var sql = BuildSql(
            appUserIdColumn,
            passwordColumn,
            roleColumn,
            isActiveColumn,
            isDeletedColumn,
            usernameColumn,
            mobileColumn,
            emailColumn,
            appUserRoleFkColumn,
            userRolePkColumn,
            userRoleNameColumn);

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@username", username);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var dbUsername = reader["UsernameValue"]?.ToString() ?? string.Empty;
        var dbAppUserId = Convert.ToInt32(reader["AppUserIdValue"]);
        var dbPassword = reader["PasswordValue"]?.ToString() ?? string.Empty;
        var dbRole = reader["RoleValue"]?.ToString();

        if (!_passwordCryptoService.IsMatch(password, dbPassword))
        {
            return null;
        }

        return new AppUserAuthResult
        {
            AppUserId = dbAppUserId,
            Username = dbUsername,
            Role = string.IsNullOrWhiteSpace(dbRole) ? "User" : dbRole
        };
    }

    private static string BuildSql(
        string appUserIdColumn,
        string passwordColumn,
        string? roleColumn,
        string? isActiveColumn,
        string? isDeletedColumn,
        string? usernameColumn,
        string? mobileColumn,
        string? emailColumn,
        string? appUserRoleFkColumn,
        string? userRolePkColumn,
        string? userRoleNameColumn)
    {
        var joinUserRole = appUserRoleFkColumn is not null
            && userRolePkColumn is not null
            && userRoleNameColumn is not null;

        var selectRole = joinUserRole
            ? $"ur.[{userRoleNameColumn}]"
            : roleColumn is null ? "'User'" : $"au.[{roleColumn}]";

        var loginMatchClause = BuildLoginMatchClause(usernameColumn, mobileColumn, emailColumn);
        if (string.IsNullOrWhiteSpace(loginMatchClause))
        {
            throw new InvalidOperationException("No supported username column found in AppUser.");
        }

        var whereClauses = new List<string> { loginMatchClause };

        if (isActiveColumn is not null)
        {
            whereClauses.Add(
                $"(TRY_CONVERT(int, au.[{isActiveColumn}]) = 1 " +
                $"OR LOWER(CAST(au.[{isActiveColumn}] AS nvarchar(10))) = 'true' " +
                $"OR au.[{isActiveColumn}] IS NULL)");
        }

        if (isDeletedColumn is not null)
        {
            whereClauses.Add(
                $"(TRY_CONVERT(int, au.[{isDeletedColumn}]) = 0 " +
                $"OR LOWER(CAST(au.[{isDeletedColumn}] AS nvarchar(10))) = 'false' " +
                $"OR au.[{isDeletedColumn}] IS NULL)");
        }

        var joinClause = joinUserRole
            ? $"LEFT JOIN [UserRole] ur ON ur.[{userRolePkColumn}] = au.[{appUserRoleFkColumn}]"
            : string.Empty;

        var usernameSelection = !string.IsNullOrWhiteSpace(mobileColumn)
            ? $"CAST(au.[{mobileColumn}] AS nvarchar(256))"
            : !string.IsNullOrWhiteSpace(emailColumn)
                ? $"CAST(au.[{emailColumn}] AS nvarchar(256))"
                : $"CAST(au.[{usernameColumn}] AS nvarchar(256))";

        return $@"
SELECT TOP 1
    CAST(au.[{appUserIdColumn}] AS int) AS AppUserIdValue,
    {usernameSelection} AS UsernameValue,
    CAST(au.[{passwordColumn}] AS nvarchar(512)) AS PasswordValue,
    CAST({selectRole} AS nvarchar(128)) AS RoleValue
FROM [AppUser] au
{joinClause}
WHERE {string.Join(" AND ", whereClauses)}";
    }

    private static string BuildLoginMatchClause(string? usernameColumn, string? mobileColumn, string? emailColumn)
    {
        var options = new List<string>();

        if (!string.IsNullOrWhiteSpace(mobileColumn))
        {
            options.Add($"CAST(au.[{mobileColumn}] AS nvarchar(50)) = @username");
        }

        if (!string.IsNullOrWhiteSpace(emailColumn))
        {
            options.Add($"au.[{emailColumn}] = @username");
        }

        if (!string.IsNullOrWhiteSpace(usernameColumn)
            && !string.Equals(usernameColumn, mobileColumn, StringComparison.OrdinalIgnoreCase)
            && !string.Equals(usernameColumn, emailColumn, StringComparison.OrdinalIgnoreCase))
        {
            // Compare as string to avoid SQL conversion failures when column type is numeric.
            options.Add($"CAST(au.[{usernameColumn}] AS nvarchar(256)) = @username");
        }

        if (options.Count == 0)
        {
            return string.Empty;
        }

        if (options.Count == 1)
        {
            return options[0];
        }

        return $"({string.Join(" OR ", options)})";
    }

    private static string? ResolveFirst(HashSet<string> columns, IReadOnlyList<string> candidates)
    {
        return candidates.FirstOrDefault(columns.Contains);
    }

    private static async Task<HashSet<string>> GetColumnsAsync(SqlConnection connection, string tableName, CancellationToken cancellationToken)
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
            var column = reader.GetString(0);
            result.Add(column);
        }

        return result;
    }
}
