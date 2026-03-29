class PatientRecordDetailModel {
  const PatientRecordDetailModel({
    required this.patientRecordDetailId,
    required this.patientMedicalRecordId,
    required this.patientNameInRecord,
    required this.recordKeywordId,
    required this.keyword,
    required this.description,
    required this.readingValue,
    this.idealLower,
    this.idealUpper,
    required this.reportDateTime,
  });

  final int patientRecordDetailId;
  final int patientMedicalRecordId;
  final String patientNameInRecord;
  final int recordKeywordId;
  final String keyword;
  final String description;
  final double readingValue;
  final double? idealLower;
  final double? idealUpper;
  final String reportDateTime;

  PatientRecordDetailModel copyWith({
    int? patientRecordDetailId,
    int? patientMedicalRecordId,
    String? patientNameInRecord,
    int? recordKeywordId,
    String? keyword,
    String? description,
    double? readingValue,
    double? idealLower,
    double? idealUpper,
    String? reportDateTime,
  }) {
    return PatientRecordDetailModel(
      patientRecordDetailId:
          patientRecordDetailId ?? this.patientRecordDetailId,
      patientMedicalRecordId:
          patientMedicalRecordId ?? this.patientMedicalRecordId,
      patientNameInRecord: patientNameInRecord ?? this.patientNameInRecord,
      recordKeywordId: recordKeywordId ?? this.recordKeywordId,
      keyword: keyword ?? this.keyword,
      description: description ?? this.description,
      readingValue: readingValue ?? this.readingValue,
      idealLower: idealLower ?? this.idealLower,
      idealUpper: idealUpper ?? this.idealUpper,
      reportDateTime: reportDateTime ?? this.reportDateTime,
    );
  }

  factory PatientRecordDetailModel.fromJson(Map<String, dynamic> json) {
    double? toNullableDouble(dynamic value) =>
        value == null ? null : (value as num).toDouble();

    return PatientRecordDetailModel(
      patientRecordDetailId: (json['patientRecordDetailId'] as num).toInt(),
      patientMedicalRecordId: (json['patientMedicalRecordId'] as num).toInt(),
      patientNameInRecord: json['patientNameInRecord'] as String? ?? '',
      recordKeywordId: (json['recordKeywordId'] as num).toInt(),
      keyword: json['keyword'] as String? ?? '',
      description: json['description'] as String? ?? '',
      readingValue: (json['readingValue'] as num).toDouble(),
      idealLower: toNullableDouble(json['idealLower']),
      idealUpper: toNullableDouble(json['idealUpper']),
      reportDateTime: json['reportDateTime'] as String? ?? '',
    );
  }
}
