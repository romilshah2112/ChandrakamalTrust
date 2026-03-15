using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlReferenceTypeService : IReferenceTypeService
{
    private readonly string _connectionString;

    public SqlReferenceTypeService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<ReferenceTypeItemDto>> ListAsync(CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT [lReferenceTypeId], [Reference]
FROM [ReferenceType]
ORDER BY [Reference], [lReferenceTypeId]";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var list = new List<ReferenceTypeItemDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var id = Convert.ToInt32(reader["lReferenceTypeId"]);
            var name = reader["Reference"] is DBNull or null ? "" : reader["Reference"].ToString() ?? "";
            list.Add(new ReferenceTypeItemDto { Id = id, Name = name });
        }

        return list;
    }
}
