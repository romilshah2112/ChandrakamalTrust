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
    private readonly Cloudinary _cloudinary;
    private readonly string _cloudName;
    private readonly string _apiSecret;

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
        _apiSecret = apiSecret;
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

        if (isPdf)
        {
            var rawParams = new RawUploadParams
            {
                File = new FileDescription(safeName, stream),
                PublicId = $"{AssetFolder}/{publicId}"
            };

            var result = await Task.Run(() => _cloudinary.Upload(rawParams), cancellationToken)
                .ConfigureAwait(false);
            if (result.Error is not null)
            {
                throw new InvalidOperationException(
                    $"Cloudinary upload failed: {result.Error.Message}");
            }

            var url = result.SecureUrl?.AbsoluteUri ?? result.Url?.AbsoluteUri;
            if (string.IsNullOrWhiteSpace(url))
            {
                throw new InvalidOperationException("Cloudinary returned no URL for the document.");
            }

            return url;
        }

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(safeName, stream),
            AssetFolder = AssetFolder,
            Folder = AssetFolder,
            PublicId = publicId,
            UseAssetFolderAsPublicIdPrefix = true
        };

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

    /// <inheritdoc/>
    public string GenerateSignedUrl(string fileUrl, int expiresInSeconds = 3600)
    {
        // Determine whether this is a raw or image resource by examining the URL path.
        bool isRaw = fileUrl.Contains("/raw/upload/", StringComparison.OrdinalIgnoreCase);
        string uploadMarker = isRaw ? "/raw/upload/" : "/image/upload/";

        var markerIdx = fileUrl.IndexOf(uploadMarker, StringComparison.OrdinalIgnoreCase);
        if (markerIdx < 0)
        {
            return fileUrl; // Not a recognisable Cloudinary URL — return as-is.
        }

        // Everything after "/raw/upload/" or "/image/upload/"
        var afterMarker = fileUrl[(markerIdx + uploadMarker.Length)..];

        // Strip optional version segment: "v1234567890/"
        string publicId;
        var firstSlash = afterMarker.IndexOf('/');
        if (firstSlash > 1
            && afterMarker[0] == 'v'
            && afterMarker[1..firstSlash].All(char.IsDigit))
        {
            publicId = afterMarker[(firstSlash + 1)..];
        }
        else
        {
            publicId = afterMarker;
        }

        if (string.IsNullOrWhiteSpace(publicId))
        {
            return fileUrl;
        }

        // CloudinaryDotNet 1.26.2 signs URLs with SHA-1, but accounts created /
        // updated after 2020 require SHA-256.  Compute the signature manually
        // using SHA-256 to match Cloudinary's documented algorithm:
        //   signature = base64url( SHA256( public_id + api_secret ) )[0..8]
        var toSign = System.Text.Encoding.UTF8.GetBytes(publicId + _apiSecret);
        var hash = System.Security.Cryptography.SHA256.HashData(toSign);

        // URL-safe base64, no padding, first 8 characters only.
        var sig = Convert.ToBase64String(hash)
            .Replace('+', '-').Replace('/', '_').TrimEnd('=')[..8];

        var resourceType = isRaw ? "raw" : "image";
        return $"https://res.cloudinary.com/{_cloudName}/{resourceType}/upload/s--{sig}--/{publicId}";
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
