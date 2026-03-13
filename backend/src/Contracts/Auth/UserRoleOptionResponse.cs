namespace OptimaHealthcare.Contracts.Auth;

public sealed class UserRoleOptionResponse
{
    public required int UserRoleId { get; init; }
    public required string RoleName { get; init; }
}
