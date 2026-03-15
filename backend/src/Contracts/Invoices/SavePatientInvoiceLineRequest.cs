namespace OptimaHealthcare.Contracts.Invoices;

public sealed class SavePatientInvoiceLineRequest
{
    public int InvoiceTypeId { get; set; }
    public double InvoiceAmount { get; set; }
    public double Deduction { get; set; }
}
