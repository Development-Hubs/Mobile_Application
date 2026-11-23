import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/json.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/ui.dart';

/// Help desk: requesters see their own cases; staff get queues. Visibility is decided by the ERP.
class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  String _queue = 'open';

  @override
  void initState() {
    super.initState();
    if (ref.read(meProvider).isStaff) _queue = 'mine';
  }
  var _list = GlobalKey<PagedListState>();
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    ref.watch(epochProvider);
    final me = ref.watch(meProvider);
    final api = ref.read(apiProvider);
    final queues = me.isStaff
        ? {'mine': context.tr('cases.q.mine'), 'unassigned': context.tr('cases.q.unassigned'), 'overdue': context.tr('cases.q.overdue'), 'open': context.tr('cases.q.open'), 'all': context.tr('cases.q.all')}
        : {'open': context.tr('cases.q.open_mine'), 'all': context.tr('cases.q.all')};

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-case',
        backgroundColor: Palette.maroon,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await context.push<bool>('/cases/new');
          if (created == true) _list.currentState?.reload();
        },
        icon: const Icon(Icons.add_comment_rounded),
        label: Text(context.tr('cases.new')),
      ),
      body: PagedList(
        key: _list,
        fetch: (page, per) => api.get('cases', query: {
          'page': page,
          'per_page': per,
          'queue': _queue,
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        }),
        header: [
          HeroHeader(
            title: context.tr('module.support'),
            subtitle: context.tr(me.isStaff ? 'cases.staff_sub' : 'cases.sub'),
            icon: Icons.support_agent_rounded,
            bottom: Column(children: [
              SearchField(controller: _search, hint: context.tr('cases.search'), onSubmitted: (_) => setState(() => _list = GlobalKey<PagedListState>())),
              const SizedBox(height: 12),
              FilterChips(options: queues, value: queues.containsKey(_queue) ? _queue : queues.keys.first, onChanged: (q) => setState(() {
                    _queue = q;
                    _list = GlobalKey<PagedListState>();
                  })),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        empty: EmptyView(icon: Icons.mark_chat_read_rounded, title: context.tr('cases.empty'), message: context.tr('cases.empty_body')),
        itemBuilder: (context, c, i) => ListRow(
          icon: c['overdue'] == true ? Icons.alarm_rounded : Icons.forum_rounded,
          iconColor: c['overdue'] == true ? Palette.danger : Palette.forStatus(str(c['status'])),
          title: str(c['subject']) ?? str(c['reference']) ?? '',
          subtitle: [str(c['reference']), if (c['assigned_to'] != null) '→ ${c['assigned_to']}', if (c['priority'] != null) context.tr('priority.${c['priority']}')].whereType<String>().join(' · '),
          meta: timeAgo(context, date(c['last_activity_at'] ?? c['created_at'])),
          trailing: StatusChip(str(c['status']), label: str(c['status_label'])),
          onTap: () async {
            await context.push('/cases/${c['id']}');
            _list.currentState?.reload();
          },
        ),
      ),
    );
  }
}
