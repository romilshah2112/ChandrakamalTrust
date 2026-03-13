using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class CloudinaryImageStorageService : IImageStorageService
{
    private const int MaxBytes = 50 * 1024;
    private readonly HttpClient _httpClient;
    private readonly string _cloudName;
    private readonly string _apiKey;
    private readonly string _apiSecret;

    public CloudinaryImageStorageService(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;

        var section = configuration.GetSection("Cloudinary");
        _cloudName = section["CLOUDINARY_CLOUD_NAME"] ?? string.Empty;
        _apiKey = section["CLOUDINARY_API_KEY"] ?? string.Empty;
        _apiSecret = section["CLOUDINARY_API_SECRET"] ?? string.Empty;
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

        if (string.IsNullOrWhiteSpace(_cloudName) ||
            string.IsNullOrWhiteSpace(_apiKey) ||
            string.IsNullOrWhiteSpace(_apiSecret))
        {
            throw new InvalidOperationException("Cloudinary configuration is missing.");
        }

        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var publicId = $"patient-{Guid.NewGuid():N}";
        var folder = "OptimaHealthcare";
        var signaturePayload = $"folder={folder}&public_id={publicId}&timestamp={timestamp}{_apiSecret}";
        var signature = ComputeSha1(signaturePayload);

        using var form = new MultipartFormDataContent();
        using var fileContent = new ByteArrayContent(bytes);
        fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType);

        form.Add(fileContent, "file", string.IsNullOrWhiteSpace(fileName) ? "patient-profile.jpg" : fileName);
        form.Add(new StringContent(_apiKey), "api_key");
        form.Add(new StringContent(timestamp.ToString()), "timestamp");
        form.Add(new StringContent(publicId), "public_id");
        form.Add(new StringContent(folder), "folder");
        form.Add(new StringContent(signature), "signature");

        var url = $"https://api.cloudinary.com/v1_1/{_cloudName}/image/upload";
        using var response = await _httpClient.PostAsync(url, form, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Cloudinary upload failed: HTTP {(int)response.StatusCode}.");
        }

        using var document = JsonDocument.Parse(body);
        if (!document.RootElement.TryGetProperty("secure_url", out var secureUrlElement))
        {
            throw new InvalidOperationException("Cloudinary response did not include secure_url.");
        }

        var secureUrl = secureUrlElement.GetString();
        if (string.IsNullOrWhiteSpace(secureUrl))
        {
            throw new InvalidOperationException("Cloudinary returned an empty image URL.");
        }

        return secureUrl;
    }

    private static string ComputeSha1(string value)
    {
        var bytes = Encoding.UTF8.GetBytes(value);
        var hash = SHA1.HashData(bytes);
        var sb = new StringBuilder(hash.Length * 2);
        foreach (var b in hash)
        {
            sb.Append(b.ToString("x2"));
        }
        return sb.ToString();
    }
}
