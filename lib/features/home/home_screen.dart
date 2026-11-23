import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_result.dart';
import '../../core/auth/models.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/doha_skyline.dart';
import '../../core/widgets/ui.dart';
import '../attendance/attendance_api.dart';
import '../attendance/team_screen.dart';
import '../modules/module_registry.dart';
import '../notifications/notifications_screen.dart';

final overviewProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('my/overview');
});

final unreadCasesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(epochProvider);
  return integer((await ref.read(apiProvider).get('cases/unread')).map['unread']) ?? 0;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Scaffold(
      body: RefreshIndicator(
        color: Palette.maroon,
        onRefresh: () async {
          await ref.read(sessionProvider.notifier).refreshMe();
          ref.invalidate(unreadNoticesProvider);
          ref.invalidate(unreadCasesProvider);
          if (me.attendance) ref.invalidate(attendanceProvider);
          if (!me.isStaff) ref.invalidate(overviewProvider);
        },
        child: ListView(padding: EdgeInsets.zero, physics: const AlwaysScrollableScrollPhysics(), children: [
          _Hero(me: me),
          if (me.isStaff) _StaffHome(me: me) else const _MemberHome(),
          const SizedBox(height: 120),
        ]),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.me});
  final Me me;

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    return context.tr(h < 12 ? 'home.morning' : (h < 17 ? 'home.afternoon' : 'home.evening'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final unread = ref.watch(unreadNoticesProvider).valueOrNull ?? 0;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: SizedBox(
        height: 250 + top,
        child: Stack(fit: StackFit.expand, children: [
          const DohaSkyline(height: 400, showDhow: true),
          DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.midnight.withValues(alpha: .1), Palette.midnight.withValues(alpha: .55)])),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: .4), blurRadius: 14)]),
                  child: Text(me.initials, style: const TextStyle(color: Palette.navy, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.companyName.isNotEmpty ? me.companyName : 'OneSource', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.goldSoft, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(me.isStaff ? (me.jobTitle ?? context.tr('home.staff')) : context.tr('workspace.kind.${me.type}'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                GlassIconButton(icon: Icons.notifications_rounded, badge: unread, tooltip: context.tr('module.notifications'), onTap: () => context.go('/inbox')),
              ]),
              const Spacer(),
              Text(_greeting(context), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              Text(me.name.split(' ').first, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text('${Fmt.weekday(DateTime.now(), context.lang)} · ${Fmt.date(DateTime.now(), context.lang)}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Staff
// ---------------------------------------------------------------------------------------------------------------

class _StaffHome extends ConsumerWidget {
  const _StaffHome({required this.me});
  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = modulesFor(me).where((m) => m.native && m.group != 'me').toList();
    final unreadCases = me.area('support') ? ref.watch(unreadCasesProvider).valueOrNull : null;
    final unreadNotices = ref.watch(unreadNoticesProvider).valueOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (me.attendance) const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: Reveal(child: _AttendanceCard())),
      if (me.pendingRequests > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Reveal(
            index: 1,
            child: _Notice(
              icon: Icons.assignment_late_rounded,
              color: Palette.warning,
              title: context.tr('home.requests', {'n': me.pendingRequests}),
              body: context.tr('home.requests_body'),
              action: me.webUrl == null ? null : () => launchUrl(Uri.parse(me.webUrl!), mode: LaunchMode.externalApplication),
            ),
          ),
        ),
      if (me.attendance && me.can('hrm.edit'))
        Builder(builder: (context) {
          final n = ref.watch(teamApprovalsProvider).valueOrNull?.list.length ?? 0;
          if (n == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Reveal(
              index: 1,
              child: _Notice(
                icon: Icons.edit_calendar_rounded,
                color: Palette.maroonBright,
                title: context.tr('home.corrections', {'n': n}),
                body: context.tr('home.corrections_body'),
                action: () => context.push('/team?tab=approvals'),
              ),
            ),
          );
        }),
      if (!me.mfa)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Reveal(index: 2, child: _Notice(icon: Icons.shield_outlined, color: Palette.info, title: context.tr('home.mfa'), body: context.tr('home.mfa_body'))),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Expanded(child: StatTile(label: context.tr('home.unread_notices'), value: '${unreadNotices ?? '–'}', icon: Icons.notifications_active_rounded, color: Palette.maroon, onTap: () => context.go('/inbox'))),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: context.tr('home.unread_cases'),
              value: unreadCases == null ? '–' : '$unreadCases',
              icon: Icons.mark_unread_chat_alt_rounded,
              color: Palette.sea,
              onTap: me.area('support') ? () => context.go('/help') : null,
            ),
          ),
        ]),
      ),
      if (modules.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 10), child: Text(context.tr('home.your_work'), style: Theme.of(context).textTheme.titleMedium)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: .95,
            children: [for (final (i, m) in modules.indexed) Reveal(index: i, child: ModuleTile(m: m))],
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: OutlinedButton.icon(onPressed: () => context.go('/more'), icon: const Icon(Icons.apps_rounded), label: Text(context.tr('home.all_modules'))),
      ),
    ]);
  }
}

class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(attendanceProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push('/attendance'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: Palette.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Palette.maroon.withValues(alpha: .3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: day.when(
          loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
          error: (e, _) => Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('attendance.load_error'), style: const TextStyle(color: Colors.white))),
            TextButton(onPressed: () => ref.invalidate(attendanceProvider), child: Text(context.tr('retry'), style: const TextStyle(color: Palette.goldSoft))),
          ]),
          data: (d) {
            final needs = d.linked && d.state == 'off' && !d.dayOff && !d.onLeave;
            return Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)),
                child: Icon(needs ? Icons.alarm_rounded : Icons.fingerprint_rounded, color: Palette.goldSoft, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr(needs ? 'home.mark_attendance' : 'attendance.state.${d.state}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    needs
                        ? context.tr('home.mark_attendance_body', {'shift': d.shiftStart ?? '—'})
                        : '${context.tr('attendance.worked_today')}: ${Fmt.hm(d.workedSeconds)}${d.firstIn != null ? ' · ${context.tr('attendance.first_in')} ${d.firstIn}' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]);
          },
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.title, required this.body, this.action});
  final IconData icon;
  final Color color;
  final String title, body;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action,
          child: Container(
            decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: color, width: 4))),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              IconBadge(icon, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(body, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                ]),
              ),
              if (action != null) const Icon(Icons.open_in_new_rounded, size: 18),
            ]),
          ),
        ),
      );
}

class ModuleTile extends StatelessWidget {
  const ModuleTile({super.key, required this.m});
  final AppModule m;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (const {'/home', '/help', '/inbox'}.contains(m.route)) {
              context.go(m.route!);
            } else {
              context.push(m.route!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(m.icon, color: m.color, size: 42),
              const Spacer(),
              Text(context.tr(m.titleKey), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Customers and workers
// ---------------------------------------------------------------------------------------------------------------

class _MemberHome extends ConsumerWidget {
  const _MemberHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(overviewProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AsyncBody(
        value: data,
        onRetry: () => ref.invalidate(overviewProvider),
        builder: (r) => r.map['kind'] == 'customer' ? _Customer(o: r.map) : _Worker(o: r.map),
      ),
    );
  }
}

class _Worker extends StatelessWidget {
  const _Worker({required this.o});
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    final docs = maps(o['documents']);
    final bed = o['accommodation'] is Map ? obj(o['accommodation']) : null;
    final trips = maps(o['trips']);
    final training = maps(o['training']);
    final certs = maps(o['certificates']);
    var i = 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (docs.isNotEmpty)
        Reveal(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Section(
              title: context.tr('home.documents'),
              icon: Icons.folder_shared_rounded,
              child: Column(children: [for (final d in docs) _DocRow(d: d)]),
            ),
          ),
        ),
      if (bed != null)
        Reveal(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Section(
              title: context.tr('home.accommodation'),
              icon: Icons.bed_rounded,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(str(bed['property']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${context.tr('home.room')} ${bed['room'] ?? ''} · ${context.tr('home.bed')} ${bed['bed'] ?? ''}\n${str(bed['address']) ?? ''}'),
                isThreeLine: true,
                trailing: StatusChip(str(bed['status'])),
              ),
            ),
          ),
        ),
      if (trips.isNotEmpty)
        Reveal(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Section(
              title: context.tr('home.trips'),
              icon: Icons.directions_bus_rounded,
              child: Column(children: [
                for (final t in trips)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text('${Fmt.dateTime(date(t['scheduled_at']), context.lang)} · ${Fmt.humanize(str(t['purpose']))}'),
                    subtitle: Text('${t['pickup'] ?? ''} → ${t['dropoff'] ?? ''}'),
                    trailing: StatusChip(str(t['status'])),
                  ),
              ]),
            ),
          ),
        ),
      if (training.isNotEmpty || certs.isNotEmpty)
        Reveal(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Section(
              title: context.tr('module.learning'),
              icon: Icons.school_rounded,
              action: TextButton(onPressed: () => context.push('/learning'), child: Text(context.tr('open'))),
              child: Column(children: [
                for (final t in training)
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.menu_book_rounded), title: Text(str(t['course']) ?? ''), trailing: StatusChip(str(t['state']))),
                for (final c in certs)
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.workspace_premium_rounded, color: Palette.gold), title: Text(str(c['course']) ?? str(c['type']) ?? ''), trailing: StatusChip(str(c['status']))),
              ]),
            ),
          ),
        ),
      if (docs.isEmpty && bed == null && trips.isEmpty && training.isEmpty && certs.isEmpty) EmptyView(icon: Icons.inbox_rounded, title: context.tr('home.nothing_yet')),
      _HelpCta(),
    ]);
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.d});
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final left = integer(d['days_left']) ?? 0;
    final c = left < 0 ? Palette.danger : (left <= 30 ? Palette.warning : Palette.success);
    final v = (left / 365).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(str(d['label']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(left < 0 ? context.tr('renewals.expired_ago', {'d': -left}) : context.tr('home.days_left', {'d': left}), style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: v),
            duration: MotionScope.duration(context, const Duration(milliseconds: 900)),
            builder: (_, x, __) => LinearProgressIndicator(value: x, minHeight: 8, color: c, backgroundColor: c.withValues(alpha: .12)),
          ),
        ),
        const SizedBox(height: 2),
        Text('${context.tr('renewals.expires')} ${Fmt.date(date(d['expires_on']), context.lang)}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
      ]),
    );
  }
}

class _Customer extends StatelessWidget {
  const _Customer({required this.o});
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    final placements = maps(o['placements']);
    final contracts = maps(o['contracts']);
    final recruitment = maps(o['recruitment']);
    Widget group(String title, IconData icon, List<Map<String, dynamic>> rows, Widget Function(Map<String, dynamic>) b) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: Section(title: title, icon: icon, child: Column(children: rows.map(b).toList())));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Reveal(
        child: group(context.tr('home.recruitment'), Icons.flight_land_rounded, recruitment, (r) {
          final pickup = r['pickup'] is Map ? obj(r['pickup']) : null;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.travel_explore_rounded),
            title: Text(str(r['reference']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if (r['expected_arrival'] != null) '${context.tr('home.expected')} ${Fmt.date(date(r['expected_arrival']), context.lang)}',
              if (r['arrived_on'] != null) '${context.tr('home.arrived')} ${Fmt.date(date(r['arrived_on']), context.lang)}',
              if (pickup != null) '${context.tr('home.pickup')} ${Fmt.dateTime(date(pickup['scheduled_at']), context.lang)}',
            ].join('\n')),
            trailing: StatusChip(str(r['status'])),
          );
        }),
      ),
      Reveal(
        index: 1,
        child: group(context.tr('home.placements'), Icons.home_work_rounded, placements, (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_pin_rounded),
              title: Text(str(p['worker']) ?? str(p['reference']) ?? ''),
              subtitle: Text('${Fmt.date(date(p['starts_on']), context.lang)} → ${Fmt.date(date(p['trial_ends_on']), context.lang)}'),
              trailing: StatusChip(str(p['status'])),
            )),
      ),
      Reveal(
        index: 2,
        child: group(context.tr('home.contracts'), Icons.description_rounded, contracts, (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_ind_rounded),
              title: Text(str(c['worker']) ?? str(c['reference']) ?? ''),
              subtitle: Text('${Fmt.date(date(c['starts_on']), context.lang)} → ${Fmt.date(date(c['ends_on']), context.lang)}'),
              trailing: StatusChip(str(c['status'])),
            )),
      ),
      if (placements.isEmpty && contracts.isEmpty && recruitment.isEmpty) EmptyView(icon: Icons.inbox_rounded, title: context.tr('home.nothing_yet')),
      _HelpCta(),
    ]);
  }
}

class _HelpCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Palette.navy, Palette.navySoft]), borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            const Icon(Icons.support_agent_rounded, color: Palette.goldSoft, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('home.need_help'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(context.tr('home.need_help_body'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.navy, minimumSize: const Size(0, 44)),
              onPressed: () => context.push('/cases/new'),
              child: Text(context.tr('home.ask')),
            ),
          ]),
        ),
      );
}
