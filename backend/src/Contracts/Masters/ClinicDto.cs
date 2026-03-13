namespace OptimaHealthcare.Contracts.Masters;

public sealed class ClinicDto
{
    public int ClinicId { get; init; }
    public string ClinicName { get; init; } = string.Empty;
    public string Address { get; init; } = string.Empty;
    public string City { get; init; } = string.Empty;
    public string Zip { get; init; } = string.Empty;
    public string State { get; init; } = string.Empty;
    public int CountryId { get; init; }
    public long Phone { get; init; }
    public string Email { get; init; } = string.Empty;
    public string Photo { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}
