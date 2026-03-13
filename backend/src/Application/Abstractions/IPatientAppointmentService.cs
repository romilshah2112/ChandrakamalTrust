using OptimaHealthcare.Contracts.Appointments;

namespace OptimaHealthcare.Application.Abstractions;

public interface IPatientAppointmentService
{
    Task<IReadOnlyList<AppointmentStatusLookupDto>> ListStatusesAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<AppointmentTypeDto>> ListAppointmentTypesAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<PatientAppointmentDto>> ListAsync(
        DateTime? from,
        DateTime? to,
        int? clinicId,
        int appUserId,
        string role,
        CancellationToken cancellationToken);

    Task<int> CreateAsync(
        SavePatientAppointmentRequest request,
        int enteredById,
        string username,
        CancellationToken cancellationToken);

    Task UpdateAsync(
        int patientAppointmentId,
        SavePatientAppointmentRequest request,
        int enteredById,
        string username,
        CancellationToken cancellationToken);

    Task DeleteAsync(int patientAppointmentId, CancellationToken cancellationToken);

    /// <summary>Lists appointments due for pre-visit reminder using AppointmentType.ReminderHoursBefore (no user filter).</summary>
    Task<IReadOnlyList<AppointmentReminderCandidateDto>> ListDueForReminderAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken);

    /// <summary>Marks an appointment as notified after sending a reminder.</summary>
    Task SetNotifiedAsync(int patientAppointmentId, CancellationToken cancellationToken);

    /// <summary>Lists appointments due for follow-up reminder using AppointmentType.FollowUpReminderHoursAfter.</summary>
    Task<IReadOnlyList<AppointmentReminderCandidateDto>> ListDueForFollowUpReminderAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken);

    /// <summary>Marks that a follow-up reminder was sent for this appointment.</summary>
    Task SetFollowUpReminderSentAsync(int patientAppointmentId, CancellationToken cancellationToken);
}



