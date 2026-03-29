import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:optima_healthcare_mobile/features/auth/models/login_response.dart';
import 'package:optima_healthcare_mobile/features/auth/models/signup_request.dart';
import 'package:optima_healthcare_mobile/features/auth/models/update_user_profile_request.dart';
import 'package:optima_healthcare_mobile/features/auth/models/user_profile.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/clinic_schedule_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/doctor_profile_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/invoice_type_model.dart';
import 'package:optima_healthcare_mobile/features/admin/models/staff_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/patient_appointment_model.dart';
import 'package:optima_healthcare_mobile/features/auth/models/user_role_option.dart';
import 'package:optima_healthcare_mobile/features/doctor_analytics/models/doctor_dashboard_analytics_model.dart';
import 'package:optima_healthcare_mobile/features/invoices/models/patient_invoice_model.dart';
import 'package:optima_healthcare_mobile/features/patients/models/patient_contact_update_request.dart';
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

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://optimahealthapp-production.up.railway.app',
  );

  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/login');

    final response = await _httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResponseModel.fromJson(jsonMap);
    }

    if (response.statusCode == 401) {
      throw const AuthException('Invalid username or password.');
    }

    throw AuthException('Login failed: HTTP ${response.statusCode}');
  }

  Future<void> signUp(SignUpRequestModel request) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/signup');

    final response = await _httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 409) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty
            ? 'User already exists. Please click forgot password to retrieve the password.'
            : body,
      );
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty ? 'Please check sign up details.' : body,
      );
    }

    throw AuthException('Sign up failed: HTTP ${response.statusCode}');
  }

  Future<void> forgotPassword({required String emailAddress}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/forgot-password');

    final response = await _httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'emailAddress': emailAddress}),
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 400) {
        throw const AuthException('Please enter a valid email address.');
      }
      throw AuthException(
        'Forgot password failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/reset-password');

    final response = await _httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Invalid or expired reset token.');
    }

    if (response.statusCode == 400) {
      throw const AuthException('Token and new password are required.');
    }

    throw AuthException('Reset password failed: HTTP ${response.statusCode}');
  }

  Future<List<UserRoleOptionModel>> getAllowedRoles() async {
    final uri = Uri.parse('$_baseUrl/api/v1/auth/roles');
    final response = await _httpClient.get(uri);

    if (response.statusCode != 200) {
      throw AuthException('Failed to load roles: HTTP ${response.statusCode}');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map(
          (item) => UserRoleOptionModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> createPatient({
    required String accessToken,
    required PatientCreateRequestModel request,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to add patients.');
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty ? 'Invalid patient details.' : body,
      );
    }

    throw AuthException('Create patient failed: HTTP ${response.statusCode}');
  }

  Future<PatientDetailModel> getMyPatientDetails({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data/me');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return PatientDetailModel.fromJson(map);
    }

    if (response.statusCode == 404) {
      throw const AuthException('No patient record found for this account.');
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view this record.');
    }

    throw AuthException(
      'Get patient details failed: HTTP ${response.statusCode}',
    );
  }

  Future<List<PatientListItemModel>> listPatients({
    required String accessToken,
    String? query,
  }) async {
    final qp = (query == null || query.trim().isEmpty)
        ? ''
        : '?query=${Uri.encodeQueryComponent(query.trim())}';
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data$qp');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (item) =>
                PatientListItemModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view patients.');
    }

    throw AuthException('List patients failed: HTTP ${response.statusCode}');
  }

  Future<PatientDetailModel> getPatientById({
    required String accessToken,
    required int patientDataId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data/$patientDataId');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return PatientDetailModel.fromJson(map);
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient not found.');
    }

    throw AuthException('Get patient failed: HTTP ${response.statusCode}');
  }

  Future<void> updateMyPatientContact({
    required String accessToken,
    required PatientContactUpdateRequestModel request,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data/me');
    final response = await _httpClient.put(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to update this record.');
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient record not found.');
    }

    if (response.statusCode == 400) {
      throw const AuthException('Invalid contact details.');
    }

    throw AuthException('Update contact failed: HTTP ${response.statusCode}');
  }

  Future<void> updatePatient({
    required String accessToken,
    required int patientDataId,
    required PatientDataUpdateRequestModel request,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data/$patientDataId');
    final response = await _httpClient.put(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient not found.');
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty ? 'Invalid patient details.' : body,
      );
    }

    throw AuthException('Update patient failed: HTTP ${response.statusCode}');
  }

  Future<void> deletePatient({
    required String accessToken,
    required int patientDataId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-data/$patientDataId');
    final response = await _httpClient.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient not found.');
    }

    if (response.statusCode == 409) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty
            ? 'Cannot delete: patient has existing appointments.'
            : body,
      );
    }

    throw AuthException('Delete patient failed: HTTP ${response.statusCode}');
  }

  Future<List<PatientMedicalRecordModel>> listPatientMedicalRecords({
    required String accessToken,
    required int patientDataId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records',
    );
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (item) => PatientMedicalRecordModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view medical records.');
    }

    if (response.statusCode == 404) {
      throw const AuthException(
        'Medical records could not be loaded. If the problem continues, deploy the latest API or check the patient id.',
      );
    }

    throw AuthException(
      'List medical records failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> createPatientMedicalRecord({
    required String accessToken,
    required int patientDataId,
    required SavePatientMedicalRecordRequestModel request,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records',
    );
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient not found.');
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to upload medical records.');
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty ? 'Invalid medical record details.' : body,
      );
    }

    throw AuthException(
      'Upload medical record failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> updatePatientMedicalRecord({
    required String accessToken,
    required int patientDataId,
    required int recordId,
    required UpdatePatientMedicalRecordRequestModel request,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records/$recordId',
    );
    final response = await _httpClient.put(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Medical record not found.');
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to edit medical records.');
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty ? 'Invalid medical record details.' : body,
      );
    }

    throw AuthException(
      'Update medical record failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> deletePatientMedicalRecord({
    required String accessToken,
    required int patientDataId,
    required int recordId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records/$recordId',
    );
    final response = await _httpClient.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Medical record not found.');
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to delete medical records.');
    }

    final body = response.body.trim();
    throw AuthException(
      body.isNotEmpty
          ? body
          : 'Delete medical record failed: HTTP ${response.statusCode}',
    );
  }

  /// Fetches the raw file bytes for a medical record via our API proxy.
  /// The API fetches the file from Cloudinary server-side, avoiding any
  /// client-side authentication / CORS issues with Cloudinary direct URLs.
  Future<List<int>> downloadMedicalRecordFile({
    required String accessToken,
    required int patientDataId,
    required int recordId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records/$recordId/file',
    );
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view this document.');
    }

    if (response.statusCode == 404) {
      throw const AuthException('Document not found.');
    }

    final body = response.body.trim();
    throw AuthException(
      body.isNotEmpty
          ? body
          : 'Could not fetch document: HTTP ${response.statusCode}',
    );
  }

  Future<List<PatientRecordDetailModel>> listPatientRecordDetails({
    required String accessToken,
    required int patientDataId,
    required int recordId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records/$recordId/ocr-preview',
    );
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (item) => PatientRecordDetailModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view parsed report details.');
    }

    if (response.statusCode == 404) {
      throw const AuthException('Record details not found.');
    }

    final body = response.body.trim();
    throw AuthException(
      body.isNotEmpty
          ? body
          : 'List patient record details failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> savePatientRecordDetails({
    required String accessToken,
    required int patientDataId,
    required int recordId,
    required String patientNameInRecord,
    required List<PatientRecordDetailModel> details,
    required String reportDateTime,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/medical-records/$recordId/details',
    );
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'patientNameInRecord': patientNameInRecord,
        'details': details
            .map(
              (detail) => {
                'recordKeywordId': detail.recordKeywordId,
                'readingValue': detail.readingValue,
                'reportDateTime': reportDateTime,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode == 204) {
      return;
    }

    final body = response.body.trim();
    throw AuthException(
      body.isNotEmpty
          ? body
          : 'Save patient record details failed: HTTP ${response.statusCode}',
    );
  }

  Future<List<PatientVitalsModel>> listPatientVitals({
    required String accessToken,
    required int patientDataId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/vitals',
    );
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (item) => PatientVitalsModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(body.isEmpty ? 'Invalid patient id.' : body);
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view patient vitals.');
    }

    throw AuthException(
      'List patient vitals failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> createPatientVitals({
    required String accessToken,
    required int patientDataId,
    required PatientVitalsSaveRequestModel request,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/patient-data/$patientDataId/vitals',
    );
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(body.isEmpty ? 'Invalid vitals details.' : body);
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to add patient vitals.');
    }

    throw AuthException(
      'Create patient vitals failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> updatePatientVitals({
    required String accessToken,
    required int patientVitalsId,
    required PatientVitalsSaveRequestModel request,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-vitals/$patientVitalsId');
    final response = await _httpClient.put(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient vitals not found.');
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(body.isEmpty ? 'Invalid vitals details.' : body);
    }

    throw AuthException(
      'Update patient vitals failed: HTTP ${response.statusCode}',
    );
  }

  Future<void> deletePatientVitals({
    required String accessToken,
    required int patientVitalsId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/patient-vitals/$patientVitalsId');
    final response = await _httpClient.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 404) {
      throw const AuthException('Patient vitals not found.');
    }

    throw AuthException(
      'Delete patient vitals failed: HTTP ${response.statusCode}',
    );
  }

  Future<List<LookupOptionModel>> getReferenceTypes({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/reference-types');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) {
            final map = item as Map<String, dynamic>;
            return LookupOptionModel(
              id: (map['id'] as num).toInt(),
              name: map['name'] as String? ?? '',
            );
          })
          .toList();
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view reference types.');
    }

    throw AuthException(
      'Get reference types failed: HTTP ${response.statusCode}',
    );
  }

  Future<List<LookupOptionModel>> getRecordTypes({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/record-types');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) {
            final map = item as Map<String, dynamic>;
            return LookupOptionModel(
              id: (map['id'] as num).toInt(),
              name: map['name'] as String? ?? '',
            );
          })
          .toList();
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view record types.');
    }

    throw AuthException(
      'Get record types failed: HTTP ${response.statusCode}',
    );
  }

  Future<List<RecordKeywordLookupModel>> getRecordKeywords({
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/record-keywords');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (item) => RecordKeywordLookupModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    if (response.statusCode == 403) {
      throw const AuthException('You are not allowed to view record keywords.');
    }

    throw AuthException(
      'Get record keywords failed: HTTP ${response.statusCode}',
    );
  }

  Future<UserProfileModel> getMyProfile({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/user-profile/me');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfileModel.fromJson(map);
    }

    throw AuthException('Get profile failed: HTTP ${response.statusCode}');
  }

  Future<void> updateMyProfile({
    required String accessToken,
    required UpdateUserProfileRequestModel request,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/user-profile/me');
    final response = await _httpClient.put(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(
        body.isEmpty ? 'Invalid profile payload.' : body,
      );
    }

    throw AuthException('Update profile failed: HTTP ${response.statusCode}');
  }

  Future<List<ClinicModel>> listClinics({required String accessToken}) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/admin/masters/clinics'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException('List clinics failed: HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ClinicModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveClinic({
    required String accessToken,
    int? id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/admin/masters/clinics'
          : '$_baseUrl/api/v1/admin/masters/clinics/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw AuthException('Save clinic failed: HTTP ${response.statusCode}');
    }
  }

  Future<void> deleteClinic({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/admin/masters/clinics/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204) {
      throw AuthException('Delete clinic failed: HTTP ${response.statusCode}');
    }
  }

  Future<List<DoctorProfileModel>> listDoctorProfiles({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/admin/masters/doctor-profiles'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException(
        'List doctor profiles failed: HTTP ${response.statusCode}',
      );
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => DoctorProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDoctorProfile({
    required String accessToken,
    int? id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/admin/masters/doctor-profiles'
          : '$_baseUrl/api/v1/admin/masters/doctor-profiles/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw AuthException(
        'Save doctor profile failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<void> deleteDoctorProfile({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/admin/masters/doctor-profiles/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204) {
      throw AuthException(
        'Delete doctor profile failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<List<StaffModel>> listStaff({required String accessToken}) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/admin/masters/staff'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException('List staff failed: HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveStaff({
    required String accessToken,
    int? id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/admin/masters/staff'
          : '$_baseUrl/api/v1/admin/masters/staff/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw AuthException('Save staff failed: HTTP ${response.statusCode}');
    }
  }

  Future<void> deleteStaff({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/admin/masters/staff/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204) {
      throw AuthException('Delete staff failed: HTTP ${response.statusCode}');
    }
  }

  Future<List<ClinicScheduleModel>> listClinicSchedules({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/admin/masters/clinic-schedules'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException(
        'List clinic schedules failed: HTTP ${response.statusCode}',
      );
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ClinicScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveClinicSchedule({
    required String accessToken,
    int? id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/admin/masters/clinic-schedules'
          : '$_baseUrl/api/v1/admin/masters/clinic-schedules/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw AuthException(
        'Save clinic schedule failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<void> deleteClinicSchedule({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/admin/masters/clinic-schedules/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204) {
      throw AuthException(
        'Delete clinic schedule failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<List<InvoiceTypeModel>> listInvoiceTypes({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/admin/masters/invoice-types'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException(
        'List invoice types failed: HTTP ${response.statusCode}',
      );
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => InvoiceTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveInvoiceType({
    required String accessToken,
    int? id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/admin/masters/invoice-types'
          : '$_baseUrl/api/v1/admin/masters/invoice-types/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw AuthException(
        'Save invoice type failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<void> deleteInvoiceType({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/admin/masters/invoice-types/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204) {
      throw AuthException(
        'Delete invoice type failed: HTTP ${response.statusCode}',
      );
    }
  }

  Future<List<InvoiceTypeModel>> listInvoiceTypeLookup({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/invoices/lookups/invoice-types'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException(
        'Load invoice type lookup failed: HTTP ${response.statusCode}',
      );
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => InvoiceTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PatientInvoiceModel>> listInvoices({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/invoices'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException('List invoices failed: HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => PatientInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> getNextInvoiceNumber({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/invoices/next-number'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthException(
        'Load next invoice number failed: HTTP ${response.statusCode}',
      );
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return map['invoiceNumber'] as String? ?? 'PHCC-0001';
  }

  Future<void> saveInvoice({
    required String accessToken,
    required Map<String, dynamic> body,
    int? id,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/invoices'
          : '$_baseUrl/api/v1/invoices/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      final bodyText = response.body.trim();
      throw AuthException(
        bodyText.isEmpty
            ? 'Save invoice failed: HTTP ${response.statusCode}'
            : bodyText,
      );
    }
  }

  Future<void> deleteInvoice({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/invoices/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 204) {
      throw AuthException('Delete invoice failed: HTTP ${response.statusCode}');
    }
  }

  Future<List<PatientAppointmentModel>> listAppointments({
    required String accessToken,
    DateTime? from,
    DateTime? to,
    int? clinicId,
  }) async {
    final queryParts = <String>[];
    if (from != null) {
      queryParts.add(
        'from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}',
      );
    }
    if (to != null) {
      queryParts.add(
        'to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}',
      );
    }
    if (clinicId != null && clinicId > 0) {
      queryParts.add(
        'clinicId=${Uri.encodeQueryComponent(clinicId.toString())}',
      );
    }
    final query = queryParts.isEmpty ? '' : '?${queryParts.join('&')}';
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments$query'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toAuthException('List appointments failed', response);
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => PatientAppointmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DoctorDashboardAnalyticsModel> getDoctorDashboardAnalytics({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/doctor-analytics/dashboard'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toAuthException('Load doctor analytics failed', response);
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return DoctorDashboardAnalyticsModel.fromJson(map);
  }

  Future<void> saveAppointment({
    required String accessToken,
    int? id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '$_baseUrl/api/v1/appointments'
          : '$_baseUrl/api/v1/appointments/$id',
    );
    final response = id == null
        ? await _httpClient.post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await _httpClient.put(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != 201 && response.statusCode != 204) {
      throw _toAuthException('Save appointment failed', response);
    }
  }

  Future<void> deleteAppointment({
    required String accessToken,
    required int id,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/api/v1/appointments/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 204) {
      throw _toAuthException('Delete appointment failed', response);
    }
  }

  Future<List<LookupOptionModel>> listAppointmentPatients({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments/lookups/patients'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toAuthException('Load patient lookup failed', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final first = map['firstName'] as String? ?? '';
      final last = map['lastName'] as String? ?? '';
      final name = '$first $last'.trim();
      return LookupOptionModel(
        id: map['patientDataId'] as int,
        name: name.isEmpty ? 'Patient #${map['patientDataId']}' : name,
      );
    }).toList();
  }

  Future<List<LookupOptionModel>> listAppointmentDoctors({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments/lookups/doctors'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toAuthException('Load doctor lookup failed', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return LookupOptionModel(
        id: map['doctorProfileId'] as int,
        name: map['doctorName'] as String? ?? 'Doctor',
      );
    }).toList();
  }

  Future<List<LookupOptionModel>> listAppointmentClinics({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments/lookups/clinics'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toAuthException('Load clinic lookup failed', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return LookupOptionModel(
        id: map['clinicId'] as int,
        name: map['clinicName'] as String? ?? 'Clinic',
      );
    }).toList();
  }

  Future<List<ClinicScheduleModel>> listAppointmentClinicSchedules({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments/lookups/clinic-schedules'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toAuthException('Load clinic schedules failed', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ClinicScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LookupOptionModel>> listAppointmentStatuses({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments/lookups/statuses'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toAuthException('Load appointment statuses failed', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return LookupOptionModel(
        id: map['appointmentStatusId'] as int,
        name: map['appointmentStatus'] as String? ?? 'Status',
      );
    }).toList();
  }

  Future<List<LookupOptionModel>> listAppointmentTypes({
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/v1/appointments/lookups/appointment-types'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toAuthException('Load appointment types failed', response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return LookupOptionModel(
        id: map['appointmentTypeId'] as int,
        name: map['appointmentTypeName'] as String? ?? 'Type',
      );
    }).toList();
  }

  Future<void> saveConsultationNotes({
    required String accessToken,
    required int patientDataId,
    required String transcript,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/consultation/save-notes');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'patientDataId': patientDataId,
        'transcript': transcript,
      }),
    );

    if (response.statusCode == 204) return;

    if (response.statusCode == 400) {
      final body = response.body.trim();
      throw AuthException(body.isEmpty ? 'Invalid request.' : body);
    }
    if (response.statusCode == 403) {
      throw const AuthException(
        'You are not allowed to save consultation notes.',
      );
    }
    throw AuthException(
      'Save consultation notes failed: HTTP ${response.statusCode}',
    );
  }

  AuthException _toAuthException(String prefix, http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return AuthException('$prefix: HTTP ${response.statusCode}');
    }
    return AuthException('$prefix: HTTP ${response.statusCode} - $body');
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
