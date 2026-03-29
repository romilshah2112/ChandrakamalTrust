class RecordKeywordLookupModel {
  const RecordKeywordLookupModel({
    required this.id,
    required this.name,
    required this.description,
    this.idealLower,
    this.idealUpper,
  });

  final int id;
  final String name;
  final String description;
  final double? idealLower;
  final double? idealUpper;

  factory RecordKeywordLookupModel.fromJson(Map<String, dynamic> json) {
    double? toNullableDouble(dynamic value) =>
        value == null ? null : (value as num).toDouble();

    return RecordKeywordLookupModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      idealLower: toNullableDouble(json['idealLower']),
      idealUpper: toNullableDouble(json['idealUpper']),
    );
  }
}
