class HealthCampModel {
  HealthCampModel({
    required this.id,
    required this.campName,
    required this.campDate,
    required this.location,
    required this.organizer,
    required this.description,
    required this.referenceTypeId,
    required this.isActive,
    required this.createdOn,
  });

  final int id;
  final String campName;
  final DateTime campDate;
  final String location;
  final String organizer;
  final String description;
  final int referenceTypeId;
  final bool isActive;
  final DateTime createdOn;

  factory HealthCampModel.fromJson(
    Map<String, dynamic> json,
  ) => HealthCampModel(
    id: json['healthCampId'] as int? ?? 0,
    campName: json['campName'] as String? ?? '',
    campDate:
        DateTime.tryParse(json['campDate'] as String? ?? '') ?? DateTime.now(),
    location: json['location'] as String? ?? '',
    organizer: json['organizer'] as String? ?? '',
    description: json['description'] as String? ?? '',
    referenceTypeId: json['referenceTypeId'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? false,
    createdOn:
        DateTime.tryParse(json['createdOn'] as String? ?? '') ?? DateTime.now(),
  );
}
