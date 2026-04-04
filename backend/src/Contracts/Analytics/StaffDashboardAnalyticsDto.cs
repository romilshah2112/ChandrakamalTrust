namespace OptimaHealthcare.Contracts.Analytics;

public sealed class StaffDashboardAnalyticsDto
{
    public IReadOnlyList<AnalyticsPointDto> PatientsByGender { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> PatientsByAgeGroup { get; init; } = [];
    public IReadOnlyList<AnalyticsPointDto> PatientsByCity { get; init; } = [];
}
