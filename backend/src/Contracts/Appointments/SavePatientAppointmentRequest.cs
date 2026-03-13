namespace OptimaHealthcare.Contracts.Appointments;

public sealed class SavePatientAppointmentRequest
{
    public int PatientDataId { get; set; }
    public int DoctorProfileId { get; set; }
    public int ClinicId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public int AppointmentStatusId { get; set; }
    /// <summary>AppointmentType (First Visit / Follow-up); used for reminder timing.</summary>
    public int? AppointmentTypeId { get; set; }
    public int IsNotified { get; set; }
    public bool IsActive { get; set; } = true;
}
