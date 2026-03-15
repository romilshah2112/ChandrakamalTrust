namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientDataCreateRequest
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
    public int AppUserId { get; set; }
    public int ReferenceTypeId { get; set; }
    public string ReferenceName { get; set; } = string.Empty;
}
