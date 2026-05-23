import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/router.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/appointments/presentation/appointments_page.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/dashboard_home_content.dart';
import 'package:optima_healthcare_mobile/features/doctor_analytics/presentation/doctor_home_overview.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/profile_page.dart';
import 'package:optima_healthcare_mobile/shared/widgets/brand_logo.dart';

class StaffDashboardShell extends StatefulWidget {
  const StaffDashboardShell({
    super.key,
    required this.title,
    this.showAdminMasters = false,
  });

  final String title;
  final bool showAdminMasters;

  @override
  State<StaffDashboardShell> createState() => _StaffDashboardShellState();
}

class _StaffDashboardShellState extends State<StaffDashboardShell> {
  int _selectedNavIndex = 0;

  static String _roleDisplayName(String? role) {
    if (role == null || role.isEmpty) return 'Staff';
    final r = role.toLowerCase();
    if (r.contains('admin')) return 'Admin';
    if (r.contains('doctor')) return 'Doctor';
    if (r.contains('receptionist')) return 'Receptionist';
    if (r.contains('nurse')) return 'Nurse';
    return role;
  }

  bool _showStaffAnalytics(String role) {
    final normalized = role.toLowerCase();
    return normalized.contains('receptionist') || normalized.contains('staff');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final role = AuthSession.role ?? '';
    final firstName = AuthSession.firstName?.trim() ?? '';
    final lastName = AuthSession.lastName?.trim() ?? '';
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty
        ? fullName
        : (AuthSession.username ?? '');
    final roleLabel = _roleDisplayName(role);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const BrandLogo(height: 44),
        actions: [
          if (role.toLowerCase().contains('doctor'))
            IconButton(
              icon: const Icon(Icons.insights_outlined),
              tooltip: 'Analytics',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.doctorAnalytics),
            ),
          if (_showStaffAnalytics(role))
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: 'Patient Analytics',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.staffAnalytics),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () => _goToProfile(),
          ),
          TextButton.icon(
            onPressed: () {
              AuthSession.clear();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
            },
            icon: Icon(Icons.logout, color: primary),
            label: Text('Logout', style: TextStyle(color: primary)),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
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
                    displayName.isEmpty ? 'User' : displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    roleLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedNavIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('New Patient'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(AppRouter.newPatient);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('View Patients'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(AppRouter.viewPatients);
              },
            ),
            if (_showStaffAnalytics(role))
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined),
                title: const Text('Patient Analytics'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.staffAnalytics);
                },
              ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Appointments'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedNavIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Invoices'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(AppRouter.invoices);
              },
            ),
            if (role.toLowerCase().contains('doctor'))
              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: const Text('Consultation'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.consultation);
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                _goToProfile();
              },
            ),
            if (widget.showAdminMasters) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.local_hospital_outlined),
                title: const Text('Clinic'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.clinicMaster);
                },
              ),
              ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: const Text('Doctor'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.doctorMaster);
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Staff'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.staffMaster);
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Clinic Schedule'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(
                    context,
                  ).pushNamed(AppRouter.clinicScheduleMaster);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Invoice Type'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.invoiceTypeMaster);
                },
              ),
              ListTile(
                leading: const Icon(Icons.diversity_1_outlined),
                title: const Text('Health Camp'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRouter.healthCampMaster);
                },
              ),
            ],
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          DashboardHomeContent(
            displayName: firstName.isNotEmpty ? firstName : displayName,
            welcomeSubtitle:
                'Use quick actions or the menu to manage patients and appointments.',
            supplementarySections: role.toLowerCase().contains('doctor')
                ? const [DoctorHomeOverview()]
                : const [],
            quickActions: [
              QuickActionItem(
                icon: Icons.person_add_alt_1,
                label: 'New Patient',
                color: primary,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.newPatient),
              ),
              QuickActionItem(
                icon: Icons.people,
                label: 'View Patients',
                color: AppTheme.accentGreen,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.viewPatients),
              ),
              if (_showStaffAnalytics(role))
                QuickActionItem(
                  icon: Icons.bar_chart,
                  label: 'Analytics',
                  color: AppTheme.accentGreen,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.staffAnalytics),
                ),
              QuickActionItem(
                icon: Icons.calendar_month,
                label: 'Appointments',
                color: AppTheme.accentOrange,
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
              QuickActionItem(
                icon: Icons.receipt_long,
                label: 'Invoices',
                color: primary,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.invoices),
              ),
              QuickActionItem(
                icon: Icons.emergency,
                label: 'Emergency',
                color: primary,
                onTap: () {}, // placeholder
              ),
              if (role.toLowerCase().contains('doctor'))
                QuickActionItem(
                  icon: Icons.record_voice_over,
                  label: 'Consultation',
                  color: AppTheme.accentGreen,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRouter.consultation),
                ),
            ],
            viewProgressLabel: 'View Appointments',
            onViewProgress: () => setState(() => _selectedNavIndex = 1),
          ),
          const AppointmentsPage(),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _goToProfile() {
    setState(() => _selectedNavIndex = 2);
  }
}
