namespace OptimaHealthcare.Contracts.Auth;

public sealed class SignUpRequest
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string MobileNumber { get; set; } = string.Empty;
    public string EmailAddress { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public int UserRoleId { get; set; }
}
