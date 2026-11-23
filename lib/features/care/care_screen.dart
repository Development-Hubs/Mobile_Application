import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/ui.dart';

/// Care calls after a placement: call, record the answers, or log "no answer".
class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});

  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  String _queue = 'today';
  var _list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(epochProvider);
    final api = ref.read(apiProvider);
    return Scaffold(
      body: PagedList(
        key: _list,
        fetch: (page, per) => api.get('care/checkins', query: {'queue': _queue, 'page': page, 'per_page': per}),
        header: [
          HeroHeader(
            title: context.tr('module.care'),
            subtitle: context.tr('module.care.body'),
            icon: Icons.favorite_rounded,
            bottom: FilterChips(
              options: {'today': context.tr('care.today'), 'upcoming': context.tr('care.upcoming')},
              value: _queue,
              onChanged: (q) => setState(() {
                _queue = q;
                _list = GlobalKey<PagedListState>();
              }),
            ),
          ),
          const SizedBox(height: 10),
        ],
        empty: EmptyView(icon: Icons.volunteer_activism_rounded, title: context.tr('care.empty')),
        itemBuilder: (context, c, i) => ListRow(
          icon: c['audience'] == 'worker' ? Icons.engineering_rounded : Icons.family_restroom_rounded,
          iconColor: c['status'] == 'attempted' ? Palette.warning : Palette.danger,
          title: str(c['call']) ?? '',
          subtitle: '${context.tr('care.audience.${c['audience']}')} · ${Fmt.humanize(str(c['milestone']))} · ${c['placement'] ?? ''}',
          meta: '${Fmt.dateTime(date(c['due_at']), context.lang)}${(integer(c['attempts']) ?? 0) > 0 ? ' · ${context.tr('care.attempts', {'n': c['attempts']})}' : ''}',
          trailing: StatusChip(str(c['status'])),
          onTap: () async {
            final done = await showModalBottomSheet<Map<String, dynamic>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _CareForm(c: c));
            if (done != null) {
              _list.currentState?.remove((x) => x['id'] == c['id']);
              if (context.mounted) Toast.success(context, context.tr(done['case_opened'] == true ? 'care.case_opened' : 'saved'));
            }
          },
        ),
      ),
    );
  }
}

class _CareForm extends ConsumerStatefulWidget {
  const _CareForm({required this.c});
  final Map<String, dynamic> c;

  @override
  ConsumerState<_CareForm> createState() => _CareFormState();
}

class _CareFormState extends ConsumerState<_CareForm> {
  int _score = 0;
  final _answers = <String, String>{};
  final _concerns = <String>{};
  final _comment = TextEditingController();
  final _key = ApiClient.newKey();
  ApiException? _error;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final questions = obj(c['questions']);
    final concerns = obj(c['concerns']);
    final phone = str(c['phone']);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(str(c['call']) ?? '', style: Theme.of(context).textTheme.titleLarge),
          Text('${c['placement'] ?? ''} · ${c['package'] ?? ''}', style: TextStyle(color: Theme.of(context).hintColor)),
          if (phone != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)), icon: const Icon(Icons.call_rounded), label: Text(context.tr('care.call', {'phone': phone}))),
          ],
          const SizedBox(height: 18),
          Text(context.tr('care.satisfaction'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var s = 1; s <= 5; s++)
              Semantics(
                button: true,
                selected: _score == s,
                label: '$s / 5',
                child: GestureDetector(
                  onTap: () => setState(() => _score = s),
                  child: AnimatedScale(
                    scale: _score == s ? 1.2 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Text(const ['😞', '🙁', '😐', '🙂', '😄'][s - 1], style: TextStyle(fontSize: 34, color: _score == 0 || _score == s ? null : Colors.black.withValues(alpha: .3))),
                  ),
                ),
              ),
          ]),
          if (_error?.fieldError('satisfaction') != null) Text(_error!.fieldError('satisfaction')!, style: const TextStyle(color: Palette.danger)),
          const SizedBox(height: 14),
          for (final q in questions.entries) ...[
            Text('${q.value}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: [for (final a in const ['yes', 'partly', 'no']) ButtonSegment(value: a, label: Text(context.tr('care.answer.$a')))],
              selected: {if (_answers[q.key] != null) _answers[q.key]!},
              onSelectionChanged: (s) => setState(() {
                if (s.isEmpty) {
                  _answers.remove(q.key);
                } else {
                  _answers[q.key] = s.first;
                }
              }),
            ),
            const SizedBox(height: 12),
          ],
          Text(context.tr('care.concerns'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in concerns.entries)
              FilterChip(label: Text('${k.value}'), selected: _concerns.contains(k.key), onSelected: (v) => setState(() => v ? _concerns.add(k.key) : _concerns.remove(k.key))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _comment, maxLines: 3, decoration: InputDecoration(labelText: context.tr('care.comment'))),
          const SizedBox(height: 8),
          Text(context.tr('care.case_note'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          const SizedBox(height: 16),
          BusyButton(
            label: context.tr('care.save'),
            icon: Icons.check_rounded,
            onPressed: () async {
              setState(() => _error = null);
              try {
                final r = await ref.read(apiProvider).post('care/checkins/${c['id']}/record', idempotencyKey: _key, body: {
                  'satisfaction': _score,
                  'answers': _answers,
                  'concerns': _concerns.toList(),
                  'comment': _comment.text.trim(),
                });
                if (context.mounted) Navigator.pop(context, r.map);
              } on ApiException catch (e) {
                setState(() => _error = e);
                if (context.mounted && e.fields.isEmpty) Toast.error(context, e);
              }
            },
          ),
          const SizedBox(height: 8),
          BusyButton(
            outlined: true,
            label: context.tr('care.no_answer'),
            icon: Icons.phone_missed_rounded,
            onPressed: () async {
              final note = await askText(context, title: context.tr('care.no_answer'), hint: context.tr('care.no_answer_hint'));
              if (note == null) return;
              try {
                final r = await ref.read(apiProvider).post('care/checkins/${c['id']}/no-answer', body: {'note': note});
                if (context.mounted) Navigator.pop(context, r.map);
              } on ApiException catch (e) {
                if (context.mounted) Toast.error(context, e);
              }
            },
          ),
        ]),
      ),
    );
  }
}
