using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/v1/admin/masters")]
public sealed class AdminMastersController : ControllerBase
{
    private readonly IMasterDataService _masterDataService;

    public AdminMastersController(IMasterDataService masterDataService)
    {
        _masterDataService = masterDataService;
    }

    [HttpGet("clinics")]
    public async Task<ActionResult<IReadOnlyList<ClinicDto>>> ListClinics(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListClinicsAsync(cancellationToken));

    [HttpPost("clinics")]
    public async Task<ActionResult> CreateClinic([FromBody] SaveClinicRequest request, CancellationToken cancellationToken)
        => StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateClinicAsync(request, cancellationToken) });

    [HttpPut("clinics/{id:int}")]
    public async Task<ActionResult> UpdateClinic(int id, [FromBody] SaveClinicRequest request, CancellationToken cancellationToken)
    {
        await _masterDataService.UpdateClinicAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("clinics/{id:int}")]
    public async Task<ActionResult> DeleteClinic(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _masterDataService.DeleteClinicAsync(id, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }

    [HttpGet("doctor-profiles")]
    public async Task<ActionResult<IReadOnlyList<DoctorProfileDto>>> ListDoctorProfiles(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListDoctorProfilesAsync(cancellationToken));

    [HttpPost("doctor-profiles")]
    public async Task<ActionResult> CreateDoctorProfile([FromBody] SaveDoctorProfileRequest request, CancellationToken cancellationToken)
        => StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateDoctorProfileAsync(request, cancellationToken) });

    [HttpPut("doctor-profiles/{id:int}")]
    public async Task<ActionResult> UpdateDoctorProfile(int id, [FromBody] SaveDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        await _masterDataService.UpdateDoctorProfileAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("doctor-profiles/{id:int}")]
    public async Task<ActionResult> DeleteDoctorProfile(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _masterDataService.DeleteDoctorProfileAsync(id, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }

    [HttpGet("staff")]
    public async Task<ActionResult<IReadOnlyList<StaffDto>>> ListStaff(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListStaffAsync(cancellationToken));

    [HttpPost("staff")]
    public async Task<ActionResult> CreateStaff([FromBody] SaveStaffRequest request, CancellationToken cancellationToken)
        => StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateStaffAsync(request, cancellationToken) });

    [HttpPut("staff/{id:int}")]
    public async Task<ActionResult> UpdateStaff(int id, [FromBody] SaveStaffRequest request, CancellationToken cancellationToken)
    {
        await _masterDataService.UpdateStaffAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("staff/{id:int}")]
    public async Task<ActionResult> DeleteStaff(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _masterDataService.DeleteStaffAsync(id, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }

    [HttpGet("clinic-schedules")]
    public async Task<ActionResult<IReadOnlyList<ClinicScheduleDto>>> ListClinicSchedules(CancellationToken cancellationToken)
        => Ok(await _masterDataService.ListClinicSchedulesAsync(cancellationToken));

    [HttpPost("clinic-schedules")]
    public async Task<ActionResult> CreateClinicSchedule([FromBody] SaveClinicScheduleRequest request, CancellationToken cancellationToken)
        => StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateClinicScheduleAsync(request, cancellationToken) });

    [HttpPut("clinic-schedules/{id:int}")]
    public async Task<ActionResult> UpdateClinicSchedule(int id, [FromBody] SaveClinicScheduleRequest request, CancellationToken cancellationToken)
    {
        await _masterDataService.UpdateClinicScheduleAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("clinic-schedules/{id:int}")]
    public async Task<ActionResult> DeleteClinicSchedule(int id, CancellationToken cancellationToken)
    {
        try
        {
            await _masterDataService.DeleteClinicScheduleAsync(id, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }
}

