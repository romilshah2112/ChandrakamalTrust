using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IRecordKeywordService
{
    Task<IReadOnlyList<RecordKeywordItemDto>> ListAsync(CancellationToken cancellationToken);
}
