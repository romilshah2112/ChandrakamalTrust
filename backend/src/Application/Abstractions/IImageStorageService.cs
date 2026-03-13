namespace OptimaHealthcare.Application.Abstractions;

public interface IImageStorageService
{
    Task<string> UploadPatientProfileAsync(
        byte[] bytes,
        string fileName,
        string contentType,
        CancellationToken cancellationToken);
}
