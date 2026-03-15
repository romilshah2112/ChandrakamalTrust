using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IReferenceTypeService
{
    Task<IReadOnlyList<ReferenceTypeItemDto>> ListAsync(CancellationToken cancellationToken);
}
