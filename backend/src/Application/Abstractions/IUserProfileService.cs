using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Application.Abstractions;

public interface IUserProfileService
{
    Task<UserProfileResponse?> GetByAppUserIdAsync(int appUserId, CancellationToken cancellationToken);
    Task<UserProfileResponse?> GetByLoginAsync(string login, CancellationToken cancellationToken);
    Task UpdateAsync(int appUserId, UpdateUserProfileRequest request, CancellationToken cancellationToken);
}
