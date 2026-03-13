class PatientDetailModel {
  PatientDetailModel({
    required this.patientDataId,
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    required this.email,
    required this.address,
    required this.gender,
    required this.city,
    required this.birthDate,
    required this.createdDate,
    required this.imageName,
    required this.appUserId,
    required this.referenceTypeId,
    required this.referenceName,
    required this.isActive,
  });

  final int patientDataId;
  final String firstName;
  final String lastName;
  final int mobileNo;
  final String email;
  final String address;
  final String gender;
  final String city;
  final String birthDate;
  final String createdDate;
  final String imageName;
  final int appUserId;
  final int referenceTypeId;
  final String referenceName;
  final bool isActive;

  factory PatientDetailModel.fromJson(Map<String, dynamic> json) {
    return PatientDetailModel(
      patientDataId: json['patientDataId'] as int,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      mobileNo: (json['mobileNo'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      city: json['city'] as String? ?? '',
      birthDate: json['birthDate'] as String? ?? '',
      createdDate: json['createdDate'] as String? ?? '',
      imageName: json['imageName'] as String? ?? '',
      appUserId: json['appUserId'] as int? ?? 0,
      referenceTypeId: json['referenceTypeId'] as int? ?? 0,
      referenceName: json['referenceName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
