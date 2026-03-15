using OptimaHealthcare.Contracts.Invoices;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Application.Abstractions;

public interface IInvoiceService
{
    Task<IReadOnlyList<PatientInvoiceDto>> ListAsync(CancellationToken cancellationToken);
    Task<string> GetNextInvoiceNumberAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<InvoiceTypeDto>> ListInvoiceTypesAsync(CancellationToken cancellationToken);
    Task<int> CreateAsync(SavePatientInvoiceRequest request, int enteredById, CancellationToken cancellationToken);
    Task UpdateAsync(int invoiceMasterId, SavePatientInvoiceRequest request, int enteredById, CancellationToken cancellationToken);
    Task DeleteAsync(int invoiceMasterId, CancellationToken cancellationToken);
}
