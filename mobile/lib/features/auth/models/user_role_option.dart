class UserRoleOptionModel {
  UserRoleOptionModel({
    required this.userRoleId,
    required this.roleName,
  });

  final int userRoleId;
  final String roleName;

  factory UserRoleOptionModel.fromJson(Map<String, dynamic> json) {
    return UserRoleOptionModel(
      userRoleId: json['userRoleId'] as int,
      roleName: json['roleName'] as String,
    );
  }
}
