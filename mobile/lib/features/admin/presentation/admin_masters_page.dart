import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/admin/data/admin_master_repository.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_schedule_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/doctor_profile_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/staff_model.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';

class ClinicMasterPage extends StatelessWidget {
  const ClinicMasterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminMastersPage(initialTab: 0, showTabs: false);
}

class DoctorMasterPage extends StatelessWidget {
  const DoctorMasterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminMastersPage(initialTab: 1, showTabs: false);
}

class StaffMasterPage extends StatelessWidget {
  const StaffMasterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminMastersPage(initialTab: 2, showTabs: false);
}

class ClinicScheduleMasterPage extends StatelessWidget {
  const ClinicScheduleMasterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminMastersPage(initialTab: 3, showTabs: false);
}

class AdminMastersPage extends StatefulWidget {
  const AdminMastersPage({
    super.key,
    this.initialTab = 0,
    this.showTabs = true,
  });

  final int initialTab;
  final bool showTabs;

  @override
  State<AdminMastersPage> createState() => _AdminMastersPageState();
}

class _AdminMastersPageState extends State<AdminMastersPage>
    with SingleTickerProviderStateMixin {
  final _repo = AdminMasterRepository();
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<ClinicModel> _clinics = const [];
  List<DoctorProfileModel> _doctors = const [];
  List<StaffModel> _staff = const [];
  List<ClinicScheduleModel> _clinicSchedules = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      final clinics = await _repo.listClinics(token);
      final doctors = await _repo.listDoctorProfiles(token);
      final staff = await _repo.listStaff(token);
      final schedules = await _repo.listClinicSchedules(token);
      setState(() {
        _clinics = clinics;
        _doctors = doctors;
        _staff = staff;
        _clinicSchedules = schedules;
      });
    } catch (ex) {
      setState(() {
        _error = _humanizeError(ex.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _humanizeError(String raw) {
    if (raw.contains('409')) {
      return 'Delete blocked due to linked records. Deactivate dependent records first.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  String _entityTitle() {
    switch (_tabController.index) {
      case 0:
        return 'Clinic';
      case 1:
        return 'Doctor';
      case 2:
        return 'Staff';
      default:
        return 'Clinic Schedule';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showTabs
              ? 'Master Data Management'
              : '${_entityTitle()} Management',
        ),
        bottom: widget.showTabs
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Clinic'),
                  Tab(text: 'Doctor'),
                  Tab(text: 'Staff'),
                  Tab(text: 'Clinic Schedule'),
                ],
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        icon: const Icon(Icons.add),
        label: Text('Add ${_entityTitle()}'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : widget.showTabs
            ? TabBarView(
                controller: _tabController,
                children: [
                  _clinicList(),
                  _doctorList(),
                  _staffList(),
                  _clinicScheduleList(),
                ],
              )
            : _singleList(),
      ),
    );
  }

  Widget _singleList() {
    switch (_tabController.index) {
      case 0:
        return _clinicList();
      case 1:
        return _doctorList();
      case 2:
        return _staffList();
      default:
        return _clinicScheduleList();
    }
  }

  void _onAdd() {
    if (_tabController.index == 0) {
      _showClinicDialog();
    } else if (_tabController.index == 1) {
      _showDoctorDialog();
    } else if (_tabController.index == 2) {
      _showStaffDialog();
    } else {
      _showClinicScheduleDialog();
    }
  }

  Widget _clinicList() {
    if (_clinics.isEmpty) return _emptyCard('No clinics found.');
    return ListView.builder(
      itemCount: _clinics.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final c = _clinics[index];
        return _masterCard(
          icon: Icons.local_hospital,
          title: c.name,
          subtitle: '${c.address} | ${c.city} | ${c.phone} | ${c.email}',
          isActive: c.isActive,
          onEdit: () => _showClinicDialog(existing: c),
          onDelete: () => _confirmDelete('clinic', () => _deleteClinic(c.id)),
        );
      },
    );
  }

  Widget _doctorList() {
    if (_doctors.isEmpty) return _emptyCard('No doctor profiles found.');
    return ListView.builder(
      itemCount: _doctors.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final d = _doctors[index];
        return _masterCard(
          icon: Icons.medical_services,
          title: d.name,
          subtitle: 'Clinic: ${d.clinicId} | ${d.phone} | ${d.email}',
          isActive: d.isActive,
          onEdit: () => _showDoctorDialog(existing: d),
          onDelete: () =>
              _confirmDelete('doctor profile', () => _deleteDoctor(d.id)),
        );
      },
    );
  }

  Widget _staffList() {
    if (_staff.isEmpty) return _emptyCard('No staff found.');
    return ListView.builder(
      itemCount: _staff.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final s = _staff[index];
        return _masterCard(
          icon: Icons.badge,
          title: s.name,
          subtitle: '${s.mobile} | ${s.email}',
          isActive: s.isActive,
          onEdit: () => _showStaffDialog(existing: s),
          onDelete: () =>
              _confirmDelete('staff record', () => _deleteStaff(s.id)),
        );
      },
    );
  }

  Widget _clinicScheduleList() {
    if (_clinicSchedules.isEmpty) {
      return _emptyCard('No clinic schedules found.');
    }
    return ListView.builder(
      itemCount: _clinicSchedules.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final s = _clinicSchedules[index];
        final clinicName = _clinicName(s.clinicId);
        final timing = s.isClosed
            ? 'Closed'
            : '${_formatTimeForDisplay(s.openTime)} - ${_formatTimeForDisplay(s.closeTime)}';
        return _masterCard(
          icon: Icons.schedule,
          title: '$clinicName | ${_dayLabel(s.dayOfWeek)}',
          subtitle: '$timing | AppUser: ${s.appUserId}',
          isActive: true,
          onEdit: () => _showClinicScheduleDialog(existing: s),
          onDelete: () => _confirmDelete(
            'clinic schedule',
            () => _deleteClinicSchedule(s.id),
          ),
        );
      },
    );
  }

  Widget _masterCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(isActive ? 'Active' : 'Inactive'),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: isActive
                  ? Colors.green.withValues(alpha: 0.14)
                  : Colors.grey.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(message),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    String entity,
    Future<void> Function() onConfirm,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delete'),
        content: Text(
          'Delete this $entity? This will be blocked when dependent data exists.',
        ),
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

    if (yes == true) {
      await _runAction(onConfirm);
    }
  }

  Future<void> _showClinicDialog({ClinicModel? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    final phone = TextEditingController(
      text: existing == null ? '' : '${existing.phone}',
    );
    final email = TextEditingController(text: existing?.email ?? '');

    await _showStyledDialog(
      title: existing == null ? 'Add Clinic' : 'Update Clinic',
      children: [
        _styledField(name, 'Clinic Name', Icons.local_hospital),
        _styledField(address, 'Address', Icons.home_outlined),
        _styledField(city, 'City', Icons.location_city),
        _styledField(phone, 'Phone', Icons.phone, numeric: true),
        _styledField(email, 'Email', Icons.email),
      ],
      onSave: () async {
        final token = AuthSession.accessToken;
        if (token == null) return;
        await _repo.saveClinic(token, {
          'clinicName': name.text,
          'address': address.text,
          'city': city.text,
          'zip': '',
          'state': '',
          'countryId': 1,
          'phone': int.tryParse(phone.text) ?? 0,
          'email': email.text,
          'photo': null,
          'isActive': true,
        }, id: existing?.id);
        await _load();
      },
    );
  }

  Future<void> _showDoctorDialog({DoctorProfileModel? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final clinicId = TextEditingController(
      text: existing == null ? '1' : '${existing.clinicId}',
    );
    final phone = TextEditingController(
      text: existing == null ? '' : '${existing.phone}',
    );
    final email = TextEditingController(text: existing?.email ?? '');

    await _showStyledDialog(
      title: existing == null ? 'Add Doctor' : 'Update Doctor',
      children: [
        _styledField(name, 'Doctor Name', Icons.person),
        _styledField(clinicId, 'Clinic Id', Icons.account_tree, numeric: true),
        _styledField(phone, 'Phone', Icons.phone, numeric: true),
        _styledField(email, 'Email', Icons.email),
      ],
      onSave: () async {
        final token = AuthSession.accessToken;
        if (token == null) return;
        await _repo.saveDoctorProfile(token, {
          'doctorName': name.text,
          'doctorDegree': '',
          'doctorStream': '',
          'clinicId': int.tryParse(clinicId.text) ?? 1,
          'doctorCity': '',
          'countryId': 1,
          'phone': int.tryParse(phone.text) ?? 0,
          'email': email.text,
          'gender': '',
          'photo': null,
          'isActive': true,
          'appUserId': AuthSession.appUserId ?? 0,
        }, id: existing?.id);
        await _load();
      },
    );
  }

  Future<void> _showStaffDialog({StaffModel? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final mobile = TextEditingController(
      text: existing == null ? '' : '${existing.mobile}',
    );
    final email = TextEditingController(text: existing?.email ?? '');

    await _showStyledDialog(
      title: existing == null ? 'Add Staff' : 'Update Staff',
      children: [
        _styledField(name, 'Name', Icons.person_outline),
        _styledField(mobile, 'Mobile', Icons.phone_android, numeric: true),
        _styledField(email, 'Email', Icons.email_outlined),
      ],
      onSave: () async {
        final token = AuthSession.accessToken;
        if (token == null) return;
        await _repo.saveStaff(token, {
          'name': name.text,
          'qualification': '',
          'mobile': int.tryParse(mobile.text) ?? 0,
          'email': email.text,
          'gender': '',
          'address': '',
          'photo': null,
          'enteredById': AuthSession.appUserId ?? 0,
          'appUserId': AuthSession.appUserId ?? 0,
          'isActive': true,
        }, id: existing?.id);
        await _load();
      },
    );
  }

  Future<void> _showClinicScheduleDialog({
    ClinicScheduleModel? existing,
  }) async {
    if (_clinics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least one clinic first.'),
        ),
      );
      return;
    }

    var selectedClinicId = existing?.clinicId ?? _clinics.first.id;
    var selectedDay = existing?.dayOfWeek ?? 1;
    var isClosed = existing?.isClosed ?? false;
    final openTime = TextEditingController(
      text: _formatTimeForInput(existing?.openTime),
    );
    final closeTime = TextEditingController(
      text: _formatTimeForInput(existing?.closeTime),
    );

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null
                        ? 'Add Clinic Schedule'
                        : 'Update Clinic Schedule',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedClinicId,
                            decoration: InputDecoration(
                              labelText: 'Clinic',
                              prefixIcon: const Icon(
                                Icons.local_hospital_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                            ),
                            items: _clinics
                                .map(
                                  (clinic) => DropdownMenuItem<int>(
                                    value: clinic.id,
                                    child: Text(clinic.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() => selectedClinicId = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDay,
                            decoration: InputDecoration(
                              labelText: 'Day of Week',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                            ),
                            items: List.generate(7, (index) {
                              final day = index + 1;
                              return DropdownMenuItem<int>(
                                value: day,
                                child: Text(_dayLabel(day)),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() => selectedDay = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            value: isClosed,
                            title: const Text('Clinic Closed'),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) {
                              setStateDialog(() => isClosed = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          if (!isClosed) ...[
                            _styledField(
                              openTime,
                              'Open Time (HH:mm)',
                              Icons.access_time,
                            ),
                            _styledField(
                              closeTime,
                              'Close Time (HH:mm)',
                              Icons.access_time_filled,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                          await _runAction(() async {
                            final token = AuthSession.accessToken;
                            if (token == null) return;

                            final cleanOpen = openTime.text.trim();
                            final cleanClose = closeTime.text.trim();

                            await _repo.saveClinicSchedule(token, {
                              'clinicId': selectedClinicId,
                              'dayOfWeek': selectedDay,
                              'openTime': isClosed
                                  ? null
                                  : (cleanOpen.isEmpty ? null : cleanOpen),
                              'closeTime': isClosed
                                  ? null
                                  : (cleanClose.isEmpty ? null : cleanClose),
                              'isClosed': isClosed,
                              'appUserId': AuthSession.appUserId ?? 0,
                            }, id: existing?.id);
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

  Widget _styledField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Future<void> _showStyledDialog({
    required String title,
    required List<Widget> children,
    required Future<void> Function() onSave,
  }) async {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(children: children),
                  ),
                ),
                const SizedBox(height: 6),
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
                        await _runAction(onSave);
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
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(ex.toString()))));
    }
  }

  String _clinicName(int clinicId) {
    for (final clinic in _clinics) {
      if (clinic.id == clinicId) {
        return clinic.name;
      }
    }
    return 'Clinic #';
  }

  String _dayLabel(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Day $dayOfWeek';
    }
  }

  String _formatTimeForInput(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hh = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatTimeForDisplay(String? value) {
    final input = _formatTimeForInput(value);
    return input.isEmpty ? '-' : input;
  }

  Future<void> _deleteClinic(int id) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await _repo.deleteClinic(token, id);
    await _load();
  }

  Future<void> _deleteDoctor(int id) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await _repo.deleteDoctorProfile(token, id);
    await _load();
  }

  Future<void> _deleteStaff(int id) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await _repo.deleteStaff(token, id);
    await _load();
  }

  Future<void> _deleteClinicSchedule(int id) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await _repo.deleteClinicSchedule(token, id);
    await _load();
  }
}
