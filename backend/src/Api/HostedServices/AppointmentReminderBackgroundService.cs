using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Api.HostedServices;

/// <summary>
/// Runs on a timer to send appointment reminders (upcoming) and follow-up reminders (post-visit).
/// </summary>
public sealed class AppointmentReminderBackgroundService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AppointmentReminderBackgroundService> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromHours(1);

    public AppointmentReminderBackgroundService(
        IServiceProvider serviceProvider,
        ILogger<AppointmentReminderBackgroundService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Appointment reminder background service started. Interval: {Interval}", _interval);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunRemindersAsync(stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in appointment reminder run");
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }

    private async Task RunRemindersAsync(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var reminderService = scope.ServiceProvider.GetRequiredService<IAppointmentReminderService>();

        var now = DateTime.UtcNow;

        // Appointment reminders: uses AppointmentType.ReminderHoursBefore (First Visit / Follow-up)
        var appointmentSent = await reminderService.SendAppointmentRemindersAsync(now, cancellationToken);
        if (appointmentSent > 0)
        {
            _logger.LogInformation("Sent {Count} appointment reminder(s)", appointmentSent);
        }

        // Follow-up reminders: uses AppointmentType.FollowUpReminderHoursAfter
        var followUpSent = await reminderService.SendFollowUpRemindersAsync(now, cancellationToken);
        if (followUpSent > 0)
        {
            _logger.LogInformation("Sent {Count} follow-up reminder(s)", followUpSent);
        }
    }
}
