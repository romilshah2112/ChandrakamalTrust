using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
public sealed class PatientVitalsController : ControllerBase
{
    private static readonly string[] StaffRoles = ["admin", "doctor", "receptionist"];
    private readonly IPatientVitalsService _patientVitalsService;
    private readonly IPatientDataService _patientDataService;

    public PatientVitalsController(
        IPatientVitalsService patientVitalsService,
        IPatientDataService patientDataService)
    {
        _patientVitalsService = patientVitalsService;
        _patientDataService = patientDataService;
    }

    [HttpGet("api/v1/patient-data/{patientDataId:int}/vitals")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientVitalsDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientVitalsDto>>> ListByPatient(int patientDataId, CancellationToken cancellationToken)
    {
        if (!await CanAccessPatientAsync(patientDataId, cancellationToken))
        {
            return Forbid();
        }

        if (patientDataId <= 0)
        {
            return BadRequest("PatientDataId is required.");
        }

        return Ok(await _patientVitalsService.ListByPatientAsync(patientDataId, cancellationToken));
    }

    [HttpPost("api/v1/patient-data/{patientDataId:int}/vitals")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create(int patientDataId, [FromBody] SavePatientVitalsRequest request, CancellationToken cancellationToken)
    {
        if (IsPatientUser())
        {
            var ownPatientDataId = await GetOwnPatientDataIdAsync(cancellationToken);
            if (ownPatientDataId <= 0 || ownPatientDataId != patientDataId)
            {
                return Forbid();
            }
        }
        else if (!IsStaffUser())
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
            var id = await _patientVitalsService.CreateAsync(request, appUserId, cancellationToken);
            return StatusCode(StatusCodes.Status201Created, new { patientVitalsId = id });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpPut("api/v1/patient-vitals/{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Update(int id, [FromBody] SavePatientVitalsRequest request, CancellationToken cancellationToken)
    {
        if (IsPatientUser())
        {
            var ownPatientDataId = await GetOwnPatientDataIdAsync(cancellationToken);
            var targetPatientDataId = await _patientVitalsService.GetPatientDataIdByVitalsIdAsync(id, cancellationToken);
            if (ownPatientDataId <= 0 || targetPatientDataId != ownPatientDataId)
            {
                return Forbid();
            }

            request.PatientDataId = ownPatientDataId;
        }
        else if (!IsStaffUser())
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
            var updated = await _patientVitalsService.UpdateAsync(id, request, cancellationToken);
            if (!updated)
            {
                return NotFound("Patient vitals not found.");
            }

            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpDelete("api/v1/patient-vitals/{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        if (IsPatientUser())
        {
            var ownPatientDataId = await GetOwnPatientDataIdAsync(cancellationToken);
            var targetPatientDataId = await _patientVitalsService.GetPatientDataIdByVitalsIdAsync(id, cancellationToken);
            if (ownPatientDataId <= 0 || targetPatientDataId != ownPatientDataId)
            {
                return Forbid();
            }
        }
        else if (!IsStaffUser())
        {
            return Forbid();
        }

        var deleted = await _patientVitalsService.DeleteAsync(id, cancellationToken);
        if (!deleted)
        {
            return NotFound("Patient vitals not found.");
        }

        return NoContent();
    }

    private static string? Validate(SavePatientVitalsRequest request)
    {
        if (request.PatientDataId <= 0)
        {
            return "PatientDataId is required.";
        }

        if (request.BPSys <= 0 ||
            request.BPDys <= 0 ||
            request.BloodSugar <= 0 ||
            request.Pulse <= 0 ||
            request.WeightKG <= 0 ||
            request.HeightCMS <= 0)
        {
            return "Blood pressure, blood sugar, pulse, weight, and height must be greater than zero.";
        }

        return null;
    }

    private async Task<bool> CanAccessPatientAsync(int patientDataId, CancellationToken cancellationToken)
    {
        if (IsStaffUser())
        {
            return true;
        }

        if (!IsPatientUser())
        {
            return false;
        }

        var ownPatientDataId = await GetOwnPatientDataIdAsync(cancellationToken);
        return ownPatientDataId > 0 && ownPatientDataId == patientDataId;
    }

    private bool IsStaffUser()
    {
        var role = User.GetRoleName();
        return StaffRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }

    private bool IsPatientUser()
    {
        var role = User.GetRoleName();
        return role.Contains("patient", StringComparison.OrdinalIgnoreCase);
    }

    private async Task<int> GetOwnPatientDataIdAsync(CancellationToken cancellationToken)
    {
        var appUserId = User.GetAppUserId();
        if (appUserId <= 0)
        {
            return 0;
        }

        var patient = await _patientDataService.GetByAppUserIdAsync(appUserId, cancellationToken);
        return patient?.PatientDataId ?? 0;
    }
}
