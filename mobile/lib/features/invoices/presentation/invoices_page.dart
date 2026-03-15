import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optima_healthcare_mobile/features/admin/models/invoice_type_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/invoices/data/invoice_repository.dart';
import 'package:optima_healthcare_mobile/features/invoices/models/patient_invoice_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _repo = InvoiceRepository();

  bool _loading = true;
  String? _error;
  List<PatientInvoiceModel> _invoices = const [];
  List<LookupOptionModel> _patients = const [];
  List<LookupOptionModel> _doctors = const [];
  List<LookupOptionModel> _clinics = const [];
  List<InvoiceTypeModel> _invoiceTypes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invoices = await _repo.listInvoices(accessToken: token);
      final patients = await _repo.listPatientLookup(accessToken: token);
      final doctors = await _repo.listDoctorLookup(accessToken: token);
      final clinics = await _repo.listClinicLookup(accessToken: token);
      final invoiceTypes = await _repo.listInvoiceTypeLookup(accessToken: token);
      setState(() {
        _invoices = invoices;
        _patients = patients;
        _doctors = doctors;
        _clinics = clinics;
        _invoiceTypes = invoiceTypes;
      });
    } catch (ex) {
      setState(() {
        _error = ex.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInvoiceDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : RefreshIndicator(
              onRefresh: _load,
              child: _invoices.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No invoices found.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _invoices.length,
                      itemBuilder: (context, index) => _invoiceCard(_invoices[index]),
                    ),
            ),
    );
  }

  Widget _invoiceCard(PatientInvoiceModel invoice) {
    final total = _invoiceTotal(invoice);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Text(invoice.invoiceNumber),
        subtitle: Text(
          '${_fmtShortDate(invoice.invoiceDate)} | Patient: ${invoice.patientName}\nDoctor: ${invoice.doctorName} | Clinic: ${invoice.clinicName}\nTotal: ${total.toStringAsFixed(2)}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<_InvoiceAction>(
          onSelected: (action) async {
            switch (action) {
              case _InvoiceAction.print:
                await _printInvoice(invoice);
                break;
              case _InvoiceAction.share:
                await _shareInvoice(invoice);
                break;
              case _InvoiceAction.edit:
                await _showInvoiceDialog(existing: invoice);
                break;
              case _InvoiceAction.delete:
                await _confirmDelete(invoice.invoiceMasterId);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _InvoiceAction.print,
              child: ListTile(
                leading: Icon(Icons.print_outlined),
                title: Text('Print'),
              ),
            ),
            PopupMenuItem(
              value: _InvoiceAction.share,
              child: ListTile(
                leading: Icon(Icons.share_outlined),
                title: Text('Share'),
              ),
            ),
            PopupMenuItem(
              value: _InvoiceAction.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
              ),
            ),
            PopupMenuItem(
              value: _InvoiceAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoice(PatientInvoiceModel invoice) async {
    try {
      final bytes = await _buildInvoicePdf(invoice);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (ex) {
      _showError(ex.toString());
    }
  }

  Future<void> _shareInvoice(PatientInvoiceModel invoice) async {
    try {
      final bytes = await _buildInvoicePdf(invoice);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${invoice.invoiceNumber}.pdf',
      );
    } catch (ex) {
      _showError(ex.toString());
    }
  }

  Future<Uint8List> _buildInvoicePdf(PatientInvoiceModel invoice) async {
    final doc = pw.Document();
    final logo = await _loadLogoBytes();
    final total = _invoiceTotal(invoice);
    final doctorTitle = _doctorTitle(invoice);
    final patientAge = _ageText(invoice.patientBirthDate);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Container(
                  width: 74,
                  height: 74,
                  margin: const pw.EdgeInsets.only(right: 16),
                  child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      invoice.clinicName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      doctorTitle,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Address: ${invoice.clinicAddress}'),
                    pw.Text('Phone: ${invoice.clinicPhone}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Bill No: ${invoice.invoiceNumber}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Date: ${_fmtLongDate(invoice.invoiceDate)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Patient Details'),
          pw.SizedBox(height: 8),
          pw.Text('Patient Name: ${invoice.patientName}'),
          pw.Text('Age/Gender: $patientAge / ${invoice.patientGender.isEmpty ? '-' : invoice.patientGender}'),
          pw.Text('Patient ID: ${_patientIdLabel(invoice.patientDataId)}'),
          pw.SizedBox(height: 18),
          _sectionTitle('Consultation Details'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.8),
            columnWidths: const {
              0: pw.FixedColumnWidth(40),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableCell('Sr', bold: true),
                  _tableCell('Description', bold: true),
                  _tableCell('Amount (Rs)', bold: true, alignRight: true),
                ],
              ),
              ...invoice.lines.asMap().entries.map((entry) {
                final line = entry.value;
                final lineAmount = line.invoiceAmount - line.deduction;
                final description = line.deduction > 0
                    ? '${line.invoiceTypeName} (Deduction: Rs ${line.deduction.toStringAsFixed(2)})'
                    : line.invoiceTypeName;
                return pw.TableRow(
                  children: [
                    _tableCell('${entry.key + 1}'),
                    _tableCell(description),
                    _tableCell(
                      lineAmount.toStringAsFixed(2),
                      alignRight: true,
                    ),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _tableCell(''),
                  _tableCell('Total Amount', bold: true),
                  _tableCell(total.toStringAsFixed(2), bold: true, alignRight: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Payment Information'),
          pw.SizedBox(height: 8),
          pw.Text('Payment Mode: Cash / UPI / Card'),
          pw.Text('Amount Paid: Rs ${total.toStringAsFixed(2)}'),
          pw.SizedBox(height: 18),
          _sectionTitle('Notes'),
          pw.SizedBox(height: 8),
          pw.Text('This bill is issued for medical consultation services.'),
          if (invoice.comments.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Comments: ${invoice.comments.trim()}'),
          ],
          pw.SizedBox(height: 36),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(width: 160, height: 1, color: PdfColors.grey700),
                pw.SizedBox(height: 6),
                pw.Text('Doctor Signature'),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List?> _loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/padam_logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  double _invoiceTotal(PatientInvoiceModel invoice) {
    return invoice.lines.fold<double>(
      0,
      (sum, line) => sum + line.invoiceAmount - line.deduction,
    );
  }

  String _doctorTitle(PatientInvoiceModel invoice) {
    final parts = [
      invoice.doctorName.trim(),
      invoice.doctorDegree.trim(),
      invoice.doctorStream.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(' ');
  }

  String _ageText(DateTime? birthDate) {
    if (birthDate == null) {
      return '-';
    }

    final today = DateTime.now();
    var years = today.year - birthDate.year;
    final birthdayReached = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayReached) {
      years -= 1;
    }
    return years < 0 ? '-' : years.toString();
  }

  String _patientIdLabel(int patientDataId) => '000$patientDataId';

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _tableCell(
    String value, {
    bool bold = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _showInvoiceDialog({PatientInvoiceModel? existing}) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    if (_patients.isEmpty || _doctors.isEmpty || _clinics.isEmpty || _invoiceTypes.isEmpty) {
      _showError('Required lookups are not available.');
      return;
    }

    final invoiceNumber = existing?.invoiceNumber ??
        await _repo.getNextInvoiceNumber(accessToken: token);
    var selectedPatientId = _pickValidId(_patients, existing?.patientDataId);
    var selectedDoctorId = _pickValidId(_doctors, existing?.doctorProfileId);
    var selectedClinicId = _pickValidId(_clinics, existing?.clinicId);
    final comments = TextEditingController(text: existing?.comments ?? '');
    var invoiceDate = existing?.invoiceDate ?? DateTime.now();
    final rows = (existing?.lines ?? const <PatientInvoiceLineModel>[])
        .map(
          (line) => _InvoiceEditorLine(
            invoiceTypeId: line.invoiceTypeId,
            amount: line.invoiceAmount.toStringAsFixed(2),
            deduction: line.deduction.toStringAsFixed(2),
          ),
        )
        .toList();
    if (rows.isEmpty) {
      rows.add(
        _InvoiceEditorLine(
          invoiceTypeId: _invoiceTypes.first.id,
          amount: _invoiceTypes.first.charges.toStringAsFixed(2),
          deduction: '0',
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Add Invoice' : 'Update Invoice',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Invoice No: $invoiceNumber'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _dropdownField(
                            label: 'Patient',
                            value: selectedPatientId,
                            options: _patients,
                            onChanged: (value) =>
                                setLocalState(() => selectedPatientId = value),
                          ),
                          const SizedBox(height: 10),
                          _dropdownField(
                            label: 'Doctor',
                            value: selectedDoctorId,
                            options: _doctors,
                            onChanged: (value) =>
                                setLocalState(() => selectedDoctorId = value),
                          ),
                          const SizedBox(height: 10),
                          _dropdownField(
                            label: 'Clinic',
                            value: selectedClinicId,
                            options: _clinics,
                            onChanged: (value) =>
                                setLocalState(() => selectedClinicId = value),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Invoice Date'),
                            subtitle: Text(_fmtShortDate(invoiceDate)),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: invoiceDate,
                                firstDate: DateTime(2020, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (picked != null) {
                                setLocalState(() => invoiceDate = picked);
                              }
                            },
                          ),
                          TextField(
                            controller: comments,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Comments',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Invoice Items',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setLocalState(() {
                                    final firstType = _invoiceTypes.first;
                                    rows.add(
                                      _InvoiceEditorLine(
                                        invoiceTypeId: firstType.id,
                                        amount: firstType.charges.toStringAsFixed(2),
                                        deduction: '0',
                                      ),
                                    );
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...rows.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            return _invoiceLineCard(
                              index: index,
                              row: row,
                              setLocalState: setLocalState,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final activeRows = rows
                              .where((row) => !row.markDeleted)
                              .toList();
                          if (activeRows.isEmpty) {
                            _showError('Add at least one invoice item.');
                            return;
                          }

                          final lines = activeRows.map((row) {
                            return {
                              'invoiceTypeId': row.invoiceTypeId,
                              'invoiceAmount': double.tryParse(row.amountController.text.trim()) ?? 0,
                              'deduction': double.tryParse(row.deductionController.text.trim()) ?? 0,
                            };
                          }).toList();

                          await _runAction(() async {
                            await _repo.saveInvoice(
                              accessToken: token,
                              id: existing?.invoiceMasterId,
                              body: {
                                'patientDataId': selectedPatientId,
                                'doctorProfileId': selectedDoctorId,
                                'clinicId': selectedClinicId,
                                'invoiceDate': invoiceDate.toIso8601String(),
                                'comments': comments.text.trim(),
                                'lines': lines,
                              },
                            );
                            await _load();
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _invoiceLineCard({
    required int index,
    required _InvoiceEditorLine row,
    required void Function(void Function()) setLocalState,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: row.invoiceTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _invoiceTypes
                        .map(
                          (type) => DropdownMenuItem<int>(
                            value: type.id,
                            child: Text(type.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final selected = _invoiceTypes.firstWhere((type) => type.id == value);
                      setLocalState(() {
                        row.invoiceTypeId = value;
                        row.amountController.text = selected.charges.toStringAsFixed(2);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setLocalState(() {
                      row.markDeleted = true;
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (row.markDeleted)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('This item will be removed.', style: TextStyle(color: Colors.red)),
              )
            else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Invoice Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: row.deductionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Deduction',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required int value,
    required List<LookupOptionModel> options,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: options
          .map((option) => DropdownMenuItem<int>(value: option.id, child: Text(option.name)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }

  int _pickValidId(List<LookupOptionModel> options, int? requestedId) {
    if (options.isEmpty) return 0;
    if (requestedId != null && options.any((item) => item.id == requestedId)) {
      return requestedId;
    }
    return options.first.id;
  }

  Future<void> _confirmDelete(int id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (yes != true) return;
    final token = AuthSession.accessToken;
    if (token == null) return;
    await _runAction(() async {
      await _repo.deleteInvoice(accessToken: token, id: id);
      await _load();
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (ex) {
      _showError(ex.toString());
    }
  }

  void _showError(String raw) {
    final message = raw.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmtShortDate(DateTime value) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${value.day.toString().padLeft(2, '0')}-${months[value.month - 1]}-${(value.year % 100).toString().padLeft(2, '0')}';
  }

  String _fmtLongDate(DateTime value) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${value.day.toString().padLeft(2, '0')}-${months[value.month - 1]}-${value.year}';
  }
}

class _InvoiceEditorLine {
  _InvoiceEditorLine({
    required this.invoiceTypeId,
    required String amount,
    required String deduction,
  })  : amountController = TextEditingController(text: amount),
        deductionController = TextEditingController(text: deduction);

  int invoiceTypeId;
  final TextEditingController amountController;
  final TextEditingController deductionController;
  bool markDeleted = false;
}

enum _InvoiceAction { print, share, edit, delete }
