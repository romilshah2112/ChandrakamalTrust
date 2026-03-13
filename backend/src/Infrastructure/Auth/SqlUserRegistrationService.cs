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

        const string existsSql = @"
SELECT TOP 1 1
FROM [AppUser]
WHERE [MobileNumber] = @mobileNumber OR [EmailAddress] = @emailAddress";

        await using (var existsCommand = new SqlCommand(existsSql, connection))
        {
            existsCommand.Parameters.AddWithValue("@mobileNumber", input.MobileNumber);
            existsCommand.Parameters.AddWithValue("@emailAddress", input.EmailAddress);
            var exists = await existsCommand.ExecuteScalarAsync(cancellationToken);
            if (exists is not null)
            {
                throw new InvalidOperationException("User already exists with this mobile number or email address.");
            }
        }

        const string insertSql = @"
INSERT INTO [AppUser]
    ([FirstName], [LastName], [MobileNumber], [EmailAddress], [Password], [lUserRoleId], [IsEnabled], [IsLogin])
OUTPUT INSERTED.[lAppUserId]
VALUES
    (@firstName, @lastName, @mobileNumber, @emailAddress, @password, @userRoleId, @isEnabled, @isLogin)";

        await using var command = new SqlCommand(insertSql, connection);
        command.Parameters.AddWithValue("@firstName", input.FirstName);
        command.Parameters.AddWithValue("@lastName", input.LastName);
        command.Parameters.AddWithValue("@mobileNumber", input.MobileNumber);
        command.Parameters.AddWithValue("@emailAddress", input.EmailAddress);
        command.Parameters.AddWithValue("@password", _passwordCryptoService.Encrypt(input.Password));
        command.Parameters.AddWithValue("@userRoleId", input.UserRoleId);
        command.Parameters.AddWithValue("@isEnabled", 1);
        command.Parameters.AddWithValue("@isLogin", false);

        var insertedId = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(insertedId);
    }
}
