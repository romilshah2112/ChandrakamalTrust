using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize(Roles = "Doctor,Nurse,Admin")]
[Route("api/v1/patients")]
public sealed class PatientsController : ControllerBase
{
    private readonly IPatientReadService _patientReadService;

    public PatientsController(IPatientReadService patientReadService)
    {
        _patientReadService = patientReadService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PatientSummaryDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientSummaryDto>>> Search([FromQuery] string? query, CancellationToken cancellationToken)
    {
        var patients = await _patientReadService.SearchAsync(query, cancellationToken);
        return Ok(patients);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(PatientDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PatientDetailDto>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var patient = await _patientReadService.GetByIdAsync(id, cancellationToken);
        if (patient is null)
        {
            return NotFound();
        }

        return Ok(patient);
    }
}
