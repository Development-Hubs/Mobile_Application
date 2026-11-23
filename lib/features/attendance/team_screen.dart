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

final teamBoardProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('attendance/team');
});

final teamApprovalsProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('attendance/approvals');
});

/// HR / managers: today's team board, and correction requests to approve or reject.
class TeamAttendanceScreen extends ConsumerStatefulWidget {
  const TeamAttendanceScreen({super.key, this.approvals = false});
  final bool approvals;

  @override
  ConsumerState<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends ConsumerState<TeamAttendanceScreen> {
  late String _tab = widget.approvals ? 'approvals' : 'board';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final canDecide = me.can('hrm.edit');
    final canView = me.can('hrm.view') || canDecide;
    final tabs = {if (canView) 'board': context.tr('team.board'), if (canDecide) 'approvals': context.tr('team.approvals')};
    final tab = tabs.containsKey(_tab) ? _tab : tabs.keys.first;
    return ModulePage(
      title: context.tr('module.team_attendance'),
      subtitle: Fmt.date(DateTime.now(), context.lang),
      icon: Icons.groups_rounded,
      onRefresh: () async {
        ref.invalidate(teamBoardProvider);
        ref.invalidate(teamApprovalsProvider);
      },
      headerBottom: FilterChips(options: tabs, value: tab, onChanged: (t) => setState(() => _tab = t)),
      children: [tab == 'board' ? _board(context) : _approvals(context)],
    );
  }

  Widget _board(BuildContext context) {
    final data = ref.watch(teamBoardProvider);
    return AsyncBody(
      value: data,
      onRetry: () => ref.invalidate(teamBoardProvider),
      builder: (r) {
        final counts = obj(r.meta['counts']);
        final rows = r.list.where((x) => _filter == 'all' || x['status'] == _filter).toList();
        const order = ['in', 'break', 'out', 'absent', 'waiting', 'leave', 'day_off'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 92,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              _CountCard(label: context.tr('team.all'), value: r.list.length, color: Palette.navySoft, on: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
              for (final s in order)
                if ((integer(counts[s]) ?? 0) > 0)
                  _CountCard(label: context.tr('team.status.$s'), value: integer(counts[s]) ?? 0, color: _color(s), on: _filter == s, onTap: () => setState(() => _filter = s)),
            ]),
          ),
          if (rows.isEmpty) EmptyView(icon: Icons.groups_2_rounded, title: context.tr('empty')),
          for (final (i, x) in rows.indexed)
            Reveal(
              index: i,
              child: ListRow(
                icon: Icons.person_rounded,
                iconColor: _color(str(x['status'])),
                title: str(x['name']) ?? '',
                subtitle: [str(x['designation']), if (x['first_in'] != null) '${x['first_in']} → ${x['last_out'] ?? '…'}', if ((integer(x['worked_seconds']) ?? 0) > 0) Fmt.hm(integer(x['worked_seconds'])!)]
                    .whereType<String>()
                    .join(' · '),
                meta: [if ((integer(x['late_minutes']) ?? 0) > 0) context.tr('team.late', {'m': x['late_minutes']}), if (x['away'] == true) context.tr('team.away')].join(' · '),
                trailing: StatusChip(str(x['status']), label: context.tr('team.status.${x['status']}')),
              ),
            ),
        ]);
      },
    );
  }

  Widget _approvals(BuildContext context) {
    final data = ref.watch(teamApprovalsProvider);
    return AsyncBody(
      value: data,
      onRetry: () => ref.invalidate(teamApprovalsProvider),
      builder: (r) => r.list.isEmpty
          ? EmptyView(icon: Icons.task_alt_rounded, title: context.tr('team.no_approvals'))
          : Column(children: [
              for (final (i, c) in r.list.indexed)
                Reveal(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            const IconBadge(Icons.edit_calendar_rounded, color: Palette.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(str(c['name']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${Fmt.date(date(c['date']), context.lang)} · ${c['kind_label'] ?? ''}', style: TextStyle(color: Theme.of(context).hintColor)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            if (c['check_in'] != null) Chip(avatar: const Icon(Icons.login_rounded, size: 16), label: Text('${c['check_in']}')),
                            if (c['check_out'] != null) Chip(avatar: const Icon(Icons.logout_rounded, size: 16), label: Text('${c['check_out']}')),
                            if (c['break_minutes'] != null) Chip(avatar: const Icon(Icons.coffee_rounded, size: 16), label: Text('${c['break_minutes']}m')),
                          ]),
                          if (str(c['reason']) != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${c['reason']}”', style: const TextStyle(fontStyle: FontStyle.italic))),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Palette.danger),
                                onPressed: () => _decide(c, 'reject'),
                                icon: const Icon(Icons.close_rounded),
                                label: Text(context.tr('team.reject')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Palette.success, minimumSize: const Size.fromHeight(50)),
                                onPressed: () => _decide(c, 'approve'),
                                icon: const Icon(Icons.check_rounded),
                                label: Text(context.tr('team.approve')),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
    );
  }

  Future<void> _decide(Map<String, dynamic> c, String decision) async {
    String? note;
    if (decision == 'reject') {
      note = await askText(context, title: context.tr('team.reject'), hint: context.tr('team.reject_hint'));
      if (note == null) return;
    } else if (!await confirmAction(context, title: context.tr('team.approve_q'), message: context.tr('team.approve_body'), icon: Icons.check_circle_rounded)) {
      return;
    }
    try {
      await ref.read(apiProvider).post('attendance/approvals/${c['id']}/$decision', body: {if (note != null && note.isNotEmpty) 'note': note}, idempotencyKey: ApiClient.newKey());
      ref.invalidate(teamApprovalsProvider);
      ref.invalidate(teamBoardProvider);
      if (mounted) Toast.success(context, context.tr(decision == 'approve' ? 'team.approved' : 'team.rejected'));
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    }
  }

  Color _color(String? s) => switch (s) {
        'in' => Palette.success,
        'break' => Palette.warning,
        'out' => Palette.navySoft,
        'absent' => Palette.danger,
        'leave' || 'day_off' => Palette.info,
        _ => Palette.gold,
      };
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value, required this.color, required this.on, required this.onTap});
  final String label;
  final int value;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MotionScope.duration(context, const Duration(milliseconds: 200)),
            width: 96,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: on ? color : color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: .35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: on ? Colors.white : color)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : null)),
            ]),
          ),
        ),
      );
}
