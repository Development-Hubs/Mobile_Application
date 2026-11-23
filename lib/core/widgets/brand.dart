import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The OneSource mark: a maroon tile with the nine-point serrated band and a ring.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .25),
            boxShadow: [BoxShadow(color: Palette.maroon.withValues(alpha: .25), blurRadius: size * .3, offset: Offset(0, size * .08))],
          ),
          child: CustomPaint(painter: _MarkPainter()),
        ),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final rect = Offset.zero & size;
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(16 * s)));
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(colors: [Palette.maroonBright, Palette.maroonDeep], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect));
    final band = Path()..moveTo(0, 0);
    band.lineTo(13 * s, 0);
    for (var i = 0; i < 10; i++) {
      final y = i * 6.4 * s;
      band.lineTo(20 * s, y + 3.2 * s);
      band.lineTo(13 * s, y + 6.4 * s);
    }
    band
      ..lineTo(0, 64 * s)
      ..close();
    canvas.drawPath(band, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(40 * s, 32 * s), 11.5 * s, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..color = Colors.white);
    canvas.drawCircle(Offset(40 * s, 32 * s), 3 * s, Paint()..color = Palette.goldSoft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "OneSource Connect" lock-up for splash and sign-in.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.light = true, this.subtitle});
  final bool light;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : Palette.ink;
    // the product name is a Latin wordmark: always left-to-right, also in Arabic
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: light ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: const BrandMark(size: 36),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'OneSource ', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18)),
            TextSpan(text: 'Connect', style: TextStyle(color: light ? Palette.goldSoft : Palette.maroon, fontWeight: FontWeight.w700, fontSize: 18)),
          ])),
          if (subtitle != null) Text(subtitle!, style: TextStyle(color: color.withValues(alpha: .7), fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

/// A ribbon on demo/staging builds so a test device is never mistaken for production.
class EnvRibbon extends StatelessWidget {
  const EnvRibbon({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return child;
    return Banner(message: label, location: BannerLocation.topEnd, color: Palette.gold, textStyle: const TextStyle(color: Palette.navy, fontWeight: FontWeight.w800, fontSize: 10), child: child);
  }
}
