namespace OptimaHealthcare.Contracts.Appointments;

public sealed class PatientAppointmentDto
{
    public int PatientAppointmentId { get; init; }
    public int PatientDataId { get; init; }
    public string PatientName { get; init; } = string.Empty;
    public int DoctorProfileId { get; init; }
    public string DoctorName { get; init; } = string.Empty;
    public int ClinicId { get; init; }
    public string ClinicName { get; init; } = string.Empty;
    public DateTime StartTime { get; init; }
    public DateTime EndTime { get; init; }
    public int AppointmentStatusId { get; init; }
    public int? AppointmentTypeId { get; init; }
    public string? AppointmentTypeName { get; init; }
    public int IsNotified { get; init; }
    public bool IsActive { get; init; }
    public DateTime? InsertedOn { get; init; }
    public DateTime? UpdatedOn { get; init; }
    public int EnteredById { get; init; }
}
