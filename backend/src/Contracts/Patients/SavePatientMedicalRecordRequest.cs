namespace OptimaHealthcare.Contracts.Patients;

public sealed class SavePatientMedicalRecordRequest
{
    public int RecordTypeId { get; set; }
    public string RecordName { get; set; } = string.Empty;
    public string? FileBase64 { get; set; }
    public string? FileName { get; set; }
    public string? ContentType { get; set; }
    public DateTime ReportDate { get; set; }
    public string? Comments { get; set; }
}
