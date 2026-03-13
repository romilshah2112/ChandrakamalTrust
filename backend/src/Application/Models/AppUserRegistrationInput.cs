namespace OptimaHealthcare.Application.Models;

public sealed class AppUserRegistrationInput
{
    public required string FirstName { get; init; }
    public required string LastName { get; init; }
    public required long MobileNumber { get; init; }
    public required string EmailAddress { get; init; }
    public required string Password { get; init; }
    public required int UserRoleId { get; init; }
}
