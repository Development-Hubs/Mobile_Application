import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/ui.dart';
import 'module_registry.dart';

/// Profile and the full module library for this person, built from `GET me`.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final all = modulesFor(me);
    final groups = <String, List<AppModule>>{};
    for (final m in all) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }
    var i = 0;
    return ModulePage(
      title: me.name,
      subtitle: [me.jobTitle ?? me.email ?? me.phone, me.companyName].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      icon: Icons.person_rounded,
      trailing: GlassIconButton(icon: Icons.settings_rounded, tooltip: context.tr('settings.title'), onTap: () => context.push('/settings')),
      headerBottom: Wrap(spacing: 8, runSpacing: 8, children: [
        if (me.isStaff && me.owner) _tag(context.tr('more.owner')),
        if (me.isStaff && me.dataScope != null) _tag(context.tr('more.scope.${me.dataScope}')),
        if (me.isStaff) _tag(context.tr('more.permissions', {'n': me.permissions.length})),
        if (!me.isStaff && me.workspaces.length > 1)
          ActionChip(
            avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(context.tr('workspace.switch')),
            onPressed: () => _switch(context, ref),
          ),
      ]),
      children: [
        for (final g in const ['mine', 'me', 'work', 'web'])
          if (groups[g] != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(children: [
                Text(context.tr('more.group.$g'), style: Theme.of(context).textTheme.titleMedium),
                if (g == 'web') ...[
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr('more.web_note'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
                ],
              ]),
            ),
            for (final m in groups[g]!)
              Reveal(
                index: i++,
                child: ListRow(
                  icon: m.icon,
                  iconColor: m.color,
                  title: context.tr(m.native ? m.titleKey : 'module.${m.key.substring(4)}'),
                  subtitle: m.native ? context.tr(m.bodyKey) : context.tr('more.opens_web'),
                  trailing: m.native ? null : const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () {
                    if (m.native) {
                      if (const {'/home', '/help', '/inbox'}.contains(m.route)) {
                        context.go(m.route!);
                      } else {
                        context.push(m.route!);
                      }
                    } else if (me.webUrl != null) {
                      launchUrl(Uri.parse(me.webUrl!), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
          ],
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Palette.danger, side: BorderSide(color: Palette.danger.withValues(alpha: .4))),
            onPressed: () async {
              if (await confirmAction(context, title: context.tr('settings.sign_out'), message: context.tr('settings.sign_out_body'), danger: true, icon: Icons.logout_rounded)) {
                await ref.read(sessionProvider.notifier).signOut();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('settings.sign_out')),
          ),
        ),
      ],
    );
  }

  Widget _tag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Palette.maroon.withValues(alpha: .08), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(color: Palette.maroon, fontWeight: FontWeight.w600, fontSize: 12.5)),
      );

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final me = ref.read(meProvider);
    final id = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final w in me.workspaces)
            ListTile(
              leading: Icon(w.kind == 'customer' ? Icons.family_restroom_rounded : Icons.engineering_rounded),
              title: Text(w.company),
              subtitle: Text(context.tr('workspace.kind.${w.kind}')),
              onTap: () => Navigator.pop(context, w.id),
            ),
        ]),
      ),
    );
    if (id == null || !context.mounted) return;
    if (!await confirmAction(context, title: context.tr('workspace.switch'), message: context.tr('workspace.switch_body'))) return;
    try {
      await ref.read(sessionProvider.notifier).switchWorkspace(id);
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}
