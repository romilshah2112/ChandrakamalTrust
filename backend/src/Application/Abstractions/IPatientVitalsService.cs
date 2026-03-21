using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientVitalsService
{
    Task<IReadOnlyList<PatientVitalsDto>> ListByPatientAsync(int patientDataId, CancellationToken cancellationToken);
    Task<int?> GetPatientDataIdByVitalsIdAsync(int patientVitalsId, CancellationToken cancellationToken);
    Task<int> CreateAsync(SavePatientVitalsRequest request, int insertedByAppUserId, CancellationToken cancellationToken);
    Task<bool> UpdateAsync(int patientVitalsId, SavePatientVitalsRequest request, CancellationToken cancellationToken);
    Task<bool> DeleteAsync(int patientVitalsId, CancellationToken cancellationToken);
}
