import 'package:flutter/widgets.dart';

/// Whether motion is reduced, from the in-app setting and the device "remove animations" setting.
class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.reduced, required super.child});

  final bool reduced;

  static bool reducedOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    return scope?.reduced ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// [d] normally, zero when motion is reduced.
  static Duration duration(BuildContext context, Duration d) => reducedOf(context) ? Duration.zero : d;

  @override
  bool updateShouldNotify(MotionScope oldWidget) => oldWidget.reduced != reduced;
}

/// Fades and lifts its child in once, with a stagger by [index]. Static when motion is reduced.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 18});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionScope.reducedOf(context)) {
      _c.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 12).toInt()), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, (1 - curve.value) * widget.offset), child: child),
      ),
    );
  }
}
