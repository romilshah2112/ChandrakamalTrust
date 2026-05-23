class PatientVitalsModel {
  PatientVitalsModel({
    required this.patientVitalsId,
    required this.patientDataId,
    required this.bpSys,
    required this.bpDys,
    required this.bloodSugar,
    required this.sugarType,
    required this.pulse,
    required this.weightKg,
    required this.heightCms,
    required this.bmi,
    required this.insertedOn,
    required this.insertedBy,
    required this.isActive,
  });

  final int patientVitalsId;
  final int patientDataId;
  final int bpSys;
  final int bpDys;
  final double bloodSugar;
  final String sugarType;
  final int pulse;
  final double weightKg;
  final double heightCms;
  final double bmi;
  final DateTime insertedOn;
  final int insertedBy;
  final bool isActive;

  factory PatientVitalsModel.fromJson(Map<String, dynamic> json) {
    return PatientVitalsModel(
      patientVitalsId: (json['patientVitalsId'] as num?)?.toInt() ?? 0,
      patientDataId: (json['patientDataId'] as num?)?.toInt() ?? 0,
      bpSys: (json['bpSys'] as num?)?.toInt() ?? 0,
      bpDys: (json['bpDys'] as num?)?.toInt() ?? 0,
      bloodSugar: (json['bloodSugar'] as num?)?.toDouble() ?? 0,
      sugarType: json['sugarType'] as String? ?? '',
      pulse: (json['pulse'] as num?)?.toInt() ?? 0,
      weightKg: (json['weightKG'] as num?)?.toDouble() ?? 0,
      heightCms: (json['heightCMS'] as num?)?.toDouble() ?? 0,
      bmi: (json['bmi'] as num?)?.toDouble() ?? 0,
      insertedOn:
          DateTime.tryParse(json['insertedOn'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      insertedBy: (json['insertedBy'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
