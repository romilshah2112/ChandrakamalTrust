import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_schedule_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/patient_appointment_model.dart';

class AppointmentRepository {
  AppointmentRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<PatientAppointmentModel>> listAppointments({
    required String accessToken,
    DateTime? from,
    DateTime? to,
    int? clinicId,
  }) {
    return _apiClient.listAppointments(
      accessToken: accessToken,
      from: from,
      to: to,
      clinicId: clinicId,
    );
  }

  Future<void> saveAppointment({
    required String accessToken,
    required Map<String, dynamic> body,
    int? id,
  }) {
    return _apiClient.saveAppointment(
      accessToken: accessToken,
      body: body,
      id: id,
    );
  }

  Future<void> deleteAppointment({
    required String accessToken,
    required int id,
  }) {
    return _apiClient.deleteAppointment(accessToken: accessToken, id: id);
  }

  Future<List<LookupOptionModel>> listPatientLookup({
    required String accessToken,
  }) {
    return _apiClient.listAppointmentPatients(accessToken: accessToken);
  }

  Future<List<LookupOptionModel>> listDoctorLookup({
    required String accessToken,
  }) {
    return _apiClient.listAppointmentDoctors(accessToken: accessToken);
  }

  Future<List<LookupOptionModel>> listClinicLookup({
    required String accessToken,
  }) {
    return _apiClient.listAppointmentClinics(accessToken: accessToken);
  }

  Future<List<ClinicScheduleModel>> listClinicScheduleLookup({
    required String accessToken,
  }) {
    return _apiClient.listAppointmentClinicSchedules(accessToken: accessToken);
  }

  Future<List<LookupOptionModel>> listStatusLookup({
    required String accessToken,
  }) {
    return _apiClient.listAppointmentStatuses(accessToken: accessToken);
  }

  Future<List<LookupOptionModel>> listAppointmentTypeLookup({
    required String accessToken,
  }) {
    return _apiClient.listAppointmentTypes(accessToken: accessToken);
  }
}
