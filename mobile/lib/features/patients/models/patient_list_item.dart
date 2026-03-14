class PatientListItemModel {
  PatientListItemModel({
    required this.patientDataId,
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    required this.email,
    required this.imageName,
    required this.isActive,
  });

  final int patientDataId;
  final String firstName;
  final String lastName;
  final int mobileNo;
  final String email;
  final String imageName;
  final bool isActive;

  factory PatientListItemModel.fromJson(Map<String, dynamic> json) {
    return PatientListItemModel(
      patientDataId: json['patientDataId'] as int,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      mobileNo: json['mobileNo'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      imageName: json['imageName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
