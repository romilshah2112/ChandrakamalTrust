namespace OptimaHealthcare.Contracts.Masters;

public sealed class SaveHealthCampRequest
{
    public string CampName { get; set; } = string.Empty;
    public DateTime CampDate { get; set; }
    public string Location { get; set; } = string.Empty;
    public string Organizer { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int ReferenceTypeId { get; set; }
    public bool IsActive { get; set; } = true;
}
