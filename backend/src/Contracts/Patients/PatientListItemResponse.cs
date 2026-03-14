namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientListItemResponse
{
    public int PatientDataId { get; init; }
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public long MobileNo { get; init; }
    public string Email { get; init; } = string.Empty;
    public string ImageName { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}
