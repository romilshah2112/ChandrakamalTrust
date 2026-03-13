using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Infrastructure.Consultation;

/// <summary>Converts transcript to SOAP note. MVP: stub returning structured placeholder; replace with OpenAI/Azure OpenAI when configured.</summary>
public sealed class LLMService : ILLMService
{
    private readonly ILogger<LLMService> _logger;

    public LLMService(ILogger<LLMService> logger)
    {
        _logger = logger;
    }

    public Task<SoapConsultationDto> TranscriptToSoapAsync(string transcript, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Generating SOAP from transcript length {Length}", transcript?.Length ?? 0);
        // TODO: Call OpenAI / Azure OpenAI with prompt to extract SOAP from transcript.
        var soap = new SoapConsultationDto
        {
            Subjective = "Patient reports improved blood pressure and adherence to medications.",
            Objective = "Vitals stable. BP within target range.",
            Assessment = "Hypertension, well controlled on current regimen.",
            Plan = "Continue current medications. Follow up in 4 weeks. Repeat labs as ordered."
        };
        return Task.FromResult(soap);
    }

    public Task<ConsultationNotesExtractedDto> ExtractConsultationNotesAsync(string transcript, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Extracting consultation notes from transcript length {Length}", transcript?.Length ?? 0);
        var t = (transcript ?? string.Empty).Trim();
        if (string.IsNullOrEmpty(t))
        {
            return Task.FromResult(new ConsultationNotesExtractedDto());
        }

        // Heuristic extraction: look for common medical note patterns.
        // TODO: Replace with OpenAI/Azure OpenAI when configured for better extraction.
        var complaint = ExtractSection(t, new[] { "chief complaint", "complains of", "presents with", "patient reports", "main concern", "reason for visit" })
            ?? (t.Length <= 800 ? t : t[..800].Trim());
        var symptoms = ExtractSection(t, new[] { "symptoms", "symptom", "experiencing", "experiences", "feels", "feeling", "pain", "aching", "dizzy", "nausea" })
            ?? string.Empty;
        var medicalHistory = ExtractSection(t, new[] { "medical history", "past medical", "history of", "previous", "medications", "allergies", "allergic", "chronic conditions", "diagnosed" })
            ?? string.Empty;

        // Ensure we always capture something: if no structured extraction, use full transcript for complaint
        var complaintText = Normalize(complaint);
        if (string.IsNullOrEmpty(complaintText))
            complaintText = t.Length <= 2000 ? t : t[..2000];

        return Task.FromResult(new ConsultationNotesExtractedDto
        {
            Complaint = complaintText,
            Symptoms = Normalize(symptoms),
            MedicalHistory = Normalize(medicalHistory)
        });
    }

    private static string? ExtractSection(string text, string[] triggers)
    {
        var lower = text.ToLowerInvariant();
        foreach (var trigger in triggers)
        {
            var idx = lower.IndexOf(trigger, StringComparison.Ordinal);
            if (idx >= 0)
            {
                var start = Math.Max(0, idx - 20);
                var segment = text[start..].Trim();
                return segment.Length > 2000 ? segment[..2000] : segment;
            }
        }
        return null;
    }

    private static string Normalize(string s)
    {
        if (string.IsNullOrWhiteSpace(s)) return string.Empty;
        return s.Trim();
    }
}
