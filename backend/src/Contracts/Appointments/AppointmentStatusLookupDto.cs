namespace OptimaHealthcare.Contracts.Appointments;

public sealed class AppointmentStatusLookupDto
{
    public int AppointmentStatusId { get; init; }
    public string AppointmentStatus { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}
