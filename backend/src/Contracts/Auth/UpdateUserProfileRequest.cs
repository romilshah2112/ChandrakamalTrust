namespace OptimaHealthcare.Contracts.Auth;

public sealed class UpdateUserProfileRequest
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string MobileNumber { get; set; } = string.Empty;
    public string EmailAddress { get; set; } = string.Empty;
    public string? NewPassword { get; set; }
    public string? ProfileImage { get; set; }
    public string? ImageBase64 { get; set; }
    public string? ImageFileName { get; set; }
    public string? ImageContentType { get; set; }
}
