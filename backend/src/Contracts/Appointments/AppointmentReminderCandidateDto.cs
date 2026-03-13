namespace OptimaHealthcare.Contracts.Appointments;

/// <summary>
/// Appointment row with patient contact info and AppointmentType reminder times for sending reminders.
/// </summary>
public sealed class AppointmentReminderCandidateDto
{
    public int PatientAppointmentId { get; init; }
    public int PatientDataId { get; init; }
    public string PatientName { get; init; } = string.Empty;
    public string PatientEmail { get; init; } = string.Empty;
    public int DoctorProfileId { get; init; }
    public string DoctorName { get; init; } = string.Empty;
    public int ClinicId { get; init; }
    public string ClinicName { get; init; } = string.Empty;
    public DateTime StartTime { get; init; }
    public DateTime EndTime { get; init; }
    public int? AppointmentTypeId { get; init; }
    public string? AppointmentTypeName { get; init; }
    /// <summary>From AppointmentType.ReminderHoursBefore.</summary>
    public int ReminderHoursBefore { get; init; }
    /// <summary>From AppointmentType.FollowUpReminderHoursAfter.</summary>
    public int FollowUpReminderHoursAfter { get; init; }
}
