namespace OptimaHealthcare.Application.Abstractions;

public interface IEmailService
{
    Task SendPasswordResetEmailAsync(string toEmail, string resetToken, CancellationToken cancellationToken = default);

    /// <summary>Sends an appointment reminder (e.g. 24h before the visit).</summary>
    Task SendAppointmentReminderAsync(
        string toEmail,
        string patientName,
        string doctorName,
        string clinicName,
        DateTime appointmentStartTime,
        CancellationToken cancellationToken = default);

    /// <summary>Sends a follow-up reminder after an appointment (e.g. next day).</summary>
    Task SendFollowUpReminderAsync(
        string toEmail,
        string patientName,
        string doctorName,
        string clinicName,
        DateTime appointmentDate,
        CancellationToken cancellationToken = default);
}
