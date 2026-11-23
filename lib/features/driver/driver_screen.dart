import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/session_controller.dart';
import '../../core/offline/offline_store.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';
import '../attendance/attendance_api.dart' show currentPosition;

final tripsProvider = FutureProvider.autoDispose.family<ApiResult, String>((ref, day) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('driver/trips', query: {'date': day});
});

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The signed-in driver's day. Each milestone is confirmed by the ERP before the screen changes.
class DriverScreen extends ConsumerStatefulWidget {
  const DriverScreen({super.key});

  @override
  ConsumerState<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends ConsumerState<DriverScreen> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final key = _ymd(_day);
    final trips = ref.watch(tripsProvider(key));
    return ModulePage(
      title: context.tr('module.driver'),
      subtitle: '${Fmt.weekday(_day, context.lang)} · ${Fmt.date(_day, context.lang)}',
      icon: Icons.local_shipping_rounded,
      onRefresh: () async => ref.invalidate(tripsProvider(key)),
      headerBottom: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final d = DateTime.now().add(Duration(days: i - 1));
            final on = _ymd(d) == key;
            return GestureDetector(
              onTap: () => setState(() => _day = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 54,
                decoration: BoxDecoration(color: on ? Palette.goldSoft : Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(Fmt.weekday(d, context.lang).characters.take(3).toString(), style: TextStyle(color: on ? Palette.navy : Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                  Text('${d.day}', style: TextStyle(color: on ? Palette.navy : Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
              ),
            );
          },
        ),
      ),
      children: [
        const _Outbox(),
        AsyncBody(
          value: trips,
          onRetry: () => ref.invalidate(tripsProvider(key)),
          builder: (r) => r.list.isEmpty
              ? EmptyView(icon: Icons.route_rounded, title: context.tr('trips.empty'))
              : Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text(context.tr('trips.tz', {'tz': r.meta['timezone'] ?? ''}), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
                  for (final t in r.list) _TripCard(t: t, onChanged: () => ref.invalidate(tripsProvider(key))),
                ]),
        ),
      ],
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.t, required this.onChanged});
  final Map<String, dynamic> t;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = strList(t['next']);
    final passengers = maps(t['passengers']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconBadge(Icons.directions_car_rounded, color: Palette.forStatus(str(t['status']))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${Fmt.time(date(t['scheduled_at']), context.lang)} · ${Fmt.humanize(str(t['purpose']))}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(str(t['reference']) ?? '', style: TextStyle(color: Theme.of(context).hintColor)),
                ]),
              ),
              StatusChip(str(t['status'])),
            ]),
            const SizedBox(height: 14),
            _Stop(icon: Icons.trip_origin_rounded, color: Palette.success, text: str(t['pickup']) ?? '—'),
            Padding(padding: const EdgeInsetsDirectional.only(start: 11), child: Container(width: 2, height: 14, color: Theme.of(context).dividerColor)),
            _Stop(icon: Icons.place_rounded, color: Palette.maroon, text: str(t['dropoff']) ?? '—'),
            if (str(t['notes']) != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(str(t['notes'])!, style: TextStyle(color: Theme.of(context).hintColor))),
            if (passengers.isNotEmpty) ...[
              const Divider(height: 24),
              for (final p in passengers)
                Row(children: [
                  const Icon(Icons.person_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(str(p['name']) ?? '')),
                  PopupMenuButton<String>(
                    tooltip: context.tr('trips.passenger'),
                    onSelected: (s) => _passenger(context, ref, p, s),
                    itemBuilder: (_) => [for (final s in const ['onboard', 'no_show', 'dropped']) PopupMenuItem(value: s, child: Text(statusLabel(context, s)))],
                    child: StatusChip(str(p['status'])),
                  ),
                ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _maps(str(t['dropoff']) ?? str(t['pickup'])), icon: const Icon(Icons.navigation_rounded), label: Text(context.tr('trips.navigate')))),
              const SizedBox(width: 8),
              IconButton.outlined(tooltip: context.tr('trips.proof'), onPressed: () => _proof(context, ref), icon: Icon(t['has_proof'] == true ? Icons.verified_rounded : Icons.photo_camera_rounded)),
              if (t['can_decline'] == true) ...[
                const SizedBox(width: 8),
                IconButton.outlined(tooltip: context.tr('trips.decline'), onPressed: () => _decline(context, ref), icon: const Icon(Icons.do_not_disturb_on_rounded, color: Palette.danger)),
              ],
            ]),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final n in next.where((n) => n != 'failed'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BusyButton(label: context.tr('trips.step.$n'), icon: Icons.arrow_forward_rounded, onPressed: () => _move(context, ref, n)),
                ),
              if (next.contains('failed'))
                TextButton.icon(onPressed: () => _move(context, ref, 'failed'), icon: const Icon(Icons.report_rounded, color: Palette.danger), label: Text(context.tr('trips.step.failed'), style: const TextStyle(color: Palette.danger))),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _maps(String? place) async {
    if (place == null) return;
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place)}'), mode: LaunchMode.externalApplication);
  }

  Future<void> _move(BuildContext context, WidgetRef ref, String to) async {
    final body = <String, dynamic>{'status': to, 'reported_at': DateTime.now().toUtc().toIso8601String()};
    if (to == 'failed') {
      final reason = await askText(context, title: context.tr('trips.step.failed'), hint: context.tr('reason'), required: true);
      if (reason == null) return;
      body['reason'] = reason;
    }
    if (to == 'completed' && t['pin_required'] == true) {
      if (!context.mounted) return;
      final pin = await askText(context, title: context.tr('trips.pin'), hint: context.tr('trips.pin_hint'), required: true, maxLines: 1);
      if (pin == null) return;
      body['pin'] = pin;
    }
    try {
      final pos = await currentPosition();
      body['lat'] = pos.latitude;
      body['lng'] = pos.longitude;
    } catch (_) {
      // location is optional for trip milestones
    }
    final key = ApiClient.newKey();
    final path = 'trips/${t['reference']}/status';
    try {
      await ref.read(apiProvider).post(path, body: body, idempotencyKey: key);
      onChanged();
      if (context.mounted) Toast.success(context, context.tr('saved'));
    } on ApiException catch (e) {
      if (e.isOffline && to != 'completed') {
        // no signal: keep the milestone with its time and place; it is sent when the connection is back
        final label = '${t['reference']} · ${context.tr('trips.step.$to')}';
        await ref.read(offlineStoreProvider).enqueue(OutboxItem(key: key, path: path, body: body, label: label));
        ref.read(outboxVersionProvider.notifier).state++;
        if (context.mounted) Toast.info(context, context.tr('outbox.queued'));
      } else if (context.mounted) {
        Toast.error(context, e);
      }
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final reason = await askText(context, title: context.tr('trips.decline'), hint: context.tr('reason'), required: true);
    if (reason == null) return;
    try {
      await ref.read(apiProvider).post('trips/${t['reference']}/decline', body: {'reason': reason});
      onChanged();
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }

  Future<void> _proof(BuildContext context, WidgetRef ref) async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 2000);
    if (x == null) return;
    try {
      await ref.read(apiProvider).upload('trips/${t['reference']}/proof', files: [File(x.path)], fileField: 'photo');
      onChanged();
      if (context.mounted) Toast.success(context, context.tr('trips.proof_saved'));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }

  Future<void> _passenger(BuildContext context, WidgetRef ref, Map<String, dynamic> p, String s) async {
    try {
      await ref.read(apiProvider).post('trips/${t['reference']}/passengers/${p['id']}', body: {'status': s});
      onChanged();
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: color, size: 24), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)))]);
}

/// Milestones saved on the phone while offline. Shown as pending until the ERP accepts them.
class _Outbox extends ConsumerStatefulWidget {
  const _Outbox();

  @override
  ConsumerState<_Outbox> createState() => _OutboxState();
}

class _OutboxState extends ConsumerState<_Outbox> {
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    final r = await ref.read(offlineStoreProvider).flush(ref.read(sessionProvider.notifier));
    ref.read(outboxVersionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.sent.isNotEmpty) {
      Toast.success(context, context.tr('outbox.sent', {'n': r.sent.length}));
      ref.invalidate(tripsProvider);
    }
    for (final (item, e) in r.refused) {
      Toast.error(context, ApiException(code: e.code, message: '${item.label}: ${e.message}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(outboxVersionProvider);
    final items = ref.read(offlineStoreProvider).outbox;
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.warning.withValues(alpha: .1), borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.warning.withValues(alpha: .4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.cloud_upload_rounded, color: Palette.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('outbox.pending', {'n': items.length}), style: const TextStyle(fontWeight: FontWeight.w800))),
            TextButton(onPressed: _busy ? null : _send, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.tr('outbox.send_now'))),
          ]),
          for (final i in items) Text('• ${i.label} · ${Fmt.time(i.createdAt, context.lang)}', style: const TextStyle(fontSize: 12.5)),
        ]),
      ),
    );
  }
}
