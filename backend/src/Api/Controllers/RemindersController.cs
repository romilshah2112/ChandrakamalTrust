using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/v1/reminders")]
public sealed class RemindersController : ControllerBase
{
    private readonly IAppointmentReminderService _reminderService;

    public RemindersController(IAppointmentReminderService reminderService)
    {
        _reminderService = reminderService;
    }

    /// <summary>
    /// Sends appointment reminders (upcoming) and follow-up reminders (post-visit).
    /// Can be called manually or by an external scheduler. Normally the background service handles this hourly.
    /// </summary>
    [HttpPost("send")]
    [ProducesResponseType(typeof(RemindersSentResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<RemindersSentResponse>> SendReminders(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        var appointmentSent = await _reminderService.SendAppointmentRemindersAsync(now, cancellationToken);
        var followUpSent = await _reminderService.SendFollowUpRemindersAsync(now, cancellationToken);

        return Ok(new RemindersSentResponse
        {
            AppointmentRemindersSent = appointmentSent,
            FollowUpRemindersSent = followUpSent
        });
    }
}

public sealed class RemindersSentResponse
{
    public int AppointmentRemindersSent { get; init; }
    public int FollowUpRemindersSent { get; init; }
}
