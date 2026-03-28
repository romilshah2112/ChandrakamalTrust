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
}
