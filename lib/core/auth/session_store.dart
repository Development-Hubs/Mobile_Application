import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The bearer token and where it belongs. Kept only in Keychain / Android Keystore-backed storage.
///
/// Passwords and one-time codes are never stored anywhere.
class StoredSession {
  const StoredSession({required this.server, required this.company, required this.token, this.expiresAt, this.tokenId});

  final String server;
  final String company;
  final String token;
  final DateTime? expiresAt;
  final String? tokenId;

  bool get renewSoon => expiresAt != null && expiresAt!.difference(DateTime.now()) < const Duration(days: 3);

  StoredSession withToken(String token, DateTime? expiresAt, String? tokenId) =>
      StoredSession(server: server, company: company, token: token, expiresAt: expiresAt, tokenId: tokenId ?? this.tokenId);
}

class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  final FlutterSecureStorage _s;

  static const _kServer = 'oc.server';
  static const _kCompany = 'oc.company';
  static const _kToken = 'oc.token';
  static const _kExpires = 'oc.expires_at';
  static const _kTokenId = 'oc.token_id';

  Future<StoredSession?> read() async {
    final token = await _s.read(key: _kToken);
    final server = await _s.read(key: _kServer);
    if (token == null || token.isEmpty || server == null) return null;
    final exp = await _s.read(key: _kExpires);
    return StoredSession(
      server: server,
      company: await _s.read(key: _kCompany) ?? '',
      token: token,
      expiresAt: exp == null ? null : DateTime.tryParse(exp),
      tokenId: await _s.read(key: _kTokenId),
    );
  }

  Future<void> write(StoredSession s) async {
    await _s.write(key: _kServer, value: s.server);
    await _s.write(key: _kCompany, value: s.company);
    await _s.write(key: _kToken, value: s.token);
    if (s.expiresAt != null) await _s.write(key: _kExpires, value: s.expiresAt!.toIso8601String());
    if (s.tokenId != null) await _s.write(key: _kTokenId, value: s.tokenId);
  }

  /// Remembers which ERP and company the device connects to (not a secret, but kept together).
  Future<void> writeTarget(String server, String company) async {
    await _s.write(key: _kServer, value: server);
    await _s.write(key: _kCompany, value: company);
  }

  Future<(String?, String?)> readTarget() async => (await _s.read(key: _kServer), await _s.read(key: _kCompany));

  /// Removes the token but keeps the company the device was connected to.
  Future<void> clearToken() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kExpires);
    await _s.delete(key: _kTokenId);
  }

  Future<void> wipe() => _s.deleteAll();
}
