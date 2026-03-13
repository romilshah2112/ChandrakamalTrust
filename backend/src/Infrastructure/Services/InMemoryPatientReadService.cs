using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Patients;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class InMemoryPatientReadService : IPatientReadService
{
    private static readonly IReadOnlyList<PatientDetailDto> Patients =
    [
        new PatientDetailDto
        {
            Id = Guid.Parse("8A0A8AA4-9AA7-45D0-B507-8B4F7D7D5E31"),
            Mrn = "OH-10001",
            FirstName = "Maya",
            LastName = "Turner",
            DateOfBirth = new DateOnly(1985, 5, 16),
            Sex = "F",
            Phone = "+1-555-0101"
        },
        new PatientDetailDto
        {
            Id = Guid.Parse("8CE397A5-1ECF-474C-BC2C-C7DA682EF3D2"),
            Mrn = "OH-10002",
            FirstName = "David",
            LastName = "Ross",
            DateOfBirth = new DateOnly(1978, 11, 3),
            Sex = "M",
            Phone = "+1-555-0102"
        },
        new PatientDetailDto
        {
            Id = Guid.Parse("3721B44C-0CA5-4D83-876D-7E12FB004C42"),
            Mrn = "OH-10003",
            FirstName = "Ava",
            LastName = "Lewis",
            DateOfBirth = new DateOnly(1993, 2, 24),
            Sex = "F",
            Phone = "+1-555-0103"
        }
    ];

    public Task<IReadOnlyList<PatientSummaryDto>> SearchAsync(string? query, CancellationToken cancellationToken)
    {
        var normalized = query?.Trim().ToLowerInvariant();

        var results = Patients
            .Where(p => string.IsNullOrWhiteSpace(normalized)
                || p.FirstName.ToLowerInvariant().Contains(normalized)
                || p.LastName.ToLowerInvariant().Contains(normalized)
                || p.Mrn.ToLowerInvariant().Contains(normalized))
            .Select(p => new PatientSummaryDto
            {
                Id = p.Id,
                Mrn = p.Mrn,
                FirstName = p.FirstName,
                LastName = p.LastName,
                DateOfBirth = p.DateOfBirth
            })
            .ToList();

        return Task.FromResult<IReadOnlyList<PatientSummaryDto>>(results);
    }

    public Task<PatientDetailDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        var patient = Patients.FirstOrDefault(p => p.Id == id);
        return Task.FromResult(patient);
    }
}
