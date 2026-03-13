class UpdateUserProfileRequestModel {
  UpdateUserProfileRequestModel({
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.emailAddress,
    this.profileImage,
    this.imageBase64,
    this.imageFileName,
    this.imageContentType,
    this.newPassword,
  });

  final String firstName;
  final String lastName;
  final String mobileNumber;
  final String emailAddress;
  final String? profileImage;
  final String? imageBase64;
  final String? imageFileName;
  final String? imageContentType;
  final String? newPassword;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'mobileNumber': mobileNumber,
      'emailAddress': emailAddress,
      'profileImage': profileImage,
      'imageBase64': imageBase64,
      'imageFileName': imageFileName,
      'imageContentType': imageContentType,
      'newPassword': (newPassword == null || newPassword!.isEmpty)
          ? null
          : newPassword,
    };
  }
}
