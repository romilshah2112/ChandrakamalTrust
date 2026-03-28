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
import 'package:url_launcher/url_launcher.dart';

class PatientMedicalRecordsPage extends StatefulWidget {
  const PatientMedicalRecordsPage({
    super.key,
    required this.patientDataId,
    required this.patientName,
  });

  final int patientDataId;
  final String patientName;

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
  int? _downloadingId;

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
      final list = await _repo.listPatientMedicalRecords(
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

  /// Inserts Cloudinary's fl_attachment flag (optionally with filename) so the
  /// browser prompts a file download rather than trying to render the URL.
  String _makeDownloadUrl(String url, String recordName) {
    const marker = '/upload/';
    final idx = url.indexOf(marker);
    if (idx == -1) return url;
    final insertAt = idx + marker.length;
    // Sanitise the suggested file name (Cloudinary rejects spaces/special chars)
    final safeName = recordName
        .replaceAll(RegExp(r'[^\w.\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final flag = 'fl_attachment:$safeName';
    return '${url.substring(0, insertAt)}$flag/${url.substring(insertAt)}';
  }

  Future<void> _downloadDocument(PatientMedicalRecordModel r) async {
    final uri = Uri.tryParse(_makeDownloadUrl(r.fileUrl.trim(), r.recordName));
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid document link.')),
        );
      }
      return;
    }

    setState(() => _downloadingId = r.id);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
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
      floatingActionButton: FloatingActionButton.extended(
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
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text('No documents yet. Tap Upload.'),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _records.length,
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            final isDownloading = _downloadingId == r.id;
                            return Card(
                              child: ListTile(
                                title: Text(r.recordName),
                                subtitle: Text(
                                  'Report: ${_formatIsoDate(r.reportDate)}\n'
                                  '${r.comments?.isNotEmpty == true ? r.comments! : 'No comments'}',
                                ),
                                isThreeLine: true,
                                trailing: isDownloading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.download),
                                        tooltip: 'Download document',
                                        onPressed: () =>
                                            _downloadDocument(r),
                                      ),
                                onTap: isDownloading
                                    ? null
                                    : () => _downloadDocument(r),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
