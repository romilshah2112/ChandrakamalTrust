using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlSeverityService : ISeverityService
{
    private readonly string _connectionString;

    public SqlSeverityService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<SeverityItemDto>> ListAsync(CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [lSeverityId], [Name]
FROM [Severity]
ORDER BY [Name], [lSeverityId]";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        var list = new List<SeverityItemDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new SeverityItemDto
            {
                Id = reader["lSeverityId"] is DBNull ? 0 : Convert.ToInt32(reader["lSeverityId"]),
                Name = reader["Name"]?.ToString() ?? string.Empty,
            });
        }

        return list;
    }
}
