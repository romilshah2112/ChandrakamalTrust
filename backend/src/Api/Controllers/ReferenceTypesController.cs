using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/reference-types")]
public sealed class ReferenceTypesController : ControllerBase
{
    private static readonly string[] AllowedRoles = ["admin", "doctor", "receptionist"];
    private readonly IReferenceTypeService _referenceTypeService;

    public ReferenceTypesController(IReferenceTypeService referenceTypeService)
    {
        _referenceTypeService = referenceTypeService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ReferenceTypeItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ReferenceTypeItemDto>>> List(CancellationToken cancellationToken)
    {
        var role = User.GetRoleName();
        var allowed = AllowedRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
        if (!allowed)
        {
            return Forbid();
        }

        var list = await _referenceTypeService.ListAsync(cancellationToken);
        return Ok(list);
    }
}
