class AuthSession {
  AuthSession._();

  static int? appUserId;
  static String? username;
  static String? role;
  static String? accessToken;
  static String? firstName;
  static String? lastName;

  static void set({
    required int appUserIdValue,
    required String usernameValue,
    required String roleValue,
    required String accessTokenValue,
    String? firstNameValue,
    String? lastNameValue,
  }) {
    appUserId = appUserIdValue;
    username = usernameValue;
    role = roleValue;
    accessToken = accessTokenValue;
    firstName = firstNameValue;
    lastName = lastNameValue;
  }

  static void updateProfileName({
    String? firstNameValue,
    String? lastNameValue,
  }) {
    firstName = firstNameValue;
    lastName = lastNameValue;
  }

  static void clear() {
    appUserId = null;
    username = null;
    role = null;
    accessToken = null;
    firstName = null;
    lastName = null;
  }
}
