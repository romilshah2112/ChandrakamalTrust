namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientDataResponse
{
    public int PatientDataId { get; init; }
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public long MobileNo { get; init; }
    public string Email { get; init; } = string.Empty;
    public string Address { get; init; } = string.Empty;
    public string Gender { get; init; } = string.Empty;
    public string City { get; init; } = string.Empty;
    public DateOnly BirthDate { get; init; }
    public DateOnly CreatedDate { get; init; }
    public string ImageName { get; init; } = string.Empty;
    public int AppUserId { get; init; }
    public int ReferenceTypeId { get; init; }
    public string ReferenceName { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}
