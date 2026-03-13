using OptimaHealthcare.Contracts.Auth;

namespace OptimaHealthcare.Application.Abstractions;

public interface IUserRoleLookupService
{
    Task<IReadOnlyList<UserRoleOptionResponse>> GetAllowedRolesAsync(CancellationToken cancellationToken);
}
