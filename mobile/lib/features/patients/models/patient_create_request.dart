class PatientCreateRequestModel {
  PatientCreateRequestModel({
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    required this.email,
    required this.address,
    required this.gender,
    required this.city,
    required this.birthDate,
    required this.password,
    required this.imageName,
    required this.imageBase64,
    required this.imageFileName,
    required this.imageContentType,
    required this.appUserId,
    required this.referenceTypeId,
    required this.referenceName,
  });

  final String firstName;
  final String lastName;
  final int mobileNo;
  final String email;
  final String address;
  final String gender;
  final String city;
  final String birthDate;
  final String password;
  final String? imageName;
  final String? imageBase64;
  final String? imageFileName;
  final String? imageContentType;
  final int appUserId;
  final int referenceTypeId;
  final String referenceName;

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
      'password': password,
      'imageName': imageName,
      'imageBase64': imageBase64,
      'imageFileName': imageFileName,
      'imageContentType': imageContentType,
      'appUserId': appUserId,
      'referenceTypeId': referenceTypeId,
      'referenceName': referenceName,
    };
  }
}
