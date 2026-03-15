using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/doctor-analytics")]
public sealed class DoctorAnalyticsController : ControllerBase
{
    private static readonly string[] AllowedRoles = ["admin", "doctor"];
    private readonly IDoctorAnalyticsService _doctorAnalyticsService;

    public DoctorAnalyticsController(IDoctorAnalyticsService doctorAnalyticsService)
    {
        _doctorAnalyticsService = doctorAnalyticsService;
    }

    [HttpGet("dashboard")]
    [ProducesResponseType(typeof(DoctorDashboardAnalyticsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DoctorDashboardAnalyticsDto>> Dashboard(CancellationToken cancellationToken)
    {
        var role = User.GetRoleName();
        var allowed = AllowedRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
        if (!allowed)
        {
            return Forbid();
        }

        var appUserId = User.GetAppUserId();
        if (appUserId <= 0)
        {
            return Forbid();
        }

        return Ok(await _doctorAnalyticsService.GetDashboardAsync(appUserId, role, cancellationToken));
    }
}
