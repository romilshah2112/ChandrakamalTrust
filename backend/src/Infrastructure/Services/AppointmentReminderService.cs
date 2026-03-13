using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Appointments;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class AppointmentReminderService : IAppointmentReminderService
{
    private readonly IPatientAppointmentService _appointmentService;
    private readonly IEmailService _emailService;
    private readonly ILogger<AppointmentReminderService> _logger;

    public AppointmentReminderService(
        IPatientAppointmentService appointmentService,
        IEmailService emailService,
        ILogger<AppointmentReminderService> logger)
    {
        _appointmentService = appointmentService;
        _emailService = emailService;
        _logger = logger;
    }

    public async Task<int> SendAppointmentRemindersAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var candidates = await _appointmentService.ListDueForReminderAsync(
            nowUtc,
            cancellationToken);

        var sent = 0;
        foreach (var c in candidates)
        {
            if (string.IsNullOrWhiteSpace(c.PatientEmail))
            {
                _logger.LogWarning(
                    "Skipping appointment reminder for PatientAppointmentId {Id}: no email for patient {PatientName}",
                    c.PatientAppointmentId, c.PatientName);
                continue;
            }

            try
            {
                await _emailService.SendAppointmentReminderAsync(
                    c.PatientEmail,
                    c.PatientName,
                    c.DoctorName,
                    c.ClinicName,
                    c.StartTime,
                    cancellationToken);
                await _appointmentService.SetNotifiedAsync(c.PatientAppointmentId, cancellationToken);
                sent++;
                _logger.LogInformation(
                    "Sent appointment reminder to {Email} for appointment {Id} at {Time}",
                    c.PatientEmail, c.PatientAppointmentId, c.StartTime);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Failed to send appointment reminder for PatientAppointmentId {Id} to {Email}",
                    c.PatientAppointmentId, c.PatientEmail);
            }
        }

        return sent;
    }

    public async Task<int> SendFollowUpRemindersAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var candidates = await _appointmentService.ListDueForFollowUpReminderAsync(
            nowUtc,
            cancellationToken);

        var sent = 0;
        foreach (var c in candidates)
        {
            if (string.IsNullOrWhiteSpace(c.PatientEmail))
            {
                _logger.LogWarning(
                    "Skipping follow-up reminder for PatientAppointmentId {Id}: no email for patient {PatientName}",
                    c.PatientAppointmentId, c.PatientName);
                continue;
            }

            try
            {
                await _emailService.SendFollowUpReminderAsync(
                    c.PatientEmail,
                    c.PatientName,
                    c.DoctorName,
                    c.ClinicName,
                    c.EndTime.Date,
                    cancellationToken);
                await _appointmentService.SetFollowUpReminderSentAsync(c.PatientAppointmentId, cancellationToken);
                sent++;
                _logger.LogInformation(
                    "Sent follow-up reminder to {Email} for appointment {Id} (ended {EndTime})",
                    c.PatientEmail, c.PatientAppointmentId, c.EndTime);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Failed to send follow-up reminder for PatientAppointmentId {Id} to {Email}",
                    c.PatientAppointmentId, c.PatientEmail);
            }
        }

        return sent;
    }
}
