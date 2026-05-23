class PatientVitalsSaveRequestModel {
  PatientVitalsSaveRequestModel({
    required this.patientDataId,
    required this.bpSys,
    required this.bpDys,
    required this.bloodSugar,
    required this.sugarType,
    required this.pulse,
    required this.weightKg,
    required this.heightCms,
    required this.measuredOn,
    this.isActive = true,
  });

  final int patientDataId;
  final int bpSys;
  final int bpDys;
  final double bloodSugar;
  final String sugarType;
  final int pulse;
  final double weightKg;
  final double heightCms;
  final DateTime measuredOn;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'patientDataId': patientDataId,
    'bpSys': bpSys,
    'bpDys': bpDys,
    'bloodSugar': bloodSugar,
    'sugarType': sugarType,
    'pulse': pulse,
    'weightKG': weightKg,
    'heightCMS': heightCms,
    'measuredOn': measuredOn.toUtc().toIso8601String(),
    'isActive': isActive,
  };
}
