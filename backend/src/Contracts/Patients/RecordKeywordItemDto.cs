namespace OptimaHealthcare.Contracts.Patients;

public sealed class RecordKeywordItemDto
{
    public int Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public double? IdealLower { get; init; }
    public double? IdealUpper { get; init; }
}
