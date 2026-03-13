namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientDetailDto
{
    public required Guid Id { get; init; }
    public required string Mrn { get; init; }
    public required string FirstName { get; init; }
    public required string LastName { get; init; }
    public DateOnly? DateOfBirth { get; init; }
    public required string Sex { get; init; }
    public required string Phone { get; init; }
}
