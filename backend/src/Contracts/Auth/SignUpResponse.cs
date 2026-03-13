namespace OptimaHealthcare.Contracts.Auth;

public sealed class SignUpResponse
{
    public required int AppUserId { get; init; }
    public required string Message { get; init; }
}
