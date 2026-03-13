import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/staff_dashboard_shell.dart';

class NurseDashboardScreen extends StatelessWidget {
  const NurseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffDashboardShell(
      title: 'Nurse Dashboard',
    );
  }
}
