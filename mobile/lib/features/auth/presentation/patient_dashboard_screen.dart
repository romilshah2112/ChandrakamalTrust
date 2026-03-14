import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/router.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';
import 'package:optima_healthcare_mobile/features/appointments/presentation/appointments_page.dart';
import 'package:optima_healthcare_mobile/features/auth/models/auth_session.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/dashboard_home_content.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/profile_page.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/my_patient_details_page.dart';
import 'package:optima_healthcare_mobile/shared/widgets/brand_logo.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final firstName = AuthSession.firstName?.trim() ?? '';
    final lastName = AuthSession.lastName?.trim() ?? '';
    final fullName = [firstName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final displayName = fullName.isNotEmpty
        ? fullName
        : (AuthSession.username ?? '');

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
              Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
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
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
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
              leading: const Icon(Icons.person),
              title: const Text('My Patient Details'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedNavIndex = 2);
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
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedNavIndex = 3);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          DashboardHomeContent(
            displayName: firstName.isNotEmpty ? firstName : displayName,
            welcomeSubtitle: 'Your heart health is looking great. Keep up the good work!',
            quickActions: [
              QuickActionItem(
                icon: Icons.videocam,
                label: 'Video Call',
                color: primary,
                onTap: () {}, // placeholder
              ),
              QuickActionItem(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                color: AppTheme.accentGreen,
                onTap: () {}, // placeholder
              ),
              QuickActionItem(
                icon: Icons.description_outlined,
                label: 'Reports',
                color: AppTheme.accentOrange,
                onTap: () {}, // placeholder
              ),
              QuickActionItem(
                icon: Icons.emergency,
                label: 'Emergency',
                color: primary,
                onTap: () {}, // placeholder
              ),
            ],
            viewProgressLabel: 'View Progress',
            onViewProgress: () => setState(() => _selectedNavIndex = 2),
          ),
          const AppointmentsPage(),
          const MyPatientDetailsPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) => setState(() => _selectedNavIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'My Details',
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
}
