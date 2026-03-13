namespace OptimaHealthcare.Contracts.Masters;

public sealed class DoctorProfileDto
{
    public int DoctorProfileId { get; init; }
    public string DoctorName { get; init; } = string.Empty;
    public string DoctorDegree { get; init; } = string.Empty;
    public string DoctorStream { get; init; } = string.Empty;
    public int ClinicId { get; init; }
    public string DoctorCity { get; init; } = string.Empty;
    public int CountryId { get; init; }
    public long Phone { get; init; }
    public string Email { get; init; } = string.Empty;
    public string Gender { get; init; } = string.Empty;
    public string Photo { get; init; } = string.Empty;
    public bool IsActive { get; init; }
    public int AppUserId { get; init; }
}
