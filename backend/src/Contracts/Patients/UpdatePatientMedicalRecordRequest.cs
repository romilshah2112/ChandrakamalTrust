namespace OptimaHealthcare.Contracts.Patients;

public sealed class UpdatePatientMedicalRecordRequest
{
    public int RecordTypeId { get; set; }
    public string RecordName { get; set; } = string.Empty;
    public DateTime ReportDate { get; set; }
    public string? Comments { get; set; }
}
