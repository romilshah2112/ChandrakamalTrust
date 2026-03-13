namespace OptimaHealthcare.Contracts.Consultation;

/// <summary>Response for POST /api/consultation/process-audio: transcript and generated SOAP JSON.</summary>
public sealed class ProcessAudioResponse
{
    public string Transcript { get; set; } = string.Empty;
    public SoapConsultationDto Soap { get; set; } = new();
}
