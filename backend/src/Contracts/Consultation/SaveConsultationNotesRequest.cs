namespace OptimaHealthcare.Contracts.Consultation;

/// <summary>Request to save consultation transcript into PatientComplaint and PatientMedicalHistory.</summary>
public sealed class SaveConsultationNotesRequest
{
    public int PatientDataId { get; set; }
    public string Transcript { get; set; } = string.Empty;
}
