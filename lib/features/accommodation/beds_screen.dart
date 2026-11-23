import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';

final bedBoardProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('accommodation/board');
});

/// Bed board: properties → rooms → beds. Check a stay in or out; assigning new stays stays on the ERP web.
class BedsScreen extends ConsumerWidget {
  const BedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(bedBoardProvider);
    return ModulePage(
      title: context.tr('module.accommodation'),
      subtitle: context.tr('beds.tap_hint'),
      icon: Icons.bed_rounded,
      onRefresh: () async => ref.invalidate(bedBoardProvider),
      children: [
        AsyncBody(
          value: board,
          onRetry: () => ref.invalidate(bedBoardProvider),
          builder: (r) {
            final props = r.list;
            final free = <Map<String, dynamic>>[
              for (final p in props)
                for (final room in maps(p['rooms']))
                  for (final b in maps(room['beds']))
                    if (const {'available', 'free'}.contains(b['status']) && maps(b['stays']).isEmpty) {'id': b['id'], 'label': '${p['name']} · ${room['name']} · ${b['label']}'},
            ];
            if (props.isEmpty) return EmptyView(icon: Icons.apartment_rounded, title: context.tr('beds.empty'));
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 12, runSpacing: 6, children: [
                  for (final s in const ['free', 'reserved', 'occupied', 'blocked']) Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: _bedColor(s), borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 4),
                    Text(context.tr('beds.$s'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
              for (final p in props)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Section(
                    title: str(p['name']),
                    icon: Icons.apartment_rounded,
                    action: Text([Fmt.humanize(str(p['kind'])), if (p['gender'] != null) Fmt.humanize(str(p['gender']))].join(' · '), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final room in maps(p['rooms'])) ...[
                        Padding(padding: const EdgeInsets.only(top: 6, bottom: 6), child: Text(str(room['name']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                        Wrap(spacing: 8, runSpacing: 8, children: [for (final b in maps(room['beds'])) _Bed(bed: b, free: free)]),
                        const SizedBox(height: 6),
                      ],
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

Color _bedColor(String? s) => switch (s) { 'free' || 'available' => Palette.success, 'reserved' => Palette.warning, 'occupied' => Palette.maroon, _ => Palette.navySoft };

class _Bed extends ConsumerWidget {
  const _Bed({required this.bed, required this.free});
  final Map<String, dynamic> bed;
  final List<Map<String, dynamic>> free;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stays = maps(bed['stays']);
    final c = _bedColor(str(bed['status']));
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: stays.isNotEmpty
          ? () => _stay(context, ref, stays.first)
          : (const {'available', 'free'}.contains(bed['status']) && ref.read(meProvider).can('accommodation.edit') ? () => _assign(context, ref) : null),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: .35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.bed_rounded, size: 16, color: c), const SizedBox(width: 4), Expanded(child: Text(str(bed['label']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 4),
          Text(stays.isEmpty ? context.tr('beds.${bed['status']}') : (str(stays.first['name']) ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
        ]),
      ),
    );
  }

  Future<void> _stay(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(str(s['name']) ?? '', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('${Fmt.date(date(s['starts_on']), context.lang)} → ${s['ends_on'] == null ? '…' : Fmt.date(date(s['ends_on']), context.lang)}'),
          const SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(str(s['status']))),
          const SizedBox(height: 18),
          if (s['status'] == 'reserved') FilledButton.icon(onPressed: () => Navigator.pop(context, 'check-in'), icon: const Icon(Icons.login_rounded), label: Text(context.tr('beds.check_in'))),
          if (s['status'] == 'active' || s['status'] == 'checked_in') OutlinedButton.icon(onPressed: () => Navigator.pop(context, 'check-out'), icon: const Icon(Icons.logout_rounded), label: Text(context.tr('beds.check_out'))),
          if (free.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => Navigator.pop(context, 'move'), icon: const Icon(Icons.swap_horiz_rounded), label: Text(context.tr('beds.move'))),
          ],
        ]),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'move') return _move(context, ref, s);
    String? reason;
    if (action == 'check-out') {
      reason = await askText(context, title: context.tr('beds.check_out'), hint: context.tr('reason'));
      if (reason == null) return;
    } else if (!await confirmAction(context, title: context.tr('beds.check_in'), message: str(s['name']))) {
      return;
    }
    try {
      await ref.read(apiProvider).post('accommodation/stays/${s['id']}/$action', body: {if (reason != null) 'reason': reason}, idempotencyKey: ApiClient.newKey());
      ref.invalidate(bedBoardProvider);
      if (context.mounted) Toast.success(context, context.tr('saved'));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }

  Future<void> _move(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final to = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (context, scroll) => ListView(controller: scroll, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(context.tr('beds.move_to'), style: Theme.of(context).textTheme.titleLarge)),
          for (final b in free) ListTile(leading: const Icon(Icons.bed_rounded, color: Palette.success), title: Text('${b['label']}'), onTap: () => Navigator.pop(context, b)),
        ]),
      ),
    );
    if (to == null || !context.mounted) return;
    final reason = await askText(context, title: context.tr('beds.move'), hint: context.tr('beds.move_reason'), required: true);
    if (reason == null) return;
    try {
      await ref.read(apiProvider).post('accommodation/stays/${s['id']}/move', body: {'bed_id': to['id'], 'reason': reason}, idempotencyKey: ApiClient.newKey());
      ref.invalidate(bedBoardProvider);
      if (context.mounted) Toast.success(context, context.tr('saved'));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final person = await showModalBottomSheet<Map<String, dynamic>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _SubjectSearch());
    if (person == null || !context.mounted) return;
    if (person['current_stay_id'] != null) {
      Toast.info(context, context.tr('beds.has_bed'));
      return;
    }
    if (!await confirmAction(context, title: context.tr('beds.assign_q', {'name': person['name'], 'bed': bed['label']}), icon: Icons.bed_rounded)) return;
    try {
      await ref.read(apiProvider).post('accommodation/stays', body: {'bed_id': bed['id'], 'subject_type': person['type'], 'subject_id': person['id']}, idempotencyKey: ApiClient.newKey());
      ref.invalidate(bedBoardProvider);
      if (context.mounted) Toast.success(context, context.tr('saved'));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}

/// Finds a worker or candidate by name (server search, 2+ letters).
class _SubjectSearch extends ConsumerStatefulWidget {
  const _SubjectSearch();

  @override
  ConsumerState<_SubjectSearch> createState() => _SubjectSearchState();
}

class _SubjectSearchState extends ConsumerState<_SubjectSearch> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  bool _busy = false;
  Object? _error;
  int _seq = 0;

  Future<void> _search(String q) async {
    final seq = ++_seq;
    if (q.trim().length < 2) {
      setState(() => _rows = const []);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).get('accommodation/subjects', query: {'q': q.trim()});
      if (mounted && seq == _seq) {
        setState(() {
          _rows = r.list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e);
    } finally {
      if (mounted && seq == _seq) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(children: [
            TextField(
              controller: _q,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('beds.search'), suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null),
            ),
            const SizedBox(height: 8),
            if (_error != null) ErrorView(error: _error!, onRetry: () => _search(_q.text)),
            Expanded(
              child: ListView(children: [
                for (final p in _rows)
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(str(p['name']) ?? ''),
                    subtitle: Text([str(p['type_label']), if (p['current_stay_id'] != null) context.tr('beds.has_bed')].whereType<String>().join(' · ')),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ]),
            ),
          ]),
        ),
      );
}
