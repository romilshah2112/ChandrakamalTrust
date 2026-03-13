namespace OptimaHealthcare.Contracts.Masters;

public sealed class SaveClinicScheduleRequest
{
    public int ClinicId { get; set; }
    public int DayOfWeek { get; set; }
    public string? OpenTime { get; set; }
    public string? CloseTime { get; set; }
    public bool IsClosed { get; set; }
    public int AppUserId { get; set; }
}
