class PatientVitalsSaveRequestModel {
  PatientVitalsSaveRequestModel({
    required this.patientDataId,
    required this.bpSys,
    required this.bpDys,
    required this.bloodSugar,
    required this.pulse,
    required this.weightKg,
    required this.heightCms,
    this.isActive = true,
  });

  final int patientDataId;
  final int bpSys;
  final int bpDys;
  final int bloodSugar;
  final int pulse;
  final int weightKg;
  final int heightCms;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'patientDataId': patientDataId,
    'bpSys': bpSys,
    'bpDys': bpDys,
    'bloodSugar': bloodSugar,
    'pulse': pulse,
    'weightKG': weightKg,
    'heightCMS': heightCms,
    'isActive': isActive,
  };
}
