using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientReadService
{
    Task<IReadOnlyList<PatientSummaryDto>> SearchAsync(string? query, CancellationToken cancellationToken);
    Task<PatientDetailDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
}
