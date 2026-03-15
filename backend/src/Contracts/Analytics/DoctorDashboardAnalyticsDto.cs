namespace OptimaHealthcare.Contracts.Analytics;

public sealed class DoctorDashboardAnalyticsDto
{
    public IReadOnlyList<DoctorAppointmentSummaryDto> TodayAppointments { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> PatientsByGender { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> PatientsByAgeGroup { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> RevenueForDay { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> RevenueByWeek { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> RevenueByMonth { get; init; } = [];
}
