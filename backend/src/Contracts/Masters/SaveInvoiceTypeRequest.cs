namespace OptimaHealthcare.Contracts.Masters;

public sealed class SaveInvoiceTypeRequest
{
    public string InvoiceTypeName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public double Charges { get; set; }
    public bool IsActive { get; set; } = true;
}
