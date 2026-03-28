class PatientMedicalRecordModel {
  const PatientMedicalRecordModel({
    required this.patientMedicalRecordId,
    required this.patientDataId,
    required this.recordTypeId,
    required this.recordName,
    required this.fileUrl,
    required this.reportDate,
    this.comments,
    required this.uploadedOn,
    required this.uploadedById,
    required this.isActive,
  });

  final int patientMedicalRecordId;
  final int patientDataId;
  final int recordTypeId;
  final String recordName;
  final String fileUrl;
  final String reportDate;
  final String? comments;
  final String uploadedOn;
  final int uploadedById;
  final bool isActive;

  factory PatientMedicalRecordModel.fromJson(Map<String, dynamic> json) {
    return PatientMedicalRecordModel(
      patientMedicalRecordId: (json['patientMedicalRecordId'] as num).toInt(),
      patientDataId: (json['patientDataId'] as num).toInt(),
      recordTypeId: (json['recordTypeId'] as num).toInt(),
      recordName: json['recordName'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
      reportDate: json['reportDate'] as String? ?? '',
      comments: json['comments'] as String?,
      uploadedOn: json['uploadedOn'] as String? ?? '',
      uploadedById: (json['uploadedById'] as num).toInt(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
