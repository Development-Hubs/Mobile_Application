import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/links/deep_links.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/json.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/ui.dart';

final unreadNoticesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(epochProvider);
  return integer((await ref.read(apiProvider).get('notifications/unread')).map['unread']) ?? 0;
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _list = GlobalKey<PagedListState>();
  bool _unread = false;

  Future<void> _readAll() async {
    try {
      await ref.read(apiProvider).post('notifications/read-all');
      ref.invalidate(unreadNoticesProvider);
      setState(() => _list = GlobalKey<PagedListState>());
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(epochProvider);
    final api = ref.read(apiProvider);
    return Scaffold(
      body: PagedList(
        key: _list,
        fetch: (page, per) => api.get('notifications', query: {'page': page, 'per_page': per, if (_unread) 'unread': 1}),
        header: [
          HeroHeader(
            title: context.tr('module.notifications'),
            subtitle: context.tr('notices.sub'),
            icon: Icons.notifications_rounded,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              GlassIconButton(icon: Icons.tune_rounded, tooltip: context.tr('notices.prefs'), onTap: () => _prefs(context)),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.done_all_rounded, tooltip: context.tr('notices.read_all'), onTap: _readAll),
            ]),
            bottom: FilterChips(
              options: {'all': context.tr('notices.all'), 'unread': context.tr('notices.unread')},
              value: _unread ? 'unread' : 'all',
              onChanged: (v) => setState(() {
                _unread = v == 'unread';
                _list = GlobalKey<PagedListState>();
              }),
            ),
          ),
          const SizedBox(height: 10),
        ],
        empty: EmptyView(icon: Icons.notifications_off_rounded, title: context.tr('notices.empty')),
        itemBuilder: (context, n, i) {
          final read = n['read'] == true;
          return ListRow(
            icon: _icon(str(n['topic'])),
            iconColor: read ? Palette.navySoft : Palette.maroon,
            title: str(n['title']) ?? '',
            subtitle: str(n['body']),
            meta: timeAgo(context, date(n['created_at'])),
            trailing: read ? null : Container(width: 10, height: 10, decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle)),
            onTap: () async {
              if (!read) {
                api.post('notifications/${n['id']}/read').then((_) {
                  _list.currentState?.replace((r) => r['id'] == n['id'], {'read': true});
                  ref.invalidate(unreadNoticesProvider);
                }).catchError((_) {});
              }
              final route = routeForLink(str(n['link']));
              if (route != null && context.mounted) context.push(route);
            },
          );
        },
      ),
    );
  }

  IconData _icon(String? topic) => switch (topic) {
        'support' || 'cases' => Icons.forum_rounded,
        'dispatch' || 'trips' => Icons.local_shipping_rounded,
        'training' => Icons.school_rounded,
        'attendance' => Icons.fingerprint_rounded,
        'account' => Icons.shield_rounded,
        'renewals' => Icons.autorenew_rounded,
        _ => Icons.notifications_rounded,
      };

  Future<void> _prefs(BuildContext context) => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _Prefs());
}

class _Prefs extends ConsumerStatefulWidget {
  const _Prefs();

  @override
  ConsumerState<_Prefs> createState() => _PrefsState();
}

class _PrefsState extends ConsumerState<_Prefs> {
  List<Map<String, dynamic>>? _topics;
  Map<String, dynamic> _meta = const {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get('notifications/preferences');
      setState(() {
        _topics = r.list;
        _meta = r.meta;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _set(Map<String, dynamic> t, bool v) async {
    final before = _topics;
    setState(() => _topics = [for (final x in _topics!) x['topic'] == t['topic'] ? {...x, 'push': v} : x]);
    try {
      final r = await ref.read(apiProvider).put('notifications/preferences', body: {
        'topics': {t['topic']: v},
      });
      setState(() => _topics = r.list); // the ERP's answer is what is shown
    } on ApiException catch (err) {
      setState(() => _topics = before);
      if (mounted) Toast.error(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('notices.prefs'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(context.tr(_meta['push_available'] == true ? 'notices.push_on' : 'notices.push_off'), style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        if (_error != null)
          ErrorView(error: _error!, onRetry: _load)
        else if (_topics == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          for (final t in _topics!)
            SwitchListTile.adaptive(
              value: t['push'] != false,
              title: Text(str(t['label']) ?? str(t['topic']) ?? ''),
              subtitle: t['locked'] == true ? Text(context.tr('notices.account_locked')) : null,
              onChanged: t['locked'] == true ? null : (v) => _set(t, v),
            ),
      ]),
    );
  }
}
