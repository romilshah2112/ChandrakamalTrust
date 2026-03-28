using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/record-types")]
public sealed class RecordTypesController : ControllerBase
{
    private static readonly string[] StaffRoles = ["admin", "doctor", "receptionist"];

    private readonly IRecordTypeService _recordTypeService;

    public RecordTypesController(IRecordTypeService recordTypeService)
    {
        _recordTypeService = recordTypeService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<RecordTypeItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<RecordTypeItemDto>>> List(CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var list = await _recordTypeService.ListAsync(cancellationToken);
        return Ok(list);
    }

    private bool IsStaffUser()
    {
        var role = User.GetRoleName();
        return StaffRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }
}
