using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientDataService
{
    Task<int> CreateAsync(PatientDataCreateRequest request, CancellationToken cancellationToken);
    Task<PatientDataResponse?> GetByAppUserIdAsync(int appUserId, CancellationToken cancellationToken);
    Task<PatientDataResponse?> GetByIdAsync(int patientDataId, string? roleName, CancellationToken cancellationToken);
    Task<IReadOnlyList<PatientListItemResponse>> ListAsync(string? query, string? roleName, CancellationToken cancellationToken);
    Task<bool> UpdateMyContactAsync(int appUserId, PatientContactUpdateRequest request, CancellationToken cancellationToken);
    Task<bool> UpdateAsync(int patientDataId, PatientDataUpdateRequest request, CancellationToken cancellationToken);
    /// <summary>Returns (true, null) if deleted; (false, reason) if blocked by reference integrity.</summary>
    Task<(bool Deleted, string? BlockReason)> TryDeleteAsync(int patientDataId, CancellationToken cancellationToken);
}
