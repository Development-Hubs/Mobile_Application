/// Build-time configuration passed with `--dart-define-from-file=config/<env>.json`.
///
/// Nothing secret belongs here: these values ship inside the app binary.
class Env {
  const Env._();

  /// Base URL of the ERP, without a trailing slash, e.g. https://demoagent.onesourceerp.com
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Optional company code pre-filled on the connect screen (single-company builds).
  static const String companyCode = String.fromEnvironment('COMPANY_CODE', defaultValue: '');

  /// Label shown in a ribbon on non-production builds (e.g. "DEMO", "STAGING"). Empty for production.
  static const String envName = String.fromEnvironment('ENV_NAME', defaultValue: '');

  /// When true the user may type another ERP address on the connect screen.
  static const bool allowCustomServer = bool.fromEnvironment('ALLOW_CUSTOM_SERVER', defaultValue: false);

  static String get apiPrefix => '/api/mobile/v1';

  // ---- stores (used by the "update required" screen) ----------------------------------------------------------
  static const String androidPackage = String.fromEnvironment('ANDROID_PACKAGE', defaultValue: 'qa.onesource.onesource_connect');

  /// Numeric App Store id, e.g. 6740000000, known once the app is created in App Store Connect.
  static const String iosAppId = String.fromEnvironment('IOS_APP_ID', defaultValue: '');

  // ---- Firebase (push). Project identifiers, not secrets; empty = push off ------------------------------------
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '');
  static const String firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');
  static const String firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: '');
  static const String firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');
  static const String firebaseIosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: '');
  static const String iosBundleId = String.fromEnvironment('IOS_BUNDLE_ID', defaultValue: 'qa.onesource.onesourceConnect');
}
