import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/session_controller.dart';

/// Push notifications through Firebase Cloud Messaging (Android) and APNs via FCM (iOS).
///
/// Push only works once the Firebase files of your own Firebase project are added to the build
/// (`flutterfire configure`, see docs/push.md). Without them [init] fails quietly and the app keeps
/// working with the in-app inbox, which is always the source of truth.
class PushService {
  PushService(this._api);
  final ApiClient _api;

  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refresh;

  /// Called with the `link` of a tapped notification (e.g. `onesource://cases/…`).
  void Function(String link)? onOpenLink;

  /// Called when a notification arrives while the app is open.
  void Function()? onForeground;

  bool get available => _ready;

  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('Push disabled: Firebase is not configured for this build ($e)');
      return;
    }
    FirebaseMessaging.onMessage.listen((_) => onForeground?.call());
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _open(initial);
  }

  void _open(RemoteMessage m) {
    final link = m.data['link']?.toString();
    if (link != null && link.isNotEmpty) onOpenLink?.call(link);
  }

  /// Asks for permission and registers this device with the ERP after sign-in.
  Future<void> register({required String appVersion, required String locale}) async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      _token = await FirebaseMessaging.instance.getToken();
      if (_token == null) return;
      await _send(_token!, appVersion, locale);
      _refresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _send(t, appVersion, locale).ignore();
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _send(String token, String appVersion, String locale) =>
      _api.post('devices/push', body: {'platform': Platform.isIOS ? 'ios' : 'android', 'push_token': token, 'app_version': appVersion, 'locale': locale});

  /// Stops pushes to this device; called before sign-out while the token is still valid.
  Future<void> unregister() async {
    if (!_ready || _token == null) return;
    try {
      await _api.delete('devices/push');
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // sign-out continues; the ERP also stops pushes when the session token is revoked
    }
    _token = null;
  }
}

final pushProvider = Provider<PushService>((ref) => PushService(ref.read(apiProvider)));
