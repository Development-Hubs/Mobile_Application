import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/widgets/ui.dart';
import 'attendance_api.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(attendanceProvider);
    return ModulePage(
      title: context.tr('module.attendance'),
      subtitle: Fmt.weekday(DateTime.now(), context.lang) + ' · ' + Fmt.date(DateTime.now(), context.lang),
      icon: Icons.fingerprint_rounded,
      trailing: GlassIconButton(icon: Icons.calendar_month_rounded, tooltip: context.tr('attendance.month'), onTap: () => context.push('/attendance/month')),
      onRefresh: () => ref.read(attendanceProvider.notifier).reload(),
      children: [
        AsyncBody<AttendanceDay>(
          value: day,
          onRetry: () => ref.invalidate(attendanceProvider),
          builder: (d) => d.linked ? _Today(day: d) : EmptyView(icon: Icons.link_off_rounded, title: context.tr('attendance.not_linked'), message: context.tr('attendance.not_linked_body')),
        ),
      ],
    );
  }
}

class _Today extends ConsumerStatefulWidget {
  const _Today({required this.day});
  final AttendanceDay day;

  @override
  ConsumerState<_Today> createState() => _TodayState();
}

class _TodayState extends ConsumerState<_Today> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _punch(String type) async {
    final d = widget.day;
    if (type == 'out') {
      final worked = Fmt.hm(d.liveWorked(_now));
      final ok = await confirmAction(context,
          title: context.tr('attendance.confirm_out'), message: context.tr('attendance.confirm_out_body', {'worked': worked}), confirm: context.tr('attendance.out'), icon: Icons.logout_rounded);
      if (!ok) return;
    }
    if (!mounted) return;
    final key = ApiClient.newKey(); // one key per tap; a lost answer is never punched twice
    try {
      final day = await ref.read(attendanceProvider.notifier).punch(type, idempotencyKey: key);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Toast.success(context, context.tr('attendance.saved.$type', {'time': day.timeline.isNotEmpty ? day.timeline.last['time'] : ''}));
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final worked = d.liveWorked(_now);
    final brk = d.liveBreak(_now);
    final progress = d.targetSeconds == 0 ? 0.0 : (worked / d.targetSeconds).clamp(0.0, 1.0).toDouble();
    final stateColor = switch (d.state) { 'in' => Palette.success, 'break' => Palette.warning, 'out' => Palette.navySoft, _ => Palette.maroon };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.dayOff || d.onLeave)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _Banner(icon: d.onLeave ? Icons.beach_access_rounded : Icons.weekend_rounded, text: context.tr(d.onLeave ? 'attendance.on_leave' : 'attendance.day_off'), color: Palette.info),
        ),
      if (d.missingOut)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _Banner(icon: Icons.warning_amber_rounded, text: context.tr('attendance.missing_out'), color: Palette.warning),
        ),
      Reveal(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(children: [
                Semantics(
                  label: '${context.tr('attendance.worked')} ${Fmt.hm(worked)}',
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(alignment: Alignment.center, children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: MotionScope.duration(context, const Duration(milliseconds: 900)),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => CustomPaint(size: const Size.square(240), painter: _RingPainter(v, d.state == 'break' ? Palette.warning : Palette.maroon, Theme.of(context).brightness == Brightness.dark)),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        _Pulse(active: d.state == 'in' || d.state == 'break', color: stateColor, child: StatusChip(d.state, label: context.tr('attendance.state.${d.state}'))),
                        const SizedBox(height: 10),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(Fmt.clock(d.state == 'break' ? brk : worked),
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 38)),
                        ),
                        Text(context.tr(d.state == 'break' ? 'attendance.on_break_for' : 'attendance.worked_today'), style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(context.tr('attendance.target', {'h': Fmt.hm(d.targetSeconds)}), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                if (d.actions.isEmpty)
                  Text(context.tr('attendance.no_actions'), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor))
                else
                  ..._buttons(d),
                if (d.needsLocation) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.location_on_rounded, size: 16, color: Theme.of(context).hintColor),
                    const SizedBox(width: 4),
                    Flexible(child: Text(context.tr('attendance.location_note'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Reveal(
          index: 1,
          child: Row(children: [
            Expanded(child: _Mini(icon: Icons.login_rounded, label: context.tr('attendance.first_in'), value: d.firstIn ?? '—', color: Palette.success)),
            const SizedBox(width: 10),
            Expanded(child: _Mini(icon: Icons.logout_rounded, label: context.tr('attendance.last_out'), value: d.lastOut ?? '—', color: Palette.navySoft)),
            const SizedBox(width: 10),
            Expanded(
                child: _Mini(
                    icon: Icons.coffee_rounded,
                    label: context.tr('attendance.break'),
                    value: d.breakAllowance > 0 ? '${Fmt.hm(brk)} / ${Fmt.hm(d.breakAllowance)}' : Fmt.hm(brk),
                    color: brk > d.breakAllowance && d.breakAllowance > 0 ? Palette.danger : Palette.warning)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Reveal(
          index: 2,
          child: Row(children: [
            Expanded(child: _Mini(icon: Icons.schedule_rounded, label: context.tr('attendance.shift'), value: d.shiftStart != null ? '${d.shiftStart} – ${d.shiftEnd ?? ''}' : '—', color: Palette.info)),
            const SizedBox(width: 10),
            Expanded(child: _Mini(icon: Icons.timer_off_rounded, label: context.tr('attendance.late'), value: d.lateMinutes > 0 ? '${d.lateMinutes}m' : '0', color: d.lateMinutes > 0 ? Palette.danger : Palette.success)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Reveal(
          index: 3,
          child: Section(
            title: context.tr('attendance.timeline'),
            icon: Icons.timeline_rounded,
            child: d.timeline.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(context.tr('attendance.timeline_empty'), style: TextStyle(color: Theme.of(context).hintColor)))
                : Column(children: [for (final (i, p) in d.timeline.indexed) _TimelineRow(p: p, last: i == d.timeline.length - 1)]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/attendance/month'), icon: const Icon(Icons.calendar_month_rounded), label: Text(context.tr('attendance.month')))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/attendance/corrections'), icon: const Icon(Icons.edit_calendar_rounded), label: Text(context.tr('attendance.fix')))),
        ]),
      ),
    ]);
  }

  List<Widget> _buttons(AttendanceDay d) {
    final primary = d.actions.first;
    const icons = {'in': Icons.login_rounded, 'out': Icons.logout_rounded, 'break_start': Icons.coffee_rounded, 'break_end': Icons.play_arrow_rounded};
    final out = <Widget>[
      BusyButton(
        label: context.tr('attendance.$primary'),
        icon: icons[primary],
        gradient: primary == 'in'
            ? const LinearGradient(colors: [Color(0xFF26A269), Palette.success])
            : primary == 'break_end'
                ? Palette.goldGradient
                : Palette.heroGradient,
        onPressed: () => _punch(primary),
      ),
    ];
    for (final a in d.actions.skip(1)) {
      out
        ..add(const SizedBox(height: 10))
        ..add(BusyButton(outlined: true, label: context.tr('attendance.$a'), icon: icons[a], onPressed: () => _punch(a)));
    }
    return out;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.dark);
  final double v;
  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = dark ? Colors.white10 : const Color(0xFFF1ECE2);
    canvas.drawCircle(c, r, track);
    // ticks
    final tick = Paint()
      ..strokeWidth = 2
      ..color = (dark ? Colors.white : Palette.navy).withValues(alpha: .12);
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * math.pi * 2;
      final o = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + o * (r - 18), c + o * (r - (i % 4 == 0 ? 26 : 22)), tick);
    }
    if (v <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [Palette.gold, color, color],
        stops: [0, (v * .6).clamp(.01, 1).toDouble(), 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, arc);
    final end = -math.pi / 2 + math.pi * 2 * v;
    final dot = c + Offset(math.cos(end), math.sin(end)) * r;
    canvas.drawCircle(dot, 11, Paint()..color = color.withValues(alpha: .25));
    canvas.drawCircle(dot, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.active, required this.color, required this.child});
  final bool active;
  final Color color;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  void _sync() {
    if (widget.active && !MotionScope.reducedOf(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            boxShadow: widget.active ? [BoxShadow(color: widget.color.withValues(alpha: .35 * (1 - _c.value)), blurRadius: 4 + 14 * _c.value, spreadRadius: 6 * _c.value)] : const [],
          ),
          child: child,
        ),
        child: widget.child,
      );
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .3))),
        child: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)))]),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.p, required this.last});
  final Map<String, dynamic> p;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final type = p['type']?.toString();
    final color = switch (type) { 'in' => Palette.success, 'out' => Palette.navySoft, 'break_start' || 'break_end' => Palette.warning, _ => Palette.info };
    final icon = switch (type) { 'in' => Icons.login_rounded, 'out' => Icons.logout_rounded, 'break_start' => Icons.coffee_rounded, 'break_end' => Icons.play_arrow_rounded, _ => Icons.fingerprint_rounded };
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 34,
          child: Column(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
            if (!last) Expanded(child: Container(width: 2, color: color.withValues(alpha: .2))),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(p['label']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(p['time']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
              Text(
                [context.tr('attendance.source.${p['source']}'), if (p['away'] == true) context.tr('attendance.away', {'m': p['distance_m'] ?? '?'}), if (p['note'] != null) p['note']].join(' · '),
                style: TextStyle(color: p['away'] == true ? Palette.danger : Theme.of(context).hintColor, fontSize: 12),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
