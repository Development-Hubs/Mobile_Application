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
// Tone: widgets inside a header know whether they sit on the light canvas or on a maroon surface.
// ---------------------------------------------------------------------------------------------------------------

class HeaderTone extends InheritedWidget {
  const HeaderTone({super.key, required this.onBrand, required super.child});

  /// true on a maroon surface (white content), false on the light canvas.
  final bool onBrand;

  static bool onBrandOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HeaderTone>()?.onBrand ?? false;

  @override
  bool updateShouldNotify(HeaderTone old) => old.onBrand != onBrand;
}

/// Colours for text and controls that sit inside a header.
class Tone {
  Tone._(this.fg, this.fg2, this.control, this.controlLine);
  final Color fg, fg2, control, controlLine;

  static Tone of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (HeaderTone.onBrandOf(context)) return Tone._(Colors.white, Colors.white70, Colors.white.withValues(alpha: .14), Colors.white24);
    return Tone._(
      dark ? Colors.white : Palette.ink,
      dark ? const Color(0xFFAAB1C0) : Palette.ink2,
      dark ? Palette.nightCard : Colors.white,
      dark ? Palette.nightLine : Palette.line,
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Headers and surfaces
// ---------------------------------------------------------------------------------------------------------------

/// Page header: a large title on the canvas with an optional icon, actions and a bottom slot (filters, search).
/// [brand] switches to a maroon surface for the few places that need emphasis.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.bottom, this.gradient = Palette.heroGradient, this.brand = false});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? bottom;
  final Gradient gradient;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final canPop = Navigator.of(context).canPop();
    return HeaderTone(
      onBrand: brand,
      child: Builder(builder: (context) {
        final tone = Tone.of(context);
        final content = Padding(
          padding: EdgeInsets.fromLTRB(20, top + 8, 20, bottom == null ? 6 : 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (canPop || trailing != null)
              SizedBox(
                height: 44,
                child: Row(children: [
                  if (canPop) GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: context.tr('back')),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ]),
              ),
            SizedBox(height: canPop || trailing != null ? 14 : 10),
            Row(children: [
              if (icon != null) ...[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: brand ? Colors.white.withValues(alpha: .14) : Palette.maroon.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: brand ? Palette.goldSoft : Palette.maroon, size: 24),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: tone.fg)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tone.fg2, fontSize: 14)),
                  ],
                ]),
              ),
            ]),
            if (bottom != null) ...[const SizedBox(height: 16), bottom!],
          ]),
        );
        if (!brand) return content;
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
          child: content,
        );
      }),
    );
  }
}

/// A round icon button that adapts to where it sits (canvas or maroon surface).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final onBrand = HeaderTone.onBrandOf(context);
    final button = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: tone.control, shape: BoxShape.circle, border: Border.all(color: tone.controlLine)),
      child: Icon(icon, color: tone.fg, size: 21),
    );
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Badge(
            isLabelVisible: badge > 0,
            label: Text(badge > 99 ? '99+' : '$badge'),
            backgroundColor: onBrand ? Palette.gold : Palette.maroon,
            textColor: Colors.white,
            child: onBrand ? ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: button)) : button,
          ),
        ),
      ),
    );
  }
}

/// A raised white panel (sign-in sheet, dialogs on brand surfaces).
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? Palette.nightCard : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: Palette.ink.withValues(alpha: dark ? .3 : .08), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: child,
    );
  }
}

/// A card with an optional title row.
class Section extends StatelessWidget {
  const Section({super.key, this.title, this.icon, this.action, required this.child, this.padding = const EdgeInsets.all(18)});
  final String? title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null) ...[
              Row(children: [
                if (icon != null) ...[Icon(icon, size: 19, color: Palette.maroon), const SizedBox(width: 8)],
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

/// A small heading above a group of cards.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 14, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null) action!,
        ]),
      );
}

/// A soft coloured pill for a status word.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String? status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = Palette.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(99)),
      child: Text(label ?? statusLabel(context, status), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Tinted rounded square with an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = Palette.maroon, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(icon, color: color, size: size * .5),
      );
}

/// Number + label tile for dashboards.
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
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconBadge(icon, color: color, size: 36),
                const Spacer(),
                if (onTap != null) Icon(Icons.arrow_forward_rounded, size: 18, color: Theme.of(context).hintColor),
              ]),
              const SizedBox(height: 14),
              CountUp(value: value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

/// Counts an integer up once (plain text for non-numbers or reduced motion).
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
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Buttons and feedback
// ---------------------------------------------------------------------------------------------------------------

/// Primary button that shows progress and blocks double taps while [onPressed] runs.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.gradient = Palette.heroGradient, this.outlined = false});
  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;

  /// The button uses one solid colour taken from this (maroon by default).
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

  Color get _color {
    if (identical(widget.gradient, Palette.heroGradient)) return Palette.maroon;
    if (identical(widget.gradient, Palette.goldGradient)) return Palette.gold;
    final g = widget.gradient;
    return g is LinearGradient ? g.colors.last : Palette.maroon;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    final fg = widget.outlined ? Theme.of(context).colorScheme.onSurface : Colors.white;
    final content = AnimatedSwitcher(
      duration: MotionScope.duration(context, const Duration(milliseconds: 180)),
      child: _busy
          ? SizedBox(key: const ValueKey('b'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
          : Row(key: const ValueKey('l'), mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: fg), const SizedBox(width: 10)],
              Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16))),
            ]),
    );
    if (widget.outlined) {
      return OutlinedButton(onPressed: enabled ? _run : null, child: content);
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _color,
        disabledBackgroundColor: _color.withValues(alpha: _busy ? 1 : .35),
        minimumSize: const Size.fromHeight(54),
      ),
      onPressed: enabled ? _run : (_busy ? () {} : null),
      child: content,
    );
  }
}

class Toast {
  const Toast._();

  static void success(BuildContext context, String message) => _show(context, message, Palette.success, Icons.check_circle_rounded);
  static void error(BuildContext context, Object error) =>
      _show(context, error is ApiException ? error.message : context.tr('error.generic'), Palette.danger, error is ApiException && error.isOffline ? Icons.wifi_off_rounded : Icons.error_rounded);
  static void info(BuildContext context, String message) => _show(context, message, Palette.ink, Icons.info_rounded);

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      backgroundColor: color,
      content: Row(children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)))]),
    ));
  }
}

/// Asks before a consequential action. Returns true only when the person confirms.
Future<bool> confirmAction(BuildContext context, {required String title, String? message, String? confirm, bool danger = false, IconData icon = Icons.help_outline_rounded}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconBadge(icon, color: danger ? Palette.danger : Palette.maroon, size: 58),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        if (message != null) ...[const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor))],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel')))),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: danger ? Palette.danger : Palette.maroon, minimumSize: const Size.fromHeight(52)),
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
          TextField(controller: c, autofocus: true, maxLines: maxLines, minLines: 1, decoration: InputDecoration(hintText: hint), onChanged: (_) => set(() {})),
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
    final base = dark ? const Color(0xFF1B2130) : const Color(0xFFECE8E3);
    final hi = dark ? const Color(0xFF262D3F) : const Color(0xFFF7F5F2);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          colors: [base, hi, base],
          stops: const [.25, .5, .75],
          begin: Alignment(-3 + _c.value * 4, 0),
          end: Alignment(-1 + _c.value * 4, 0),
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
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                child: Container(height: 76, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
              ),
            ),
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.action});
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.maroon.withValues(alpha: .07)),
            child: Icon(icon, size: 34, color: Palette.maroon),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)],
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

/// Standard module page: header + pull-to-refresh body.
class ModulePage extends StatelessWidget {
  const ModulePage({super.key, required this.title, this.subtitle, this.icon, this.trailing, this.headerBottom, required this.children, this.onRefresh, this.fab, this.brand = false});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? headerBottom;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? fab;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        HeroHeader(title: title, subtitle: subtitle, icon: icon, trailing: trailing, bottom: headerBottom, brand: brand),
        const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Theme.of(context).dividerColor)),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                if (icon != null) ...[IconBadge(icon!, color: iconColor, size: 42), const SizedBox(width: 13)],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                    ],
                    if (meta != null && meta!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meta!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                    ],
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

/// Horizontal filter pills (queues, tabs). Adapts to the canvas or a maroon header.
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.value, required this.onChanged, this.onDark});
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  /// Leave null to follow the surrounding header.
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final brand = onDark ?? HeaderTone.onBrandOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.entries.map((e) {
          final on = e.key == value;
          final bg = on ? (brand ? Colors.white : Palette.maroon) : (brand ? Colors.white.withValues(alpha: .14) : (dark ? Palette.nightCard : Colors.white));
          final fg = on ? (brand ? Palette.maroon : Colors.white) : (brand || dark ? Colors.white : Palette.ink);
          final border = on ? Colors.transparent : (brand ? Colors.white24 : (dark ? Palette.nightLine : Palette.line));
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Material(
              color: bg,
              shape: StadiumBorder(side: BorderSide(color: border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(e.key);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text(e.value, style: TextStyle(color: fg, fontWeight: on ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5))),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A search field for page headers.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, this.onSubmitted});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 14)),
      );
}

String timeAgo(BuildContext context, DateTime? d) => Fmt.ago(d, context.lang);

/// Translated status word, or the humanised server value when there is no translation.
String statusLabel(BuildContext context, String? status) {
  final key = 'status.$status';
  final t = context.tr(key);
  return t == key ? Fmt.humanize(status) : t;
}
