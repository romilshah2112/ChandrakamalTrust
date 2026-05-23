import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/staff_analytics/models/staff_dashboard_analytics_model.dart';

class StaffAnalyticsRepository {
  StaffAnalyticsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<StaffDashboardAnalyticsModel> getDashboardAnalytics({
    required String accessToken,
    String? referenceName,
  }) => _apiClient.getStaffDashboardAnalytics(
    accessToken: accessToken,
    referenceName: referenceName,
  );

  Future<List<String>> getReferenceNames({required String accessToken}) =>
      _apiClient.getStaffAnalyticsReferenceNames(accessToken: accessToken);
}
