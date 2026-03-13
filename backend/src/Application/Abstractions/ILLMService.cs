using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Application.Abstractions;

/// <summary>Converts consultation transcript to structured SOAP note and consultation notes (e.g. OpenAI, Azure OpenAI).</summary>
public interface ILLMService
{
    /// <summary>Generates SOAP (Subjective, Objective, Assessment, Plan) from transcript.</summary>
    Task<SoapConsultationDto> TranscriptToSoapAsync(string transcript, CancellationToken cancellationToken = default);

    /// <summary>Extracts complaint, symptoms, and medical history from transcript for database storage.</summary>
    Task<ConsultationNotesExtractedDto> ExtractConsultationNotesAsync(string transcript, CancellationToken cancellationToken = default);
}
