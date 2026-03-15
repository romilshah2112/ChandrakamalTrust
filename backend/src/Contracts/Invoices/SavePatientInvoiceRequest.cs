namespace OptimaHealthcare.Contracts.Invoices;

public sealed class SavePatientInvoiceRequest
{
    public int PatientDataId { get; set; }
    public int DoctorProfileId { get; set; }
    public int ClinicId { get; set; }
    public DateTime InvoiceDate { get; set; }
    public string? Comments { get; set; }
    public IReadOnlyList<SavePatientInvoiceLineRequest> Lines { get; set; } = [];
}
