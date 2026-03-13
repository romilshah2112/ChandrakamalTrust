namespace OptimaHealthcare.Contracts.Consultation;

/// <summary>Structured SOAP note returned after AI processing of consultation audio.</summary>
public sealed class SoapConsultationDto
{
    public string Subjective { get; set; } = string.Empty;
    public string Objective { get; set; } = string.Empty;
    public string Assessment { get; set; } = string.Empty;
    public string Plan { get; set; } = string.Empty;
}
