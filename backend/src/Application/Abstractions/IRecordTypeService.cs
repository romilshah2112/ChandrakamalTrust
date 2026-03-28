using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IRecordTypeService
{
    Task<IReadOnlyList<RecordTypeItemDto>> ListAsync(CancellationToken cancellationToken);
}
