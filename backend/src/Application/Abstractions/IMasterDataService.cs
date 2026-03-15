using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Application.Abstractions;

public interface IMasterDataService
{
    Task<IReadOnlyList<ClinicDto>> ListClinicsAsync(CancellationToken cancellationToken);
    Task<int> CreateClinicAsync(SaveClinicRequest request, CancellationToken cancellationToken);
    Task UpdateClinicAsync(int clinicId, SaveClinicRequest request, CancellationToken cancellationToken);
    Task DeleteClinicAsync(int clinicId, CancellationToken cancellationToken);

    Task<IReadOnlyList<DoctorProfileDto>> ListDoctorProfilesAsync(CancellationToken cancellationToken);
    Task<int?> GetDoctorProfileIdByAppUserIdAsync(int appUserId, CancellationToken cancellationToken);

    Task<int> CreateDoctorProfileAsync(SaveDoctorProfileRequest request, CancellationToken cancellationToken);
    Task UpdateDoctorProfileAsync(int doctorProfileId, SaveDoctorProfileRequest request, CancellationToken cancellationToken);
    Task DeleteDoctorProfileAsync(int doctorProfileId, CancellationToken cancellationToken);

    Task<IReadOnlyList<StaffDto>> ListStaffAsync(CancellationToken cancellationToken);
    Task<int> CreateStaffAsync(SaveStaffRequest request, CancellationToken cancellationToken);
    Task UpdateStaffAsync(int staffId, SaveStaffRequest request, CancellationToken cancellationToken);
    Task DeleteStaffAsync(int staffId, CancellationToken cancellationToken);

    Task<IReadOnlyList<ClinicScheduleDto>> ListClinicSchedulesAsync(CancellationToken cancellationToken);
    Task<int> CreateClinicScheduleAsync(SaveClinicScheduleRequest request, CancellationToken cancellationToken);
    Task UpdateClinicScheduleAsync(int scheduleId, SaveClinicScheduleRequest request, CancellationToken cancellationToken);
    Task DeleteClinicScheduleAsync(int scheduleId, CancellationToken cancellationToken);

    Task<IReadOnlyList<InvoiceTypeDto>> ListInvoiceTypesAsync(CancellationToken cancellationToken);
    Task<int> CreateInvoiceTypeAsync(SaveInvoiceTypeRequest request, CancellationToken cancellationToken);
    Task UpdateInvoiceTypeAsync(int invoiceTypeId, SaveInvoiceTypeRequest request, CancellationToken cancellationToken);
    Task DeleteInvoiceTypeAsync(int invoiceTypeId, CancellationToken cancellationToken);
}
