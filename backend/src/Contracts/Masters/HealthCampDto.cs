namespace OptimaHealthcare.Contracts.Masters;

public sealed class HealthCampDto
{
    public int HealthCampId { get; init; }
    public string CampName { get; init; } = string.Empty;
    public DateTime CampDate { get; init; }
    public string Location { get; init; } = string.Empty;
    public string Organizer { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public int ReferenceTypeId { get; init; }
    public bool IsActive { get; init; }
    public DateTime CreatedOn { get; init; }
}
