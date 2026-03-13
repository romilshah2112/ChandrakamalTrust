namespace OptimaHealthcare.Contracts.Consultation;

/// <summary>Structured extraction from consultation transcript: complaint, symptoms, medical history.</summary>
public sealed class ConsultationNotesExtractedDto
{
    public string Complaint { get; set; } = string.Empty;
    public string Symptoms { get; set; } = string.Empty;
    public string MedicalHistory { get; set; } = string.Empty;
}
