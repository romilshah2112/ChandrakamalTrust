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
    public async Task<ActionResult<StaffDashboardAnalyticsDto>> Dashboard([FromQuery] string? referenceName, CancellationToken cancellationToken)
    {
        if (!IsAllowed())
        {
            return Forbid();
        }

        return Ok(await _staffAnalyticsService.GetDashboardAsync(referenceName, cancellationToken));
    }

    [HttpGet("reference-names")]
    [ProducesResponseType(typeof(IReadOnlyList<string>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<string>>> ReferenceNames(CancellationToken cancellationToken)
    {
        if (!IsAllowed())
        {
            return Forbid();
        }

        return Ok(await _staffAnalyticsService.ListReferenceNamesAsync(cancellationToken));
    }

    private bool IsAllowed()
    {
        var role = User.GetRoleName();
        return AllowedRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }
}
