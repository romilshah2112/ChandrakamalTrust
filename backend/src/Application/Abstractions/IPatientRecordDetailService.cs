using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientRecordDetailService
{
    Task<IReadOnlyList<PatientRecordDetailDto>> ExtractPreviewAsync(
        byte[] fileBytes,
        string contentType,
        string fallbackPatientName,
        DateTime reportDateTime,
        CancellationToken cancellationToken);

    Task SaveAsync(
        int patientMedicalRecordId,
        string patientNameInRecord,
        IReadOnlyList<SavePatientRecordDetailItemRequest> details,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<PatientRecordDetailDto>> ListByMedicalRecordAsync(
        int patientMedicalRecordId,
        CancellationToken cancellationToken);
}
