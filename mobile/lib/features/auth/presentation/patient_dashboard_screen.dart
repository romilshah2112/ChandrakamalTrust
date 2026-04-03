import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/router.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/appointments/presentation/appointments_page.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/dashboard_home_content.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/profile_page.dart';
import 'package:optima_healthcare_mobile/features/patients/data/patient_repository.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_detail.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/my_patient_details_page.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/patient_analytics_page.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/patient_medical_records_page.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/patient_vitals_page.dart';
import 'package:optima_healthcare_mobile/shared/widgets/brand_logo.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _selectedNavIndex = 0;

  final _repo = PatientRepository();
  PatientDetailModel? _patientData;
  bool _patientDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _patientDataLoading = false);
      return;
    }
    try {
      final data = await _repo.getMyPatientDetails(accessToken: token);
      if (mounted) setState(() { _patientData = data; _patientDataLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _patientDataLoading = false);
    }
  }

  // ── Navigation helpers ──────────────────────────────────────────────────────

  void _closeDrawerAndDo(void Function() action) {
    Navigator.of(context).pop(); // close drawer
    action();
  }

  String get _patientFullName =>
      '${_patientData?.firstName ?? ''} ${_patientData?.lastName ?? ''}'.trim();

  /// Shows a SnackBar if patient data is still loading, otherwise runs [action].
  void _requirePatientData(void Function(PatientDetailModel data) action) {
    if (_patientDataLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading your data, please try again shortly.')),
      );
      return;
    }
    if (_patientData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load patient data. Please log out and log in again.')),
      );
      return;
    }
    action(_patientData!);
  }

  void _navigateToVitals() {
    _requirePatientData((data) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PatientVitalsPage(
          patientDataId: data.patientDataId,
          patientName: _patientFullName,
        ),
      ));
    });
  }

  void _navigateToMedicalRecords() {
    _requirePatientData((data) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PatientMedicalRecordsPage(
          patientDataId: data.patientDataId,
          patientName: _patientFullName,
          readOnly: true,
        ),
      ));
    });
  }

  void _navigateToAnalytics() {
    _requirePatientData((data) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PatientAnalyticsPage(
          patientDataId: data.patientDataId,
          patientName: _patientFullName,
          patientGender: data.gender,
          patientMobile: '${data.mobileNo}',
          patientCity: data.city,
          patientBirthDate: data.birthDate,
          readOnly: true,
        ),
      ));
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final firstName = AuthSession.firstName?.trim() ?? '';
    final lastName = AuthSession.lastName?.trim() ?? '';
    final fullName = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty ? fullName : (AuthSession.username ?? '');

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const BrandLogo(height: 44),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () => setState(() => _selectedNavIndex = 3),
          ),
          TextButton.icon(
            onPressed: () {
              AuthSession.clear();
              Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.login, (route) => false);
            },
            icon: Icon(Icons.logout, color: primary),
            label: Text('Logout', style: TextStyle(color: primary)),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName.isEmpty ? 'Patient' : displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Patient',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),

            // ── General ──────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () => _closeDrawerAndDo(
                  () => setState(() => _selectedNavIndex = 0)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Appointments'),
              onTap: () => _closeDrawerAndDo(
                  () => setState(() => _selectedNavIndex = 1)),
            ),

            // ── My Health ─────────────────────────────────────────────────────
            const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'MY HEALTH',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('My Vitals'),
              onTap: () => _closeDrawerAndDo(_navigateToVitals),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('My Health Records'),
              onTap: () => _closeDrawerAndDo(_navigateToMedicalRecords),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('My Health Analytics'),
              onTap: () => _closeDrawerAndDo(_navigateToAnalytics),
            ),
            ListTile(
              leading: const Icon(Icons.person_outlined),
              title: const Text('My Details'),
              onTap: () => _closeDrawerAndDo(
                  () => setState(() => _selectedNavIndex = 2)),
            ),

            // ── Account ───────────────────────────────────────────────────────
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Profile'),
              onTap: () => _closeDrawerAndDo(
                  () => setState(() => _selectedNavIndex = 3)),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          DashboardHomeContent(
            displayName: firstName.isNotEmpty ? firstName : displayName,
            welcomeSubtitle:
                'Your heart health is looking great. Keep up the good work!',
            quickActions: [
              QuickActionItem(
                icon: Icons.videocam,
                label: 'Video Call',
                color: primary,
                onTap: () {},
              ),
              QuickActionItem(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                color: AppTheme.accentGreen,
                onTap: () {},
              ),
              QuickActionItem(
                icon: Icons.description_outlined,
                label: 'Reports',
                color: AppTheme.accentOrange,
                onTap: () => _navigateToMedicalRecords(),
              ),
              QuickActionItem(
                icon: Icons.emergency,
                label: 'Emergency',
                color: primary,
                onTap: () {},
              ),
            ],
            viewProgressLabel: 'View Analytics',
            onViewProgress: () => _navigateToAnalytics(),
          ),
          const AppointmentsPage(),
          const MyPatientDetailsPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedNavIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'My Details',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
