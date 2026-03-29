class UpdatePatientMedicalRecordRequestModel {
  UpdatePatientMedicalRecordRequestModel({
    required this.recordTypeId,
    required this.recordName,
    required this.reportDate,
    this.comments,
  });

  final int recordTypeId;
  final String recordName;
  final DateTime reportDate;
  final String? comments;

  Map<String, dynamic> toJson() {
    return {
      'recordTypeId': recordTypeId,
      'recordName': recordName,
      'reportDate': reportDate.toUtc().toIso8601String(),
      if (comments != null && comments!.trim().isNotEmpty)
        'comments': comments!.trim(),
    };
  }
}
