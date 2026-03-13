class UserProfileModel {
  UserProfileModel({
    required this.appUserId,
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.emailAddress,
    required this.profileImage,
    required this.userRoleId,
    required this.roleName,
  });

  final int appUserId;
  final String firstName;
  final String lastName;
  final int mobileNumber;
  final String emailAddress;
  final String profileImage;
  final int userRoleId;
  final String roleName;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      appUserId: json['appUserId'] as int,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as int? ?? 0,
      emailAddress: json['emailAddress'] as String? ?? '',
      profileImage: json['profileImage'] as String? ?? '',
      userRoleId: json['userRoleId'] as int? ?? 0,
      roleName: json['roleName'] as String? ?? '',
    );
  }
}
