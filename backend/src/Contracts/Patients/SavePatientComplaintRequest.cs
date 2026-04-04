namespace OptimaHealthcare.Contracts.Patients;

public sealed class SavePatientComplaintRequest
{
    public int PatientDataId { get; set; }
    public string Symptoms { get; set; } = string.Empty;
    public int SeverityId { get; set; }
    public bool IsActive { get; set; } = true;
}
