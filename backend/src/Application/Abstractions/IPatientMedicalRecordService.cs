using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientMedicalRecordService
{
    Task<IReadOnlyList<PatientMedicalRecordDto>> ListByPatientAsync(int patientDataId, CancellationToken cancellationToken);

    Task<int> InsertAsync(
        int patientDataId,
        int recordTypeId,
        string recordName,
        string fileUrl,
        DateTime reportDate,
        string? comments,
        int uploadedByAppUserId,
        CancellationToken cancellationToken);
}
