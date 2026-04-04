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
  });

  final List<StaffAnalyticsPointModel> patientsByGender;
  final List<StaffAnalyticsPointModel> patientsByAgeGroup;
  final List<StaffAnalyticsPointModel> patientsByCity;

  factory StaffDashboardAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      StaffDashboardAnalyticsModel(
        patientsByGender: _pointsFromJson(json['patientsByGender']),
        patientsByAgeGroup: _pointsFromJson(json['patientsByAgeGroup']),
        patientsByCity: _pointsFromJson(json['patientsByCity']),
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
