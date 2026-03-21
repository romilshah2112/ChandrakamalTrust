import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_vitals_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_vitals_save_request.dart';

class PatientVitalsPage extends StatefulWidget {
  const PatientVitalsPage({
    super.key,
    required this.patientDataId,
    required this.patientName,
  });

  final int patientDataId;
  final String patientName;

  @override
  State<PatientVitalsPage> createState() => _PatientVitalsPageState();
}

class _PatientVitalsPageState extends State<PatientVitalsPage> {
  static const List<String> _monthNames = [
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

  final _repo = PatientRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PatientVitalsModel> _vitals = const [];

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
      final list = await _repo.listPatientVitals(
        accessToken: token,
        patientDataId: widget.patientDataId,
      );
      if (!mounted) return;
      setState(() {
        _vitals = list;
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

  Future<void> _showVitalsDialog({PatientVitalsModel? existing}) async {
    final latest = existing == null && _vitals.isNotEmpty ? _vitals.first : null;
    final formKey = GlobalKey<FormState>();
    final bpSys = TextEditingController(text: existing?.bpSys.toString() ?? '');
    final bpDys = TextEditingController(text: existing?.bpDys.toString() ?? '');
    final pulse = TextEditingController(text: existing?.pulse.toString() ?? '');
    final weightKg = TextEditingController(
      text: existing?.weightKg.toString() ?? latest?.weightKg.toString() ?? '',
    );
    final heightCms = TextEditingController(
      text: existing?.heightCms.toString() ?? latest?.heightCms.toString() ?? '',
    );
    var isActive = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Vitals' : 'Update Vitals'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _numberField(controller: bpSys, label: 'BP Systolic'),
                      const SizedBox(height: 12),
                      _numberField(controller: bpDys, label: 'BP Diastolic'),
                      const SizedBox(height: 12),
                      _numberField(controller: pulse, label: 'Pulse'),
                      const SizedBox(height: 12),
                      _numberField(controller: weightKg, label: 'Weight (kg)'),
                      const SizedBox(height: 12),
                      _numberField(controller: heightCms, label: 'Height (cm)'),
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
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final token = AuthSession.accessToken;
                          if (token == null) {
                            if (!mounted) return;
                            setState(() {
                              _error = 'Session expired. Please login again.';
                            });
                            Navigator.of(context).pop();
                            return;
                          }

                          final request = PatientVitalsSaveRequestModel(
                            patientDataId: widget.patientDataId,
                            bpSys: int.parse(bpSys.text.trim()),
                            bpDys: int.parse(bpDys.text.trim()),
                            pulse: int.parse(pulse.text.trim()),
                            weightKg: int.parse(weightKg.text.trim()),
                            heightCms: int.parse(heightCms.text.trim()),
                            isActive: isActive,
                          );

                          setState(() {
                            _saving = true;
                            _error = null;
                          });

                          try {
                            if (existing == null) {
                              await _repo.createPatientVitals(
                                accessToken: token,
                                patientDataId: widget.patientDataId,
                                request: request,
                              );
                            } else {
                              await _repo.updatePatientVitals(
                                accessToken: token,
                                patientVitalsId: existing.patientVitalsId,
                                request: request,
                              );
                            }

                            if (!mounted) return;
                            Navigator.of(context).pop(true);
                          } on AuthException catch (ex) {
                            if (!mounted) return;
                            setState(() => _error = ex.message);
                          } catch (ex) {
                            if (!mounted) return;
                            setState(() => _error = ex.toString());
                          } finally {
                            if (mounted) {
                              setState(() => _saving = false);
                            }
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

    bpSys.dispose();
    bpDys.dispose();
    pulse.dispose();
    weightKg.dispose();
    heightCms.dispose();

    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Patient vitals saved successfully.'
                : 'Patient vitals updated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteVitals(PatientVitalsModel vitals) async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() {
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vitals?'),
        content: const Text('This will remove this vitals entry from the list.'),
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

    if (confirm != true) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repo.deletePatientVitals(
        accessToken: token,
        patientVitalsId: vitals.patientVitalsId,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient vitals deleted.')));
    } on AuthException catch (ex) {
      if (!mounted) return;
      setState(() => _error = ex.message);
    } catch (ex) {
      if (!mounted) return;
      setState(() => _error = ex.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return 'Required';
        }

        final parsed = int.tryParse(trimmed);
        if (parsed == null || parsed <= 0) {
          return 'Enter a valid number';
        }

        return null;
      },
    );
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
      appBar: AppBar(
        title: Text('${widget.patientName} Vitals'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _showVitalsDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Vitals'),
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
          : _vitals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monitor_heart_outlined, size: 56),
                    const SizedBox(height: 12),
                    const Text('No vitals recorded yet.'),
                    const SizedBox(height: 8),
                    Text(
                      'Add blood pressure, pulse, weight, and height for ${widget.patientName}.',
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
                itemCount: _vitals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _vitals[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monitor_heart, color: Colors.red),
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
                                    _showVitalsDialog(existing: item);
                                  } else if (value == 'delete') {
                                    _deleteVitals(item);
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
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _metricChip('BP', '${item.bpSys}/${item.bpDys}'),
                              _metricChip('Pulse', '${item.pulse} bpm'),
                              _metricChip('Weight', '${item.weightKg} kg'),
                              _metricChip('Height', '${item.heightCms} cm'),
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

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
