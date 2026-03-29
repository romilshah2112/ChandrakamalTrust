using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlRecordKeywordService : IRecordKeywordService
{
    private readonly string _connectionString;

    public SqlRecordKeywordService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<RecordKeywordItemDto>> ListAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT [lRecordKeywordId], [Keyword], [Description], [IdealLower], [IdealUpper]
FROM [RecordKeyword]
WHERE [IsActive] = 1
ORDER BY [Keyword], [lRecordKeywordId]";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var list = new List<RecordKeywordItemDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new RecordKeywordItemDto
            {
                Id = Convert.ToInt32(reader["lRecordKeywordId"]),
                Name = reader["Keyword"] is DBNull or null ? string.Empty : reader["Keyword"].ToString() ?? string.Empty,
                Description = reader["Description"] is DBNull or null ? string.Empty : reader["Description"].ToString() ?? string.Empty,
                IdealLower = reader["IdealLower"] is DBNull ? null : Convert.ToDouble(reader["IdealLower"]),
                IdealUpper = reader["IdealUpper"] is DBNull ? null : Convert.ToDouble(reader["IdealUpper"])
            });
        }

        return list;
    }
}
