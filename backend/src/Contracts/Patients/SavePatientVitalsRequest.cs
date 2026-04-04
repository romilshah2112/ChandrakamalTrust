namespace OptimaHealthcare.Contracts.Patients;

public sealed class SavePatientVitalsRequest
{
    public int PatientDataId { get; set; }
    public int BPSys { get; set; }
    public int BPDys { get; set; }
    public int BloodSugar { get; set; }
    public int Pulse { get; set; }
    public int WeightKG { get; set; }
    public int HeightCMS { get; set; }
    public bool IsActive { get; set; } = true;
}
