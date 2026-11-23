import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final calendarProvider = FutureProvider.autoDispose.family<ApiResult, String>((ref, from) async {
  ref.watch(epochProvider);
  final start = DateTime.parse(from);
  return ref.read(apiProvider).get('calendar', query: {'from': from, 'to': _ymd(start.add(const Duration(days: 30)))});
});

/// Agenda for the next 30 days with RSVP. Answering an invitation is not attendance.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _from = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final key = _ymd(_from);
    final data = ref.watch(calendarProvider(key));
    return ModulePage(
      title: context.tr('module.calendar'),
      subtitle: '${Fmt.dayMonth(_from, context.lang)} – ${Fmt.dayMonth(_from.add(const Duration(days: 30)), context.lang)}',
      icon: Icons.event_rounded,
      onRefresh: () async => ref.invalidate(calendarProvider(key)),
      headerBottom: Row(children: [
        GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: context.tr('previous'), onTap: () => setState(() => _from = _from.subtract(const Duration(days: 30)))),
        const Spacer(),
        TextButton(onPressed: () => setState(() => _from = DateTime.now()), child: Text(context.tr('today'))),
        const Spacer(),
        GlassIconButton(icon: Icons.chevron_right_rounded, tooltip: context.tr('next'), onTap: () => setState(() => _from = _from.add(const Duration(days: 30)))),
      ]),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(calendarProvider(key)),
          builder: (r) {
            final events = [...r.list]..sort((a, b) => (str(a['starts_at']) ?? '').compareTo(str(b['starts_at']) ?? ''));
            if (events.isEmpty) return EmptyView(icon: Icons.event_available_rounded, title: context.tr('calendar.empty'));
            final groups = <String, List<Map<String, dynamic>>>{};
            for (final e in events) {
              groups.putIfAbsent(_ymd(date(e['starts_at']) ?? DateTime.now()), () => []).add(e);
            }
            var i = 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(children: [
                    Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(gradient: Palette.heroGradient, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Text('${DateTime.parse(g.key).day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Text(Fmt.weekday(DateTime.parse(g.key), context.lang), style: Theme.of(context).textTheme.titleMedium),
                  ]),
                ),
                for (final e in g.value) Reveal(index: i++, child: _Event(e: e, onChanged: () => ref.invalidate(calendarProvider(key)))),
              ],
            ]);
          },
        ),
      ],
    );
  }
}

class _Event extends ConsumerWidget {
  const _Event({required this.e, required this.onChanged});
  final Map<String, dynamic> e;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = e['invitation'] is Map ? obj(e['invitation']) : null;
    final start = date(e['starts_at']), end = date(e['ends_at']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: Palette.forStatus(str(e['type'])), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(e['title']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(e['all_day'] == true ? context.tr('calendar.all_day') : '${Fmt.time(start, context.lang)} – ${Fmt.time(end, context.lang)}${str(e['location']) != null ? ' · ${e['location']}' : ''}',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ]),
              ),
              StatusChip(str(e['status'])),
            ]),
            if (inv != null) ...[
              const SizedBox(height: 10),
              SegmentedButton<String>(
                emptySelectionAllowed: true,
                segments: [
                  ButtonSegment(value: 'accepted', icon: const Icon(Icons.check_rounded), label: Text(context.tr('calendar.yes'))),
                  ButtonSegment(value: 'tentative', icon: const Icon(Icons.help_outline_rounded), label: Text(context.tr('calendar.maybe'))),
                  ButtonSegment(value: 'declined', icon: const Icon(Icons.close_rounded), label: Text(context.tr('calendar.no'))),
                ],
                selected: {if (const {'accepted', 'tentative', 'declined'}.contains(inv['response'])) inv['response'] as String},
                onSelectionChanged: (s) async {
                  if (s.isEmpty) return;
                  try {
                    await ref.read(apiProvider).post('calendar/invitations/${inv['id']}/respond', body: {'response': s.first}, idempotencyKey: ApiClient.newKey());
                    onChanged();
                  } on ApiException catch (err) {
                    if (context.mounted) Toast.error(context, err);
                  }
                },
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
