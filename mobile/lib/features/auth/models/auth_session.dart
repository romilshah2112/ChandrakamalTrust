class AuthSession {
  AuthSession._();

  static int? appUserId;
  static String? username;
  static String? role;
  static String? accessToken;

  static void set({
    required int appUserIdValue,
    required String usernameValue,
    required String roleValue,
    required String accessTokenValue,
  }) {
    appUserId = appUserIdValue;
    username = usernameValue;
    role = roleValue;
    accessToken = accessTokenValue;
  }

  static void clear() {
    appUserId = null;
    username = null;
    role = null;
    accessToken = null;
  }
}
