class SavePatientMedicalRecordRequestModel {
  SavePatientMedicalRecordRequestModel({
    required this.recordTypeId,
    required this.recordName,
    required this.fileBase64,
    required this.fileName,
    required this.contentType,
    required this.reportDate,
    this.comments,
  });

  final int recordTypeId;
  final String recordName;
  final String fileBase64;
  final String fileName;
  final String contentType;
  final DateTime reportDate;
  final String? comments;

  Map<String, dynamic> toJson() {
    return {
      'recordTypeId': recordTypeId,
      'recordName': recordName,
      'fileBase64': fileBase64,
      'fileName': fileName,
      'contentType': contentType,
      'reportDate': reportDate.toUtc().toIso8601String(),
      if (comments != null && comments!.trim().isNotEmpty)
        'comments': comments!.trim(),
    };
  }
}
