using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/record-keywords")]
public sealed class RecordKeywordsController : ControllerBase
{
    private static readonly string[] StaffRoles = ["admin", "doctor", "receptionist"];

    private readonly IRecordKeywordService _recordKeywordService;

    public RecordKeywordsController(IRecordKeywordService recordKeywordService)
    {
        _recordKeywordService = recordKeywordService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<RecordKeywordItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<RecordKeywordItemDto>>> List(CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var list = await _recordKeywordService.ListAsync(cancellationToken);
        return Ok(list);
    }

    private bool IsStaffUser()
    {
        var role = User.GetRoleName();
        return StaffRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }
}
