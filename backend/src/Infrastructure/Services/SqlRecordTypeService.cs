using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlRecordTypeService : IRecordTypeService
{
    private readonly string _connectionString;

    public SqlRecordTypeService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<RecordTypeItemDto>> ListAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT [lRecordTypeId], [Name]
FROM [RecordType]
WHERE [IsActive] = 1
ORDER BY [Name], [lRecordTypeId]";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var list = new List<RecordTypeItemDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var id = Convert.ToInt32(reader["lRecordTypeId"]);
            var name = reader["Name"] is DBNull or null ? "" : reader["Name"].ToString() ?? "";
            list.Add(new RecordTypeItemDto { Id = id, Name = name });
        }

        return list;
    }
}
