namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientComplaintDto
{
    public int PatientComplaintId { get; init; }
    public int PatientDataId { get; init; }
    public string Symptoms { get; init; } = string.Empty;
    public int SeverityId { get; init; }
    public string Severity { get; init; } = string.Empty;
    public DateTime InsertedOn { get; init; }
    public int EnteredById { get; init; }
    public bool IsActive { get; init; }
}
