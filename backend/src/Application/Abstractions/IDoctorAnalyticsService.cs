using OptimaHealthcare.Contracts.Analytics;

namespace OptimaHealthcare.Application.Abstractions;

public interface IDoctorAnalyticsService
{
    Task<DoctorDashboardAnalyticsDto> GetDashboardAsync(
        int appUserId,
        string roleName,
        CancellationToken cancellationToken);
}
