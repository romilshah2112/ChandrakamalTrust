import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_contact_update_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_detail.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/patient_vitals_page.dart';

class MyPatientDetailsPage extends StatefulWidget {
  const MyPatientDetailsPage({super.key});

  @override
  State<MyPatientDetailsPage> createState() => _MyPatientDetailsPageState();
}

class _MyPatientDetailsPageState extends State<MyPatientDetailsPage> {
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
  String? _error;
  PatientDetailModel? _patient;

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

    try {
      final result = await _repo.getMyPatientDetails(accessToken: token);
      setState(() {
        _patient = result;
        _error = null;
      });
    } catch (ex) {
      setState(() {
        _error = ex.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _editContact() async {
    if (_patient == null) return;
    final token = AuthSession.accessToken;
    if (token == null) return;

    final mobileController = TextEditingController(text: '${_patient!.mobileNo}');
    final emailController = TextEditingController(text: _patient!.email);
    final addressController = TextEditingController(text: _patient!.address);
    final cityController = TextEditingController(text: _patient!.city);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? dialogError;
            bool saving = false;
            return AlertDialog(
              title: const Text('Update contact details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(dialogError!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final mobile = int.tryParse(mobileController.text.trim());
                          if (mobile == null) {
                            setDialogState(() => dialogError = 'Enter a valid mobile number.');
                            return;
                          }
                          if (emailController.text.trim().isEmpty) {
                            setDialogState(() => dialogError = 'Email is required.');
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            dialogError = null;
                          });
                          try {
                            await _repo.updateMyPatientContact(
                              accessToken: token,
                              request: PatientContactUpdateRequestModel(
                                mobileNo: mobile,
                                email: emailController.text.trim(),
                                address: addressController.text.trim(),
                                city: cityController.text.trim(),
                              ),
                            );
                            if (context.mounted) Navigator.of(context).pop(true);
                          } on AuthException catch (e) {
                            setDialogState(() {
                              dialogError = e.message;
                              saving = false;
                            });
                          } catch (_) {
                            setDialogState(() {
                              dialogError = 'Update failed.';
                              saving = false;
                            });
                          }
                        },
                  child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) _load();
  }

  Future<void> _openVitals() async {
    if (_patient == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PatientVitalsPage(
          patientDataId: _patient!.patientDataId,
          patientName: '${_patient!.firstName} ${_patient!.lastName}'.trim(),
        ),
      ),
    );
  }

  String? _normalizeRemoteImageUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    return trimmed;
  }

  Widget _buildProfileAvatar(PatientDetailModel patient) {
    final imageUrl = _normalizeRemoteImageUrl(patient.imageName);
    return Center(
      child: imageUrl != null
          ? CircleAvatar(
              radius: 52,
              backgroundImage: NetworkImage(imageUrl),
            )
          : const CircleAvatar(
              radius: 52,
              child: Icon(Icons.person, size: 42),
            ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) {
      return raw;
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = _monthNames[parsed.month - 1];
    final year = (parsed.year % 100).toString().padLeft(2, '0');
    return '$day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Details'),
        actions: [
          if (_patient != null) ...[
            IconButton(
              icon: const Icon(Icons.monitor_heart_outlined),
              tooltip: 'My vitals',
              onPressed: _loading ? null : _openVitals,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Update contact details',
              onPressed: _loading ? null : _editContact,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _patient == null
                  ? const Center(child: Text('No patient details found.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildProfileAvatar(_patient!),
                        const SizedBox(height: 16),
                        _item('Name', '${_patient!.firstName} ${_patient!.lastName}'),
                        _item('Mobile', '${_patient!.mobileNo}'),
                        _item('Email', _patient!.email),
                        _item('Address', _patient!.address),
                        _item('Gender', _patient!.gender),
                        _item('City', _patient!.city),
                        _item('Birth Date', _formatDate(_patient!.birthDate)),
                        _item('Created Date', _formatDate(_patient!.createdDate)),
                        _item('Reference', _patient!.referenceName),
                        _item('Active', _patient!.isActive ? 'Yes' : 'No'),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openVitals,
                              icon: const Icon(Icons.monitor_heart_outlined),
                              label: const Text('My vitals'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _editContact,
                              icon: const Icon(Icons.edit),
                              label: const Text('Update contact details'),
                            ),
                          ],
                        ),
                      ],
                    ),
    );
  }

  Widget _item(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
