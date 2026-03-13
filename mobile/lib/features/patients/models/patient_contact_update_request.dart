class PatientContactUpdateRequestModel {
  PatientContactUpdateRequestModel({
    required this.mobileNo,
    required this.email,
    required this.address,
    required this.city,
  });

  final int mobileNo;
  final String email;
  final String address;
  final String city;

  Map<String, dynamic> toJson() {
    return {
      'mobileNo': mobileNo,
      'email': email,
      'address': address,
      'city': city,
    };
  }
}
