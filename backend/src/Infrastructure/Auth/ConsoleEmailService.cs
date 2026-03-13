using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Auth;

/// <summary>
/// Logs password reset tokens to console. Use for development.
/// In production, replace with an SMTP-based implementation.
/// </summary>
public sealed class ConsoleEmailService : IEmailService
{
    private readonly ILogger<ConsoleEmailService> _logger;

    public ConsoleEmailService(ILogger<ConsoleEmailService> logger)
    {
        _logger = logger;
    }

    public Task SendPasswordResetEmailAsync(string toEmail, string resetToken, CancellationToken cancellationToken = default)
    {
        _logger.LogWarning(
            "[DEV] Password reset requested for {Email}. Reset token (valid 1 hour): {Token}. In production, send this via email.",
            toEmail, resetToken);
        return Task.CompletedTask;
    }

    public Task SendAppointmentReminderAsync(
        string toEmail,
        string patientName,
        string doctorName,
        string clinicName,
        DateTime appointmentStartTime,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "[DEV] Appointment reminder would be sent to {Email} for {PatientName}, Dr. {DoctorName}, {ClinicName} at {Time}",
            toEmail, patientName, doctorName, clinicName, appointmentStartTime.ToString("f"));
        return Task.CompletedTask;
    }

    public Task SendFollowUpReminderAsync(
        string toEmail,
        string patientName,
        string doctorName,
        string clinicName,
        DateTime appointmentDate,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "[DEV] Follow-up reminder would be sent to {Email} for {PatientName} (appointment was on {Date})",
            toEmail, patientName, appointmentDate.ToString("D"));
        return Task.CompletedTask;
    }
}
