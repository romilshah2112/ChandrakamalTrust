using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/staff-analytics")]
public sealed class StaffAnalyticsController : ControllerBase
{
    private static readonly string[] AllowedRoles = ["receptionist", "staff"];
    private readonly IStaffAnalyticsService _staffAnalyticsService;

    public StaffAnalyticsController(IStaffAnalyticsService staffAnalyticsService)
    {
        _staffAnalyticsService = staffAnalyticsService;
    }

    [HttpGet("dashboard")]
    [ProducesResponseType(typeof(StaffDashboardAnalyticsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<StaffDashboardAnalyticsDto>> Dashboard(CancellationToken cancellationToken)
    {
        var role = User.GetRoleName();
        var allowed = AllowedRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
        if (!allowed)
        {
            return Forbid();
        }

        return Ok(await _staffAnalyticsService.GetDashboardAsync(cancellationToken));
    }
}
