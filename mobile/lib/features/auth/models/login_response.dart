class LoginResponseModel {
  LoginResponseModel({
    required this.appUserId,
    required this.username,
    required this.accessToken,
    required this.expiresAtUtc,
    required this.role,
  });

  final int appUserId;
  final String username;
  final String accessToken;
  final DateTime expiresAtUtc;
  final String role;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      appUserId: json['appUserId'] as int,
      username: json['username'] as String,
      accessToken: json['accessToken'] as String,
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String),
      role: json['role'] as String,
    );
  }
}
