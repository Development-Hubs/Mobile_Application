import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';
import 'attendance_api.dart';

class AttendanceMonthScreen extends ConsumerStatefulWidget {
  const AttendanceMonthScreen({super.key});

  @override
  ConsumerState<AttendanceMonthScreen> createState() => _AttendanceMonthScreenState();
}

class _AttendanceMonthScreenState extends ConsumerState<AttendanceMonthScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _shift(int by) {
    final next = DateTime(_month.year, _month.month + by);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(attendanceMonthProvider(_key));
    return ModulePage(
      title: context.tr('attendance.month'),
      subtitle: Fmt.month(_month, context.lang),
      icon: Icons.calendar_month_rounded,
      onRefresh: () async => ref.invalidate(attendanceMonthProvider(_key)),
      headerBottom: Row(children: [
        GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: context.tr('previous'), onTap: () => _shift(-1)),
        Expanded(child: Center(child: Text(Fmt.month(_month, context.lang), style: Theme.of(context).textTheme.titleLarge))),
        GlassIconButton(icon: Icons.chevron_right_rounded, tooltip: context.tr('next'), onTap: () => _shift(1)),
      ]),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(attendanceMonthProvider(_key)),
          builder: (r) {
            final days = maps(r.map['days']);
            final totals = obj(r.map['totals']);
            if (days.isEmpty) return EmptyView(icon: Icons.event_busy_rounded, title: context.tr('attendance.month_empty'));
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: StatTile(label: context.tr('attendance.present'), value: '${totals['present'] ?? 0}', icon: Icons.check_circle_rounded, color: Palette.success)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: context.tr('attendance.late_days'), value: '${totals['late'] ?? 0}', icon: Icons.schedule_rounded, color: Palette.warning)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: context.tr('attendance.absent'), value: '${totals['absent'] ?? 0}', icon: Icons.cancel_rounded, color: Palette.danger)),
                ]),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Section(
                  title: context.tr('attendance.hours', {'h': Fmt.hm((integer(totals['worked']) ?? 0) * 60)}),
                  icon: Icons.timelapse_rounded,
                  child: _Grid(month: _month, days: days),
                ),
              ),
              const SizedBox(height: 10),
              for (final (i, d) in days.where((d) => d['future'] != true && (d['check_in'] != null || d['status'] == 'absent')).toList().reversed.indexed)
                Reveal(
                  index: i,
                  child: ListRow(
                    icon: Icons.today_rounded,
                    iconColor: Palette.forStatus(str(d['status'])),
                    title: '${Fmt.weekday(date(d['date']), context.lang)} · ${Fmt.dayMonth(date(d['date']), context.lang)}',
                    subtitle: d['check_in'] == null ? null : '${d['check_in']} → ${d['check_out'] ?? '…'} · ${Fmt.hm((integer(d['worked_minutes']) ?? 0) * 60)}',
                    trailing: StatusChip(str(d['status'])),
                    onTap: () => _daySheet(context, d),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }

  void _daySheet(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(Fmt.date(date(d['date']), context.lang), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(str(d['status']))),
          const SizedBox(height: 16),
          _kv(context, 'attendance.first_in', d['check_in'] ?? '—'),
          _kv(context, 'attendance.last_out', d['check_out'] ?? '—'),
          _kv(context, 'attendance.worked', Fmt.hm((integer(d['worked_minutes']) ?? 0) * 60)),
          _kv(context, 'attendance.break', Fmt.hm((integer(d['break_minutes']) ?? 0) * 60)),
          _kv(context, 'attendance.late', '${d['late_minutes'] ?? 0}m'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/attendance/corrections', extra: str(d['date']));
            },
            icon: const Icon(Icons.edit_calendar_rounded),
            label: Text(context.tr('attendance.fix_this_day')),
          ),
        ]),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, Object v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(context.tr(k), style: TextStyle(color: Theme.of(context).hintColor))), Text('$v', style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.month, required this.days});
  final DateTime month;
  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in days) date(d['date'])?.day: d};
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday % 7; // Sunday first, as in Qatar
    final count = DateTime(month.year, month.month + 1, 0).day;
    final names = List.generate(7, (i) => Fmt.weekday(DateTime(2024, 9, 1 + i), context.lang).characters.take(context.lang == 'ar' ? 3 : 2).toString());
    return Column(children: [
      Row(children: names.map((n) => Expanded(child: Center(child: Text(n, style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w700, fontSize: 12))))).toList()),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var day = 1; day <= count; day++) _cell(context, day, byDay[day]),
        ],
      ),
    ]);
  }

  Widget _cell(BuildContext context, int day, Map<String, dynamic>? d) {
    final status = str(d?['status']);
    final future = d?['future'] == true;
    final today = d?['today'] == true;
    final c = status == null || future ? Colors.transparent : Palette.forStatus(status);
    return AnimatedContainer(
      duration: MotionScope.duration(context, const Duration(milliseconds: 300)),
      decoration: BoxDecoration(
        color: c == Colors.transparent ? null : c.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10),
        border: today ? Border.all(color: Palette.maroon, width: 2) : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$day', style: TextStyle(fontWeight: FontWeight.w700, color: future ? Theme.of(context).hintColor.withValues(alpha: .5) : null)),
        if (c != Colors.transparent) Container(margin: const EdgeInsets.only(top: 2), width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      ]),
    );
  }
}

/// My correction requests and a form to ask for a new one. Managers approve on the web.
class CorrectionsScreen extends ConsumerWidget {
  const CorrectionsScreen({super.key, this.forDate});

  /// Day to pre-fill when opened from the month calendar (YYYY-MM-DD).
  final String? forDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(correctionsProvider);
    return ModulePage(
      title: context.tr('attendance.fix'),
      subtitle: context.tr('attendance.fix_body'),
      icon: Icons.edit_calendar_rounded,
      onRefresh: () async => ref.invalidate(correctionsProvider),
      fab: FloatingActionButton.extended(
        backgroundColor: Palette.maroon,
        foregroundColor: Colors.white,
        onPressed: () => _form(context, ref, obj(data.valueOrNull?.meta['kinds'])),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('attendance.new_fix')),
      ),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(correctionsProvider),
          builder: (r) => r.list.isEmpty
              ? EmptyView(icon: Icons.fact_check_rounded, title: context.tr('attendance.no_fixes'))
              : Column(children: [
                  for (final (i, c) in r.list.indexed)
                    Reveal(
                      index: i,
                      child: ListRow(
                        icon: Icons.edit_note_rounded,
                        iconColor: Palette.forStatus(str(c['status'])),
                        title: '${Fmt.date(date(c['date']), context.lang)} · ${c['kind_label'] ?? ''}',
                        subtitle: [if (c['check_in'] != null) '${context.tr('attendance.first_in')} ${c['check_in']}', if (c['check_out'] != null) '${context.tr('attendance.last_out')} ${c['check_out']}', c['reason'] ?? '']
                            .where((e) => e.toString().isNotEmpty)
                            .join(' · '),
                        meta: c['decided_by'] != null ? '${c['decided_by']}${c['decision_note'] != null ? ' — ${c['decision_note']}' : ''}' : null,
                        trailing: StatusChip(str(c['status'])),
                      ),
                    ),
                ]),
        ),
      ],
    );
  }

  Future<void> _form(BuildContext context, WidgetRef ref, Map<String, dynamic> kinds) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CorrectionForm(kinds: kinds, initialDate: forDate),
    );
    if (created == true) ref.invalidate(correctionsProvider);
  }
}

class _CorrectionForm extends ConsumerStatefulWidget {
  const _CorrectionForm({required this.kinds, this.initialDate});
  final Map<String, dynamic> kinds;
  final String? initialDate;

  @override
  ConsumerState<_CorrectionForm> createState() => _CorrectionFormState();
}

class _CorrectionFormState extends ConsumerState<_CorrectionForm> {
  late DateTime _date = DateTime.tryParse(widget.initialDate ?? '') ?? DateTime.now().subtract(const Duration(days: 1));
  String _kind = 'missed_out';
  TimeOfDay? _in, _out;
  final _reason = TextEditingController();
  final _key = ApiClient.newKey();
  ApiException? _error;

  String _t(TimeOfDay? t) => t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final kinds = widget.kinds.isEmpty ? {'missed_out': 'Forgot to check out', 'missed_in': 'Forgot to check in', 'wrong_time': 'Wrong time', 'break': 'Break time', 'absent': 'Marked absent but worked'} : widget.kinds;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('attendance.new_fix'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const IconBadge(Icons.event_rounded),
            title: Text(context.tr('attendance.day')),
            subtitle: Text(Fmt.date(_date, context.lang)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kinds.containsKey(_kind) ? _kind : kinds.keys.first,
            decoration: InputDecoration(labelText: context.tr('attendance.what')),
            items: kinds.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value}'))).toList(),
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _timeField(context, 'attendance.first_in', _in, (t) => setState(() => _in = t))),
            const SizedBox(width: 10),
            Expanded(child: _timeField(context, 'attendance.last_out', _out, (t) => setState(() => _out = t))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _reason, maxLines: 3, decoration: InputDecoration(labelText: context.tr('attendance.reason'), errorText: _error?.fieldError('reason'))),
          if (_error != null && _error!.fields.isEmpty) ...[const SizedBox(height: 8), Text(_error!.message, style: const TextStyle(color: Palette.danger))],
          const SizedBox(height: 18),
          BusyButton(
            label: context.tr('attendance.send_fix'),
            icon: Icons.send_rounded,
            onPressed: () async {
              setState(() => _error = null);
              try {
                await ref.read(apiProvider).post('attendance/corrections', idempotencyKey: _key, body: {
                  'date': '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                  'kind': _kind,
                  if (_in != null) 'check_in': _t(_in),
                  if (_out != null) 'check_out': _t(_out),
                  'reason': _reason.text.trim(),
                });
                if (!context.mounted) return;
                Toast.success(context, context.tr('attendance.fix_sent'));
                Navigator.pop(context, true);
              } on ApiException catch (e) {
                setState(() => _error = e);
              }
            },
          ),
        ]),
      ),
    );
  }

  Widget _timeField(BuildContext context, String label, TimeOfDay? value, ValueChanged<TimeOfDay> set) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: value ?? const TimeOfDay(hour: 8, minute: 0));
          if (t != null) set(t);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: context.tr(label), prefixIcon: const Icon(Icons.schedule_rounded)),
          child: Text(value == null ? '—' : _t(value), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
