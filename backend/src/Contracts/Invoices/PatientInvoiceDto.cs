namespace OptimaHealthcare.Contracts.Invoices;

public sealed class PatientInvoiceDto
{
    public int InvoiceMasterId { get; init; }
    public string InvoiceNumber { get; init; } = string.Empty;
    public int PatientDataId { get; init; }
    public string PatientName { get; init; } = string.Empty;
    public DateOnly? PatientBirthDate { get; init; }
    public string PatientGender { get; init; } = string.Empty;
    public int DoctorProfileId { get; init; }
    public string DoctorName { get; init; } = string.Empty;
    public string DoctorDegree { get; init; } = string.Empty;
    public string DoctorStream { get; init; } = string.Empty;
    public int ClinicId { get; init; }
    public string ClinicName { get; init; } = string.Empty;
    public string ClinicAddress { get; init; } = string.Empty;
    public string ClinicPhone { get; init; } = string.Empty;
    public DateTime InvoiceDate { get; init; }
    public string Comments { get; init; } = string.Empty;
    public int EnteredById { get; init; }
    public DateTime EnteredOn { get; init; }
    public bool IsActive { get; init; }
    public IReadOnlyList<InvoiceLineDto> Lines { get; init; } = [];
}
