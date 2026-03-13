import 'package:optima_healthcare_mobile/core/network/api_client.dart';
import 'package:optima_healthcare_mobile/features/auth/models/login_response.dart';
import 'package:optima_healthcare_mobile/features/auth/models/signup_request.dart';
import 'package:optima_healthcare_mobile/features/auth/models/user_role_option.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) {
    return _apiClient.login(username: username, password: password);
  }

  Future<void> signUp(SignUpRequestModel request) {
    return _apiClient.signUp(request);
  }

  Future<List<UserRoleOptionModel>> getAllowedRoles() {
    return _apiClient.getAllowedRoles();
  }

  Future<void> forgotPassword({required String emailAddress}) {
    return _apiClient.forgotPassword(emailAddress: emailAddress);
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _apiClient.resetPassword(token: token, newPassword: newPassword);
  }
}
