using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Application.Abstractions;

/// <summary>Saves consultation transcript into PatientComplaint and PatientMedicalHistory.</summary>
public interface IConsultationNotesService
{
    /// <summary>Extracts complaint, symptoms, medical history from transcript and saves to DB.</summary>
    Task SaveConsultationNotesAsync(SaveConsultationNotesRequest request, int enteredByAppUserId, CancellationToken cancellationToken = default);
}
