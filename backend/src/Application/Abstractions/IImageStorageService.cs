namespace OptimaHealthcare.Application.Abstractions;

public interface IImageStorageService
{
    Task<string> UploadPatientProfileAsync(
        byte[] bytes,
        string fileName,
        string contentType,
        CancellationToken cancellationToken);

    /// <summary>Uploads a patient medical document (JPG, PNG, BMP, PDF). Returns the secure HTTPS URL to store in FileURL.</summary>
    Task<string> UploadMedicalDocumentAsync(
        byte[] bytes,
        string fileName,
        string contentType,
        CancellationToken cancellationToken);

    string? ResolveImageUrl(string? storedValue);

    string? NormalizeStoredValue(string? value);

    /// <summary>
    /// Returns a Cloudinary signed URL for the given stored file URL.
    /// Signed URLs bypass "Strict CDN Security" or other access restrictions
    /// on the Cloudinary account and are valid for <paramref name="expiresInSeconds"/>.
    /// </summary>
    string GenerateSignedUrl(string fileUrl, int expiresInSeconds = 3600);
}
