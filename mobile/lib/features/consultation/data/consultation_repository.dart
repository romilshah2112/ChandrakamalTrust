import 'package:optima_healthcare_mobile/core/network/api_client.dart';

class ConsultationRepository {
  ConsultationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> saveConsultationNotes({
    required String accessToken,
    required int patientDataId,
    required String transcript,
  }) {
    return _apiClient.saveConsultationNotes(
      accessToken: accessToken,
      patientDataId: patientDataId,
      transcript: transcript,
    );
  }
}
