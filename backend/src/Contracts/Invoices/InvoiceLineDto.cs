namespace OptimaHealthcare.Contracts.Invoices;

public sealed class InvoiceLineDto
{
    public int InvoiceDetailId { get; init; }
    public int InvoiceTypeId { get; init; }
    public string InvoiceTypeName { get; init; } = string.Empty;
    public double InvoiceAmount { get; init; }
    public double Deduction { get; init; }
}
