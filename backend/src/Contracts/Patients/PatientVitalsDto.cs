namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientVitalsDto
{
    public int PatientVitalsId { get; init; }
    public int PatientDataId { get; init; }
    public int BPSys { get; init; }
    public int BPDys { get; init; }
    public double BloodSugar { get; init; }
    public string SugarType { get; init; } = string.Empty;
    public int Pulse { get; init; }
    public double WeightKG { get; init; }
    public double HeightCMS { get; init; }
    public double BMI { get; init; }
    public DateTime InsertedOn { get; init; }
    public int InsertedBy { get; init; }
    public bool IsActive { get; init; }
}
