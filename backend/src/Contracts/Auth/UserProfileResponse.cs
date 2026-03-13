namespace OptimaHealthcare.Contracts.Auth;

public sealed class UserProfileResponse
{
    public int AppUserId { get; init; }
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public long MobileNumber { get; init; }
    public string EmailAddress { get; init; } = string.Empty;
    public string ProfileImage { get; init; } = string.Empty;
    public int UserRoleId { get; init; }
    public string RoleName { get; init; } = string.Empty;
}
