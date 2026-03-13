namespace OptimaHealthcare.Contracts.Masters;

public sealed class ClinicScheduleDto
{
    public int ScheduleId { get; init; }
    public int ClinicId { get; init; }
    public int DayOfWeek { get; init; }
    public string? OpenTime { get; init; }
    public string? CloseTime { get; init; }
    public bool IsClosed { get; init; }
    public int AppUserId { get; init; }
}
