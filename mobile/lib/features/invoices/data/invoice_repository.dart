import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/admin/models/invoice_type_model.dart';
import 'package:optima_healthcare_mobile/features/appointments/models/lookup_option_model.dart';
import 'package:optima_healthcare_mobile/features/invoices/models/patient_invoice_model.dart';

class InvoiceRepository {
  InvoiceRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<PatientInvoiceModel>> listInvoices({
    required String accessToken,
  }) => _apiClient.listInvoices(accessToken: accessToken);

  Future<String> getNextInvoiceNumber({
    required String accessToken,
  }) => _apiClient.getNextInvoiceNumber(accessToken: accessToken);

  Future<List<LookupOptionModel>> listPatientLookup({
    required String accessToken,
  }) => _apiClient.listAppointmentPatients(accessToken: accessToken);

  Future<List<LookupOptionModel>> listDoctorLookup({
    required String accessToken,
  }) => _apiClient.listAppointmentDoctors(accessToken: accessToken);

  Future<List<LookupOptionModel>> listClinicLookup({
    required String accessToken,
  }) => _apiClient.listAppointmentClinics(accessToken: accessToken);

  Future<List<InvoiceTypeModel>> listInvoiceTypeLookup({
    required String accessToken,
  }) => _apiClient.listInvoiceTypeLookup(accessToken: accessToken);

  Future<void> saveInvoice({
    required String accessToken,
    required Map<String, dynamic> body,
    int? id,
  }) => _apiClient.saveInvoice(accessToken: accessToken, body: body, id: id);

  Future<void> deleteInvoice({
    required String accessToken,
    required int id,
  }) => _apiClient.deleteInvoice(accessToken: accessToken, id: id);
}
