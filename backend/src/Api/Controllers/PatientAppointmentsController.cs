using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using OptimaHealthcare.Api.Security;
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
    private static readonly string[] AppointmentManagerRoles = ["admin", "doctor", "receptionist"];
    private readonly ILogger<PatientAppointmentsController> _logger;
    private readonly IPatientAppointmentService _appointmentService;
    private readonly IPatientDataService _patientDataService;
    private readonly IMasterDataService _masterDataService;

    public PatientAppointmentsController(
        ILogger<PatientAppointmentsController> logger,
        IPatientAppointmentService appointmentService,
        IPatientDataService patientDataService,
        IMasterDataService masterDataService)
    {
        _logger = logger;
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
        LogAuthState("List");
        var role = User.GetRoleName();
        var appUserId = User.GetAppUserId();
        if (appUserId <= 0)
        {
            return Forbid();
        }

        var list = await _appointmentService.ListAsync(from, to, clinicId, appUserId, role, cancellationToken);
        return Ok(list);
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create([FromBody] SavePatientAppointmentRequest request, CancellationToken cancellationToken)
    {
        LogAuthState("Create");
        if (!CanManageAppointments())
        {
            return Forbid();
        }

        if (!ValidateSaveRequest(request, out var error))
        {
            return BadRequest(error);
        }

        var appUserId = User.GetAppUserId();
        var username = User.GetLoginName() ?? string.Empty;
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
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Update(int id, [FromBody] SavePatientAppointmentRequest request, CancellationToken cancellationToken)
    {
        LogAuthState("Update");
        if (!CanManageAppointments())
        {
            return Forbid();
        }

        if (!ValidateSaveRequest(request, out var error))
        {
            return BadRequest(error);
        }

        var appUserId = User.GetAppUserId();
        var username = User.GetLoginName() ?? string.Empty;
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
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        LogAuthState("Delete");
        if (!CanManageAppointments())
        {
            return Forbid();
        }

        await _appointmentService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpGet("lookups/patients")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientListItemResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientListItemResponse>>> Patients(CancellationToken cancellationToken)
    {
        LogAuthState("PatientsLookup");
        if (!CanManageAppointments())
        {
            return Forbid();
        }

        return Ok(await _patientDataService.ListAsync(null, User.GetRoleName(), cancellationToken));
    }

    [HttpGet("lookups/doctors")]
    [ProducesResponseType(typeof(IReadOnlyList<DoctorProfileDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<DoctorProfileDto>>> Doctors(CancellationToken cancellationToken)
    {
        LogAuthState("DoctorsLookup");
        if (!CanManageAppointments())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListDoctorProfilesAsync(cancellationToken));
    }

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

    private bool CanManageAppointments()
    {
        var role = User.GetRoleName();
        var allowed = AppointmentManagerRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));

        _logger.LogInformation(
            "Appointments auth check. allowed={Allowed} role={Role} appUserId={AppUserId}",
            allowed,
            role,
            User.GetAppUserId());

        return allowed;
    }

    private void LogAuthState(string actionName)
    {
        var claims = User.Claims
            .Select(c => $"{c.Type}={c.Value}")
            .ToArray();

        _logger.LogInformation(
            "Appointments {Action} request auth. isAuthenticated={IsAuthenticated} appUserId={AppUserId} role={Role} claims=[{Claims}]",
            actionName,
            User.Identity?.IsAuthenticated ?? false,
            User.GetAppUserId(),
            User.GetRoleName(),
            string.Join(", ", claims));
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
