using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class SqlUserProfileService : IUserProfileService
{
    private readonly string _connectionString;
    private readonly IPasswordCryptoService _passwordCryptoService;
    private readonly IImageStorageService _imageStorageService;

    public SqlUserProfileService(
        IConfiguration configuration,
        IPasswordCryptoService passwordCryptoService,
        IImageStorageService imageStorageService)
    {
        _passwordCryptoService = passwordCryptoService;
        _imageStorageService = imageStorageService;
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<UserProfileResponse?> GetByAppUserIdAsync(int appUserId, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT TOP 1
    au.[lAppUserId], au.[FirstName], au.[LastName], au.[MobileNumber], au.[EmailAddress], ISNULL(au.[ProfileImage], '') AS [ProfileImage], au.[lUserRoleId],
    ISNULL(ur.[RoleName], '') AS RoleName
FROM [AppUser] au
LEFT JOIN [UserRole] ur ON ur.[lUserRoleId] = au.[lUserRoleId]
WHERE au.[lAppUserId] = @appUserId";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@appUserId", appUserId);
        return await ReadSingleAsync(command, cancellationToken);
    }

    public async Task<UserProfileResponse?> GetByLoginAsync(string login, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = @"
SELECT TOP 1
    au.[lAppUserId], au.[FirstName], au.[LastName], au.[MobileNumber], au.[EmailAddress], ISNULL(au.[ProfileImage], '') AS [ProfileImage], au.[lUserRoleId],
    ISNULL(ur.[RoleName], '') AS RoleName
FROM [AppUser] au
LEFT JOIN [UserRole] ur ON ur.[lUserRoleId] = au.[lUserRoleId]
WHERE CAST(au.[MobileNumber] AS nvarchar(50)) = @login
   OR au.[EmailAddress] = @login";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@login", login);
        return await ReadSingleAsync(command, cancellationToken);
    }

    public async Task UpdateAsync(int appUserId, UpdateUserProfileRequest request, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var setPassword = !string.IsNullOrWhiteSpace(request.NewPassword);
        var profileImage = await ResolveProfileImageAsync(request, cancellationToken);

        var sql = setPassword
            ? @"
UPDATE [AppUser]
SET [FirstName] = @firstName,
    [LastName] = @lastName,
    [MobileNumber] = @mobileNumber,
    [EmailAddress] = @emailAddress,
    [ProfileImage] = @profileImage,
    [Password] = @password
WHERE [lAppUserId] = @appUserId"
            : @"
UPDATE [AppUser]
SET [FirstName] = @firstName,
    [LastName] = @lastName,
    [MobileNumber] = @mobileNumber,
    [EmailAddress] = @emailAddress,
    [ProfileImage] = @profileImage
WHERE [lAppUserId] = @appUserId";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@firstName", request.FirstName);
        command.Parameters.AddWithValue("@lastName", request.LastName);
        command.Parameters.AddWithValue("@mobileNumber", long.Parse(request.MobileNumber));
        command.Parameters.AddWithValue("@emailAddress", request.EmailAddress);
        command.Parameters.AddWithValue("@profileImage", (object?)profileImage ?? DBNull.Value);
        command.Parameters.AddWithValue("@appUserId", appUserId);

        if (setPassword)
        {
            command.Parameters.AddWithValue("@password", _passwordCryptoService.Encrypt(request.NewPassword!));
        }

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<UserProfileResponse?> ReadSingleAsync(SqlCommand command, CancellationToken cancellationToken)
    {
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new UserProfileResponse
        {
            AppUserId = Convert.ToInt32(reader["lAppUserId"]),
            FirstName = reader["FirstName"]?.ToString() ?? string.Empty,
            LastName = reader["LastName"]?.ToString() ?? string.Empty,
            MobileNumber = Convert.ToInt64(reader["MobileNumber"]),
            EmailAddress = reader["EmailAddress"]?.ToString() ?? string.Empty,
            ProfileImage = reader["ProfileImage"]?.ToString() ?? string.Empty,
            UserRoleId = Convert.ToInt32(reader["lUserRoleId"]),
            RoleName = reader["RoleName"]?.ToString() ?? string.Empty,
        };
    }

    private async Task<string?> ResolveProfileImageAsync(
        UpdateUserProfileRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.ImageBase64))
        {
            return request.ProfileImage;
        }

        try
        {
            var bytes = Convert.FromBase64String(request.ImageBase64);
            var fileName = string.IsNullOrWhiteSpace(request.ImageFileName)
                ? "user-profile.jpg"
                : request.ImageFileName;
            var contentType = string.IsNullOrWhiteSpace(request.ImageContentType)
                ? "image/jpeg"
                : request.ImageContentType;

            return await _imageStorageService.UploadPatientProfileAsync(
                bytes,
                fileName,
                contentType,
                cancellationToken);
        }
        catch (FormatException)
        {
            throw new InvalidOperationException("Profile image is not a valid base64 payload.");
        }
    }
}
