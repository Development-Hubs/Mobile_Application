import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/ui.dart';

/// Document renewals (passport, QID, visa…). Moves are validated by the ERP; the app only offers `next`.
class RenewalsScreen extends ConsumerStatefulWidget {
  const RenewalsScreen({super.key});

  @override
  ConsumerState<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends ConsumerState<RenewalsScreen> {
  String _queue = 'open';
  var _list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(epochProvider);
    final api = ref.read(apiProvider);
    final queues = {for (final q in const ['open', 'mine', 'week', 'expired', 'submitted']) q: context.tr('renewals.q.$q')};
    return Scaffold(
      body: PagedList(
        key: _list,
        fetch: (page, per) => api.get('renewals', query: {'queue': _queue, 'page': page, 'per_page': per}),
        header: [
          HeroHeader(
            title: context.tr('module.renewals'),
            subtitle: context.tr('module.renewals.body'),
            icon: Icons.autorenew_rounded,
            bottom: FilterChips(options: queues, value: _queue, onChanged: (q) => setState(() {
                  _queue = q;
                  _list = GlobalKey<PagedListState>();
                })),
          ),
          const SizedBox(height: 10),
        ],
        empty: EmptyView(icon: Icons.verified_rounded, title: context.tr('renewals.empty')),
        itemBuilder: (context, t, i) {
          final exp = date(t['expires_on']);
          final days = exp?.difference(DateTime.now()).inDays;
          final color = days == null ? Palette.navySoft : (days < 0 ? Palette.danger : (days <= 14 ? Palette.warning : Palette.success));
          return ListRow(
            icon: _icon(str(t['requirement'])),
            iconColor: color,
            title: str(t['label']) ?? str(t['reference']) ?? '',
            subtitle: '${context.tr('renewals.req.${t['requirement']}')} · ${t['reference']}',
            meta: exp == null ? null : (days! < 0 ? context.tr('renewals.expired_ago', {'d': -days}) : context.tr('renewals.expires_in', {'d': days, 'date': Fmt.date(exp, context.lang)})),
            trailing: StatusChip(str(t['status'])),
            onTap: () => _open(context, t),
          );
        },
      ),
    );
  }

  IconData _icon(String? r) => switch (r) {
        'passport' => Icons.menu_book_rounded,
        'qid' => Icons.badge_rounded,
        'visa' => Icons.airplane_ticket_rounded,
        'medical' => Icons.medical_services_rounded,
        'contract' => Icons.description_rounded,
        'certificate' => Icons.workspace_premium_rounded,
        _ => Icons.folder_rounded,
      };

  Future<void> _open(BuildContext context, Map<String, dynamic> t) async {
    final next = strList(t['next']);
    final status = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(str(t['label']) ?? '', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('${t['reference']} · ${context.tr('renewals.req.${t['requirement']}')}', style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            StatusChip(str(t['status'])),
            if (t['needs_sponsor'] == true) StatusChip('pending', label: context.tr('renewals.needs_sponsor')),
          ]),
          const SizedBox(height: 12),
          Text('${context.tr('renewals.expires')}: ${Fmt.date(date(t['expires_on']), context.lang)}   ·   ${context.tr('renewals.due')}: ${Fmt.date(date(t['due_on']), context.lang)}'),
          if (t['submission_reference'] != null) Text('${context.tr('renewals.submission')}: ${t['submission_reference']}'),
          const SizedBox(height: 18),
          if (next.isEmpty) Text(context.tr('renewals.final'), style: TextStyle(color: Theme.of(context).hintColor)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in next)
              ActionChip(
                avatar: Icon(Icons.arrow_forward_rounded, size: 16, color: Palette.forStatus(n)),
                label: Text(statusLabel(context, n)),
                onPressed: () => Navigator.pop(context, n),
              ),
          ]),
        ]),
      ),
    );
    if (status == null || !context.mounted) return;

    final body = <String, dynamic>{};
    if (status == 'submitted') {
      final refNo = await askText(context, title: context.tr('renewals.submission'), hint: context.tr('renewals.submission_hint'), required: true, maxLines: 1);
      if (refNo == null) return;
      body['submission_reference'] = refNo;
    } else if (status == 'completed') {
      if (!context.mounted) return;
      final d = await showDatePicker(context: context, helpText: context.tr('renewals.new_expiry'), initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
      if (d == null) return;
      body['new_expires_on'] = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } else if (const {'cancelled', 'not_needed', 'rejected', 'returned'}.contains(status)) {
      if (!context.mounted) return;
      final reason = await askText(context, title: context.tr('reason'), required: true);
      if (reason == null) return;
      body['reason'] = reason;
    } else {
      if (!context.mounted) return;
      if (!await confirmAction(context, title: context.tr('renewals.move_to', {'s': statusLabel(context, status)}))) return;
    }
    try {
      final r = await ref.read(apiProvider).post('renewals/${t['reference']}/actions/$status', body: body, idempotencyKey: ApiClient.newKey());
      _list.currentState?.replace((x) => x['reference'] == t['reference'], r.map);
      if (context.mounted) Toast.success(context, context.tr('saved'));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}
