class AppConstants {
  AppConstants._();

  static const String serverUrl = 'https://app.xamepage.com';
  static const String appName = 'XamePay';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // Retain the existing account/session key contract with the shared backend.
  // Android/iOS application storage is isolated by the native app identity.
  static const String keyUser = 'xame:user';
  static const String keySessionToken = 'xame:sessionToken';
  static const String keyStealth = 'xame:stealth';

  static const String reconnectBaseUrl = serverUrl;
}
