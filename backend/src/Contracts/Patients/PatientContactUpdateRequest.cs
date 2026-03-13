namespace OptimaHealthcare.Contracts.Patients;

/// <summary>
/// Contact details only - for patient self-update.
/// </summary>
public sealed class PatientContactUpdateRequest
{
    public long MobileNo { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
}
