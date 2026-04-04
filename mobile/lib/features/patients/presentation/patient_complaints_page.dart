import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_complaint_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_complaint_save_request.dart';

class PatientComplaintsPage extends StatefulWidget {
  const PatientComplaintsPage({
    super.key,
    required this.patientDataId,
    required this.patientName,
  });

  final int patientDataId;
  final String patientName;

  @override
  State<PatientComplaintsPage> createState() => _PatientComplaintsPageState();
}

class _PatientComplaintsPageState extends State<PatientComplaintsPage> {
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final _repo = PatientRepository();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PatientComplaintModel> _complaints = const [];
  List<LookupOptionModel> _severities = const [];

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
      final severities = await _repo.getComplaintSeverities(accessToken: token);
      final complaints = await _repo.listPatientComplaints(
        accessToken: token,
        patientDataId: widget.patientDataId,
      );
      if (!mounted) return;
      setState(() {
        _severities = severities;
        _complaints = complaints;
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

  Future<void> _showComplaintDialog({PatientComplaintModel? existing}) async {
    final formKey = GlobalKey<FormState>();
    final symptoms = TextEditingController(text: existing?.symptoms ?? '');
    int? severityId = (existing?.severityId ?? 0) > 0
        ? existing!.severityId
        : (_severities.isNotEmpty ? _severities.first.id : null);
    var isActive = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Complaint' : 'Update Complaint'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: symptoms,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Symptoms',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: severityId,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: _severities
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => severityId = value),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final token = AuthSession.accessToken;
                          if (token == null) {
                            if (!mounted) return;
                            setState(() => _error = 'Session expired. Please login again.');
                            Navigator.of(context).pop();
                            return;
                          }
                          final request = PatientComplaintSaveRequestModel(
                            patientDataId: widget.patientDataId,
                            symptoms: symptoms.text.trim(),
                            severityId: severityId!,
                            isActive: isActive,
                          );
                          setState(() {
                            _saving = true;
                            _error = null;
                          });
                          try {
                            if (existing == null) {
                              await _repo.createPatientComplaint(
                                accessToken: token,
                                patientDataId: widget.patientDataId,
                                request: request,
                              );
                            } else {
                              await _repo.updatePatientComplaint(
                                accessToken: token,
                                patientComplaintId: existing.patientComplaintId,
                                request: request,
                              );
                            }
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop(true);
                          } on AuthException catch (ex) {
                            if (!mounted) return;
                            setState(() => _error = ex.message);
                          } catch (ex) {
                            if (!mounted) return;
                            setState(() => _error = ex.toString());
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(existing == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    symptoms.dispose();

    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'Complaint saved successfully.'
              : 'Complaint updated successfully.'),
        ),
      );
    }
  }

  Future<void> _deleteComplaint(PatientComplaintModel complaint) async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _error = 'Session expired. Please login again.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete complaint?'),
        content: const Text('This will remove this complaint entry from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.deletePatientComplaint(
        accessToken: token,
        patientComplaintId: complaint.patientComplaintId,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Complaint deleted.')));
    } on AuthException catch (ex) {
      if (!mounted) return;
      setState(() => _error = ex.message);
    } catch (ex) {
      if (!mounted) return;
      setState(() => _error = ex.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatRecordedOn(DateTime value) {
    final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    final day = ist.day.toString().padLeft(2, '0');
    final month = _monthNames[ist.month - 1];
    final year = (ist.year % 100).toString().padLeft(2, '0');
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final period = ist.hour >= 12 ? 'PM' : 'AM';
    return '$day-$month-$year $hour:$minute $period IST';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.patientName} - Complaints')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving || _severities.isEmpty
            ? null
            : () => _showComplaintDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Complaint'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _complaints.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sick_outlined, size: 56),
                            const SizedBox(height: 12),
                            const Text('No complaints recorded yet.'),
                            const SizedBox(height: 8),
                            Text(
                              'Add symptoms and severity for ${widget.patientName}.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _complaints.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _complaints[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.sick_outlined),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Recorded on ${_formatRecordedOn(item.insertedOn)}',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showComplaintDialog(existing: item);
                                          } else if (value == 'delete') {
                                            _deleteComplaint(item);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    item.symptoms,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _tagChip('Severity', item.severity),
                                      _tagChip(
                                        'Status',
                                        item.isActive ? 'Active' : 'Inactive',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _tagChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
