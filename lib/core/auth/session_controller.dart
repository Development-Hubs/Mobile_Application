import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../config/env.dart';
import '../offline/offline_store.dart';
import '../push/push_service.dart';
import '../settings/app_settings.dart';
import '../util/json.dart';
import 'models.dart';
import 'session_store.dart';

enum Phase { loading, connect, update, maintenance, offline, signedOut, locked, chooseWorkspace, signedIn }

class SessionState {
  const SessionState({
    this.phase = Phase.loading,
    this.server = '',
    this.company = '',
    this.boot,
    this.me,
    this.error,
    this.notice,
    this.epoch = 0,
  });

  final Phase phase;
  final String server;
  final String company;
  final Bootstrap? boot;
  final Me? me;
  final ApiException? error;

  /// A message to show once on the sign-in screen (e.g. "You were signed out on another device").
  final String? notice;

  /// Bumps on every workspace switch and sign-out, so data providers drop cached lists, drafts and files.
  final int epoch;

  SessionState copyWith({int? epoch, Phase? phase, String? server, String? company, Bootstrap? boot, Me? me, ApiException? error, String? notice, bool clearMe = false}) => SessionState(
        phase: phase ?? this.phase,
        server: server ?? this.server,
        company: company ?? this.company,
        boot: boot ?? this.boot,
        me: clearMe ? null : (me ?? this.me),
        error: error,
        notice: notice,
        epoch: epoch ?? this.epoch,
      );
}

final apiProvider = Provider<ApiClient>((ref) => ApiClient());
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Owns the sign-in lifecycle: bootstrap → token → `me`, renewals, workspace switches and sign-out.
class SessionController extends Notifier<SessionState> {
  ApiClient get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);
  StoredSession? _session;
  String _appVersion = '1.0.0';

  @override
  SessionState build() {
    _api.onSessionEnded = _ended;
    _api.needsRenewal = () => _session?.renewSoon ?? false;
    _api.renewer = _renew;
    Future.microtask(start);
    return const SessionState();
  }

  ApiClient get api => _api;

  /// Id of this device's token, to mark "this device" in the device list.
  String? get tokenId => _session?.tokenId;

  String get deviceName => '${Platform.isIOS ? 'iPhone' : 'Android'} · OneSource Connect';

  Future<void> start() async {
    state = state.copyWith(phase: Phase.loading);
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    _api.appVersion = _appVersion;
    _api.locale = ref.read(settingsProvider).locale ?? Platform.localeName.split('_').first;

    final (savedServer, savedCompany) = await _store.readTarget();
    final server = (Env.allowCustomServer ? savedServer : null) ?? (Env.baseUrl.isNotEmpty ? Env.baseUrl : savedServer ?? '');
    final company = savedCompany ?? Env.companyCode;
    if (server.isEmpty) {
      state = state.copyWith(phase: Phase.connect, company: company);
      return;
    }
    _api.server = server;
    state = state.copyWith(server: server, company: company);

    final ok = await _bootstrap(company);
    if (!ok) return;

    _session = await _store.read();
    if (_session == null || _session!.server != server) {
      state = state.copyWith(phase: Phase.signedOut);
      return;
    }
    _api.token = _session!.token;
    await refreshMe(lockIfEnabled: true);
  }

  Future<bool> _bootstrap(String company) async {
    try {
      final r = await _api.get('bootstrap', query: {if (company.isNotEmpty) 'company': company});
      final boot = Bootstrap(r.map);
      state = state.copyWith(boot: boot);
      if (versionBelow(_appVersion, boot.minClientVersion)) {
        state = state.copyWith(phase: Phase.update);
        return false;
      }
      if (boot.maintenance) {
        state = state.copyWith(phase: Phase.maintenance);
        return false;
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(phase: Phase.offline, error: e);
      return false;
    }
  }

  /// Saves the ERP address chosen on the connect screen (only when custom servers are allowed).
  Future<void> connect(String server, String company) async {
    final clean = server.trim().replaceAll(RegExp(r'/+$'), '');
    await _store.writeTarget(clean.startsWith('http') ? clean : 'https://$clean', company.trim());
    await start();
  }

  Future<void> loadMe() => refreshMe();

  Future<void> refreshMe({bool lockIfEnabled = false}) async {
    try {
      final me = Me((await _api.get('me')).map);
      _registerPush();
      final lock = lockIfEnabled && ref.read(settingsProvider).biometrics;
      state = state.copyWith(me: me, phase: lock ? Phase.locked : (me.isPending && me.workspaces.length > 1 ? Phase.chooseWorkspace : Phase.signedIn));
    } on ApiException catch (e) {
      if (e.endsSession || e.status == 401) {
        await _signedOutLocally(notice: e.message);
      } else {
        state = state.copyWith(phase: Phase.offline, error: e);
      }
    }
  }

  void unlocked() => state = state.copyWith(phase: Phase.signedIn);

  // ---- staff --------------------------------------------------------------------------------------------------

  /// Throws [ApiException] with code `mfa_required` when a code is needed; the caller repeats with [mfaCode].
  /// [company] is optional: the ERP finds the company from the address or the email, and asks for the
  /// code (field error `company`) only when it cannot.
  Future<void> staffLogin({String company = '', required String email, required String password, String? mfaCode}) async {
    final r = await _api.post('auth/staff/login', body: {
      if (company.trim().isNotEmpty) 'company': company.trim(),
      'email': email.trim(),
      'password': password,
      if (mfaCode != null && mfaCode.isNotEmpty) 'mfa_code': mfaCode.trim(),
      'device_name': deviceName,
    });
    final code = company.trim().isNotEmpty ? company.trim() : state.company;
    await _store.writeTarget(state.server, code);
    state = state.copyWith(company: code);
    await _adopt(r.map);
    await refreshMe();
  }

  // ---- customers and workers ----------------------------------------------------------------------------------

  /// Returns how the code was sent (`sms`, `whatsapp`, …) and how long it is valid.
  Future<(String, int)> requestOtp(String phone) async {
    final r = await _api.post('auth/otp/request', body: {'phone': phone});
    return (str(r.map['delivery']) ?? 'sms', integer(r.map['expires_in']) ?? 300);
  }

  /// Returns the claim status when an invitation code was used (`pending`, `active`) or null.
  /// With [register], a phone that has no workspace yet is registered as a new customer of this company
  /// (`auth/register`) before the app opens; the ERP decides whether that is allowed.
  Future<String?> verifyOtp({required String phone, required String code, String? name, String? invitation, ({String name, String email})? register}) async {
    final r = await _api.post('auth/otp/verify', body: {
      'phone': phone,
      'code': code,
      if (name != null && name.isNotEmpty) 'name': name,
      if (invitation != null && invitation.isNotEmpty) 'invitation_code': invitation,
      'device_name': deviceName,
    });
    await _adopt(r.map);
    var workspaces = maps(r.map['workspaces']);
    if (register != null && workspaces.isEmpty) {
      final reg = await _api.post('auth/register', body: {
        'name': register.name.trim(),
        if (register.email.trim().isNotEmpty) 'email': register.email.trim(),
        if (state.company.isNotEmpty) 'company': state.company,
      });
      final id = integer(reg.map['membership_id']);
      if (id != null) {
        await switchWorkspace(id);
        _registerPush();
        return str(reg.map['claim_status']);
      }
      workspaces = maps(reg.map['workspaces']);
    }
    final me = Me((await _api.get('me')).map);
    _registerPush();
    // a chooser only when the phone is linked to more than one company or record
    state = state.copyWith(me: me, phase: workspaces.length > 1 ? Phase.chooseWorkspace : Phase.signedIn);
    return str(r.map['claim_status']);
  }

  /// Signed in by phone but not linked to anything yet: ask the ERP to register this person as a new customer.
  Future<String?> registerCustomer({required String name, String email = ''}) async {
    final reg = await _api.post('auth/register', body: {
      'name': name.trim(),
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (state.company.isNotEmpty) 'company': state.company,
    });
    final id = integer(reg.map['membership_id']);
    if (id != null) {
      await switchWorkspace(id);
    } else {
      await refreshMe();
    }
    return str(reg.map['claim_status']);
  }

  Future<String?> claim(String invitation) async {
    final r = await _api.post('auth/claim', body: {'invitation_code': invitation});
    await refreshMe();
    return str(r.map['claim_status']);
  }

  Future<void> switchWorkspace(int membershipId) async {
    final r = await _api.post('auth/workspace', body: {'membership_id': membershipId});
    await _adopt(r.map);
    await ref.read(offlineStoreProvider).wipe();
    // every cached list, draft and file belongs to the old workspace
    state = state.copyWith(epoch: state.epoch + 1, clearMe: true, phase: Phase.loading);
    await refreshMe();
  }

  // ---- sign out -----------------------------------------------------------------------------------------------

  Future<void> signOut({bool everywhere = false}) async {
    await ref.read(pushProvider).unregister();
    try {
      await _api.post(everywhere ? 'auth/logout-all' : 'auth/logout');
    } catch (_) {
      // the local session is removed whatever the server answered
    }
    await _signedOutLocally();
  }

  Future<void> _adopt(Map<String, dynamic> m) async {
    final token = str(m['token']);
    if (token == null) throw ApiException(code: 'unexpected_response', message: 'The server did not return a session.');
    _session = StoredSession(server: state.server, company: state.company, token: token, expiresAt: date(m['expires_at']), tokenId: str(m['token_id']));
    _api.token = token;
    await _store.write(_session!);
  }

  void _registerPush() {
    ref.read(pushProvider).register(appVersion: _appVersion, locale: _api.locale).ignore();
  }

  Future<String?> _renew() async {
    final r = await _api.post('auth/token/renew');
    await _adopt(r.map);
    return _session?.token;
  }

  void _ended(ApiException e) => _signedOutLocally(notice: e.message);

  Future<void> _signedOutLocally({String? notice}) async {
    _session = null;
    _api.token = null;
    await _store.clearToken();
    await ref.read(offlineStoreProvider).wipe();
    state = state.copyWith(phase: Phase.signedOut, clearMe: true, notice: notice, epoch: state.epoch + 1);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in person. Only read inside signed-in screens.
final meProvider = Provider<Me>((ref) => ref.watch(sessionProvider).me ?? Me(const {}));

/// Watch this in data providers so they reload after a workspace switch or sign-out.
final epochProvider = Provider<int>((ref) => ref.watch(sessionProvider.select((s) => s.epoch)));
