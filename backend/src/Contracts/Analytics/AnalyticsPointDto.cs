namespace OptimaHealthcare.Contracts.Analytics;

public sealed class AnalyticsPointDto
{
    public string Label { get; init; } = string.Empty;
    public double Value { get; init; }
}
