using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class SqlUserRoleLookupService : IUserRoleLookupService
{
    private static readonly string[] RoleIdCandidates = ["lUserRoleId", "UserRoleId", "RoleId", "Id"];
    private static readonly string[] RoleNameCandidates = ["RoleName", "Name", "Role", "UserRole"];
    private static readonly string[] AllowedRoles = ["Patient", "Doctor", "Receptionist"];

    private readonly string _connectionString;

    public SqlUserRoleLookupService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<UserRoleOptionResponse>> GetAllowedRolesAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var columns = await GetColumnsAsync(connection, cancellationToken);
        var roleIdColumn = ResolveFirst(columns, RoleIdCandidates);
        var roleNameColumn = ResolveFirst(columns, RoleNameCandidates);

        if (roleIdColumn is null || roleNameColumn is null)
        {
            return [];
        }

        var sql = $@"
SELECT
    CAST([{roleIdColumn}] AS int) AS RoleId,
    CAST([{roleNameColumn}] AS nvarchar(100)) AS RoleName
FROM [UserRole]
WHERE LOWER(CAST([{roleNameColumn}] AS nvarchar(100))) IN ('patient', 'doctor', 'receptionist')
ORDER BY RoleName";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var roles = new List<UserRoleOptionResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var roleId = reader.GetInt32(0);
            var roleName = reader.GetString(1);
            if (AllowedRoles.Any(ar => string.Equals(ar, roleName, StringComparison.OrdinalIgnoreCase)))
            {
                roles.Add(new UserRoleOptionResponse
                {
                    UserRoleId = roleId,
                    RoleName = roleName
                });
            }
        }

        return roles;
    }

    private static string? ResolveFirst(HashSet<string> columns, IReadOnlyList<string> candidates)
    {
        return candidates.FirstOrDefault(columns.Contains);
    }

    private static async Task<HashSet<string>> GetColumnsAsync(SqlConnection connection, CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'UserRole'";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(reader.GetString(0));
        }

        return result;
    }
}
