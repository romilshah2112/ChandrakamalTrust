class InvoiceTypeModel {
  InvoiceTypeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.charges,
    required this.isActive,
  });

  final int id;
  final String name;
  final String description;
  final double charges;
  final bool isActive;

  factory InvoiceTypeModel.fromJson(Map<String, dynamic> json) =>
      InvoiceTypeModel(
        id: json['invoiceTypeId'] as int,
        name: json['invoiceTypeName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        charges: (json['charges'] as num?)?.toDouble() ?? 0,
        isActive: json['isActive'] as bool? ?? false,
      );
}
