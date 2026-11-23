import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/doha_skyline.dart';
import '../../core/widgets/ui.dart';

/// Night sky + Doha skyline backdrop with a frosted panel rising from the bottom. Used by every sign-in step.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({super.key, required this.child, this.title, this.subtitle, this.showBack = false});

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final skyline = (size.height * .42).clamp(240.0, 420.0).toDouble();
    return Scaffold(
      backgroundColor: Palette.midnight,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Palette.nightGradient),
        child: Stack(children: [
          Positioned(top: 0, left: 0, right: 0, child: DohaSkyline(height: skyline)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      if (showBack)
                        GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: context.tr('back'), onTap: () => Navigator.of(context).maybePop())
                      else
                        const BrandLockup(),
                      const Spacer(),
                      const _LanguageToggle(),
                    ]),
                    SizedBox(height: skyline * .55),
                    Reveal(
                      offset: 40,
                      child: GlassCard(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        radius: 30,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (title != null) Text(title!, style: Theme.of(context).textTheme.headlineSmall),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(subtitle!, style: TextStyle(color: Theme.of(context).hintColor, height: 1.35)),
                          ],
                          if (title != null || subtitle != null) const SizedBox(height: 20),
                          child,
                        ]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(context.tr('auth.footer'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12)),
                  ]),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.translate_rounded, color: Palette.goldSoft, size: 18),
            const SizedBox(width: 6),
            Text(ar ? 'English' : 'العربية', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
