namespace OptimaHealthcare.Contracts.Masters;

public sealed class StaffDto
{
    public int StaffId { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Qualification { get; init; } = string.Empty;
    public long Mobile { get; init; }
    public string Email { get; init; } = string.Empty;
    public string Gender { get; init; } = string.Empty;
    public string Address { get; init; } = string.Empty;
    public string Photo { get; init; } = string.Empty;
    public int EnteredById { get; init; }
    public int AppUserId { get; init; }
    public bool IsActive { get; init; }
}
