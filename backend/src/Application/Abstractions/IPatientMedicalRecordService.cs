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

    /// <summary>Returns the raw FileURL for one record, or null if not found.</summary>
    Task<string?> GetFileUrlAsync(int recordId, int patientDataId, CancellationToken cancellationToken);

    Task<bool> UpdateAsync(
        int recordId,
        int patientDataId,
        UpdatePatientMedicalRecordRequest request,
        CancellationToken cancellationToken);

    Task<string?> DeleteAsync(int recordId, int patientDataId, CancellationToken cancellationToken);
}
