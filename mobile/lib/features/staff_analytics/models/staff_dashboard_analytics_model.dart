class StaffAnalyticsPointModel {
  StaffAnalyticsPointModel({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  factory StaffAnalyticsPointModel.fromJson(Map<String, dynamic> json) =>
      StaffAnalyticsPointModel(
        label: json['label'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

class StaffDashboardAnalyticsModel {
  StaffDashboardAnalyticsModel({
    required this.patientsByGender,
    required this.patientsByAgeGroup,
    required this.patientsByCity,
    required this.patientsByBPSystolicRange,
    required this.patientsByBPDiastolicRange,
    required this.patientsByBloodSugarRange,
    required this.patientsByBmiRange,
  });

  final List<StaffAnalyticsPointModel> patientsByGender;
  final List<StaffAnalyticsPointModel> patientsByAgeGroup;
  final List<StaffAnalyticsPointModel> patientsByCity;
  final List<StaffAnalyticsPointModel> patientsByBPSystolicRange;
  final List<StaffAnalyticsPointModel> patientsByBPDiastolicRange;
  final List<StaffAnalyticsPointModel> patientsByBloodSugarRange;
  final List<StaffAnalyticsPointModel> patientsByBmiRange;

  factory StaffDashboardAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      StaffDashboardAnalyticsModel(
        patientsByGender: _pointsFromJson(json['patientsByGender']),
        patientsByAgeGroup: _pointsFromJson(json['patientsByAgeGroup']),
        patientsByCity: _pointsFromJson(json['patientsByCity']),
        patientsByBPSystolicRange: _pointsFromJson(
          json['patientsByBPSystolicRange'],
        ),
        patientsByBPDiastolicRange: _pointsFromJson(
          json['patientsByBPDiastolicRange'],
        ),
        patientsByBloodSugarRange: _pointsFromJson(
          json['patientsByBloodSugarRange'],
        ),
        patientsByBmiRange: _pointsFromJson(json['patientsByBmiRange']),
      );

  static List<StaffAnalyticsPointModel> _pointsFromJson(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map(
          (item) =>
              StaffAnalyticsPointModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
