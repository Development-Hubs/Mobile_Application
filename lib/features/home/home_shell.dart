import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../notifications/notifications_screen.dart';

/// Bottom navigation: Home · Help · Inbox · More. Each tab keeps its own navigation stack.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticesProvider).valueOrNull ?? 0;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
          if (i == 2) ref.invalidate(unreadNoticesProvider);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard_rounded), label: context.tr('tab.home')),
          NavigationDestination(icon: const Icon(Icons.forum_outlined), selectedIcon: const Icon(Icons.forum_rounded), label: context.tr('tab.help')),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_none_rounded)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_rounded)),
            label: context.tr('tab.inbox'),
          ),
          NavigationDestination(icon: const Icon(Icons.apps_outlined), selectedIcon: const Icon(Icons.apps_rounded), label: context.tr('tab.more')),
        ],
      ),
    );
  }
}
