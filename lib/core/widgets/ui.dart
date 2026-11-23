import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../i18n/i18n.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../util/format.dart';

// ---------------------------------------------------------------------------------------------------------------
// Headers and surfaces
// ---------------------------------------------------------------------------------------------------------------

/// A large gradient header with a soft pattern, used at the top of every module.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.bottom, this.gradient = Palette.heroGradient});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? bottom;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Palette.maroon.withValues(alpha: .25), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Stack(children: [
        Positioned.fill(child: ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)), child: CustomPaint(painter: _ArabesquePainter()))),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (Navigator.of(context).canPop())
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: context.tr('back')),
                ),
              const Spacer(),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (icon != null) ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                  child: Icon(icon, color: Palette.goldSoft, size: 26),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: .78), fontWeight: FontWeight.w500)),
                  ],
                ]),
              ),
            ]),
            if (bottom != null) ...[const SizedBox(height: 18), bottom!],
          ]),
        ),
      ]),
    );
  }
}

/// Eight-point star lattice drawn faintly over headers (generated pattern).
class _ArabesquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .06);
    const step = 44.0;
    for (var y = -step; y < size.height + step; y += step) {
      for (var x = -step; x < size.width + step; x += step) {
        final c = Offset(x + (y ~/ step).isOdd.toDouble() * step / 2, y);
        final r = step * .32;
        canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: r * 2), p);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(.785398);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), p);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension on bool {
  double toDouble() => this ? 1 : 0;
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Semantics(
          button: true,
          label: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              backgroundColor: Palette.gold,
              textColor: Palette.navy,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// A frosted card for content placed on top of gradients and the skyline.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: dark ? const Color(0xCC0C1630) : Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? Colors.white12 : Colors.white),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A white rounded section with an optional title row.
class Section extends StatelessWidget {
  const Section({super.key, this.title, this.icon, this.action, required this.child, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 18, color: scheme.primary), const SizedBox(width: 8)],
              Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
              if (action != null) action!,
            ]),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      ),
    );
  }
}

/// A small coloured pill for a status word.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String? status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = Palette.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: c.withValues(alpha: .25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label ?? statusLabel(context, status), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

/// Coloured round icon used in tiles.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = Palette.maroon, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: .18), color.withValues(alpha: .08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(icon, color: color, size: size * .5),
      );
}

/// Big number with a label, for dashboards.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.color = Palette.maroon, this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(icon, color: color, size: 38),
              const SizedBox(height: 12),
              CountUp(value: value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        ),
      );
}

/// Animates an integer text from zero once (falls back to plain text for non-numbers or reduced motion).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style});
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(value);
    if (n == null || MotionScope.reducedOf(context)) return Text(value, style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: n.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Buttons and feedback
// ---------------------------------------------------------------------------------------------------------------

/// A filled button that shows progress and blocks double taps while [onPressed] runs.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.gradient = Palette.heroGradient, this.outlined = false});
  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool outlined;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    final content = AnimatedSwitcher(
      duration: MotionScope.duration(context, const Duration(milliseconds: 200)),
      child: _busy
          ? const SizedBox(key: ValueKey('b'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Row(key: const ValueKey('l'), mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 10)],
              Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
            ]),
    );
    if (widget.outlined) {
      return OutlinedButton(onPressed: enabled ? _run : null, child: content);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedOpacity(
        opacity: enabled || _busy ? 1 : .45,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled ? [BoxShadow(color: Palette.maroon.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))] : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? _run : null,
              child: SizedBox(height: 54, child: Center(child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16), child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: content)))),
            ),
          ),
        ),
      ),
    );
  }
}

class Toast {
  const Toast._();

  static void success(BuildContext context, String message) => _show(context, message, Palette.success, Icons.check_circle_rounded);
  static void error(BuildContext context, Object error) =>
      _show(context, error is ApiException ? error.message : context.tr('error.generic'), Palette.danger, error is ApiException && error.isOffline ? Icons.wifi_off_rounded : Icons.error_rounded);
  static void info(BuildContext context, String message) => _show(context, message, Palette.navySoft, Icons.info_rounded);

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      backgroundColor: color,
      content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)))]),
    ));
  }
}

/// Asks before a consequential action. Returns true only when the person confirms.
Future<bool> confirmAction(BuildContext context, {required String title, String? message, String? confirm, bool danger = false, IconData icon = Icons.help_rounded}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconBadge(icon, color: danger ? Palette.danger : Palette.maroon, size: 64),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        if (message != null) ...[const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor))],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel')))),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: danger ? Palette.danger : Palette.maroon, minimumSize: const Size.fromHeight(50)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm ?? context.tr('confirm')),
            ),
          ),
        ]),
      ]),
    ),
  );
  return ok ?? false;
}

/// Asks for a short text (reason, note). Returns null when cancelled.
Future<String?> askText(BuildContext context, {required String title, String? hint, bool required = false, int maxLines = 3}) {
  final c = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: StatefulBuilder(
        builder: (context, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: c, autofocus: true, maxLines: maxLines, decoration: InputDecoration(hintText: hint), onChanged: (_) => set(() {})),
          const SizedBox(height: 16),
          FilledButton(onPressed: required && c.text.trim().isEmpty ? null : () => Navigator.pop(context, c.text.trim()), child: Text(context.tr('continue'))),
        ]),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Loading, empty and error states
// ---------------------------------------------------------------------------------------------------------------

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reducedOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF16223F) : const Color(0xFFEAE4D8);
    final hi = dark ? const Color(0xFF223159) : const Color(0xFFF8F4EC);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          colors: [base, hi, base],
          stops: const [.25, .5, .75],
          begin: Alignment(-1 - 2 + _c.value * 4, 0),
          end: Alignment(1 - 2 + _c.value * 4, 0),
        ).createShader(r),
        child: child,
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.tr('loading'),
        child: Shimmer(
          child: Column(
            children: List.generate(
              count,
              (i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Container(
                  height: 78,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.message, this.icon = Icons.inbox_rounded, this.action});
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Palette.gold.withValues(alpha: .25), Palette.maroon.withValues(alpha: .12)])),
            child: Icon(icon, size: 44, color: Palette.maroon),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor))],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      );
}

/// Shows the ERP's own error message and a retry button. Never replaces data with samples.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final offline = api?.isOffline ?? false;
    final disabled = api?.code == 'module_disabled' || api?.status == 404;
    return EmptyView(
      icon: offline ? Icons.wifi_off_rounded : (disabled ? Icons.block_rounded : Icons.error_outline_rounded),
      title: offline ? context.tr('error.offline') : (disabled ? context.tr('error.unavailable') : context.tr('error.title')),
      message: api?.message ?? context.tr('error.generic'),
      action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(context.tr('retry'))),
    );
  }
}

/// Renders an [AsyncValue] with skeleton, error (with retry) and data states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry, this.skeleton});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) => value.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: builder,
        loading: () => skeleton ?? const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      );
}

/// Standard module page: gradient header + pull-to-refresh body.
class ModulePage extends StatelessWidget {
  const ModulePage({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.headerBottom, required this.children, this.onRefresh, this.fab});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? headerBottom;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        HeroHeader(title: title, subtitle: subtitle, icon: icon, trailing: trailing, bottom: headerBottom),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 120),
      ],
    );
    return Scaffold(
      floatingActionButton: fab,
      body: onRefresh == null ? list : RefreshIndicator(color: Palette.maroon, onRefresh: onRefresh!, child: list),
    );
  }
}

/// A row in a list: icon, title, subtitle, trailing widget.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.title, this.subtitle, this.icon, this.iconColor = Palette.maroon, this.trailing, this.onTap, this.meta});
  final String title;
  final String? subtitle;
  final String? meta;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                if (icon != null) ...[IconBadge(icon!, color: iconColor), const SizedBox(width: 14)],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))],
                    if (meta != null) ...[const SizedBox(height: 6), Text(meta!, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5, fontWeight: FontWeight.w600))],
                  ]),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                if (onTap != null && trailing == null) Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
              ]),
            ),
          ),
        ),
      );
}

/// Horizontal filter chips (queues, tabs).
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.value, required this.onChanged, this.onDark = true});
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool onDark;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: options.entries.map((e) {
            final on = e.key == value;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                selected: on,
                showCheckmark: false,
                label: Text(e.value),
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: on ? Palette.navy : (onDark ? Colors.white : null)),
                selectedColor: Palette.goldSoft,
                backgroundColor: onDark ? Colors.white.withValues(alpha: .14) : null,
                onSelected: (_) => onChanged(e.key),
              ),
            );
          }).toList(),
        ),
      );
}

String timeAgo(BuildContext context, DateTime? d) => Fmt.ago(d, context.lang);

/// Translated status word, or the humanised server value when there is no translation.
String statusLabel(BuildContext context, String? status) {
  final key = 'status.$status';
  final t = context.tr(key);
  return t == key ? Fmt.humanize(status) : t;
}
