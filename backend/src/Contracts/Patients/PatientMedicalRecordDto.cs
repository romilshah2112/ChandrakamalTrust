namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientMedicalRecordDto
{
    public int PatientMedicalRecordId { get; init; }
    public int PatientDataId { get; init; }
    public int RecordTypeId { get; init; }
    public string RecordName { get; init; } = string.Empty;
    public string FileUrl { get; init; } = string.Empty;
    public DateTime ReportDate { get; init; }
    public string? Comments { get; init; }
    public DateTime UploadedOn { get; init; }
    public int UploadedById { get; init; }
    public bool IsActive { get; init; }
}
