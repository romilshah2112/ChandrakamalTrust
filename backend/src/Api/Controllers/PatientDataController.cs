using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/patient-data")]
public sealed class PatientDataController : ControllerBase
{
    private readonly IPatientDataService _patientDataService;

    public PatientDataController(IPatientDataService patientDataService)
    {
        _patientDataService = patientDataService;
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create([FromBody] PatientDataCreateRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FirstName)
            || string.IsNullOrWhiteSpace(request.LastName)
            || string.IsNullOrWhiteSpace(request.Email)
            || string.IsNullOrWhiteSpace(request.Password)
            || request.AppUserId <= 0
            || request.ReferenceTypeId <= 0
            || request.MobileNo <= 0)
        {
            return BadRequest("Invalid patient payload.");
        }
        try
        {
            var patientId = await _patientDataService.CreateAsync(request, cancellationToken);
            return StatusCode(StatusCodes.Status201Created, new { patientDataId = patientId });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    /// <summary>Returns the patient record where PatientData.lAppUserId equals the logged-in user's app user id. No other validation.</summary>
    [HttpGet("me")]
    [ProducesResponseType(typeof(PatientDataResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PatientDataResponse>> GetMyPatientRecord(CancellationToken cancellationToken)
    {
        var appUserId = ResolveAppUserId(User);
        if (appUserId is null or <= 0)
        {
            return Unauthorized();
        }

        var patient = await _patientDataService.GetByAppUserIdAsync(appUserId.Value, cancellationToken);
        if (patient is null)
        {
            return NotFound();
        }

        return Ok(patient);
    }

    private static int? ResolveAppUserId(ClaimsPrincipal user)
    {
        var claimTypes = new[]
        {
            ClaimTypes.NameIdentifier,
            "app_user_id",
            "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
            "sub"
        };
        foreach (var claimType in claimTypes)
        {
            var value = user.FindFirstValue(claimType);
            if (!string.IsNullOrEmpty(value) && int.TryParse(value, out var id) && id > 0)
                return id;
        }
        return null;
    }

    /// <summary>Updates contact details for the patient record where PatientData.lAppUserId equals the logged-in user's app user id.</summary>
    [HttpPut("me")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateMyContact([FromBody] PatientContactUpdateRequest request, CancellationToken cancellationToken)
    {
        var appUserId = ResolveAppUserId(User);
        if (appUserId is null or <= 0)
        {
            return Unauthorized();
        }

        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest("Email is required.");
        }

        var updated = await _patientDataService.UpdateMyContactAsync(appUserId.Value, request, cancellationToken);
        if (!updated)
        {
            return NotFound("Patient record not found.");
        }

        return NoContent();
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(typeof(PatientDataResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PatientDataResponse>> GetById(int id, CancellationToken cancellationToken)
    {
        var patient = await _patientDataService.GetByIdAsync(id, cancellationToken);
        if (patient is null)
        {
            return NotFound();
        }

        return Ok(patient);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(int id, [FromBody] PatientDataUpdateRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.FirstName) || string.IsNullOrWhiteSpace(request.LastName) || string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest("FirstName, LastName and Email are required.");
        }
        try
        {
            var updated = await _patientDataService.UpdateAsync(id, request, cancellationToken);
            if (!updated)
            {
                return NotFound("Patient not found.");
            }

            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var (deleted, blockReason) = await _patientDataService.TryDeleteAsync(id, cancellationToken);
        if (!string.IsNullOrEmpty(blockReason))
        {
            return Conflict(blockReason);
        }

        if (!deleted)
        {
            return NotFound("Patient not found.");
        }

        return NoContent();
    }

    [HttpGet]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientListItemResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientListItemResponse>>> List([FromQuery] string? query, CancellationToken cancellationToken)
    {
        var list = await _patientDataService.ListAsync(query, cancellationToken);
        return Ok(list);
    }
}
