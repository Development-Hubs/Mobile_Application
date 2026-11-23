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
}
