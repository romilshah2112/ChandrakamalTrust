class DoctorProfileModel {
  DoctorProfileModel({required this.id, required this.name, required this.clinicId, required this.phone, required this.email, required this.isActive});
  final int id;
  final String name;
  final int clinicId;
  final int phone;
  final String email;
  final bool isActive;

  factory DoctorProfileModel.fromJson(Map<String, dynamic> json) => DoctorProfileModel(
        id: json['doctorProfileId'] as int,
        name: json['doctorName'] as String? ?? '',
        clinicId: json['clinicId'] as int? ?? 0,
        phone: json['phone'] as int? ?? 0,
        email: json['email'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
      );
}
