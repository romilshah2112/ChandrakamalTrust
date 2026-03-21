class StaffModel {
  StaffModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.isActive,
    required this.appUserId,
  });

  final int id;
  final String name;
  final int mobile;
  final String email;
  final bool isActive;
  final int appUserId;

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
        id: json['staffId'] as int,
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as int? ?? 0,
        email: json['email'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
        appUserId: json['appUserId'] as int? ?? 0,
      );
}
