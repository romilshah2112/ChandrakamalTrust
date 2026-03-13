class SignUpRequestModel {
  SignUpRequestModel({
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.emailAddress,
    required this.password,
    required this.userRoleId,
  });

  final String firstName;
  final String lastName;
  final String mobileNumber;
  final String emailAddress;
  final String password;
  final int userRoleId;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'mobileNumber': mobileNumber,
      'emailAddress': emailAddress,
      'password': password,
      'userRoleId': userRoleId,
    };
  }
}
