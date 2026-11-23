import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/biometrics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/palette.dart';
import '../notifications/notifications_screen.dart';

/// Bottom navigation: Home · Help · Inbox · More. Each tab keeps its own navigation stack.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometrics());
  }

  /// After the first sign-in on this phone, offer Face ID / fingerprint for the next time (asked once).
  Future<void> _offerBiometrics() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (ref.read(settingsProvider).biometrics || (prefs.getBool('bio_offered') ?? false)) return;
    final bio = Biometrics();
    if (!await bio.available() || !mounted) return;
    await prefs.setBool('bio_offered', true);
    if (!mounted) return;
    final yes = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(gradient: Palette.heroGradient, shape: BoxShape.circle),
                child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 18),
            Text(context.tr('bio.offer_title'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('bio.offer_body'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.5)),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('bio.offer_yes'))),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('bio.offer_no'))),
          ]),
        ),
      ),
    );
    if (yes != true || !mounted) return;
    // confirm with the device once, so the switch is only on when it really works
    if (await bio.unlock(translate(context.lang, 'lock.reason'))) {
      await ref.read(settingsProvider.notifier).setBiometrics(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
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
