import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_contact_update_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_create_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_data_update_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_detail.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_list_item.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_vitals_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_vitals_save_request.dart';

class PatientRepository {
  PatientRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> createPatient({
    required String accessToken,
    required PatientCreateRequestModel request,
  }) {
    return _apiClient.createPatient(accessToken: accessToken, request: request);
  }

  Future<List<LookupOptionModel>> getReferenceTypes({
    required String accessToken,
  }) {
    return _apiClient.getReferenceTypes(accessToken: accessToken);
  }

  Future<PatientDetailModel> getMyPatientDetails({required String accessToken}) {
    return _apiClient.getMyPatientDetails(accessToken: accessToken);
  }

  Future<PatientDetailModel> getPatientById({
    required String accessToken,
    required int patientDataId,
  }) {
    return _apiClient.getPatientById(
      accessToken: accessToken,
      patientDataId: patientDataId,
    );
  }

  Future<List<PatientListItemModel>> listPatients({
    required String accessToken,
    String? query,
  }) {
    return _apiClient.listPatients(accessToken: accessToken, query: query);
  }

  Future<void> updateMyPatientContact({
    required String accessToken,
    required PatientContactUpdateRequestModel request,
  }) {
    return _apiClient.updateMyPatientContact(
      accessToken: accessToken,
      request: request,
    );
  }

  Future<void> updatePatient({
    required String accessToken,
    required int patientDataId,
    required PatientDataUpdateRequestModel request,
  }) {
    return _apiClient.updatePatient(
      accessToken: accessToken,
      patientDataId: patientDataId,
      request: request,
    );
  }

  Future<void> deletePatient({
    required String accessToken,
    required int patientDataId,
  }) {
    return _apiClient.deletePatient(
      accessToken: accessToken,
      patientDataId: patientDataId,
    );
  }

  Future<List<PatientVitalsModel>> listPatientVitals({
    required String accessToken,
    required int patientDataId,
  }) {
    return _apiClient.listPatientVitals(
      accessToken: accessToken,
      patientDataId: patientDataId,
    );
  }

  Future<void> createPatientVitals({
    required String accessToken,
    required int patientDataId,
    required PatientVitalsSaveRequestModel request,
  }) {
    return _apiClient.createPatientVitals(
      accessToken: accessToken,
      patientDataId: patientDataId,
      request: request,
    );
  }

  Future<void> updatePatientVitals({
    required String accessToken,
    required int patientVitalsId,
    required PatientVitalsSaveRequestModel request,
  }) {
    return _apiClient.updatePatientVitals(
      accessToken: accessToken,
      patientVitalsId: patientVitalsId,
      request: request,
    );
  }

  Future<void> deletePatientVitals({
    required String accessToken,
    required int patientVitalsId,
  }) {
    return _apiClient.deletePatientVitals(
      accessToken: accessToken,
      patientVitalsId: patientVitalsId,
    );
  }
}
