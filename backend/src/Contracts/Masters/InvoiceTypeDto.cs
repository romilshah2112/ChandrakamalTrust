namespace OptimaHealthcare.Contracts.Masters;

public sealed class InvoiceTypeDto
{
    public int InvoiceTypeId { get; init; }
    public string InvoiceTypeName { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public double Charges { get; init; }
    public bool IsActive { get; init; }
}
