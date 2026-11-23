import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_exception.dart';
import '../auth/session_controller.dart';
import '../settings/app_settings.dart';

/// Things kept on the phone while offline, inside the app sandbox only:
///
/// * **Drafts** — unsent case text, so nothing typed is lost.
/// * **Outbox** — driver trip milestones, sent later with the original `reported_at`, location and
///   `Idempotency-Key`, so a late resend is accepted once by the ERP.
///
/// Both are shown as *pending* until the ERP answers, and both are wiped on sign-out and workspace switch.
/// Case creation, bed moves, assessments and anything with money are never queued: they need a live answer.
class OfflineStore {
  OfflineStore(this._p);
  final SharedPreferences _p;

  static const _draft = 'oc.draft.';
  static const _outbox = 'oc.outbox';

  String? draft(String key) => _p.getString('$_draft$key');

  Future<void> saveDraft(String key, String text) => text.trim().isEmpty ? _p.remove('$_draft$key') : _p.setString('$_draft$key', text);

  Future<void> clearDraft(String key) => _p.remove('$_draft$key');

  List<OutboxItem> get outbox {
    final raw = _p.getString(_outbox);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).whereType<Map>().map((m) => OutboxItem.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<OutboxItem> items) => _p.setString(_outbox, jsonEncode(items.map((e) => e.toJson()).toList()));

  Future<void> enqueue(OutboxItem item) async => _write([...outbox.where((e) => e.key != item.key), item]);

  Future<void> remove(String key) async => _write(outbox.where((e) => e.key != key).toList());

  Future<void> wipe() async {
    for (final k in _p.getKeys().where((k) => k.startsWith(_draft)).toList()) {
      await _p.remove(k);
    }
    await _p.remove(_outbox);
  }

  /// Sends queued items. Items the ERP refuses (4xx other than a timeout) are dropped and returned, so the
  /// person sees what failed; items that still cannot reach the ERP stay queued.
  Future<OutboxResult> flush(SessionController session) async {
    final api = session.api;
    final sent = <OutboxItem>[], refused = <(OutboxItem, ApiException)>[];
    for (final item in outbox) {
      try {
        await api.post(item.path, body: item.body, idempotencyKey: item.key);
        await remove(item.key);
        sent.add(item);
      } on ApiException catch (e) {
        if (e.isOffline || (e.status ?? 0) >= 500 || e.code == 'request_in_progress') break;
        await remove(item.key);
        refused.add((item, e));
      }
    }
    return OutboxResult(sent, refused);
  }
}

class OutboxItem {
  OutboxItem({required this.key, required this.path, required this.body, required this.label, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();

  final String key;
  final String path;
  final Map<String, dynamic> body;
  final String label;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'key': key, 'path': path, 'body': body, 'label': label, 'created_at': createdAt.toIso8601String()};

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
        key: j['key'] as String,
        path: j['path'] as String,
        body: Map<String, dynamic>.from(j['body'] as Map),
        label: (j['label'] ?? '') as String,
        createdAt: DateTime.tryParse('${j['created_at']}'),
      );
}

class OutboxResult {
  const OutboxResult(this.sent, this.refused);
  final List<OutboxItem> sent;
  final List<(OutboxItem, ApiException)> refused;
}

final offlineStoreProvider = Provider<OfflineStore>((ref) => OfflineStore(ref.read(sharedPrefsProvider)));

/// Bumps when the outbox changes, so screens can show the pending count.
final outboxVersionProvider = StateProvider<int>((ref) => 0);
