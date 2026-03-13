namespace OptimaHealthcare.Application.Abstractions;

/// <summary>Transcribes audio to text (e.g. Azure Speech, Whisper).</summary>
public interface ISpeechService
{
    /// <summary>Transcribes audio from the given file path. Caller is responsible for temp file lifecycle.</summary>
    Task<string> TranscribeAsync(string audioFilePath, CancellationToken cancellationToken = default);
}
