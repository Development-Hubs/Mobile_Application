import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session_controller.dart';
import 'core/config/env.dart';
import 'core/i18n/i18n.dart';
import 'core/links/deep_links.dart';
import 'core/offline/offline_store.dart';
import 'core/push/push_service.dart';
import 'core/router/router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'core/widgets/brand.dart';
import 'features/notifications/notifications_screen.dart';

class OneSourceApp extends ConsumerStatefulWidget {
  const OneSourceApp({super.key});

  @override
  ConsumerState<OneSourceApp> createState() => _OneSourceAppState();
}

class _OneSourceAppState extends ConsumerState<OneSourceApp> with WidgetsBindingObserver {
  final _links = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  /// A link that arrived before sign-in; opened once the person is signed in.
  String? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushProvider)
      ..onOpenLink = _open
      ..onForeground = () => ref.invalidate(unreadNoticesProvider);
    push.init();
    _links.getInitialLink().then((u) {
      if (u != null) _open(u.toString());
    }).catchError((_) {});
    _linkSub = _links.uriLinkStream.listen((u) => _open(u.toString()), onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(sessionProvider).phase != Phase.signedIn) return;
    // queued driver milestones go out as soon as the app is back and signed in
    _flushOutbox();
    ref.invalidate(unreadNoticesProvider);
  }

  Future<void> _flushOutbox() async {
    final store = ref.read(offlineStoreProvider);
    if (store.outbox.isEmpty) return;
    await store.flush(ref.read(sessionProvider.notifier));
    ref.read(outboxVersionProvider.notifier).state++;
  }

  void _open(String link) {
    final route = routeForLink(link);
    if (route == null) return;
    if (ref.read(sessionProvider).phase == Phase.signedIn) {
      ref.read(routerProvider).push(route);
    } else {
      _pending = route;
    }
  }

  Locale _locale(String? chosen) {
    return Locale(chosen == 'en' ? 'en' : 'ar');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final locale = _locale(settings.locale);
    ref.read(apiProvider).locale = locale.languageCode; // the ERP answers messages in the same language

    ref.listen(sessionProvider.select((s) => s.phase), (before, now) {
      if (now != Phase.signedIn) return;
      _flushOutbox();
      final p = _pending;
      if (p != null) {
        _pending = null;
        // let the redirect to /home finish first
        WidgetsBinding.instance.addPostFrameCallback((_) => router.push(p));
      }
    });

    return MaterialApp.router(
      title: 'OneSource Connect',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      themeMode: settings.themeMode,
      builder: (context, child) {
        final device = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        final reduced = switch (settings.motion) { MotionPref.reduced => true, MotionPref.full => false, MotionPref.system => device };
        return MotionScope(
          reduced: reduced,
          child: EnvRibbon(label: Env.envName, child: child ?? const SizedBox()),
        );
      },
    );
  }
}
