class PatientComplaintModel {
  PatientComplaintModel({
    required this.patientComplaintId,
    required this.patientDataId,
    required this.symptoms,
    required this.severityId,
    required this.severity,
    required this.insertedOn,
    required this.enteredById,
    required this.isActive,
  });

  final int patientComplaintId;
  final int patientDataId;
  final String symptoms;
  final int severityId;
  final String severity;
  final DateTime insertedOn;
  final int enteredById;
  final bool isActive;

  factory PatientComplaintModel.fromJson(Map<String, dynamic> json) {
    return PatientComplaintModel(
      patientComplaintId: (json['patientComplaintId'] as num?)?.toInt() ?? 0,
      patientDataId: (json['patientDataId'] as num?)?.toInt() ?? 0,
      symptoms: json['symptoms'] as String? ?? '',
      severityId: (json['severityId'] as num?)?.toInt() ?? 0,
      severity: json['severity'] as String? ?? '',
      insertedOn:
          DateTime.tryParse(json['insertedOn'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      enteredById: (json['enteredById'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
