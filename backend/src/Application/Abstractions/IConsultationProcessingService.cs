using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Application.Abstractions;

/// <summary>Orchestrates audio upload → transcribe → SOAP generation. Saves temp file and cleans up.</summary>
public interface IConsultationProcessingService
{
    /// <summary>Processes audio stream: saves to temp file, transcribes, generates SOAP, returns result. Deletes temp file when done.</summary>
    Task<ProcessAudioResponse> ProcessAudioAsync(Stream audioStream, string? fileName, CancellationToken cancellationToken = default);
}
