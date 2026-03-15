class PatientInvoiceLineModel {
  PatientInvoiceLineModel({
    required this.invoiceDetailId,
    required this.invoiceTypeId,
    required this.invoiceTypeName,
    required this.invoiceAmount,
    required this.deduction,
  });

  final int invoiceDetailId;
  final int invoiceTypeId;
  final String invoiceTypeName;
  final double invoiceAmount;
  final double deduction;

  factory PatientInvoiceLineModel.fromJson(Map<String, dynamic> json) =>
      PatientInvoiceLineModel(
        invoiceDetailId: json['invoiceDetailId'] as int? ?? 0,
        invoiceTypeId: json['invoiceTypeId'] as int? ?? 0,
        invoiceTypeName: json['invoiceTypeName'] as String? ?? '',
        invoiceAmount: (json['invoiceAmount'] as num?)?.toDouble() ?? 0,
        deduction: (json['deduction'] as num?)?.toDouble() ?? 0,
      );
}

class PatientInvoiceModel {
  PatientInvoiceModel({
    required this.invoiceMasterId,
    required this.invoiceNumber,
    required this.patientDataId,
    required this.patientName,
    required this.patientBirthDate,
    required this.patientGender,
    required this.doctorProfileId,
    required this.doctorName,
    required this.doctorDegree,
    required this.doctorStream,
    required this.clinicId,
    required this.clinicName,
    required this.clinicAddress,
    required this.clinicPhone,
    required this.invoiceDate,
    required this.comments,
    required this.enteredById,
    required this.enteredOn,
    required this.isActive,
    required this.lines,
  });

  final int invoiceMasterId;
  final String invoiceNumber;
  final int patientDataId;
  final String patientName;
  final DateTime? patientBirthDate;
  final String patientGender;
  final int doctorProfileId;
  final String doctorName;
  final String doctorDegree;
  final String doctorStream;
  final int clinicId;
  final String clinicName;
  final String clinicAddress;
  final String clinicPhone;
  final DateTime invoiceDate;
  final String comments;
  final int enteredById;
  final DateTime enteredOn;
  final bool isActive;
  final List<PatientInvoiceLineModel> lines;

  factory PatientInvoiceModel.fromJson(Map<String, dynamic> json) =>
      PatientInvoiceModel(
        invoiceMasterId: json['invoiceMasterId'] as int? ?? 0,
        invoiceNumber: json['invoiceNumber'] as String? ?? '',
        patientDataId: json['patientDataId'] as int? ?? 0,
        patientName: json['patientName'] as String? ?? '',
        patientBirthDate: _tryParseDate(json['patientBirthDate'] as String?),
        patientGender: json['patientGender'] as String? ?? '',
        doctorProfileId: json['doctorProfileId'] as int? ?? 0,
        doctorName: json['doctorName'] as String? ?? '',
        doctorDegree: json['doctorDegree'] as String? ?? '',
        doctorStream: json['doctorStream'] as String? ?? '',
        clinicId: json['clinicId'] as int? ?? 0,
        clinicName: json['clinicName'] as String? ?? '',
        clinicAddress: json['clinicAddress'] as String? ?? '',
        clinicPhone: json['clinicPhone'] as String? ?? '',
        invoiceDate: DateTime.parse(json['invoiceDate'] as String).toLocal(),
        comments: json['comments'] as String? ?? '',
        enteredById: json['enteredById'] as int? ?? 0,
        enteredOn: DateTime.parse(json['enteredOn'] as String).toLocal(),
        isActive: json['isActive'] as bool? ?? false,
        lines: (json['lines'] as List<dynamic>? ?? const [])
            .map(
              (item) => PatientInvoiceLineModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  static DateTime? _tryParseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toLocal();
  }
}
