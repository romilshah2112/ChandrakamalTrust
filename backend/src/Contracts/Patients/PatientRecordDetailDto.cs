namespace OptimaHealthcare.Contracts.Patients;

public sealed class PatientRecordDetailDto
{
    public int PatientRecordDetailId { get; init; }
    public int PatientMedicalRecordId { get; init; }
    public string PatientNameInRecord { get; init; } = string.Empty;
    public int RecordKeywordId { get; init; }
    public string Keyword { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public double ReadingValue { get; init; }
    public double? IdealLower { get; init; }
    public double? IdealUpper { get; init; }
    public DateTime ReportDateTime { get; init; }

    /// <summary>Populated only by the analytics endpoint (ListByPatientAsync).</summary>
    public int RecordParameterId { get; init; }
    public string RecordParameterName { get; init; } = string.Empty;
}
