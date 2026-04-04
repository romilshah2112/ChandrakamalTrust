using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Application.Abstractions;

public interface IStaffAnalyticsService
{
    Task<StaffDashboardAnalyticsDto> GetDashboardAsync(CancellationToken cancellationToken);
}
