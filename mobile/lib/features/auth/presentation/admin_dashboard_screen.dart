import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/staff_dashboard_shell.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffDashboardShell(
      title: 'Admin Dashboard',
      showAdminMasters: true,
    );
  }
}
