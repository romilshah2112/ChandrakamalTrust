using OptimaHealthcare.Application.Models;

namespace OptimaHealthcare.Application.Abstractions;

public interface IUserRegistrationService
{
    Task<int> RegisterAsync(AppUserRegistrationInput input, CancellationToken cancellationToken);
}
