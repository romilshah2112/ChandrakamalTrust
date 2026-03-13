namespace OptimaHealthcare.Contracts.Auth;

public sealed class ForgotPasswordRequest
{
    public string EmailAddress { get; set; } = string.Empty;
}
