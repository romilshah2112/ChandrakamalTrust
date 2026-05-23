using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Application.Abstractions;

public interface IStaffAnalyticsService
{
    Task<StaffDashboardAnalyticsDto> GetDashboardAsync(string? referenceName, CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> ListReferenceNamesAsync(CancellationToken cancellationToken);
}
