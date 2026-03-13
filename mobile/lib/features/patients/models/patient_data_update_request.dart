class PatientDataUpdateRequestModel {
  PatientDataUpdateRequestModel({
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    required this.email,
    required this.address,
    required this.gender,
    required this.city,
    required this.birthDate,
    this.imageName,
    this.imageBase64,
    this.imageFileName,
    this.imageContentType,
    required this.referenceTypeId,
    required this.referenceName,
    required this.isActive,
  });

  final String firstName;
  final String lastName;
  final int mobileNo;
  final String email;
  final String address;
  final String gender;
  final String city;
  final String birthDate;
  final String? imageName;
  final String? imageBase64;
  final String? imageFileName;
  final String? imageContentType;
  final int referenceTypeId;
  final String referenceName;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'mobileNo': mobileNo,
      'email': email,
      'address': address,
      'gender': gender,
      'city': city,
      'birthDate': birthDate,
      'imageName': imageName,
      'imageBase64': imageBase64,
      'imageFileName': imageFileName,
      'imageContentType': imageContentType,
      'referenceTypeId': referenceTypeId,
      'referenceName': referenceName,
      'isActive': isActive,
    };
  }
}
