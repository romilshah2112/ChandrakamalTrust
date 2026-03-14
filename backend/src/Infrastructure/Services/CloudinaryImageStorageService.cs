using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class CloudinaryImageStorageService : IImageStorageService
{
    private const int MaxBytes = 50 * 1024;
    private const string AssetFolder = "OptimaHealthcare";
    private readonly Cloudinary _cloudinary;
    private readonly string _cloudName;

    public CloudinaryImageStorageService(IConfiguration configuration)
    {
        var section = configuration.GetSection("Cloudinary");
        var cloudName = section["CLOUDINARY_CLOUD_NAME"] ?? string.Empty;
        var apiKey = section["CLOUDINARY_API_KEY"] ?? string.Empty;
        var apiSecret = section["CLOUDINARY_API_SECRET"] ?? string.Empty;

        if (string.IsNullOrWhiteSpace(cloudName) ||
            string.IsNullOrWhiteSpace(apiKey) ||
            string.IsNullOrWhiteSpace(apiSecret))
        {
            throw new InvalidOperationException("Cloudinary configuration is missing.");
        }

        _cloudName = cloudName;
        _cloudinary = new Cloudinary(new Account(cloudName, apiKey, apiSecret));
    }

    public async Task<string> UploadPatientProfileAsync(
        byte[] bytes,
        string fileName,
        string contentType,
        CancellationToken cancellationToken)
    {
        if (bytes.Length == 0)
        {
            throw new InvalidOperationException("Patient image is empty.");
        }

        if (bytes.Length > MaxBytes)
        {
            throw new InvalidOperationException("Patient image must be less than 50KB.");
        }

        var publicIdPrefix = ResolvePublicIdPrefix(fileName);
        var publicId = $"{publicIdPrefix}-{Guid.NewGuid():N}";

        await using var stream = new MemoryStream(bytes, writable: false);
        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(
                string.IsNullOrWhiteSpace(fileName) ? "patient-profile.jpg" : fileName,
                stream),
            AssetFolder = AssetFolder,
            Folder = AssetFolder,
            PublicId = publicId,
            UseAssetFolderAsPublicIdPrefix = true
        };

        var result = await _cloudinary.UploadAsync(uploadParams);
        if (result.Error is not null)
        {
            throw new InvalidOperationException(
                $"Cloudinary upload failed: {result.Error.Message}");
        }

        var format = result.Format;
        if (string.IsNullOrWhiteSpace(format))
        {
            throw new InvalidOperationException("Cloudinary returned an empty image format.");
        }

        return $"{publicId}.{format}";
    }

    public string? ResolveImageUrl(string? storedValue)
    {
        var normalized = NormalizeStoredValue(storedValue);
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        var extension = Path.GetExtension(normalized);
        var format = string.IsNullOrWhiteSpace(extension)
            ? null
            : extension.TrimStart('.').ToLowerInvariant();
        var fileNameWithoutExtension = Path.GetFileNameWithoutExtension(normalized);
        if (string.IsNullOrWhiteSpace(fileNameWithoutExtension))
        {
            return null;
        }

        var publicId = BuildPublicId(fileNameWithoutExtension);
        var url = _cloudinary.Api.UrlImgUp.Secure(true);
        if (!string.IsNullOrWhiteSpace(format))
        {
            url = url.Format(format);
        }

        return url.BuildUrl(publicId);
    }

    public string? NormalizeStoredValue(string? value)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return null;
        }

        if (Uri.TryCreate(trimmed, UriKind.Absolute, out var uri))
        {
            var fileName = Path.GetFileName(uri.AbsolutePath);
            return string.IsNullOrWhiteSpace(fileName) ? null : fileName;
        }

        if (trimmed.Contains('/'))
        {
            var fileName = trimmed.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault();
            return string.IsNullOrWhiteSpace(fileName) ? null : fileName;
        }

        return trimmed;
    }

    private static string BuildPublicId(string fileNameWithoutExtension)
    {
        // New uploads use the OptimaHealthcare folder and generated patient-* ids.
        // Older database rows contain legacy names that live at the Cloudinary root.
        return fileNameWithoutExtension.StartsWith("patient-", StringComparison.OrdinalIgnoreCase)
            || fileNameWithoutExtension.StartsWith("profile-", StringComparison.OrdinalIgnoreCase)
            ? $"{AssetFolder}/{fileNameWithoutExtension}"
            : fileNameWithoutExtension;
    }

    private static string ResolvePublicIdPrefix(string fileName)
    {
        var normalized = fileName.Trim();
        return normalized.StartsWith("user-profile", StringComparison.OrdinalIgnoreCase)
            || normalized.StartsWith("profile", StringComparison.OrdinalIgnoreCase)
            ? "profile"
            : "patient";
    }
}
