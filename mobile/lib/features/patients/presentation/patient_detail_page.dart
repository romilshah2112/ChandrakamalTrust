import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/patient_edit_page.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_detail.dart';

class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({super.key, required this.patientDataId});

  final int patientDataId;

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final _repo = PatientRepository();
  bool _loading = true;
  String? _error;
  PatientDetailModel? _patient;
  bool _deleting = false;

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
      final result = await _repo.getPatientById(
        accessToken: token,
        patientDataId: widget.patientDataId,
      );
      if (mounted) {
        setState(() {
          _patient = result;
          _loading = false;
        });
      }
    } catch (ex) {
      if (mounted) {
        setState(() {
          _error = ex.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final token = AuthSession.accessToken;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete patient?'),
        content: const Text(
          'This cannot be undone. If this patient has appointments, delete will be blocked.',
        ),
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

    if (confirm != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await _repo.deletePatient(
        accessToken: token,
        patientDataId: widget.patientDataId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _deleting = false;
        });
      }
    } catch (ex) {
      if (mounted) {
        setState(() {
          _error = ex.toString();
          _deleting = false;
        });
      }
    }
  }

  Future<void> _navigateToEdit() async {
    if (_patient == null) return;
    final token = AuthSession.accessToken;
    if (token == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => PatientEditPage(
          patientDataId: widget.patientDataId,
          patient: _patient!,
        ),
      ),
    );
    if (updated == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient details'),
        actions: [
          if (_patient != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: _loading || _deleting ? null : _navigateToEdit,
            ),
            IconButton(
              icon: _deleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _loading || _deleting ? null : _delete,
            ),
          ],
        ],
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
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : _patient == null
                  ? const Center(child: Text('Patient not found.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _item('Name', '${_patient!.firstName} ${_patient!.lastName}'),
                        _item('Mobile', '${_patient!.mobileNo}'),
                        _item('Email', _patient!.email),
                        _item('Address', _patient!.address),
                        _item('Gender', _patient!.gender),
                        _item('City', _patient!.city),
                        _item('Birth Date', _patient!.birthDate),
                        _item('Created Date', _patient!.createdDate),
                        _item('Reference', _patient!.referenceName),
                        _item('Active', _patient!.isActive ? 'Yes' : 'No'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _navigateToEdit,
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: _deleting ? null : _delete,
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              icon: _deleting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete),
                              label: const Text('Delete'),
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
