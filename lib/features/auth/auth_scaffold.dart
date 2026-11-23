import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/doha_skyline.dart';
import '../../core/widgets/ui.dart';

/// Sign-in layout: a maroon brand band with the West Bay silhouette, and a light sheet that holds the form.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({super.key, required this.child, this.title, this.subtitle, this.showBack = false, this.footer});

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    final band = keyboard ? 140.0 : (media.size.height * .32).clamp(220.0, 300.0).toDouble();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.maroonDeep,
        body: Stack(children: [
          AnimatedContainer(
            duration: MotionScope.duration(context, const Duration(milliseconds: 250)),
            height: band + 40,
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.maroonDeep, Palette.maroon])),
            child: Stack(children: [
              if (!keyboard) const Positioned(left: 0, right: 0, bottom: 34, child: SkylineSilhouette(height: 120)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: HeaderTone(
                    onBrand: true,
                    child: Row(children: [
                      if (showBack)
                        GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: context.tr('back'), onTap: () => Navigator.of(context).maybePop())
                      else
                        const BrandLockup(),
                      const Spacer(),
                      const _LanguageToggle(),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          Positioned.fill(
            top: band,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  children: [
                    Reveal(
                      offset: 16,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (title != null) Text(title!, style: Theme.of(context).textTheme.headlineSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
                        ],
                        if (title != null || subtitle != null) const SizedBox(height: 24),
                        child,
                      ]),
                    ),
                    const SizedBox(height: 24),
                    footer ??
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: Theme.of(context).hintColor),
                          const SizedBox(width: 6),
                          Flexible(child: Text(context.tr('auth.footer'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
                        ]),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.lang == 'ar';
    return Semantics(
      button: true,
      label: context.tr('settings.language'),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => ref.read(settingsProvider.notifier).setLocale(ar ? 'en' : 'ar'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language_rounded, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Text(ar ? 'English' : 'العربية', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
          ]),
        ),
      ),
    );
  }
}
