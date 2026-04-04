using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
public sealed class PatientComplaintsController : ControllerBase
{
    private static readonly string[] StaffRoles = ["admin", "doctor", "receptionist"];
    private readonly IPatientComplaintService _patientComplaintService;
    private readonly IPatientDataService _patientDataService;
    private readonly ISeverityService _severityService;

    public PatientComplaintsController(
        IPatientComplaintService patientComplaintService,
        IPatientDataService patientDataService,
        ISeverityService severityService)
    {
        _patientComplaintService = patientComplaintService;
        _patientDataService = patientDataService;
        _severityService = severityService;
    }

    [HttpGet("api/v1/patient-data/{patientDataId:int}/complaints")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientComplaintDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientComplaintDto>>> ListByPatient(int patientDataId, CancellationToken cancellationToken)
    {
        if (!await CanAccessPatientAsync(patientDataId, cancellationToken))
        {
            return Forbid();
        }

        if (patientDataId <= 0)
        {
            return BadRequest("PatientDataId is required.");
        }

        return Ok(await _patientComplaintService.ListByPatientAsync(patientDataId, cancellationToken));
    }

    [HttpPost("api/v1/patient-data/{patientDataId:int}/complaints")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create(int patientDataId, [FromBody] SavePatientComplaintRequest request, CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        request.PatientDataId = patientDataId;
        var validationError = Validate(request);
        if (validationError is not null)
        {
            return BadRequest(validationError);
        }

        var appUserId = User.GetAppUserId();
        if (appUserId <= 0)
        {
            return Unauthorized();
        }

        try
        {
            var id = await _patientComplaintService.CreateAsync(request, appUserId, cancellationToken);
            return StatusCode(StatusCodes.Status201Created, new { patientComplaintId = id });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpPut("api/v1/patient-complaints/{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Update(int id, [FromBody] SavePatientComplaintRequest request, CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var validationError = Validate(request);
        if (validationError is not null)
        {
            return BadRequest(validationError);
        }

        try
        {
            var updated = await _patientComplaintService.UpdateAsync(id, request, cancellationToken);
            if (!updated)
            {
                return NotFound("Patient complaint not found.");
            }

            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpDelete("api/v1/patient-complaints/{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var deleted = await _patientComplaintService.DeleteAsync(id, cancellationToken);
        if (!deleted)
        {
            return NotFound("Patient complaint not found.");
        }

        return NoContent();
    }

    [HttpGet("api/v1/patient-complaints/lookups/severities")]
    [ProducesResponseType(typeof(IReadOnlyList<SeverityItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<SeverityItemDto>>> Severities(CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        return Ok(await _severityService.ListAsync(cancellationToken));
    }

    private static string? Validate(SavePatientComplaintRequest request)
    {
        if (request.PatientDataId <= 0)
        {
            return "PatientDataId is required.";
        }

        if (string.IsNullOrWhiteSpace(request.Symptoms))
        {
            return "Symptoms are required.";
        }

        if (request.SeverityId <= 0)
        {
            return "Severity is required.";
        }

        return null;
    }

    private async Task<bool> CanAccessPatientAsync(int patientDataId, CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return false;
        }

        var patient = await _patientDataService.GetByIdAsync(patientDataId, User.GetRoleName(), cancellationToken);
        return patient is not null;
    }

    private bool IsStaffUser()
    {
        var role = User.GetRoleName();
        return StaffRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }
}
