namespace OptimaHealthcare.Contracts.Masters;

public sealed class SaveStaffRequest
{
    public string Name { get; set; } = string.Empty;
    public string Qualification { get; set; } = string.Empty;
    public long Mobile { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Gender { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string? Photo { get; set; }
    public int EnteredById { get; set; }
    public int AppUserId { get; set; }
    public bool IsActive { get; set; } = true;
}
