class PatientComplaintSaveRequestModel {
  PatientComplaintSaveRequestModel({
    required this.patientDataId,
    required this.symptoms,
    required this.severityId,
    this.isActive = true,
  });

  final int patientDataId;
  final String symptoms;
  final int severityId;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'patientDataId': patientDataId,
    'symptoms': symptoms,
    'severityId': severityId,
    'isActive': isActive,
  };
}
