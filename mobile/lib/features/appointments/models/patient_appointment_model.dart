class PatientAppointmentModel {
  PatientAppointmentModel({
    required this.patientAppointmentId,
    required this.patientDataId,
    required this.patientName,
    required this.doctorProfileId,
    required this.doctorName,
    required this.clinicId,
    required this.clinicName,
    required this.startTime,
    required this.endTime,
    required this.appointmentStatusId,
    this.appointmentTypeId,
    this.appointmentTypeName,
    required this.isNotified,
    required this.isActive,
    required this.enteredById,
  });

  final int patientAppointmentId;
  final int patientDataId;
  final String patientName;
  final int doctorProfileId;
  final String doctorName;
  final int clinicId;
  final String clinicName;
  final DateTime startTime;
  final DateTime endTime;
  final int appointmentStatusId;
  final int? appointmentTypeId;
  final String? appointmentTypeName;
  final int isNotified;
  final bool isActive;
  final int enteredById;

  factory PatientAppointmentModel.fromJson(Map<String, dynamic> json) {
    return PatientAppointmentModel(
      patientAppointmentId: json['patientAppointmentId'] as int,
      patientDataId: json['patientDataId'] as int? ?? 0,
      patientName: json['patientName'] as String? ?? '',
      doctorProfileId: json['doctorProfileId'] as int? ?? 0,
      doctorName: json['doctorName'] as String? ?? '',
      clinicId: json['clinicId'] as int? ?? 0,
      clinicName: json['clinicName'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      appointmentStatusId: json['appointmentStatusId'] as int? ?? 0,
      appointmentTypeId: json['appointmentTypeId'] as int?,
      appointmentTypeName: json['appointmentTypeName'] as String?,
      isNotified: json['isNotified'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      enteredById: json['enteredById'] as int? ?? 0,
    );
  }
}
