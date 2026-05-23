using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
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
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListClinicsAsync(cancellationToken));
    }

    [HttpPost("clinics")]
    public async Task<ActionResult> CreateClinic([FromBody] SaveClinicRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateClinicAsync(request, cancellationToken) });
    }

    [HttpPut("clinics/{id:int}")]
    public async Task<ActionResult> UpdateClinic(int id, [FromBody] SaveClinicRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        await _masterDataService.UpdateClinicAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("clinics/{id:int}")]
    public async Task<ActionResult> DeleteClinic(int id, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

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
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListDoctorProfilesAsync(cancellationToken));
    }

    [HttpPost("doctor-profiles")]
    public async Task<ActionResult> CreateDoctorProfile([FromBody] SaveDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        request.AppUserId = 0;
        return StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateDoctorProfileAsync(request, cancellationToken) });
    }

    [HttpPut("doctor-profiles/{id:int}")]
    public async Task<ActionResult> UpdateDoctorProfile(int id, [FromBody] SaveDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        await _masterDataService.UpdateDoctorProfileAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("doctor-profiles/{id:int}")]
    public async Task<ActionResult> DeleteDoctorProfile(int id, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

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
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListStaffAsync(cancellationToken));
    }

    [HttpPost("staff")]
    public async Task<ActionResult> CreateStaff([FromBody] SaveStaffRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        request.AppUserId = 0;
        return StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateStaffAsync(request, cancellationToken) });
    }

    [HttpPut("staff/{id:int}")]
    public async Task<ActionResult> UpdateStaff(int id, [FromBody] SaveStaffRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        await _masterDataService.UpdateStaffAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("staff/{id:int}")]
    public async Task<ActionResult> DeleteStaff(int id, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

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
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListClinicSchedulesAsync(cancellationToken));
    }

    [HttpPost("clinic-schedules")]
    public async Task<ActionResult> CreateClinicSchedule([FromBody] SaveClinicScheduleRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateClinicScheduleAsync(request, cancellationToken) });
    }

    [HttpPut("clinic-schedules/{id:int}")]
    public async Task<ActionResult> UpdateClinicSchedule(int id, [FromBody] SaveClinicScheduleRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        await _masterDataService.UpdateClinicScheduleAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("clinic-schedules/{id:int}")]
    public async Task<ActionResult> DeleteClinicSchedule(int id, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

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

    [HttpGet("invoice-types")]
    public async Task<ActionResult<IReadOnlyList<InvoiceTypeDto>>> ListInvoiceTypes(CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListInvoiceTypesAsync(cancellationToken));
    }

    [HttpPost("invoice-types")]
    public async Task<ActionResult> CreateInvoiceType([FromBody] SaveInvoiceTypeRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateInvoiceTypeAsync(request, cancellationToken) });
    }

    [HttpPut("invoice-types/{id:int}")]
    public async Task<ActionResult> UpdateInvoiceType(int id, [FromBody] SaveInvoiceTypeRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        await _masterDataService.UpdateInvoiceTypeAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("invoice-types/{id:int}")]
    public async Task<ActionResult> DeleteInvoiceType(int id, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        try
        {
            await _masterDataService.DeleteInvoiceTypeAsync(id, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }

    [HttpGet("health-camps")]
    public async Task<ActionResult<IReadOnlyList<HealthCampDto>>> ListHealthCamps(CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return Ok(await _masterDataService.ListHealthCampsAsync(cancellationToken));
    }

    [HttpPost("health-camps")]
    public async Task<ActionResult> CreateHealthCamp([FromBody] SaveHealthCampRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        return StatusCode(StatusCodes.Status201Created, new { id = await _masterDataService.CreateHealthCampAsync(request, cancellationToken) });
    }

    [HttpPut("health-camps/{id:int}")]
    public async Task<ActionResult> UpdateHealthCamp(int id, [FromBody] SaveHealthCampRequest request, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        await _masterDataService.UpdateHealthCampAsync(id, request, cancellationToken);
        return NoContent();
    }

    [HttpDelete("health-camps/{id:int}")]
    public async Task<ActionResult> DeleteHealthCamp(int id, CancellationToken cancellationToken)
    {
        if (!IsAdminUser())
        {
            return Forbid();
        }

        try
        {
            await _masterDataService.DeleteHealthCampAsync(id, cancellationToken);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }

    private bool IsAdminUser()
        => User.GetRoleName().Contains("admin", StringComparison.OrdinalIgnoreCase);
}

