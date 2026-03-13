using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Consultation;

/// <summary>Transcribes audio to text. MVP: stub returning placeholder; replace with Azure Speech / Whisper when keys are configured.</summary>
public sealed class SpeechService : ISpeechService
{
    private readonly ILogger<SpeechService> _logger;

    public SpeechService(ILogger<SpeechService> logger)
    {
        _logger = logger;
    }

    public Task<string> TranscribeAsync(string audioFilePath, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Transcribing audio from {Path}", audioFilePath);
        // TODO: Integrate Azure Speech SDK or OpenAI Whisper when configuration is available.
        // For MVP return a placeholder so the pipeline (save → transcribe → SOAP → return) is testable.
        var placeholder = "Patient presents for follow-up. Blood pressure improved. Continue current medications. Next visit in 4 weeks.";
        return Task.FromResult(placeholder);
    }
}
