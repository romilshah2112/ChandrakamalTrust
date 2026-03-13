namespace OptimaHealthcare.Contracts.Auth;

public sealed class LoginResponse
{
    public required int AppUserId { get; init; }
    public required string Username { get; init; }
    public required string AccessToken { get; init; }
    public required DateTime ExpiresAtUtc { get; init; }
    public required string Role { get; init; }
}
