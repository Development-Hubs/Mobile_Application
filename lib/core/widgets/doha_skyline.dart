import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

/// Generated artwork: an evening Doha skyline over the Corniche — West Bay towers, a dhow on the water,
/// twinkling windows and stars, and a gentle tide. Drawn in code (no photo, no third-party image).
///
/// When motion is reduced the scene is drawn once and does not move.
class DohaSkyline extends StatefulWidget {
  const DohaSkyline({super.key, this.height = 320, this.night = true, this.showDhow = true});

  final double height;
  final bool night;
  final bool showDhow;

  @override
  State<DohaSkyline> createState() => _DohaSkylineState();
}

class _DohaSkylineState extends State<DohaSkyline> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reducedOf(context)) {
      _c.stop();
      _c.value = .3;
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
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _SkylinePainter(_c.value, widget.night, widget.showDhow)),
        ),
      ),
    );
  }
}

class _Tower {
  const _Tower(this.x, this.w, this.h, this.kind, {this.tone = 0});
  final double x, w, h;
  final String kind; // block, dome, spire, cone, twist, slant, stepped, cylinder
  final double tone;
}

class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.t, this.night, this.dhow);

  final double t;
  final bool night;
  final bool dhow;

  static const _towers = <_Tower>[
    _Tower(.02, .06, .30, 'stepped'),
    _Tower(.07, .05, .42, 'slant', tone: .1),
    _Tower(.115, .045, .36, 'block'),
    _Tower(.16, .07, .62, 'cylinder', tone: .2),
    _Tower(.235, .05, .48, 'twist'),
    _Tower(.29, .055, .56, 'cone', tone: .1),
    _Tower(.35, .04, .40, 'block'),
    _Tower(.395, .065, .74, 'spire', tone: .25),
    _Tower(.465, .05, .52, 'slant'),
    _Tower(.52, .07, .66, 'twist', tone: .15),
    _Tower(.595, .045, .44, 'dome'),
    _Tower(.645, .06, .58, 'cone'),
    _Tower(.71, .05, .38, 'block', tone: .2),
    _Tower(.76, .065, .50, 'stepped'),
    _Tower(.83, .05, .64, 'spire'),
    _Tower(.885, .06, .34, 'dome', tone: .1),
    _Tower(.945, .05, .46, 'slant'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * .74;
    final skyH = horizon;

    // sky
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: night
            ? const [Color(0xFF050B1C), Palette.navy, Color(0xFF4A1230), Color(0xFFB4485F)]
            : const [Color(0xFF1C2E57), Color(0xFF6B2A4A), Color(0xFFC8704E), Color(0xFFF1C27D)],
        stops: const [0, .45, .82, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon), sky);

    // stars
    final rnd = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 70; i++) {
      final sx = rnd.nextDouble() * w, sy = rnd.nextDouble() * skyH * .6;
      final phase = rnd.nextDouble() * math.pi * 2;
      final a = (.35 + .65 * (.5 + .5 * math.sin(t * math.pi * 2 * 3 + phase))) * (night ? 1 : .35);
      star.color = Colors.white.withValues(alpha: a * .8);
      canvas.drawCircle(Offset(sx, sy), rnd.nextDouble() * 1.1 + .3, star);
    }

    // crescent moon with glow
    final moon = Offset(w * .82, skyH * .2);
    canvas.drawCircle(moon, 46, Paint()..shader = RadialGradient(colors: [Palette.goldSoft.withValues(alpha: .35), Colors.transparent]).createShader(Rect.fromCircle(center: moon, radius: 46)));
    final crescent = Path()
      ..addOval(Rect.fromCircle(center: moon, radius: 15))
      ..fillType = PathFillType.evenOdd;
    final bite = Path()..addOval(Rect.fromCircle(center: moon.translate(6, -4), radius: 13));
    canvas.drawPath(Path.combine(PathOperation.difference, crescent, bite), Paint()..color = Palette.goldSoft);

    // distant haze towers
    final haze = Paint()..color = const Color(0xFF2A1E44).withValues(alpha: .55);
    for (var i = 0; i < 26; i++) {
      final x = i / 26 * w, bw = w / 30, bh = skyH * (.12 + (math.sin(i * 1.7) + 1) * .08);
      canvas.drawRect(Rect.fromLTWH(x, horizon - bh, bw, bh), haze);
    }

    // main towers
    final windowRnd = math.Random(11);
    for (final tw in _towers) {
      final x = tw.x * w, bw = tw.w * w, bh = tw.h * skyH;
      final top = horizon - bh;
      final body = _shape(tw.kind, x, top, bw, bh);
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(const Color(0xFF1B2347), const Color(0xFF3A1B3F), tw.tone)!, const Color(0xFF0B1022)],
        ).createShader(Rect.fromLTWH(x, top, bw, bh));
      canvas.drawPath(body, fill);
      // rim light from the sunset
      canvas.drawPath(body, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Palette.goldSoft.withValues(alpha: .18));

      // windows
      canvas.save();
      canvas.clipPath(body);
      final cols = (bw / 5).floor().clamp(2, 12).toInt(), rows = (bh / 7).floor();
      for (var r = 2; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final seed = windowRnd.nextDouble();
          if (seed < .55) continue;
          final blink = .5 + .5 * math.sin(t * math.pi * 2 * 2 + seed * 40);
          final on = seed > .9 ? blink : 1.0;
          final color = seed > .8 ? Palette.goldSoft : const Color(0xFFFFE9B8);
          canvas.drawRect(Rect.fromLTWH(x + 2 + c * (bw - 4) / cols, top + r * 7.0, 1.8, 2.6), Paint()..color = color.withValues(alpha: .55 * on));
        }
      }
      canvas.restore();

      if (tw.kind == 'spire') {
        // aviation light
        final blink = (t * 24 % 1) < .5 ? 1.0 : .25;
        canvas.drawCircle(Offset(x + bw / 2, top - bh * .12), 2.2, Paint()..color = Colors.redAccent.withValues(alpha: blink));
      }
    }

    // Corniche promenade line with lamps
    canvas.drawRect(Rect.fromLTWH(0, horizon, w, 3), Paint()..color = const Color(0xFF0A0F1F));
    for (var i = 0; i < 24; i++) {
      final lx = (i + .5) / 24 * w;
      canvas.drawCircle(Offset(lx, horizon - 2), 1.6, Paint()..color = Palette.goldSoft.withValues(alpha: .9));
      canvas.drawCircle(Offset(lx, horizon - 2), 6, Paint()..color = Palette.goldSoft.withValues(alpha: .08));
    }

    // water
    final water = Rect.fromLTWH(0, horizon + 3, w, h - horizon - 3);
    canvas.drawRect(
        water,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14284A), Color(0xFF07101F)])
              .createShader(water));

    // reflections
    for (final tw in _towers) {
      final x = tw.x * w, bw = tw.w * w;
      final len = (h - horizon) * (.4 + tw.h * .6);
      for (var y = 0.0; y < len; y += 4) {
        final wobble = math.sin((y / 9) + t * math.pi * 2 * 4 + tw.x * 20) * 2.5;
        final alpha = (1 - y / len) * .14;
        canvas.drawRect(Rect.fromLTWH(x + wobble + bw * .15, horizon + 4 + y, bw * .7, 1.6), Paint()..color = Palette.goldSoft.withValues(alpha: alpha));
      }
    }

    // moon path on the water
    for (var y = 0.0; y < h - horizon; y += 5) {
      final wobble = math.sin(y / 7 + t * math.pi * 2 * 5) * 6;
      canvas.drawRect(Rect.fromLTWH(moon.dx - 14 + wobble, horizon + 6 + y, 28 - y * .1, 1.4), Paint()..color = Palette.goldSoft.withValues(alpha: .22 * (1 - y / (h - horizon))));
    }

    // tide lines
    final tide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .06);
    for (var k = 0; k < 4; k++) {
      final p = Path();
      final base = horizon + 14 + k * (h - horizon) / 5;
      for (var x = 0.0; x <= w; x += 8) {
        final y = base + math.sin(x / 34 + t * math.pi * 2 * (2 + k) + k) * 2;
        x == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      canvas.drawPath(p, tide);
    }

    if (dhow) _drawDhow(canvas, Offset(w * (.12 + .76 * ((t * 1.0) % 1)), horizon + (h - horizon) * .5), (h - horizon) * .55);
  }

  static Path _shape(String kind, double x, double top, double bw, double bh) {
    final p = Path();
    final bottom = top + bh;
    switch (kind) {
      case 'dome':
        p.moveTo(x, bottom);
        p.lineTo(x, top + bw / 2);
        p.arcToPoint(Offset(x + bw, top + bw / 2), radius: Radius.circular(bw / 2));
        p.lineTo(x + bw, bottom);
        break;
      case 'spire':
        p.moveTo(x, bottom);
        p.lineTo(x, top + bh * .08);
        p.lineTo(x + bw * .38, top);
        p.lineTo(x + bw * .5, top - bh * .12);
        p.lineTo(x + bw * .62, top);
        p.lineTo(x + bw, top + bh * .08);
        p.lineTo(x + bw, bottom);
        break;
      case 'cone':
        p.moveTo(x, bottom);
        p.lineTo(x + bw * .12, top + bh * .18);
        p.quadraticBezierTo(x + bw / 2, top - bh * .04, x + bw * .88, top + bh * .18);
        p.lineTo(x + bw, bottom);
        break;
      case 'twist':
        p.moveTo(x, bottom);
        p.cubicTo(x - bw * .1, top + bh * .6, x + bw * .2, top + bh * .3, x + bw * .1, top);
        p.lineTo(x + bw * .9, top + bh * .04);
        p.cubicTo(x + bw * .8, top + bh * .3, x + bw * 1.1, top + bh * .6, x + bw, bottom);
        break;
      case 'slant':
        p.moveTo(x, bottom);
        p.lineTo(x, top + bh * .12);
        p.lineTo(x + bw, top);
        p.lineTo(x + bw, bottom);
        break;
      case 'stepped':
        p.moveTo(x, bottom);
        p.lineTo(x, top + bh * .3);
        p.lineTo(x + bw * .2, top + bh * .3);
        p.lineTo(x + bw * .2, top + bh * .12);
        p.lineTo(x + bw * .4, top + bh * .12);
        p.lineTo(x + bw * .4, top);
        p.lineTo(x + bw * .6, top);
        p.lineTo(x + bw * .6, top + bh * .12);
        p.lineTo(x + bw * .8, top + bh * .12);
        p.lineTo(x + bw * .8, top + bh * .3);
        p.lineTo(x + bw, top + bh * .3);
        p.lineTo(x + bw, bottom);
        break;
      case 'cylinder':
        // a rounded tower with a lattice crown and a short mast
        p.moveTo(x, bottom);
        p.lineTo(x, top + bw * .5);
        p.quadraticBezierTo(x + bw / 2, top - bw * .1, x + bw, top + bw * .5);
        p.lineTo(x + bw, bottom);
        p.addRect(Rect.fromLTWH(x + bw * .47, top - bh * .1, bw * .06, bh * .1));
        break;
      default:
        p.addRect(Rect.fromLTWH(x, top, bw, bh));
    }
    p.close();
    return p;
  }

  void _drawDhow(Canvas canvas, Offset c, double size) {
    final s = size.clamp(18.0, 42.0).toDouble();
    final hull = Path()
      ..moveTo(c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx - s * .2, c.dy + s * .35, c.dx + s * .9, c.dy - s * .05)
      ..lineTo(c.dx + s * 1.1, c.dy - s * .2)
      ..lineTo(c.dx - s * 1.15, c.dy - s * .12)
      ..close();
    final dark = Paint()..color = const Color(0xFF060A16);
    canvas.drawPath(hull, dark);
    canvas.drawRect(Rect.fromLTWH(c.dx - s * .05, c.dy - s * 1.3, s * .05, s * 1.2), dark);
    final sail = Path()
      ..moveTo(c.dx - s * .02, c.dy - s * 1.3)
      ..quadraticBezierTo(c.dx + s * .9, c.dy - s * .8, c.dx + s * .6, c.dy - s * .25)
      ..lineTo(c.dx - s * .7, c.dy - s * .3)
      ..close();
    canvas.drawPath(sail, Paint()..color = Palette.goldSoft.withValues(alpha: .85));
    // reflection
    canvas.drawRect(Rect.fromLTWH(c.dx - s * .8, c.dy + s * .2, s * 1.6, 1.4), Paint()..color = Palette.goldSoft.withValues(alpha: .12));
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => old.t != t || old.night != night;
}


/// A quiet silhouette of the West Bay skyline for brand surfaces: two layers of towers in white at low opacity,
/// a thin Corniche line and a few warm lights. Generated artwork; static.
class SkylineSilhouette extends StatelessWidget {
  const SkylineSilhouette({super.key, this.height = 150, this.opacity = 1});
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SilhouettePainter(opacity)),
      );
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h - 6;
    // back row: low, wide, faint
    final back = Paint()..color = Colors.white.withValues(alpha: .07 * opacity);
    for (var i = 0; i < 22; i++) {
      final x = i / 22 * w, bw = w / 24, bh = h * (.18 + ((i * 37) % 11) / 11 * .22);
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x, base - bh, bw, bh), topLeft: const Radius.circular(2), topRight: const Radius.circular(2)), back);
    }
    // front row: the recognisable towers
    final front = Paint()..color = Colors.white.withValues(alpha: .14 * opacity);
    for (final t in _SkylinePainter._towers) {
      final x = t.x * w, bw = t.w * w * .9, bh = t.h * h * .95;
      canvas.drawPath(_SkylinePainter._shape(t.kind, x, base - bh, bw, bh), front);
    }
    // Corniche line and lamps
    canvas.drawRect(Rect.fromLTWH(0, base, w, 1.2), Paint()..color = Colors.white.withValues(alpha: .25 * opacity));
    final lamp = Paint()..color = Palette.goldSoft.withValues(alpha: .7 * opacity);
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(Offset((i + .5) / 18 * w, base - 2), 1.3, lamp);
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => old.opacity != opacity;
}

/// A real photograph of Doha (assets/photos/doha.jpg) under a maroon wash so text on it stays readable.
/// Falls back to the drawn silhouette when the photograph is not part of the build.
class DohaPhoto extends StatelessWidget {
  const DohaPhoto({super.key, this.wash = .55, this.alignment = const Alignment(0, -.2)});

  /// Strength of the maroon overlay at the bottom (0–1).
  final double wash;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Image.asset(
          'assets/photos/doha.jpg',
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(gradient: Palette.heroGradient),
            child: Align(alignment: Alignment.bottomCenter, child: SkylineSilhouette(height: 140)),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Palette.maroonDeep.withValues(alpha: .55),
                Palette.maroon.withValues(alpha: wash * .45),
                Palette.maroonDeep.withValues(alpha: wash + .25 > 1 ? 1 : wash + .25),
              ],
              stops: const [0, .45, 1],
            ),
          ),
        ),
      ]);
}
