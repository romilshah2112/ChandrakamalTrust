namespace OptimaHealthcare.Application.Models;

public sealed class AppUserAuthResult
{
    public required int AppUserId { get; init; }
    public required string Username { get; init; }
    public required string Role { get; init; }
}
