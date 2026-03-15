class AnalyticsPointModel {
  AnalyticsPointModel({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  factory AnalyticsPointModel.fromJson(Map<String, dynamic> json) =>
      AnalyticsPointModel(
        label: json['label'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

class DoctorAppointmentSummaryModel {
  DoctorAppointmentSummaryModel({
    required this.patientName,
    required this.startTime,
    required this.endTime,
    required this.clinicName,
  });

  final String patientName;
  final DateTime startTime;
  final DateTime endTime;
  final String clinicName;

  factory DoctorAppointmentSummaryModel.fromJson(Map<String, dynamic> json) =>
      DoctorAppointmentSummaryModel(
        patientName: json['patientName'] as String? ?? '',
        startTime: DateTime.parse(json['startTime'] as String).toLocal(),
        endTime: DateTime.parse(json['endTime'] as String).toLocal(),
        clinicName: json['clinicName'] as String? ?? '',
      );
}

class DoctorDashboardAnalyticsModel {
  DoctorDashboardAnalyticsModel({
    required this.todayAppointments,
    required this.patientsByGender,
    required this.patientsByAgeGroup,
    required this.revenueForDay,
    required this.revenueByWeek,
    required this.revenueByMonth,
  });

  final List<DoctorAppointmentSummaryModel> todayAppointments;
  final List<AnalyticsPointModel> patientsByGender;
  final List<AnalyticsPointModel> patientsByAgeGroup;
  final List<AnalyticsPointModel> revenueForDay;
  final List<AnalyticsPointModel> revenueByWeek;
  final List<AnalyticsPointModel> revenueByMonth;

  factory DoctorDashboardAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      DoctorDashboardAnalyticsModel(
        todayAppointments: (json['todayAppointments'] as List<dynamic>? ?? const [])
            .map(
              (item) => DoctorAppointmentSummaryModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
        patientsByGender: _pointsFromJson(json['patientsByGender']),
        patientsByAgeGroup: _pointsFromJson(json['patientsByAgeGroup']),
        revenueForDay: _pointsFromJson(json['revenueForDay']),
        revenueByWeek: _pointsFromJson(json['revenueByWeek']),
        revenueByMonth: _pointsFromJson(json['revenueByMonth']),
      );

  static List<AnalyticsPointModel> _pointsFromJson(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => AnalyticsPointModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
