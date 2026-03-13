using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Appointments;
using OptimaHealthcare.Contracts.Masters;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/appointments")]
public sealed class PatientAppointmentsController : ControllerBase
{
    private readonly IPatientAppointmentService _appointmentService;
    private readonly IPatientDataService _patientDataService;
    private readonly IMasterDataService _masterDataService;

    public PatientAppointmentsController(
        IPatientAppointmentService appointmentService,
        IPatientDataService patientDataService,
        IMasterDataService masterDataService)
    {
        _appointmentService = appointmentService;
        _patientDataService = patientDataService;
        _masterDataService = masterDataService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PatientAppointmentDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientAppointmentDto>>> List(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] int? clinicId,
        CancellationToken cancellationToken)
    {
        var role = User.FindFirstValue(ClaimTypes.Role) ?? string.Empty;
        var appUserId = GetAppUserId();
        if (appUserId <= 0)
        {
            return Forbid();
        }

        var list = await _appointmentService.ListAsync(from, to, clinicId, appUserId, role, cancellationToken);
        return Ok(list);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create([FromBody] SavePatientAppointmentRequest request, CancellationToken cancellationToken)
    {
        if (!ValidateSaveRequest(request, out var error))
        {
            return BadRequest(error);
        }

        var appUserId = GetAppUserId();
        var username = User.FindFirstValue(ClaimTypes.Name) ?? string.Empty;
        if (appUserId <= 0)
        {
            return Forbid();
        }

        try
        {
            var id = await _appointmentService.CreateAsync(request, appUserId, username, cancellationToken);
            return StatusCode(StatusCodes.Status201Created, new { patientAppointmentId = id });
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            return Conflict("Appointment save blocked due to data integrity constraints.");
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Update(int id, [FromBody] SavePatientAppointmentRequest request, CancellationToken cancellationToken)
    {
        if (!ValidateSaveRequest(request, out var error))
        {
            return BadRequest(error);
        }

        var appUserId = GetAppUserId();
        var username = User.FindFirstValue(ClaimTypes.Name) ?? string.Empty;
        if (appUserId <= 0)
        {
            return Forbid();
        }

        try
        {
            await _appointmentService.UpdateAsync(id, request, appUserId, username, cancellationToken);
            return NoContent();
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            return Conflict("Appointment update blocked due to data integrity constraints.");
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _appointmentService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpGet("lookups/patients")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientListItemResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientListItemResponse>>> Patients(CancellationToken cancellationToken)
        => Ok(await _patientDataService.ListAsync(null, cancellationToken));

    [HttpGet("lookups/doctors")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(typeof(IReadOnlyList<DoctorProfileDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<DoctorProfileDto>>> Doctors(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListDoctorProfilesAsync(cancellationToken));

    [HttpGet("lookups/clinics")]
    [ProducesResponseType(typeof(IReadOnlyList<ClinicDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ClinicDto>>> Clinics(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListClinicsAsync(cancellationToken));


    [HttpGet("lookups/clinic-schedules")]
    [ProducesResponseType(typeof(IReadOnlyList<ClinicScheduleDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ClinicScheduleDto>>> ClinicSchedules(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListClinicSchedulesAsync(cancellationToken));
    [HttpGet("lookups/statuses")]
    [ProducesResponseType(typeof(IReadOnlyList<AppointmentStatusLookupDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AppointmentStatusLookupDto>>> Statuses(CancellationToken cancellationToken)
        => Ok(await _appointmentService.ListStatusesAsync(cancellationToken));

    [HttpGet("lookups/appointment-types")]
    [ProducesResponseType(typeof(IReadOnlyList<AppointmentTypeDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AppointmentTypeDto>>> AppointmentTypes(CancellationToken cancellationToken)
        => Ok(await _appointmentService.ListAppointmentTypesAsync(cancellationToken));

    private int GetAppUserId()
    {
        var appUserIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(appUserIdClaim, out var appUserId) ? appUserId : 0;
    }

    private static bool ValidateSaveRequest(SavePatientAppointmentRequest request, out string error)
    {
        if (request.PatientDataId <= 0)
        {
            error = "PatientDataId is required.";
            return false;
        }
        if (request.DoctorProfileId <= 0)
        {
            error = "DoctorProfileId is required.";
            return false;
        }
        if (request.ClinicId <= 0)
        {
            error = "ClinicId is required.";
            return false;
        }
        if (request.EndTime <= request.StartTime)
        {
            error = "EndTime must be greater than StartTime.";
            return false;
        }
        if (request.AppointmentStatusId <= 0)
        {
            error = "AppointmentStatusId is required.";
            return false;
        }

        error = string.Empty;
        return true;
    }
}


