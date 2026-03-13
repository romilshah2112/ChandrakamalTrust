class ClinicModel {
  ClinicModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.isActive,
  });

  final int id;
  final String name;
  final String address;
  final String city;
  final int phone;
  final String email;
  final bool isActive;

  factory ClinicModel.fromJson(Map<String, dynamic> json) => ClinicModel(
    id: json['clinicId'] as int,
    name: json['clinicName'] as String? ?? '',
    address: json['address'] as String? ?? '',
    city: json['city'] as String? ?? '',
    phone: json['phone'] as int? ?? 0,
    email: json['email'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? false,
  );
}
