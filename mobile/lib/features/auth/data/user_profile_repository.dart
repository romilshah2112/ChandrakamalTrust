import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/update_user_profile_request.dart';
import 'package:optima_healthcare_mobile/features/auth/models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<UserProfileModel> getMyProfile({required String accessToken}) {
    return _apiClient.getMyProfile(accessToken: accessToken);
  }

  Future<void> updateMyProfile({
    required String accessToken,
    required UpdateUserProfileRequestModel request,
  }) {
    return _apiClient.updateMyProfile(accessToken: accessToken, request: request);
  }
}
