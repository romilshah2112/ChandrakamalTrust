using System;

namespace OptimaHealthcare.Contracts.Patients;

public sealed class SavePatientVitalsRequest
{
    public int PatientDataId { get; set; }
    public int BPSys { get; set; }
    public int BPDys { get; set; }
    public double BloodSugar { get; set; }
    public string SugarType { get; set; } = string.Empty;
    public int Pulse { get; set; }
    public double WeightKG { get; set; }
    public double HeightCMS { get; set; }
    public DateTime MeasuredOn { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;
}
