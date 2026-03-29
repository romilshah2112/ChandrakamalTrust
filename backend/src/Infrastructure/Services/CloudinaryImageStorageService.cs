using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class CloudinaryImageStorageService : IImageStorageService
{
    private const int MaxBytes = 50 * 1024;
    private const int MaxMedicalDocumentBytes = 20 * 1024 * 1024;
    private const string AssetFolder = "OptimaHealthcare";
    private const string MedicalRecordsFolder = $"{AssetFolder}/Records";

    private readonly Cloudinary _cloudinary;

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

    public async Task<string> UploadMedicalDocumentAsync(
        byte[] bytes,
        string fileName,
        string contentType,
        CancellationToken cancellationToken)
    {
        if (bytes.Length == 0)
        {
            throw new InvalidOperationException("Document is empty.");
        }

        if (bytes.Length > MaxMedicalDocumentBytes)
        {
            throw new InvalidOperationException("Document must be 20MB or less.");
        }

        var normalizedType = (contentType ?? string.Empty).Trim().ToLowerInvariant();
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        var isPdf = normalizedType == "application/pdf" || ext == ".pdf";
        var isImage = normalizedType is "image/jpeg" or "image/png" or "image/bmp"
                      || ext is ".jpg" or ".jpeg" or ".png" or ".bmp";

        if (!isPdf && !isImage)
        {
            throw new InvalidOperationException("Only JPG, PNG, BMP, and PDF files are allowed.");
        }

        var safeName = string.IsNullOrWhiteSpace(fileName)
            ? (isPdf ? "document.pdf" : "document.jpg")
            : Path.GetFileName(fileName);
        var publicId = $"medical-{Guid.NewGuid():N}";

        await using var stream = new MemoryStream(bytes, writable: false);

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(safeName, stream),
            AssetFolder = MedicalRecordsFolder,
            Folder = MedicalRecordsFolder,
            PublicId = publicId,
            UseAssetFolderAsPublicIdPrefix = true
        };

        if (isPdf)
        {
            uploadParams.Format = "pdf";
        }

        var imageResult = await _cloudinary.UploadAsync(uploadParams);
        if (imageResult.Error is not null)
        {
            throw new InvalidOperationException(
                $"Cloudinary upload failed: {imageResult.Error.Message}");
        }

        var secure = imageResult.SecureUrl?.AbsoluteUri ?? imageResult.Url?.AbsoluteUri;
        if (string.IsNullOrWhiteSpace(secure))
        {
            throw new InvalidOperationException("Cloudinary returned no URL for the image.");
        }

        return secure;
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

    public string GenerateSignedUrl(string fileUrl, int expiresInSeconds = 3600)
    {
        return GenerateSignedUrlCandidates(fileUrl, expiresInSeconds).FirstOrDefault() ?? fileUrl;
    }

    public IReadOnlyList<string> GenerateSignedUrlCandidates(string fileUrl, int expiresInSeconds = 3600)
    {
        var asset = TryParseCloudinaryAsset(fileUrl);
        if (asset is null)
        {
            return [fileUrl];
        }

        var urls = new List<string>();

        var url = _cloudinary.Api.UrlImgUp
            .ResourceType(asset.ResourceType)
            .Secure(true)
            .Signed(true)
            .LongUrlSignature(true);

        if (!string.IsNullOrWhiteSpace(asset.Format))
        {
            url = url.Format(asset.Format);
        }

        urls.Add(url.BuildUrl(asset.PublicId));

        if (asset.ResourceType.Equals("image", StringComparison.OrdinalIgnoreCase) &&
            !string.IsNullOrWhiteSpace(asset.Format))
        {
            var legacyUrl = _cloudinary.Api.UrlImgUp
                .ResourceType(asset.ResourceType)
                .Secure(true)
                .Signed(true)
                .LongUrlSignature(true)
                .BuildUrl($"{asset.PublicId}.{asset.Format}");

            if (!urls.Contains(legacyUrl, StringComparer.OrdinalIgnoreCase))
            {
                urls.Add(legacyUrl);
            }
        }

        if (!urls.Contains(fileUrl, StringComparer.OrdinalIgnoreCase))
        {
            urls.Add(fileUrl);
        }

        return urls;
    }

    public async Task DeleteFileAsync(string fileUrl, CancellationToken cancellationToken)
    {
        var asset = TryParseCloudinaryAsset(fileUrl);
        if (asset is null)
        {
            return;
        }

        var result = await _cloudinary.DestroyAsync(new DeletionParams(asset.PublicId)
        {
            ResourceType = ResolveDeletionResourceType(asset.ResourceType),
            Type = "upload",
            Invalidate = true
        });

        if (result.Error is not null)
        {
            throw new InvalidOperationException(
                $"Cloudinary delete failed: {result.Error.Message}");
        }
    }

    private static CloudinaryAssetInfo? TryParseCloudinaryAsset(string? fileUrl)
    {
        var trimmed = fileUrl?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed) ||
            !Uri.TryCreate(trimmed, UriKind.Absolute, out var uri))
        {
            return null;
        }

        var segments = uri.AbsolutePath
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var uploadIndex = Array.FindIndex(segments, segment =>
            segment.Equals("upload", StringComparison.OrdinalIgnoreCase));

        if (uploadIndex <= 0 || uploadIndex >= segments.Length - 1)
        {
            return null;
        }

        var publicIdSegments = segments[(uploadIndex + 1)..];
        if (publicIdSegments.Length == 0)
        {
            return null;
        }

        if (publicIdSegments[0].Length > 1 &&
            publicIdSegments[0][0] == 'v' &&
            publicIdSegments[0][1..].All(char.IsDigit))
        {
            publicIdSegments = publicIdSegments[1..];
        }

        if (publicIdSegments.Length == 0)
        {
            return null;
        }

        var resourceType = segments[uploadIndex - 1];
        string? format = null;

        if (resourceType.Equals("image", StringComparison.OrdinalIgnoreCase))
        {
            var lastSegment = publicIdSegments[^1];
            var extension = Path.GetExtension(lastSegment);
            if (!string.IsNullOrWhiteSpace(extension))
            {
                format = extension.TrimStart('.').ToLowerInvariant();
                publicIdSegments[^1] = Path.GetFileNameWithoutExtension(lastSegment);
            }
        }

        return new CloudinaryAssetInfo(
            resourceType,
            string.Join('/', publicIdSegments),
            format);
    }

    private static string BuildPublicId(string fileNameWithoutExtension)
    {
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

    private static ResourceType ResolveDeletionResourceType(string resourceType)
    {
        return resourceType.Equals("raw", StringComparison.OrdinalIgnoreCase)
            ? ResourceType.Raw
            : ResourceType.Image;
    }

    private sealed record CloudinaryAssetInfo(string ResourceType, string PublicId, string? Format);
}
