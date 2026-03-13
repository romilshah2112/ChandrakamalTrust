import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/staff_dashboard_shell.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffDashboardShell(
      title: 'Doctor Dashboard',
    );
  }
}
