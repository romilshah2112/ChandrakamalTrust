import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_contact_update_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_complaint_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_complaint_save_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_create_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_data_update_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_detail.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_list_item.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_medical_record_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_record_detail_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/record_keyword_lookup_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/save_patient_medical_record_request.dart';
import 'package:optima_healthcare_mobile/features/patients/models/update_patient_medical_record_request.dart';
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

  Future<List<LookupOptionModel>> getRecordTypes({
    required String accessToken,
  }) {
    return _apiClient.getRecordTypes(accessToken: accessToken);
  }

  Future<List<LookupOptionModel>> getComplaintSeverities({
    required String accessToken,
  }) {
    return _apiClient.getComplaintSeverities(accessToken: accessToken);
  }

  Future<List<PatientMedicalRecordModel>> listPatientMedicalRecords({
    required String accessToken,
    required int patientDataId,
  }) {
    return _apiClient.listPatientMedicalRecords(
      accessToken: accessToken,
      patientDataId: patientDataId,
    );
  }

  Future<void> createPatientMedicalRecord({
    required String accessToken,
    required int patientDataId,
    required SavePatientMedicalRecordRequestModel request,
  }) {
    return _apiClient.createPatientMedicalRecord(
      accessToken: accessToken,
      patientDataId: patientDataId,
      request: request,
    );
  }

  Future<void> updatePatientMedicalRecord({
    required String accessToken,
    required int patientDataId,
    required int recordId,
    required UpdatePatientMedicalRecordRequestModel request,
  }) {
    return _apiClient.updatePatientMedicalRecord(
      accessToken: accessToken,
      patientDataId: patientDataId,
      recordId: recordId,
      request: request,
    );
  }

  Future<void> deletePatientMedicalRecord({
    required String accessToken,
    required int patientDataId,
    required int recordId,
  }) {
    return _apiClient.deletePatientMedicalRecord(
      accessToken: accessToken,
      patientDataId: patientDataId,
      recordId: recordId,
    );
  }

  Future<List<int>> downloadMedicalRecordFile({
    required String accessToken,
    required int patientDataId,
    required int recordId,
  }) {
    return _apiClient.downloadMedicalRecordFile(
      accessToken: accessToken,
      patientDataId: patientDataId,
      recordId: recordId,
    );
  }

  Future<List<PatientRecordDetailModel>> listPatientRecordDetails({
    required String accessToken,
    required int patientDataId,
    required int recordId,
  }) {
    return _apiClient.listPatientRecordDetails(
      accessToken: accessToken,
      patientDataId: patientDataId,
      recordId: recordId,
    );
  }

  Future<List<PatientRecordDetailModel>> getPatientAnalytics({
    required String accessToken,
    required int patientDataId,
  }) {
    return _apiClient.getPatientAnalytics(
      accessToken: accessToken,
      patientDataId: patientDataId,
    );
  }

  // ── Patient self-access (my own records) ────────────────────────────────────

  Future<List<PatientMedicalRecordModel>> getMyMedicalRecords({
    required String accessToken,
  }) {
    return _apiClient.getMyMedicalRecords(accessToken: accessToken);
  }

  Future<List<int>> downloadMyMedicalRecordFile({
    required String accessToken,
    required int recordId,
  }) {
    return _apiClient.downloadMyMedicalRecordFile(
      accessToken: accessToken,
      recordId: recordId,
    );
  }

  Future<List<PatientRecordDetailModel>> getMyAnalytics({
    required String accessToken,
  }) {
    return _apiClient.getMyAnalytics(accessToken: accessToken);
  }

  Future<List<RecordKeywordLookupModel>> getRecordKeywords({
    required String accessToken,
  }) {
    return _apiClient.getRecordKeywords(accessToken: accessToken);
  }

  Future<void> savePatientRecordDetails({
    required String accessToken,
    required int patientDataId,
    required int recordId,
    required String patientNameInRecord,
    required List<PatientRecordDetailModel> details,
    required String reportDateTime,
  }) {
    return _apiClient.savePatientRecordDetails(
      accessToken: accessToken,
      patientDataId: patientDataId,
      recordId: recordId,
      patientNameInRecord: patientNameInRecord,
      details: details,
      reportDateTime: reportDateTime,
    );
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

  Future<List<PatientComplaintModel>> listPatientComplaints({
    required String accessToken,
    required int patientDataId,
  }) {
    return _apiClient.listPatientComplaints(
      accessToken: accessToken,
      patientDataId: patientDataId,
    );
  }

  Future<void> createPatientComplaint({
    required String accessToken,
    required int patientDataId,
    required PatientComplaintSaveRequestModel request,
  }) {
    return _apiClient.createPatientComplaint(
      accessToken: accessToken,
      patientDataId: patientDataId,
      request: request,
    );
  }

  Future<void> updatePatientComplaint({
    required String accessToken,
    required int patientComplaintId,
    required PatientComplaintSaveRequestModel request,
  }) {
    return _apiClient.updatePatientComplaint(
      accessToken: accessToken,
      patientComplaintId: patientComplaintId,
      request: request,
    );
  }

  Future<void> deletePatientComplaint({
    required String accessToken,
    required int patientComplaintId,
  }) {
    return _apiClient.deletePatientComplaint(
      accessToken: accessToken,
      patientComplaintId: patientComplaintId,
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
