namespace OptimaHealthcare.Application.Abstractions;

/// <summary>
/// Sends appointment reminders (before visit) and follow-up reminders (after visit).
/// </summary>
public interface IAppointmentReminderService
{
    /// <summary>Sends reminders using AppointmentType.ReminderHoursBefore (first-time / follow-up visitors).</summary>
    Task<int> SendAppointmentRemindersAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken = default);

    /// <summary>Sends follow-up reminders using AppointmentType.FollowUpReminderHoursAfter.</summary>
    Task<int> SendFollowUpRemindersAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken = default);
}
