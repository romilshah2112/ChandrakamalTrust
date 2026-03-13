import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/features/admin/presentation/admin_masters_page.dart';
import 'package:optima_healthcare_mobile/features/appointments/presentation/appointments_page.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/admin_dashboard_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/doctor_dashboard_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/login_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/nurse_dashboard_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/patient_dashboard_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/profile_page.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/receptionist_dashboard_screen.dart';
import 'package:optima_healthcare_mobile/features/auth/presentation/user_dashboard_screen.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/my_patient_details_page.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/new_patient_page.dart';
import 'package:optima_healthcare_mobile/features/patients/presentation/view_patients_page.dart';
import 'package:optima_healthcare_mobile/features/consultation/presentation/consultation_page.dart';

class AppRouter {
  static const String login = '/';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String adminDashboard = '/admin-dashboard';
  static const String doctorDashboard = '/doctor-dashboard';
  static const String nurseDashboard = '/nurse-dashboard';
  static const String receptionistDashboard = '/receptionist-dashboard';
  static const String patientDashboard = '/patient-dashboard';
  static const String userDashboard = '/user-dashboard';
  static const String newPatient = '/new-patient';
  static const String viewPatients = '/view-patients';
  static const String myPatientDetails = '/my-patient-details';
  static const String profile = '/profile';
  static const String appointments = '/appointments';
  static const String adminMasters = '/admin-masters';
  static const String clinicMaster = '/master-clinic';
  static const String doctorMaster = '/master-doctor';
  static const String staffMaster = '/master-staff';
  static const String clinicScheduleMaster = '/master-clinic-schedule';
  static const String consultation = '/consultation';

  static Map<String, WidgetBuilder> get routes => {
    login: (_) => const LoginScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    resetPassword: (_) => const ResetPasswordScreen(),
    adminDashboard: (_) => const AdminDashboardScreen(),
    doctorDashboard: (_) => const DoctorDashboardScreen(),
    nurseDashboard: (_) => const NurseDashboardScreen(),
    receptionistDashboard: (_) => const ReceptionistDashboardScreen(),
    patientDashboard: (_) => const PatientDashboardScreen(),
    userDashboard: (_) => const UserDashboardScreen(),
    newPatient: (_) => const NewPatientPage(),
    viewPatients: (_) => const ViewPatientsPage(),
    myPatientDetails: (_) => const MyPatientDetailsPage(),
    profile: (_) => const ProfilePage(),
    appointments: (_) => const AppointmentsPage(),
    adminMasters: (_) => const AdminMastersPage(),
    clinicMaster: (_) => const ClinicMasterPage(),
    doctorMaster: (_) => const DoctorMasterPage(),
    staffMaster: (_) => const StaffMasterPage(),
    clinicScheduleMaster: (_) => const ClinicScheduleMasterPage(),
    consultation: (_) => const ConsultationPage(),
  };

  static String routeForRole(String role) {
    final normalizedRole = role.toLowerCase();

    if (normalizedRole.contains('admin')) {
      return adminDashboard;
    }
    if (normalizedRole.contains('doctor')) {
      return doctorDashboard;
    }
    if (normalizedRole.contains('receptionist')) {
      return receptionistDashboard;
    }
    if (normalizedRole.contains('patient')) {
      return patientDashboard;
    }
    if (normalizedRole.contains('nurse')) {
      return nurseDashboard;
    }

    return userDashboard;
  }
}
