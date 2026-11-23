import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session_controller.dart';
import 'core/config/env.dart';
import 'core/i18n/i18n.dart';
import 'core/router/router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'core/widgets/brand.dart';

class OneSourceApp extends ConsumerWidget {
  const OneSourceApp({super.key});

  Locale _locale(String? chosen) {
    if (chosen != null) return Locale(chosen);
    return Platform.localeName.toLowerCase().startsWith('ar') ? const Locale('ar') : const Locale('en');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final locale = _locale(settings.locale);
    ref.read(apiProvider).locale = locale.languageCode; // the ERP answers messages in the same language

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
