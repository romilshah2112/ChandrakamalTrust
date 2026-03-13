namespace OptimaHealthcare.Contracts.Masters;

public sealed class SaveClinicRequest
{
    public string ClinicName { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public string Zip { get; set; } = string.Empty;
    public string State { get; set; } = string.Empty;
    public int CountryId { get; set; }
    public long Phone { get; set; }
    public string Email { get; set; } = string.Empty;
    public string? Photo { get; set; }
    public bool IsActive { get; set; } = true;
}
