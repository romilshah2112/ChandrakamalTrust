using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Api.Controllers;

/// <summary>
/// Staff medical document uploads per patient. Routes match <see cref="PatientVitalsController"/> (full path on actions).
/// </summary>
[ApiController]
[Authorize]
public sealed class PatientMedicalRecordsController : ControllerBase
{
    private static readonly string[] StaffRoles = ["admin", "doctor", "receptionist"];

    private readonly IPatientDataService _patientDataService;
    private readonly IPatientMedicalRecordService _medicalRecordService;
    private readonly IImageStorageService _imageStorage;

    public PatientMedicalRecordsController(
        IPatientDataService patientDataService,
        IPatientMedicalRecordService medicalRecordService,
        IImageStorageService imageStorage)
    {
        _patientDataService = patientDataService;
        _medicalRecordService = medicalRecordService;
        _imageStorage = imageStorage;
    }

    [HttpGet("api/v1/patient-data/{patientDataId:int}/medical-records")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientMedicalRecordDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<PatientMedicalRecordDto>>> List(
        int patientDataId,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        if (patientDataId <= 0)
        {
            return BadRequest("PatientDataId is required.");
        }

        var list = await _medicalRecordService.ListByPatientAsync(patientDataId, cancellationToken);
        return Ok(list);
    }

    [HttpPost("api/v1/patient-data/{patientDataId:int}/medical-records")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> Create(
        int patientDataId,
        [FromBody] SavePatientMedicalRecordRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var appUserId = User.GetAppUserId();
        if (appUserId <= 0)
        {
            return Unauthorized();
        }

        var patient = await _patientDataService.GetByIdAsync(patientDataId, cancellationToken);
        if (patient is null)
        {
            return NotFound();
        }

        if (request.RecordTypeId <= 0 || string.IsNullOrWhiteSpace(request.RecordName))
        {
            return BadRequest("Record type and record name are required.");
        }

        if (request.ReportDate == default)
        {
            return BadRequest("Report date is required.");
        }

        if (string.IsNullOrWhiteSpace(request.FileBase64))
        {
            return BadRequest("File is required.");
        }

        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(request.FileBase64.Trim());
        }
        catch (FormatException)
        {
            return BadRequest("Invalid file data.");
        }

        var fileName = string.IsNullOrWhiteSpace(request.FileName) ? "document" : request.FileName.Trim();
        var contentType = string.IsNullOrWhiteSpace(request.ContentType)
            ? "application/octet-stream"
            : request.ContentType.Trim();

        string fileUrl;
        try
        {
            fileUrl = await _imageStorage.UploadMedicalDocumentAsync(bytes, fileName, contentType, cancellationToken);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }

        var id = await _medicalRecordService.InsertAsync(
            patientDataId,
            request.RecordTypeId,
            request.RecordName.Trim(),
            fileUrl,
            request.ReportDate,
            request.Comments,
            appUserId,
            cancellationToken);

        return StatusCode(StatusCodes.Status201Created, new { patientMedicalRecordId = id });
    }

    /// <summary>
    /// Proxy endpoint: fetches the stored file from Cloudinary server-side and
    /// streams the bytes back to the authenticated Flutter client.  This avoids
    /// any Cloudinary authentication / CORS issues that arise when the mobile
    /// app tries to call the Cloudinary URL directly.
    /// </summary>
    [HttpGet("api/v1/patient-data/{patientDataId:int}/medical-records/{recordId:int}/file")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> DownloadFile(
        int patientDataId,
        int recordId,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser()) return Forbid();

        var fileUrl = await _medicalRecordService.GetFileUrlAsync(recordId, patientDataId, cancellationToken);
        if (string.IsNullOrWhiteSpace(fileUrl)) return NotFound();

        using var httpClient = new HttpClient();
        HttpResponseMessage response;
        try
        {
            response = await httpClient.GetAsync(fileUrl, cancellationToken);
        }
        catch (Exception ex)
        {
            return StatusCode(StatusCodes.Status502BadGateway, $"Could not fetch document: {ex.Message}");
        }

        if (!response.IsSuccessStatusCode)
        {
            return StatusCode((int)response.StatusCode, "Document storage returned an error.");
        }

        var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
        var contentType = response.Content.Headers.ContentType?.MediaType
                          ?? (fileUrl.Contains("/image/") ? "image/jpeg" : "application/pdf");

        return File(bytes, contentType);
    }

    private bool IsStaffUser()
    {
        var role = User.GetRoleName();
        return StaffRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }
}
