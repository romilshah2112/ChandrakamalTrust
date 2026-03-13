import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_schedule_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/doctor_profile_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/staff_model.dart';

class AdminMasterRepository {
  AdminMasterRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ClinicModel>> listClinics(String token) =>
      _apiClient.listClinics(accessToken: token);
  Future<void> saveClinic(String token, Map<String, dynamic> body, {int? id}) =>
      _apiClient.saveClinic(accessToken: token, body: body, id: id);
  Future<void> deleteClinic(String token, int id) =>
      _apiClient.deleteClinic(accessToken: token, id: id);

  Future<List<DoctorProfileModel>> listDoctorProfiles(String token) =>
      _apiClient.listDoctorProfiles(accessToken: token);
  Future<void> saveDoctorProfile(
    String token,
    Map<String, dynamic> body, {
    int? id,
  }) => _apiClient.saveDoctorProfile(accessToken: token, body: body, id: id);
  Future<void> deleteDoctorProfile(String token, int id) =>
      _apiClient.deleteDoctorProfile(accessToken: token, id: id);

  Future<List<StaffModel>> listStaff(String token) =>
      _apiClient.listStaff(accessToken: token);
  Future<void> saveStaff(String token, Map<String, dynamic> body, {int? id}) =>
      _apiClient.saveStaff(accessToken: token, body: body, id: id);
  Future<void> deleteStaff(String token, int id) =>
      _apiClient.deleteStaff(accessToken: token, id: id);

  Future<List<ClinicScheduleModel>> listClinicSchedules(String token) =>
      _apiClient.listClinicSchedules(accessToken: token);
  Future<void> saveClinicSchedule(
    String token,
    Map<String, dynamic> body, {
    int? id,
  }) => _apiClient.saveClinicSchedule(accessToken: token, body: body, id: id);
  Future<void> deleteClinicSchedule(String token, int id) =>
      _apiClient.deleteClinicSchedule(accessToken: token, id: id);
}
