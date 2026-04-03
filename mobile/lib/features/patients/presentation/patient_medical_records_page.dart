import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_medical_record_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/save_patient_medical_record_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/update_patient_medical_record_request.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/document_viewer_page.dart';

class PatientMedicalRecordsPage extends StatefulWidget {
  const PatientMedicalRecordsPage({
    super.key,
    required this.patientDataId,
    required this.patientName,
    this.readOnly = false,
  });

  final int patientDataId;
  final String patientName;
  /// When [readOnly] is true the page uses the patient self-access endpoints
  /// and hides upload / edit / delete controls.
  final bool readOnly;

  @override
  State<PatientMedicalRecordsPage> createState() =>
      _PatientMedicalRecordsPageState();
}

class _PatientMedicalRecordsPageState extends State<PatientMedicalRecordsPage> {
  static const int _maxBytes = 20 * 1024 * 1024;

  final _repo = PatientRepository();
  final _recordNameCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
  final _uploadFormKey = GlobalKey<FormState>();

  bool _loading = true;
  String? _error;
  List<PatientMedicalRecordModel> _records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recordNameCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
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
      final list = widget.readOnly
          ? await _repo.getMyMedicalRecords(accessToken: token)
          : await _repo.listPatientMedicalRecords(
              accessToken: token,
              patientDataId: widget.patientDataId,
            );
      if (!mounted) return;
      setState(() {
        _records = list;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (ex) {
      if (!mounted) return;
      setState(() {
        _error = ex.toString();
        _loading = false;
      });
    }
  }

  void _openViewer(PatientMedicalRecordModel r) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerPage(
          record: r,
          readOnly: widget.readOnly,
        ),
      ),
    );
  }

  String _formatIsoDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${l.day.toString().padLeft(2, '0')}-${months[l.month - 1]}-${l.year}';
  }

  Future<void> _showUploadSheet() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired.')),
        );
      }
      return;
    }

    List<LookupOptionModel> recordTypes = const [];
    try {
      recordTypes = await _repo.getRecordTypes(accessToken: token);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load record types. Try again.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    if (recordTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No record types available. Check RecordType table.'),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    _recordNameCtrl.clear();
    _commentsCtrl.clear();
    final recordNameCtrl = _recordNameCtrl;
    final commentsCtrl = _commentsCtrl;
    final formKey = _uploadFormKey;
    int? selectedTypeId = recordTypes.first.id;
    DateTime? reportDate = DateTime.now();
    Uint8List? fileBytes;
    String? fileName;
    String? contentType;
    bool uploading = false;
    String? sheetError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              Future<void> pickFile() async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const [
                    'jpg',
                    'jpeg',
                    'png',
                    'bmp',
                    'pdf',
                  ],
                  withData: true,
                );
                if (result == null || result.files.isEmpty) return;
                final f = result.files.single;
                final bytes = f.bytes;
                if (bytes == null || bytes.isEmpty) {
                  setSheet(() => sheetError = 'Could not read file.');
                  return;
                }
                if (bytes.length > _maxBytes) {
                  setSheet(
                    () => sheetError = 'File must be 20MB or smaller.',
                  );
                  return;
                }
                final name = f.name;
                final ext = name.contains('.')
                    ? name.substring(name.lastIndexOf('.'))
                    : '';
                setSheet(() {
                  fileBytes = bytes;
                  fileName = name;
                  contentType = _contentTypeForExtension(ext);
                  sheetError = null;
                });
              }

              Future<void> submit() async {
                if (!formKey.currentState!.validate()) return;
                if (reportDate == null) {
                  setSheet(() => sheetError = 'Select report date.');
                  return;
                }
                if (fileBytes == null || fileName == null) {
                  setSheet(() => sheetError = 'Choose a file.');
                  return;
                }
                final t = AuthSession.accessToken;
                if (t == null) return;

                setSheet(() {
                  uploading = true;
                  sheetError = null;
                });

                try {
                  await _repo.createPatientMedicalRecord(
                    accessToken: t,
                    patientDataId: widget.patientDataId,
                    request: SavePatientMedicalRecordRequestModel(
                      recordTypeId: selectedTypeId!,
                      recordName: recordNameCtrl.text.trim(),
                      fileBase64: base64Encode(fileBytes!),
                      fileName: fileName!,
                      contentType: contentType ?? 'application/octet-stream',
                      reportDate: reportDate!,
                      comments: commentsCtrl.text.trim().isEmpty
                          ? null
                          : commentsCtrl.text.trim(),
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Document uploaded.')),
                    );
                    _load();
                  }
                } on AuthException catch (e) {
                  setSheet(() {
                    uploading = false;
                    sheetError = e.message;
                  });
                } catch (e) {
                  setSheet(() {
                    uploading = false;
                    sheetError = e.toString();
                  });
                }
              }

              Future<void> pickReportDate() async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: reportDate ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setSheet(() => reportDate = picked);
                }
              }

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Upload medical record',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey<int?>(selectedTypeId),
                          initialValue: selectedTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Record type',
                            border: OutlineInputBorder(),
                          ),
                          items: recordTypes
                              .map(
                                (rt) => DropdownMenuItem(
                                  value: rt.id,
                                  child: Text(rt.name),
                                ),
                              )
                              .toList(),
                          onChanged: uploading
                              ? null
                              : (v) => setSheet(() => selectedTypeId = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: recordNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Record name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: uploading ? null : pickReportDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Report date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              reportDate == null
                                  ? 'Tap to select'
                                  : _formatIsoDate(
                                      reportDate!.toUtc().toIso8601String(),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: commentsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Comments (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: uploading ? null : pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            fileName == null ? 'Choose file' : fileName!,
                          ),
                        ),
                        const Text(
                          'JPG, PNG, BMP, or PDF — max 20MB',
                          style: TextStyle(fontSize: 12),
                        ),
                        if (sheetError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            sheetError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: uploading ? null : submit,
                          child: uploading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Upload'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

  }

  static String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.bmp':
        return 'image/bmp';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _editRecord(PatientMedicalRecordModel record) async {
    final token = AuthSession.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired.')),
      );
      return;
    }

    List<LookupOptionModel> recordTypes = const [];
    try {
      recordTypes = await _repo.getRecordTypes(accessToken: token);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load record types. Try again.')),
      );
      return;
    }

    if (!mounted || recordTypes.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    final recordNameCtrl = TextEditingController(text: record.recordName);
    final commentsCtrl = TextEditingController(text: record.comments ?? '');
    var selectedTypeId = record.recordTypeId;
    var reportDate = DateTime.tryParse(record.reportDate)?.toLocal() ?? DateTime.now();
    var saving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            Future<void> pickReportDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: reportDate,
                firstDate: DateTime(1900),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setDialog(() => reportDate = picked);
              }
            }

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;

              setDialog(() {
                saving = true;
                dialogError = null;
              });

              try {
                await _repo.updatePatientMedicalRecord(
                  accessToken: token,
                  patientDataId: widget.patientDataId,
                  recordId: record.patientMedicalRecordId,
                  request: UpdatePatientMedicalRecordRequestModel(
                    recordTypeId: selectedTypeId,
                    recordName: recordNameCtrl.text.trim(),
                    reportDate: reportDate,
                    comments: commentsCtrl.text.trim().isEmpty
                        ? null
                        : commentsCtrl.text.trim(),
                  ),
                );
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Document updated.')),
                );
                _load();
              } on AuthException catch (e) {
                setDialog(() {
                  saving = false;
                  dialogError = e.message;
                });
              } catch (e) {
                setDialog(() {
                  saving = false;
                  dialogError = e.toString();
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit document'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Record type',
                          border: OutlineInputBorder(),
                        ),
                        items: recordTypes
                            .map(
                              (rt) => DropdownMenuItem<int>(
                                value: rt.id,
                                child: Text(rt.name),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialog(() => selectedTypeId = value);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: recordNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Record name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Enter record name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: saving ? null : pickReportDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Report date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatIsoDate(reportDate.toUtc().toIso8601String())),
                              const Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: commentsCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comments',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    recordNameCtrl.dispose();
    commentsCtrl.dispose();
  }

  Future<void> _deleteRecord(PatientMedicalRecordModel record) async {
    final token = AuthSession.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Delete "${record.recordName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repo.deletePatientMedicalRecord(
        accessToken: token,
        patientDataId: widget.patientDataId,
        recordId: record.patientMedicalRecordId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted.')),
      );
      _load();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handleRecordAction(
    _MedicalRecordAction action,
    PatientMedicalRecordModel record,
  ) async {
    switch (action) {
      case _MedicalRecordAction.view:
        _openViewer(record);
        break;
      case _MedicalRecordAction.edit:
        await _editRecord(record);
        break;
      case _MedicalRecordAction.delete:
        await _deleteRecord(record);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medical records'),
            Text(
              widget.patientName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : _showUploadSheet,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                widget.readOnly
                                    ? 'No medical records found.'
                                    : 'No documents yet. Tap Upload.',
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _records.length,
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            final path =
                                Uri.tryParse(r.fileUrl)?.path.toLowerCase() ??
                                    r.fileUrl.toLowerCase();
                            final isImage = path.endsWith('.jpg') ||
                                path.endsWith('.jpeg') ||
                                path.endsWith('.png') ||
                                path.endsWith('.bmp');
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  isImage
                                      ? Icons.image_outlined
                                      : Icons.picture_as_pdf_outlined,
                                  color: isImage ? Colors.blue : Colors.red,
                                ),
                                title: Text(r.recordName),
                                subtitle: Text(
                                  'Report: ${_formatIsoDate(r.reportDate)}\n'
                                  '${r.comments?.isNotEmpty == true ? r.comments! : 'No comments'}',
                                ),
                                isThreeLine: true,
                                trailing: widget.readOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.open_in_new),
                                        tooltip: 'Open',
                                        onPressed: () => _openViewer(r),
                                      )
                                    : PopupMenuButton<_MedicalRecordAction>(
                                        onSelected: (action) =>
                                            _handleRecordAction(action, r),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: _MedicalRecordAction.view,
                                            child: Text('Open'),
                                          ),
                                          PopupMenuItem(
                                            value: _MedicalRecordAction.edit,
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem(
                                            value: _MedicalRecordAction.delete,
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                onTap: () => _openViewer(r),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

enum _MedicalRecordAction { view, edit, delete }
