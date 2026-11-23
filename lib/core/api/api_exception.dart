/// An error answered by the ERP (`{ok:false, error:{code, message, fields}}`) or a transport failure.
///
/// Screens switch on [code] and show [message]; they never invent a success when this is thrown.
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.status, this.fields = const {}});

  final String code;
  final String message;
  final int? status;
  final Map<String, List<String>> fields;

  /// No network, DNS failure or timeout: nothing reached the ERP (or the answer was lost).
  bool get isOffline => code == 'offline' || code == 'timeout';

  /// The session is no longer valid and the user must sign in again.
  bool get endsSession => const {
        'unauthenticated',
        'token_expired',
        'token_revoked',
        'reauthentication_required',
        'workspace_revoked',
        'account_blocked',
        'company_unavailable',
      }.contains(code);

  String? fieldError(String name) {
    final list = fields[name];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  static Map<String, List<String>> parseFields(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v is List ? v.map((e) => e.toString()).toList() : [v.toString()]));
  }

  @override
  String toString() => 'ApiException($code, $status): $message';
}
