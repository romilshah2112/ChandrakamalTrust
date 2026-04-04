using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientComplaintService
{
    Task<IReadOnlyList<PatientComplaintDto>> ListByPatientAsync(int patientDataId, CancellationToken cancellationToken);
    Task<int?> GetPatientDataIdByComplaintIdAsync(int patientComplaintId, CancellationToken cancellationToken);
    Task<int> CreateAsync(SavePatientComplaintRequest request, int enteredByAppUserId, CancellationToken cancellationToken);
    Task<bool> UpdateAsync(int patientComplaintId, SavePatientComplaintRequest request, CancellationToken cancellationToken);
    Task<bool> DeleteAsync(int patientComplaintId, CancellationToken cancellationToken);
}
