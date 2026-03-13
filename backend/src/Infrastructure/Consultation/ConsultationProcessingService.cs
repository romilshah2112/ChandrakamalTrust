using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Infrastructure.Consultation;

/// <summary>Orchestrates: save audio to temp file → transcribe → SOAP → return result; deletes temp file.</summary>
public sealed class ConsultationProcessingService : IConsultationProcessingService
{
    private readonly ISpeechService _speechService;
    private readonly ILLMService _llmService;
    private readonly ILogger<ConsultationProcessingService> _logger;

    public ConsultationProcessingService(
        ISpeechService speechService,
        ILLMService llmService,
        ILogger<ConsultationProcessingService> logger)
    {
        _speechService = speechService;
        _llmService = llmService;
        _logger = logger;
    }

    public async Task<ProcessAudioResponse> ProcessAudioAsync(Stream audioStream, string? fileName, CancellationToken cancellationToken = default)
    {
        var ext = string.IsNullOrEmpty(fileName) || !fileName.Contains('.')
            ? ".wav"
            : Path.GetExtension(fileName);
        var tempPath = Path.Combine(Path.GetTempPath(), $"consultation_{Guid.NewGuid():N}{ext}");

        try
        {
            await using (var fileStream = File.Create(tempPath))
            {
                await audioStream.CopyToAsync(fileStream, cancellationToken);
            }

            _logger.LogInformation("Saved temp audio to {Path}, transcribing.", tempPath);
            var transcript = await _speechService.TranscribeAsync(tempPath, cancellationToken);
            var soap = await _llmService.TranscriptToSoapAsync(transcript, cancellationToken);

            return new ProcessAudioResponse
            {
                Transcript = transcript,
                Soap = soap
            };
        }
        finally
        {
            try
            {
                if (File.Exists(tempPath))
                {
                    File.Delete(tempPath);
                    _logger.LogDebug("Deleted temp file {Path}", tempPath);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to delete temp file {Path}", tempPath);
            }
        }
    }
}
