using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class SqlUserProfileService : IUserProfileService
{
    private static readonly string[] AppUserIdCandidates = ["lAppUserId", "AppUserId", "UserId", "Id"];
    private readonly string _connectionString;
    private readonly IPasswordCryptoService _passwordCryptoService;
    private readonly IImageStorageService _imageStorageService;
    private readonly ILogger<SqlUserProfileService> _logger;

    public SqlUserProfileService(
        IConfiguration configuration,
        IPasswordCryptoService passwordCryptoService,
        IImageStorageService imageStorageService,
        ILogger<SqlUserProfileService> logger)
    {
        _passwordCryptoService = passwordCryptoService;
        _imageStorageService = imageStorageService;
        _logger = logger;
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

        var appUserIdColumn = await ResolveAppUserIdColumnAsync(connection, cancellationToken);
        if (string.IsNullOrWhiteSpace(appUserIdColumn))
        {
            _logger.LogError(
                "Profile update failed because no AppUser id column was resolved. appUserId={AppUserId}",
                appUserId);
            throw new InvalidOperationException("AppUser id column could not be resolved for profile update.");
        }

        _logger.LogInformation(
            "Profile update started. appUserId={AppUserId}, appUserIdColumn={AppUserIdColumn}, setPassword={SetPassword}",
            appUserId,
            appUserIdColumn,
            !string.IsNullOrWhiteSpace(request.NewPassword));

        var userExists = await EnsureUserExistsAsync(connection, appUserIdColumn, appUserId, cancellationToken);
        _logger.LogInformation(
            "Profile update user existence check. appUserId={AppUserId}, appUserIdColumn={AppUserIdColumn}, exists={Exists}",
            appUserId,
            appUserIdColumn,
            userExists);

        var setPassword = !string.IsNullOrWhiteSpace(request.NewPassword);
        var profileImage = await ResolveProfileImageAsync(request, cancellationToken);
        _logger.LogInformation(
            "Profile update image resolution. appUserId={AppUserId}, imageProvided={ImageProvided}, storedProfileImageValue={StoredProfileImageValue}",
            appUserId,
            !string.IsNullOrWhiteSpace(request.ImageBase64),
            profileImage);

        var sql = setPassword
            ? @"
UPDATE [AppUser]
SET [FirstName] = @firstName,
    [LastName] = @lastName,
    [MobileNumber] = @mobileNumber,
    [EmailAddress] = @emailAddress,
    [ProfileImage] = @profileImage,
    [Password] = @password
WHERE [{0}] = @appUserId"
            : @"
UPDATE [AppUser]
SET [FirstName] = @firstName,
    [LastName] = @lastName,
    [MobileNumber] = @mobileNumber,
    [EmailAddress] = @emailAddress,
    [ProfileImage] = @profileImage
WHERE [{0}] = @appUserId";

        sql = string.Format(sql, appUserIdColumn);

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

        var rows = await command.ExecuteNonQueryAsync(cancellationToken);
        _logger.LogInformation(
            "Profile update SQL executed. appUserId={AppUserId}, appUserIdColumn={AppUserIdColumn}, rowsAffected={RowsAffected}",
            appUserId,
            appUserIdColumn,
            rows);
    }

    private async Task<bool> EnsureUserExistsAsync(
        SqlConnection connection,
        string appUserIdColumn,
        int appUserId,
        CancellationToken cancellationToken)
    {
        var sql = $"SELECT COUNT(1) FROM [AppUser] WHERE [{appUserIdColumn}] = @appUserId";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@appUserId", appUserId);
        var count = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken));
        _logger.LogInformation(
            "Profile update existence count. appUserId={AppUserId}, appUserIdColumn={AppUserIdColumn}, count={Count}",
            appUserId,
            appUserIdColumn,
            count);
        if (count <= 0)
        {
            throw new InvalidOperationException("Profile update did not match any user record.");
        }

        return true;
    }

    private async Task<string?> ResolveAppUserIdColumnAsync(
        SqlConnection connection,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'AppUser'";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var columns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(cancellationToken))
        {
            columns.Add(reader.GetString(0));
        }

        var resolved = AppUserIdCandidates.FirstOrDefault(columns.Contains);
        _logger.LogInformation(
            "Resolved AppUser id column for profile service. resolvedColumn={ResolvedColumn}, availableColumns={AvailableColumns}",
            resolved,
            string.Join(",", columns.OrderBy(x => x)));
        return resolved;
    }

    private async Task<UserProfileResponse?> ReadSingleAsync(SqlCommand command, CancellationToken cancellationToken)
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
            ProfileImage = _imageStorageService.ResolveImageUrl(reader["ProfileImage"]?.ToString()) ?? string.Empty,
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
            return _imageStorageService.NormalizeStoredValue(request.ProfileImage);
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
