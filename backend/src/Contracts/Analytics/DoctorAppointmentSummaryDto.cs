namespace OptimaHealthcare.Contracts.Analytics;

public sealed class DoctorAppointmentSummaryDto
{
    public string PatientName { get; init; } = string.Empty;
    public DateTime StartTime { get; init; }
    public DateTime EndTime { get; init; }
    public string ClinicName { get; init; } = string.Empty;
}
