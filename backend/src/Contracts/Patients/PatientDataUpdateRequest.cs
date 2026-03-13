namespace OptimaHealthcare.Contracts.Patients;

/// <summary>
/// Full patient data update - for staff (Admin, Doctor, Receptionist).
/// </summary>
public sealed class PatientDataUpdateRequest
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public long MobileNo { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string Gender { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public DateOnly BirthDate { get; set; }
    public string? ImageName { get; set; }
    public string? ImageBase64 { get; set; }
    public string? ImageFileName { get; set; }
    public string? ImageContentType { get; set; }
    public int ReferenceTypeId { get; set; }
    public string ReferenceName { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}
