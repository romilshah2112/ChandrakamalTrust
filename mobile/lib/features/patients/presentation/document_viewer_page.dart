import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/core/utils/download_helper.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_medical_record_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_record_detail_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/record_keyword_lookup_model.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({super.key, required this.record});

  final PatientMedicalRecordModel record;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage>
    with SingleTickerProviderStateMixin {
  final _repo = PatientRepository();

  late final TabController _tabController;

  Uint8List? _bytes;
  String? _fetchError;
  bool _loadingDocument = true;

  List<PatientRecordDetailModel> _ocrDetails = const [];
  final Map<int, TextEditingController> _readingControllers = {};
  List<RecordKeywordLookupModel> _recordKeywords = const [];
  String? _ocrError;
  bool _loadingOcr = true;
  bool _loadingKeywords = true;
  bool _savingOcr = false;

  bool _actioning = false;
  bool _ocrSaved = false;
  bool _loadedFromSavedDetails = false;

  bool get _isImage {
    final path = Uri.tryParse(widget.record.fileUrl)?.path.toLowerCase() ??
        widget.record.fileUrl.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.bmp');
  }

  String get _fileName {
    final safe = widget.record.recordName
        .replaceAll(RegExp(r'[^\w.\- ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return _isImage ? '$safe.jpg' : '$safe.pdf';
  }

  String get _mimeType => _isImage ? 'image/jpeg' : 'application/pdf';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDocument();
    _fetchRecordKeywords();
    _fetchOcrPreview();
  }

  @override
  void dispose() {
    for (final controller in _readingControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}-${_months[l.month - 1]}-${l.year}';
  }

  Future<void> _fetchDocument() async {
    setState(() {
      _loadingDocument = true;
      _fetchError = null;
    });

    try {
      final token = AuthSession.accessToken;
      if (token == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final raw = await _repo.downloadMedicalRecordFile(
        accessToken: token,
        patientDataId: widget.record.patientDataId,
        recordId: widget.record.patientMedicalRecordId,
      );

      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(raw);
        _loadingDocument = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Could not load document: $e';
        _loadingDocument = false;
      });
    }
  }

  Future<void> _fetchRecordKeywords() async {
    setState(() => _loadingKeywords = true);

    try {
      final token = AuthSession.accessToken;
      if (token == null) {
        throw const AuthException('Session expired. Please log in again.');
      }

      final keywords = await _repo.getRecordKeywords(accessToken: token);
      if (!mounted) return;
      setState(() {
        _recordKeywords = keywords;
        _loadingKeywords = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingKeywords = false;
        _ocrError ??= e.toString();
      });
    }
  }

  Future<void> _fetchOcrPreview() async {
    setState(() {
      _loadingOcr = true;
      _ocrError = null;
      _ocrSaved = false;
    });

    try {
      final token = AuthSession.accessToken;
      if (token == null) {
        throw const AuthException('Session expired. Please log in again.');
      }

      final details = await _repo.listPatientRecordDetails(
        accessToken: token,
        patientDataId: widget.record.patientDataId,
        recordId: widget.record.patientMedicalRecordId,
      );

      if (!mounted) return;
      final loadedFromSavedDetails = details.any(
        (detail) => detail.patientRecordDetailId > 0,
      );
      setState(() {
        _ocrDetails = details;
        _loadedFromSavedDetails = loadedFromSavedDetails;
        _syncReadingControllers();
        _loadingOcr = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrError = e.toString();
        _loadingOcr = false;
      });
    }
  }

  void _syncReadingControllers() {
    final activeIds = _ocrDetails.map((detail) => detail.recordKeywordId).toSet();
    final staleIds = _readingControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();

    for (final id in staleIds) {
      _readingControllers.remove(id)?.dispose();
    }

    for (final detail in _ocrDetails) {
      final controller = _readingControllers.putIfAbsent(
        detail.recordKeywordId,
        () => TextEditingController(),
      );

      final nextText = _formatEditableReading(detail.readingValue);
      if (controller.text != nextText) {
        controller.text = nextText;
      }
    }
  }

  String _formatEditableReading(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  void _updateReading(int recordKeywordId, String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return;
    }

    setState(() {
      _ocrSaved = false;
      _ocrDetails = _ocrDetails
          .map(
            (detail) => detail.recordKeywordId == recordKeywordId
                ? detail.copyWith(readingValue: parsed)
                : detail,
          )
          .toList(growable: false);
    });
  }

  void _removeDetail(int recordKeywordId) {
    setState(() {
      _ocrSaved = false;
      _ocrDetails = _ocrDetails
          .where((detail) => detail.recordKeywordId != recordKeywordId)
          .toList(growable: false);
      _readingControllers.remove(recordKeywordId)?.dispose();
    });
  }

  Future<void> _showAddDetailDialog() async {
    if (_loadingKeywords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading keyword list. Please wait.')),
      );
      return;
    }

    if (_recordKeywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No record keywords available.')),
      );
      return;
    }

    final existingIds = _ocrDetails.map((detail) => detail.recordKeywordId).toSet();
    final availableKeywords = _recordKeywords
        .where((item) => !existingIds.contains(item.id))
        .toList(growable: false);

    if (availableKeywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All available keywords are already added.')),
      );
      return;
    }

    RecordKeywordLookupModel selectedKeyword = availableKeywords.first;
    final readingController = TextEditingController();

    final added = await showDialog<PatientRecordDetailModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Keyword / Reading'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedKeyword.id,
                    decoration: const InputDecoration(
                      labelText: 'Keyword',
                      border: OutlineInputBorder(),
                    ),
                    items: availableKeywords
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedKeyword = availableKeywords.firstWhere(
                          (item) => item.id == value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: readingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Reading',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (selectedKeyword.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      selectedKeyword.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reading = double.tryParse(readingController.text.trim());
                    if (reading == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid numeric reading.'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop(
                      PatientRecordDetailModel(
                        patientRecordDetailId: 0,
                        patientMedicalRecordId:
                            widget.record.patientMedicalRecordId,
                        patientNameInRecord: _ocrDetails.isNotEmpty
                            ? _ocrDetails.first.patientNameInRecord
                            : '',
                        recordKeywordId: selectedKeyword.id,
                        keyword: selectedKeyword.name,
                        description: selectedKeyword.description,
                        readingValue: reading,
                        idealLower: selectedKeyword.idealLower,
                        idealUpper: selectedKeyword.idealUpper,
                        reportDateTime: widget.record.reportDate,
                      ),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    readingController.dispose();

    if (added == null || !mounted) {
      return;
    }

    setState(() {
      _ocrSaved = false;
      _ocrDetails = [..._ocrDetails, added];
      _syncReadingControllers();
    });
  }

  Future<void> _saveOcrDetails() async {
    if (_ocrDetails.isEmpty || _savingOcr) return;

    final token = AuthSession.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired.')),
      );
      return;
    }

    for (final detail in _ocrDetails) {
      final controller = _readingControllers[detail.recordKeywordId];
      final parsed = double.tryParse(controller?.text.trim() ?? '');
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid reading for ${detail.keyword}.')),
        );
        return;
      }
    }

    final patientNameInRecord = _ocrDetails.isNotEmpty
        ? _ocrDetails.first.patientNameInRecord
        : '';

    setState(() => _savingOcr = true);
    try {
      await _repo.savePatientRecordDetails(
        accessToken: token,
        patientDataId: widget.record.patientDataId,
        recordId: widget.record.patientMedicalRecordId,
        patientNameInRecord: patientNameInRecord,
        details: _ocrDetails,
        reportDateTime: widget.record.reportDate,
      );

      if (!mounted) return;
      setState(() {
        _savingOcr = false;
        _ocrSaved = true;
        _loadedFromSavedDetails = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extracted values saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingOcr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null || _actioning) return;

    setState(() => _actioning = true);
    try {
      if (kIsWeb) {
        await triggerDownload(bytes, _fileName);
      } else {
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: _fileName, mimeType: _mimeType)],
          subject: widget.record.recordName,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _actioning = false);
      }
    }
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null || _actioning) return;

    setState(() => _actioning = true);
    try {
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: _fileName, mimeType: _mimeType)],
        subject: widget.record.recordName,
      );
    } catch (_) {
      if (kIsWeb) {
        await triggerDownload(bytes, _fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'File downloaded - attach it in WhatsApp or Email manually.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _actioning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Scaffold(
      appBar: AppBar(
        title: Text(record.recordName, overflow: TextOverflow.ellipsis),
        actions: _actioning
            ? const [
                Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: _bytes == null ? null : _share,
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download',
                  onPressed: _bytes == null ? null : _download,
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Document'),
            Tab(text: 'Extracted Values'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 20,
              runSpacing: 4,
              children: [
                _chip(Icons.calendar_today, 'Report: ${_fmtDate(record.reportDate)}'),
                _chip(Icons.upload, 'Uploaded: ${_fmtDate(record.uploadedOn)}'),
                if (record.comments != null && record.comments!.isNotEmpty)
                  _chip(Icons.comment, record.comments!),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDocumentTab(),
                _buildExtractedValuesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _buildDocumentTab() {
    if (_loadingDocument) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document...'),
          ],
        ),
      );
    }

    if (_fetchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_fetchError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _fetchDocument,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = _bytes!;
    return _isImage ? _buildImageViewer(bytes) : _buildPdfViewer(bytes);
  }

  Widget _buildExtractedValuesTab() {
    if (_loadingOcr || _loadingKeywords) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing extracted values...'),
          ],
        ),
      );
    }

    if (_ocrError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_ocrError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _fetchOcrPreview,
                child: const Text('Retry OCR'),
              ),
            ],
          ),
        ),
      );
    }

    final patientName = _ocrDetails.isNotEmpty
        ? _ocrDetails.first.patientNameInRecord
        : '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loadedFromSavedDetails
                          ? 'Edit or delete saved values, then save changes.'
                          : 'Review and correct values before saving.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (patientName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Patient in report: $patientName',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (_ocrSaved)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _loadedFromSavedDetails
                              ? 'Changes saved to PatientRecordDetail.'
                              : 'Saved to PatientRecordDetail.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showAddDetailDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Row'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _savingOcr || _ocrDetails.isEmpty ? null : _saveOcrDetails,
                icon: _savingOcr
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _savingOcr
                      ? 'Saving'
                      : (_loadedFromSavedDetails ? 'Save Changes' : 'Save'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_ocrDetails.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.playlist_add_check_circle_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No extracted rows yet. Use Add Row to enter values manually.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showAddDetailDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Row'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Keyword')),
                    DataColumn(label: Text('Reading')),
                    DataColumn(label: Text('Ideal Range')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _ocrDetails
                      .map(
                        (detail) => DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  detail.keyword,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller:
                                      _readingControllers[detail.recordKeywordId],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: false,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) => _updateReading(
                                    detail.recordKeywordId,
                                    value,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(_formatRange(detail))),
                            DataCell(
                              IconButton(
                                onPressed: () =>
                                    _removeDetail(detail.recordKeywordId),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove row',
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatRange(PatientRecordDetailModel detail) {
    final lower = detail.idealLower;
    final upper = detail.idealUpper;
    if (lower == null && upper == null) {
      return '-';
    }

    final lowerText = lower == null ? '' : _formatEditableReading(lower);
    final upperText = upper == null ? '' : _formatEditableReading(upper);
    return '$lowerText - $upperText'.trim();
  }

  Widget _buildImageViewer(Uint8List bytes) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 8,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('Image could not be displayed.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer(Uint8List bytes) {
    return PdfPreview(
      build: (_) => bytes,
      actions: const [],
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      maxPageWidth: 900,
    );
  }
}
