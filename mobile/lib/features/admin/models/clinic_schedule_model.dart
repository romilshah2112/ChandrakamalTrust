class ClinicScheduleModel {
  ClinicScheduleModel({
    required this.id,
    required this.clinicId,
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
    required this.appUserId,
    required this.appUserName,
  });

  final int id;
  final int clinicId;
  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;
  final int appUserId;
  final String appUserName;

  factory ClinicScheduleModel.fromJson(Map<String, dynamic> json) => ClinicScheduleModel(
    id: json['scheduleId'] as int,
    clinicId: json['clinicId'] as int? ?? 0,
    dayOfWeek: json['dayOfWeek'] as int? ?? 0,
    openTime: json['openTime'] as String?,
    closeTime: json['closeTime'] as String?,
    isClosed: json['isClosed'] as bool? ?? false,
    appUserId: json['appUserId'] as int? ?? 0,
    appUserName: json['appUserName'] as String? ?? '',
  );
}
