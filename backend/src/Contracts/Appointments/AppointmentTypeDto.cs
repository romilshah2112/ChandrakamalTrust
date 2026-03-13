namespace OptimaHealthcare.Contracts.Appointments;

/// <summary>
/// Appointment type (e.g. First Visit, Follow-up) with reminder timing from AppointmentType table.
/// </summary>
public sealed class AppointmentTypeDto
{
    public int AppointmentTypeId { get; init; }
    public string AppointmentTypeName { get; init; } = string.Empty;
    /// <summary>Hours before appointment start to send reminder.</summary>
    public int ReminderHoursBefore { get; init; }
    /// <summary>Hours after appointment end to send follow-up reminder; 0 = no follow-up.</summary>
    public int FollowUpReminderHoursAfter { get; init; }
    public string? Description { get; init; }
}
