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
    private readonly IPatientRecordDetailService _patientRecordDetailService;
    private readonly IImageStorageService _imageStorage;

    public PatientMedicalRecordsController(
        IPatientDataService patientDataService,
        IPatientMedicalRecordService medicalRecordService,
        IPatientRecordDetailService patientRecordDetailService,
        IImageStorageService imageStorage)
    {
        _patientDataService = patientDataService;
        _medicalRecordService = medicalRecordService;
        _patientRecordDetailService = patientRecordDetailService;
        _imageStorage = imageStorage;
    }

    // ── Patient self-access (read-only) ────────────────────────────────────────

    /// <summary>Returns the logged-in patient's own medical records.</summary>
    [HttpGet("api/v1/patient-data/me/medical-records")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientMedicalRecordDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<PatientMedicalRecordDto>>> ListMine(
        CancellationToken cancellationToken)
    {
        var appUserId = User.GetAppUserId();
        if (appUserId <= 0) return Unauthorized();

        var patient = await _patientDataService.GetByAppUserIdAsync(appUserId, cancellationToken);
        if (patient is null) return NotFound();

        var list = await _medicalRecordService.ListByPatientAsync(patient.PatientDataId, cancellationToken);
        return Ok(list);
    }

    /// <summary>Streams a medical-record file for the logged-in patient (own records only).</summary>
    [HttpGet("api/v1/patient-data/me/medical-records/{recordId:int}/file")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> DownloadMyFile(int recordId, CancellationToken cancellationToken)
    {
        var appUserId = User.GetAppUserId();
        if (appUserId <= 0) return Unauthorized();

        var patient = await _patientDataService.GetByAppUserIdAsync(appUserId, cancellationToken);
        if (patient is null) return NotFound();

        var fileUrl = await _medicalRecordService.GetFileUrlAsync(recordId, patient.PatientDataId, cancellationToken);
        if (string.IsNullOrWhiteSpace(fileUrl)) return NotFound();

        using var httpClient = new HttpClient();
        HttpResponseMessage? response = null;
        string? failureDetail = null;

        foreach (var candidateUrl in _imageStorage.GenerateSignedUrlCandidates(fileUrl))
        {
            try { response = await httpClient.GetAsync(candidateUrl, cancellationToken); }
            catch (Exception ex) { failureDetail = ex.Message; continue; }

            if (response.IsSuccessStatusCode)
            {
                var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
                var contentType = response.Content.Headers.ContentType?.MediaType
                    ?? (fileUrl.Contains(".pdf", StringComparison.OrdinalIgnoreCase)
                        ? "application/pdf" : "image/jpeg");
                return File(bytes, contentType);
            }

            failureDetail = await response.Content.ReadAsStringAsync(cancellationToken);
        }

        var statusCode = response?.StatusCode is not null
            ? (int)response.StatusCode : StatusCodes.Status502BadGateway;
        return StatusCode(StatusCodes.Status502BadGateway,
            $"Cloudinary returned {statusCode}. {failureDetail ?? "File may be inaccessible."}");
    }

    /// <summary>Returns analytics data for the logged-in patient's own records.</summary>
    [HttpGet("api/v1/patient-data/me/analytics")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientRecordDetailDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<PatientRecordDetailDto>>> GetMyAnalytics(
        CancellationToken cancellationToken)
    {
        var appUserId = User.GetAppUserId();
        if (appUserId <= 0) return Unauthorized();

        var patient = await _patientDataService.GetByAppUserIdAsync(appUserId, cancellationToken);
        if (patient is null) return NotFound();

        var details = await _patientRecordDetailService.ListByPatientAsync(patient.PatientDataId, cancellationToken);
        return Ok(details);
    }

    // ── Staff endpoints ─────────────────────────────────────────────────────────

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
        HttpResponseMessage? response = null;
        string? failureDetail = null;

        foreach (var candidateUrl in _imageStorage.GenerateSignedUrlCandidates(fileUrl))
        {
            try
            {
                response = await httpClient.GetAsync(candidateUrl, cancellationToken);
            }
            catch (Exception ex)
            {
                failureDetail = ex.Message;
                continue;
            }

            if (response.IsSuccessStatusCode)
            {
                var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
                var contentType = response.Content.Headers.ContentType?.MediaType
                                  ?? (fileUrl.Contains(".pdf", StringComparison.OrdinalIgnoreCase)
                                      ? "application/pdf"
                                      : "image/jpeg");

                return File(bytes, contentType);
            }

            failureDetail = await response.Content.ReadAsStringAsync(cancellationToken);
        }

        var statusCode = response?.StatusCode is not null
            ? (int)response.StatusCode
            : StatusCodes.Status502BadGateway;

        return StatusCode(
            StatusCodes.Status502BadGateway,
            $"Cloudinary returned {statusCode}. {failureDetail ?? "The file may be inaccessible or the signed URL is invalid."}");
    }

    [HttpGet("api/v1/patient-data/{patientDataId:int}/analytics")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientRecordDetailDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IReadOnlyList<PatientRecordDetailDto>>> GetAnalytics(
        int patientDataId,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var patient = await _patientDataService.GetByIdAsync(patientDataId, cancellationToken);
        if (patient is null)
        {
            return NotFound();
        }

        var details = await _patientRecordDetailService.ListByPatientAsync(patientDataId, cancellationToken);
        return Ok(details);
    }

    [HttpGet("api/v1/patient-data/{patientDataId:int}/medical-records/{recordId:int}/ocr-preview")]
    [ProducesResponseType(typeof(IReadOnlyList<PatientRecordDetailDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<IReadOnlyList<PatientRecordDetailDto>>> OcrPreview(
        int patientDataId,
        int recordId,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var patient = await _patientDataService.GetByIdAsync(patientDataId, cancellationToken);
        if (patient is null)
        {
            return NotFound();
        }

        var existingDetails = await _patientRecordDetailService.ListByMedicalRecordAsync(
            recordId,
            cancellationToken);
        if (existingDetails.Count > 0)
        {
            return Ok(existingDetails);
        }

        var fileBytesResult = await TryGetStoredFileBytesAsync(patientDataId, recordId, cancellationToken);
        if (!fileBytesResult.Success)
        {
            return StatusCode(fileBytesResult.StatusCode, fileBytesResult.ErrorMessage);
        }

        try
        {
            var details = await _patientRecordDetailService.ExtractPreviewAsync(
                fileBytesResult.Bytes!,
                fileBytesResult.ContentType ?? "application/octet-stream",
                $"{patient.FirstName} {patient.LastName}".Trim(),
                DateTime.UtcNow,
                cancellationToken);
            return Ok(details);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpPost("api/v1/patient-data/{patientDataId:int}/medical-records/{recordId:int}/details")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> SaveDetails(
        int patientDataId,
        int recordId,
        [FromBody] SavePatientRecordDetailsRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var fileUrl = await _medicalRecordService.GetFileUrlAsync(recordId, patientDataId, cancellationToken);
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return NotFound();
        }

        if (request.Details is null)
        {
            return BadRequest("Details payload is required.");
        }

        await _patientRecordDetailService.SaveAsync(
            recordId,
            request.PatientNameInRecord,
            request.Details,
            cancellationToken);

        return NoContent();
    }

    [HttpPut("api/v1/patient-data/{patientDataId:int}/medical-records/{recordId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> Update(
        int patientDataId,
        int recordId,
        [FromBody] UpdatePatientMedicalRecordRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        if (patientDataId <= 0 || recordId <= 0)
        {
            return BadRequest("Patient and record ids are required.");
        }

        if (request.RecordTypeId <= 0 || string.IsNullOrWhiteSpace(request.RecordName))
        {
            return BadRequest("Record type and record name are required.");
        }

        if (request.ReportDate == default)
        {
            return BadRequest("Report date is required.");
        }

        var updated = await _medicalRecordService.UpdateAsync(
            recordId,
            patientDataId,
            request,
            cancellationToken);

        if (!updated)
        {
            return NotFound("Medical record not found.");
        }

        return NoContent();
    }

    [HttpDelete("api/v1/patient-data/{patientDataId:int}/medical-records/{recordId:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult> Delete(
        int patientDataId,
        int recordId,
        CancellationToken cancellationToken)
    {
        if (!IsStaffUser())
        {
            return Forbid();
        }

        var fileUrl = await _medicalRecordService.DeleteAsync(recordId, patientDataId, cancellationToken);
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return NotFound("Medical record not found.");
        }

        try
        {
            await _imageStorage.DeleteFileAsync(fileUrl, cancellationToken);
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(StatusCodes.Status502BadGateway, ex.Message);
        }

        return NoContent();
    }

    private bool IsStaffUser()
    {
        var role = User.GetRoleName();
        return StaffRoles.Any(allowedRole =>
            role.Contains(allowedRole, StringComparison.OrdinalIgnoreCase));
    }

    private async Task<(bool Success, byte[]? Bytes, string? ContentType, int StatusCode, string? ErrorMessage)>
        TryGetStoredFileBytesAsync(
            int patientDataId,
            int recordId,
            CancellationToken cancellationToken)
    {
        var fileUrl = await _medicalRecordService.GetFileUrlAsync(recordId, patientDataId, cancellationToken);
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return (false, null, null, StatusCodes.Status404NotFound, "Document not found.");
        }

        using var httpClient = new HttpClient();
        HttpResponseMessage? response = null;
        string? failureDetail = null;

        foreach (var candidateUrl in _imageStorage.GenerateSignedUrlCandidates(fileUrl))
        {
            try
            {
                response = await httpClient.GetAsync(candidateUrl, cancellationToken);
            }
            catch (Exception ex)
            {
                failureDetail = ex.Message;
                continue;
            }

            if (response.IsSuccessStatusCode)
            {
                var bytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);
                var contentType = response.Content.Headers.ContentType?.MediaType
                                  ?? (fileUrl.Contains(".pdf", StringComparison.OrdinalIgnoreCase)
                                      ? "application/pdf"
                                      : "image/jpeg");
                return (true, bytes, contentType, StatusCodes.Status200OK, null);
            }

            failureDetail = await response.Content.ReadAsStringAsync(cancellationToken);
        }

        var statusCode = response?.StatusCode is not null
            ? (int)response.StatusCode
            : StatusCodes.Status502BadGateway;

        return (
            false,
            null,
            null,
            StatusCodes.Status502BadGateway,
            $"Cloudinary returned {statusCode}. {failureDetail ?? "The file may be inaccessible or the signed URL is invalid."}");
    }
}
