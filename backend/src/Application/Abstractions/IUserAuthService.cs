using OptimaHealthcare.Application.Models;

namespace OptimaHealthcare.Application.Abstractions;

public interface IUserAuthService
{
    Task<AppUserAuthResult?> AuthenticateAsync(string username, string password, CancellationToken cancellationToken);
}
