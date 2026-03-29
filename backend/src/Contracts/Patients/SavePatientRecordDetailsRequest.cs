namespace OptimaHealthcare.Contracts.Patients;

public sealed class SavePatientRecordDetailsRequest
{
    public string PatientNameInRecord { get; set; } = string.Empty;
    public List<SavePatientRecordDetailItemRequest> Details { get; set; } = [];
}

public sealed class SavePatientRecordDetailItemRequest
{
    public int RecordKeywordId { get; set; }
    public double ReadingValue { get; set; }
    public DateTime ReportDateTime { get; set; }
}
