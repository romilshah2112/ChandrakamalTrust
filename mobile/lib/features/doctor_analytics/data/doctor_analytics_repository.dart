import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/doctor_analytics/models/doctor_dashboard_analytics_model.dart';

class DoctorAnalyticsRepository {
  DoctorAnalyticsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<DoctorDashboardAnalyticsModel> getDashboardAnalytics({
    required String accessToken,
  }) => _apiClient.getDoctorDashboardAnalytics(accessToken: accessToken);
}
