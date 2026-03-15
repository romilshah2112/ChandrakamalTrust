using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/consultation")]
public sealed class ConsultationController : ControllerBase
{
    private readonly IConsultationProcessingService _consultationProcessing;
    private readonly IConsultationNotesService _consultationNotesService;

    public ConsultationController(
        IConsultationProcessingService consultationProcessing,
        IConsultationNotesService consultationNotesService)
    {
        _consultationProcessing = consultationProcessing;
        _consultationNotesService = consultationNotesService;
    }

    /// <summary>Upload audio (multipart/form-data), get back transcript and SOAP JSON. Temp file is saved then removed after processing.</summary>
    [HttpPost("process-audio")]
    [ProducesResponseType(typeof(ProcessAudioResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ProcessAudioResponse>> ProcessAudio(CancellationToken cancellationToken)
    {
        if (!Request.HasFormContentType || Request.Form.Files.Count == 0)
        {
            return BadRequest("Expected multipart/form-data with at least one file (e.g. 'file' or 'audio').");
        }

        var file = Request.Form.Files.GetFile("file") ?? Request.Form.Files.GetFile("audio") ?? Request.Form.Files[0];
        await using var stream = file.OpenReadStream();

        var result = await _consultationProcessing.ProcessAudioAsync(stream, file.FileName, cancellationToken);
        return Ok(result);
    }

    /// <summary>Save consultation transcript to PatientComplaint and PatientMedicalHistory tables. Extracts complaint, symptoms, medical history.</summary>
    [HttpPost("save-notes")]
    [Authorize(Roles = "Admin,Doctor,Receptionist")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> SaveNotes([FromBody] SaveConsultationNotesRequest request, CancellationToken cancellationToken)
    {
        var appUserId = User.GetAppUserId();
        if (appUserId <= 0)
        {
            return Forbid();
        }

        if (request.PatientDataId <= 0)
        {
            return BadRequest("PatientDataId is required.");
        }
        if (string.IsNullOrWhiteSpace(request.Transcript))
        {
            return BadRequest("Transcript cannot be empty.");
        }

        try
        {
            await _consultationNotesService.SaveConsultationNotesAsync(request, appUserId, cancellationToken);
            return NoContent();
        }
        catch (ArgumentException ex)
        {
            return BadRequest(ex.Message);
        }
    }
}
