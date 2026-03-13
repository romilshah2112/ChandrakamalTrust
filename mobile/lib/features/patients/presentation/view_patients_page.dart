import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_list_item.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/patient_detail_page.dart';

class ViewPatientsPage extends StatefulWidget {
  const ViewPatientsPage({super.key});

  @override
  State<ViewPatientsPage> createState() => _ViewPatientsPageState();
}

class _ViewPatientsPageState extends State<ViewPatientsPage> {
  final _repo = PatientRepository();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<PatientListItemModel> _patients = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final list = await _repo.listPatients(
        accessToken: token,
        query: _searchController.text.trim(),
      );
      setState(() {
        _patients = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Patients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by name, mobile, email',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _patients.isEmpty
                        ? const Center(child: Text('No patients found.'))
                        : ListView.builder(
                            itemCount: _patients.length,
                            itemBuilder: (context, index) {
                              final p = _patients[index];
                              return Card(
                                child: ListTile(
                                  title: Text('${p.firstName} ${p.lastName}'),
                                  subtitle: Text('${p.mobileNo} | ${p.email}'),
                                  trailing: Text(p.isActive ? 'Active' : 'Inactive'),
                                  onTap: () async {
                                    final deleted = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute<bool>(
                                        builder: (context) => PatientDetailPage(patientDataId: p.patientDataId),
                                      ),
                                    );
                                    if (deleted == true && mounted) _load();
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
