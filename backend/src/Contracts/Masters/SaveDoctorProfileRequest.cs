namespace OptimaHealthcare.Contracts.Masters;

public sealed class SaveDoctorProfileRequest
{
    public string DoctorName { get; set; } = string.Empty;
    public string DoctorDegree { get; set; } = string.Empty;
    public string DoctorStream { get; set; } = string.Empty;
    public int ClinicId { get; set; }
    public string DoctorCity { get; set; } = string.Empty;
    public int CountryId { get; set; }
    public long Phone { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Gender { get; set; } = string.Empty;
    public string? Photo { get; set; }
    public bool IsActive { get; set; } = true;
    public int AppUserId { get; set; }
}
