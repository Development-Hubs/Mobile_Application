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
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/ui.dart';

final myLearningProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('training/my');
});

/// Customer / worker learning: requirements, enrolments with sessions and results, certificates.
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myLearningProvider);
    return DefaultTabController(
      length: 3,
      child: ModulePage(
        title: context.tr('module.learning'),
        subtitle: context.tr('module.learning.body'),
        icon: Icons.school_rounded,
        trailing: GlassIconButton(icon: Icons.qr_code_scanner_rounded, tooltip: context.tr('learning.check_in'), onTap: () => _checkIn(context, ref, data.valueOrNull)),
        onRefresh: () async => ref.invalidate(myLearningProvider),
        children: [
          AsyncBody(
            value: data,
            onRetry: () => ref.invalidate(myLearningProvider),
            builder: (r) {
              final enrolments = maps(r.map['enrolments']);
              final reqs = maps(r.map['requirements']);
              final certs = maps(r.map['certificates']);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: StatTile(label: context.tr('learning.courses'), value: '${enrolments.length}', icon: Icons.menu_book_rounded, color: Palette.maroon)),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(label: context.tr('learning.certificates'), value: '${certs.where((c) => c['status'] == 'issued').length}', icon: Icons.workspace_premium_rounded, color: Palette.gold)),
                  ]),
                ),
                for (final p in reqs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Section(
                      title: str(p['pathway']),
                      icon: Icons.flag_rounded,
                      child: Column(children: [
                        for (final it in maps(p['items']))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(it['met'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: it['met'] == true ? Palette.success : Palette.warning),
                            title: Text(str(it['course']) ?? ''),
                            subtitle: Text([Fmt.humanize(str(it['requirement'])), if (it['expires_on'] != null) '${context.tr('renewals.expires')} ${Fmt.date(date(it['expires_on']), context.lang)}'].join(' · ')),
                          ),
                      ]),
                    ),
                  ),
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6), child: Text(context.tr('learning.my_courses'), style: Theme.of(context).textTheme.titleMedium)),
                if (enrolments.isEmpty) EmptyView(icon: Icons.school_outlined, title: context.tr('learning.none')),
                for (final (i, e) in enrolments.indexed) Reveal(index: i, child: _Enrolment(e: e)),
                if (certs.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6), child: Text(context.tr('learning.certificates'), style: Theme.of(context).textTheme.titleMedium)),
                  for (final c in certs) _Certificate(c: c),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _Catalogue())),
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: Text(context.tr('learning.catalogue')),
                  ),
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkIn(BuildContext context, WidgetRef ref, ApiResult? r) async {
    final sessions = [
      for (final e in maps(r?.map['enrolments']))
        for (final s in maps(e['sessions']))
          if (s['status'] != 'cancelled' && (date(s['ends_at'])?.isAfter(DateTime.now()) ?? false) && (date(s['starts_at'])?.difference(DateTime.now()).inHours ?? 99) < 2) {...s, 'course': obj(e['course'])['name']},
    ];
    if (sessions.isEmpty) {
      Toast.info(context, context.tr('learning.no_session_now'));
      return;
    }
    final s = sessions.first;
    final code = await askText(context, title: context.tr('learning.check_in'), hint: context.tr('learning.code_hint'), required: true, maxLines: 1);
    if (code == null) return;
    try {
      final res = await ref.read(apiProvider).post('training/sessions/${s['id']}/check-in', body: {'code': code});
      ref.invalidate(myLearningProvider);
      if (context.mounted) Toast.success(context, context.tr('learning.checked_in', {'s': statusLabel(context, str(res.map['attendance']))}));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}

class _Enrolment extends ConsumerWidget {
  const _Enrolment({required this.e});
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = obj(e['course']);
    final sessions = maps(e['sessions']);
    final results = maps(e['results']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const IconBadge(Icons.menu_book_rounded, color: Palette.maroon),
            title: Text(str(course['name']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(str(e['state'])))),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              if (e['waitlist_position'] != null) Text(context.tr('learning.waitlist', {'n': e['waitlist_position']})),
              for (final s in sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(Fmt.dateTime(date(s['starts_at']), context.lang)),
                  subtitle: Text([str(s['location']), str(s['joining_instructions'])].whereType<String>().join(' · ')),
                  trailing: StatusChip(str(s['attendance'])),
                ),
              for (final r in results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(r['outcome'] == 'pass' ? Icons.emoji_events_rounded : Icons.assignment_rounded, color: r['outcome'] == 'pass' ? Palette.gold : null),
                  title: Text('${Fmt.humanize(str(r['method']))} · ${Fmt.humanize(str(r['outcome']))}'),
                  subtitle: str(r['feedback']) == null ? null : Text(str(r['feedback'])!),
                ),
              if (strList(e['actions']).contains('withdraw'))
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () async {
                      final reason = await askText(context, title: context.tr('learning.withdraw'), hint: context.tr('reason'));
                      if (reason == null) return;
                      try {
                        await ref.read(apiProvider).post('training/enrolments/${e['id']}/withdraw', body: {'reason': reason}, idempotencyKey: ApiClient.newKey());
                        ref.invalidate(myLearningProvider);
                      } on ApiException catch (err) {
                        if (context.mounted) Toast.error(context, err);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: Palette.danger),
                    label: Text(context.tr('learning.withdraw'), style: const TextStyle(color: Palette.danger)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Certificate extends StatelessWidget {
  const _Certificate({required this.c});
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: c['status'] == 'issued' ? const LinearGradient(colors: [Palette.navy, Palette.maroonDeep]) : null,
            color: c['status'] == 'issued' ? null : Theme.of(context).cardTheme.color,
            border: Border.all(color: Palette.gold.withValues(alpha: .5)),
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium_rounded, color: Palette.gold, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: c['status'] == 'issued' ? Colors.white : null),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(c['course']) ?? str(c['type']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${c['serial'] ?? ''} · ${str(c['issuer']) ?? ''}', style: const TextStyle(fontSize: 12)),
                  Text('${Fmt.date(date(c['issued_on']), context.lang)} → ${c['expires_on'] == null ? '∞' : Fmt.date(date(c['expires_on']), context.lang)}', style: const TextStyle(fontSize: 12)),
                  if (c['verify_code'] != null) Text('${context.tr('learning.verify')}: ${c['verify_code']}', style: const TextStyle(fontSize: 12, color: Palette.goldSoft, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            StatusChip(str(c['status'])),
          ]),
        ),
      );
}

class _Catalogue extends ConsumerWidget {
  const _Catalogue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    return Scaffold(
      body: PagedList(
        fetch: (page, per) => api.get('training/catalogue', query: {'page': page, 'per_page': per}),
        header: [HeroHeader(title: context.tr('learning.catalogue'), subtitle: context.tr('learning.catalogue_sub'), icon: Icons.travel_explore_rounded), const SizedBox(height: 10)],
        empty: EmptyView(icon: Icons.menu_book_rounded, title: context.tr('learning.catalogue_empty')),
        itemBuilder: (context, c, i) => ListRow(
          icon: Icons.auto_stories_rounded,
          iconColor: Palette.sea,
          title: (context.lang == 'ar' ? str(c['name_ar']) : null) ?? str(c['name']) ?? '',
          subtitle: str(c['description']),
          meta: [str(c['code']), Fmt.humanize(str(c['modality'])), if (c['duration_minutes'] != null) Fmt.hm((integer(c['duration_minutes']) ?? 0) * 60)].whereType<String>().join(' · '),
          trailing: FilledButton.tonal(
            onPressed: () async {
              if (!await confirmAction(context, title: context.tr('learning.request'), message: str(c['name']), icon: Icons.school_rounded)) return;
              try {
                await api.post('training/requests', body: {'course_code': c['code']}, idempotencyKey: ApiClient.newKey());
                ref.invalidate(myLearningProvider);
                if (context.mounted) Toast.success(context, context.tr('learning.requested'));
              } on ApiException catch (e) {
                if (context.mounted) Toast.error(context, e);
              }
            },
            child: Text(context.tr('learning.join')),
          ),
        ),
      ),
    );
  }
}

/// Trainer view: upcoming sessions, roster attendance and the check-in code to show learners.
class TrainerScreen extends ConsumerWidget {
  const TrainerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(epochProvider);
    final api = ref.read(apiProvider);
    return Scaffold(
      body: PagedList(
        fetch: (page, per) => api.get('training/staff/sessions', query: {'page': page, 'per_page': per}),
        header: [HeroHeader(title: context.tr('module.trainer'), subtitle: context.tr('module.trainer.body'), icon: Icons.co_present_rounded), const SizedBox(height: 10)],
        empty: EmptyView(icon: Icons.event_available_rounded, title: context.tr('trainer.empty')),
        itemBuilder: (context, s, i) => ListRow(
          icon: Icons.groups_rounded,
          iconColor: Palette.forStatus(str(s['status'])),
          title: str(s['course']) ?? '',
          subtitle: '${Fmt.dateTime(date(s['starts_at']), context.lang)} · ${str(s['location']) ?? ''}',
          meta: s['capacity'] == null ? null : context.tr('trainer.capacity', {'n': s['capacity']}),
          trailing: StatusChip(str(s['status'])),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Session(id: integer(s['id'])!))),
        ),
      ),
    );
  }
}

final _sessionProvider = FutureProvider.autoDispose.family<ApiResult, int>((ref, id) => ref.read(apiProvider).get('training/staff/sessions/$id'));

class _Session extends ConsumerWidget {
  const _Session({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_sessionProvider(id));
    return ModulePage(
      title: data.valueOrNull?.map['course']?.toString() ?? context.tr('module.trainer'),
      subtitle: Fmt.dateTime(date(data.valueOrNull?.map['starts_at']), context.lang),
      icon: Icons.groups_rounded,
      trailing: GlassIconButton(icon: Icons.qr_code_2_rounded, tooltip: context.tr('trainer.code'), onTap: () => _code(context, ref)),
      onRefresh: () async => ref.invalidate(_sessionProvider(id)),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(_sessionProvider(id)),
          builder: (r) {
            final roster = maps(r.map['roster']);
            if (roster.isEmpty) return EmptyView(icon: Icons.person_off_rounded, title: context.tr('trainer.no_roster'));
            return Column(children: [
              for (final p in roster)
                ListRow(
                  icon: Icons.person_rounded,
                  iconColor: Palette.forStatus(str(p['attendance'])),
                  title: str(p['name']) ?? '',
                  subtitle: statusLabel(context, str(p['state'])),
                  trailing: PopupMenuButton<String>(
                    tooltip: context.tr('trainer.mark'),
                    onSelected: (st) async {
                      try {
                        await ref.read(apiProvider).post('training/staff/sessions/$id/attendance', body: {'enrolment_id': p['enrolment_id'], 'status': st}, idempotencyKey: ApiClient.newKey());
                        ref.invalidate(_sessionProvider(id));
                      } on ApiException catch (e) {
                        if (context.mounted) Toast.error(context, e);
                      }
                    },
                    itemBuilder: (_) => [for (final st in const ['present', 'late', 'absent', 'excused']) PopupMenuItem(value: st, child: Text(statusLabel(context, st)))],
                    child: StatusChip(str(p['attendance'])),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }

  Future<void> _code(BuildContext context, WidgetRef ref) async {
    try {
      final r = await ref.read(apiProvider).post('training/staff/sessions/$id/check-in-code');
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.tr('trainer.code'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(gradient: Palette.heroGradient, borderRadius: BorderRadius.circular(22)),
              child: Text('${r.map['code']}', style: const TextStyle(color: Colors.white, fontSize: 40, letterSpacing: 8, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            Text(context.tr('trainer.code_valid', {'m': r.map['expires_in_minutes'] ?? 30}), style: TextStyle(color: Theme.of(context).hintColor)),
          ]),
        ),
      );
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}
