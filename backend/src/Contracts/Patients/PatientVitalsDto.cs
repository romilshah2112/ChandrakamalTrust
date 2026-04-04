namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientVitalsDto
{
    public int PatientVitalsId { get; init; }
    public int PatientDataId { get; init; }
    public int BPSys { get; init; }
    public int BPDys { get; init; }
    public int BloodSugar { get; init; }
    public int Pulse { get; init; }
    public int WeightKG { get; init; }
    public int HeightCMS { get; init; }
    public DateTime InsertedOn { get; init; }
    public int InsertedBy { get; init; }
    public bool IsActive { get; init; }
}
