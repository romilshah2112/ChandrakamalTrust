using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface ISeverityService
{
    Task<IReadOnlyList<SeverityItemDto>> ListAsync(CancellationToken cancellationToken);
}
