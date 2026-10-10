import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'tile_art.dart';

/// Hand-drawn game icons (no icon fonts), drawn in a 100x100 box.
enum GameIcons {
  heart,
  heartBroken,
  coin,
  star,
  starEmpty,
  lock,
  gear,
  pause,
  play,
  close,
  music,
  sound,
  vibrate,
  brush,
  swap,
  splash,
  plus,
  map,
  retry,
  video,
  check,
  arrow,
  back,
}

class GameIcon extends StatelessWidget {
  final GameIcons icon;
  final double size;
  const GameIcon(this.icon, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _IconPainter(icon));
}

class _IconPainter extends CustomPainter {
  final GameIcons icon;
  _IconPainter(this.icon);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);
    IconArt.draw(canvas, icon);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.icon != icon;
}

class IconArt {
  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _grad(Rect r, List<Color> colors, {bool vertical = true}) =>
      Paint()
        ..shader = ui.Gradient.linear(
          vertical ? r.topCenter : r.centerLeft,
          vertical ? r.bottomCenter : r.centerRight,
          colors,
        );

  static void _gloss(Canvas canvas, Path clip, Rect area) {
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawOval(
      area,
      Paint()
        ..shader = ui.Gradient.linear(area.topCenter, area.bottomCenter, [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.0),
        ]),
    );
    canvas.restore();
  }

  static Path heartPath() => Path()
    ..moveTo(50, 88)
    ..cubicTo(36, 76, 8, 60, 9, 36)
    ..cubicTo(10, 18, 26, 9, 38, 12)
    ..cubicTo(44, 13, 48, 17, 50, 22)
    ..cubicTo(52, 17, 56, 13, 62, 12)
    ..cubicTo(74, 9, 90, 18, 91, 36)
    ..cubicTo(92, 60, 64, 76, 50, 88)
    ..close();

  static Path starPath(double cx, double cy, double outer, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / 5;
      final o = Offset(cx + r * cos(a), cy + r * sin(a));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  static void draw(Canvas canvas, GameIcons icon) {
    switch (icon) {
      case GameIcons.heart:
      case GameIcons.heartBroken:
        final p = heartPath();
        canvas.drawPath(
          p.shift(const Offset(0, 4)),
          _fill(const Color(0x40300020)),
        );
        canvas.drawPath(
          p,
          _grad(const Rect.fromLTWH(0, 10, 100, 80), [
            const Color(0xFFFF6B8B),
            const Color(0xFFE5174B),
          ]),
        );
        _gloss(canvas, p, const Rect.fromLTWH(18, 14, 52, 30));
        canvas.drawPath(p, _stroke(const Color(0xFF9C0F35), 5));
        if (icon == GameIcons.heartBroken) {
          canvas.drawPath(
            Path()
              ..moveTo(50, 22)
              ..lineTo(42, 40)
              ..lineTo(56, 52)
              ..lineTo(46, 70)
              ..lineTo(50, 88),
            _stroke(const Color(0xFF3B1A63), 6),
          );
        }
      case GameIcons.coin:
        canvas.drawCircle(
          const Offset(50, 54),
          40,
          _fill(const Color(0x40402000)),
        );
        canvas.drawCircle(
          const Offset(50, 50),
          40,
          _grad(const Rect.fromLTWH(10, 10, 80, 80), [
            const Color(0xFFFFE680),
            const Color(0xFFF2A50C),
          ]),
        );
        canvas.drawCircle(
          const Offset(50, 50),
          40,
          _stroke(const Color(0xFFB36B00), 5),
        );
        canvas.drawCircle(
          const Offset(50, 50),
          29,
          _stroke(const Color(0xFFD98E05), 4),
        );
        final s = starPath(50, 51, 18, 8);
        canvas.drawPath(s, _fill(const Color(0xFFFFF4C2)));
        canvas.drawPath(s, _stroke(const Color(0xFFC77D00), 3));
        _gloss(
          canvas,
          Path()..addOval(const Rect.fromLTWH(10, 10, 80, 80)),
          const Rect.fromLTWH(20, 12, 50, 28),
        );
      case GameIcons.star:
      case GameIcons.starEmpty:
        final p = starPath(50, 54, 44, 21);
        final rounded = p;
        canvas.drawPath(
          rounded.shift(const Offset(0, 4)),
          _fill(const Color(0x40402000)),
        );
        if (icon == GameIcons.star) {
          canvas.drawPath(
            rounded,
            _grad(const Rect.fromLTWH(0, 10, 100, 90), [
              const Color(0xFFFFF07A),
              const Color(0xFFFFB300),
            ]),
          );
          _gloss(canvas, rounded, const Rect.fromLTWH(22, 14, 50, 34));
          canvas.drawPath(rounded, _stroke(const Color(0xFFC77700), 5));
        } else {
          canvas.drawPath(rounded, _fill(const Color(0xFF8B79A8)));
          canvas.drawPath(rounded, _stroke(const Color(0xFF5B4878), 5));
        }
      case GameIcons.lock:
        canvas.drawPath(
          Path()
            ..moveTo(30, 48)
            ..lineTo(30, 34)
            ..arcToPoint(
              const Offset(70, 34),
              radius: const Radius.circular(20),
            )
            ..lineTo(70, 48),
          _stroke(const Color(0xFF8C8FA3), 10),
        );
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 44, 60, 46),
          const Radius.circular(10),
        );
        canvas.drawRRect(
          body,
          _grad(body.outerRect, [
            const Color(0xFFFFD45A),
            const Color(0xFFE39A12),
          ]),
        );
        canvas.drawRRect(body, _stroke(const Color(0xFF9C6200), 4));
        canvas.drawCircle(
          const Offset(50, 63),
          6,
          _fill(const Color(0xFF7A4B00)),
        );
        canvas.drawRect(
          const Rect.fromLTWH(47.5, 64, 5, 12),
          _fill(const Color(0xFF7A4B00)),
        );
      case GameIcons.gear:
        final g = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          g.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(50 + cos(a) * 34, 50 + sin(a) * 34),
                width: 20,
                height: 20,
              ),
              const Radius.circular(5),
            ),
          );
        }
        g.addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 34));
        canvas.drawPath(
          g.shift(const Offset(0, 3)),
          _fill(const Color(0x40200040)),
        );
        canvas.drawPath(
          g,
          _grad(const Rect.fromLTWH(0, 0, 100, 100), [
            const Color(0xFFB9C4DD),
            const Color(0xFF6E7A99),
          ]),
        );
        canvas.drawCircle(
          const Offset(50, 50),
          13,
          _fill(const Color(0xFF4A5372)),
        );
        canvas.drawCircle(
          const Offset(50, 50),
          34,
          _stroke(const Color(0xFF4A5372), 3),
        );
      case GameIcons.pause:
        for (final x in [30.0, 58.0]) {
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 22, 13, 56),
            const Radius.circular(6),
          );
          canvas.drawRRect(r, _fill(Colors.white));
        }
      case GameIcons.play:
        final p = Path()
          ..moveTo(32, 20)
          ..lineTo(80, 50)
          ..lineTo(32, 80)
          ..close();
        canvas.drawPath(p, _fill(Colors.white));
        canvas.drawPath(p, _stroke(Colors.white, 8));
      case GameIcons.close:
        canvas.drawLine(
          const Offset(28, 28),
          const Offset(72, 72),
          _stroke(Colors.white, 14),
        );
        canvas.drawLine(
          const Offset(72, 28),
          const Offset(28, 72),
          _stroke(Colors.white, 14),
        );
      case GameIcons.plus:
        canvas.drawLine(
          const Offset(50, 22),
          const Offset(50, 78),
          _stroke(Colors.white, 16),
        );
        canvas.drawLine(
          const Offset(22, 50),
          const Offset(78, 50),
          _stroke(Colors.white, 16),
        );
      case GameIcons.back:
        canvas.save();
        canvas.translate(100, 0);
        canvas.scale(-1, 1);
        draw(canvas, GameIcons.arrow);
        canvas.restore();
      case GameIcons.arrow:
        final p = Path()
          ..moveTo(12, 38)
          ..lineTo(52, 38)
          ..lineTo(52, 18)
          ..lineTo(90, 50)
          ..lineTo(52, 82)
          ..lineTo(52, 62)
          ..lineTo(12, 62)
          ..close();
        canvas.drawPath(
          p.shift(const Offset(0, 4)),
          _fill(const Color(0x40300020)),
        );
        canvas.drawPath(
          p,
          _grad(const Rect.fromLTWH(0, 18, 100, 64), [
            const Color(0xFFFFF07A),
            const Color(0xFFFFB300),
          ]),
        );
        canvas.drawPath(p, _stroke(const Color(0xFF3B1A63), 6));
      case GameIcons.check:
        canvas.drawPath(
          Path()
            ..moveTo(22, 52)
            ..lineTo(42, 72)
            ..lineTo(80, 30),
          _stroke(Colors.white, 14),
        );
      case GameIcons.music:
        final w = _fill(Colors.white);
        canvas.drawOval(const Rect.fromLTWH(18, 62, 26, 20), w);
        canvas.drawOval(const Rect.fromLTWH(56, 54, 26, 20), w);
        canvas.drawPath(
          Path()
            ..moveTo(40, 72)
            ..lineTo(40, 24)
            ..lineTo(78, 16)
            ..lineTo(78, 64),
          _stroke(Colors.white, 7),
        );
        canvas.drawLine(
          const Offset(40, 34),
          const Offset(78, 26),
          _stroke(Colors.white, 9),
        );
      case GameIcons.sound:
        canvas.drawPath(
          Path()
            ..moveTo(16, 38)
            ..lineTo(32, 38)
            ..lineTo(52, 20)
            ..lineTo(52, 80)
            ..lineTo(32, 62)
            ..lineTo(16, 62)
            ..close(),
          _fill(Colors.white),
        );
        canvas.drawArc(
          const Rect.fromLTWH(46, 34, 24, 32),
          -pi / 3,
          2 * pi / 3,
          false,
          _stroke(Colors.white, 7),
        );
        canvas.drawArc(
          const Rect.fromLTWH(44, 22, 40, 56),
          -pi / 3,
          2 * pi / 3,
          false,
          _stroke(Colors.white, 7),
        );
      case GameIcons.vibrate:
        final phone = RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, 18, 32, 64),
          const Radius.circular(8),
        );
        canvas.drawRRect(phone, _stroke(Colors.white, 7));
        for (final s in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(50 + s * 26, 34)
              ..lineTo(50 + s * 32, 42)
              ..lineTo(50 + s * 24, 50)
              ..lineTo(50 + s * 32, 58)
              ..lineTo(50 + s * 26, 66),
            _stroke(Colors.white, 5),
          );
        }
      case GameIcons.map:
        final p = Path()
          ..moveTo(14, 24)
          ..lineTo(38, 16)
          ..lineTo(62, 26)
          ..lineTo(86, 18)
          ..lineTo(86, 76)
          ..lineTo(62, 84)
          ..lineTo(38, 74)
          ..lineTo(14, 82)
          ..close();
        canvas.drawPath(p, _fill(Colors.white));
        canvas.drawLine(
          const Offset(38, 16),
          const Offset(38, 74),
          _stroke(const Color(0x553B1A63), 4),
        );
        canvas.drawLine(
          const Offset(62, 26),
          const Offset(62, 84),
          _stroke(const Color(0x553B1A63), 4),
        );
      case GameIcons.retry:
        canvas.drawArc(
          const Rect.fromLTWH(20, 20, 60, 60),
          -pi * 0.35,
          pi * 1.6,
          false,
          _stroke(Colors.white, 12),
        );
        canvas.drawPath(
          Path()
            ..moveTo(62, 6)
            ..lineTo(84, 28)
            ..lineTo(56, 36)
            ..close(),
          _fill(Colors.white),
        );
      case GameIcons.video:
        final r = RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, 26, 56, 48),
          const Radius.circular(10),
        );
        canvas.drawRRect(r, _fill(Colors.white));
        canvas.drawPath(
          Path()
            ..moveTo(70, 42)
            ..lineTo(90, 30)
            ..lineTo(90, 70)
            ..lineTo(70, 58)
            ..close(),
          _fill(Colors.white),
        );
        canvas.drawPath(
          Path()
            ..moveTo(32, 38)
            ..lineTo(50, 50)
            ..lineTo(32, 62)
            ..close(),
          _fill(const Color(0xFF3FB6FF)),
        );
      case GameIcons.brush:
        _brush(canvas);
      case GameIcons.swap:
        _swap(canvas);
      case GameIcons.splash:
        _splash(canvas);
    }
  }

  static void _brush(Canvas canvas) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-pi / 4);
    // Handle.
    final handle = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, 2, 18, 46),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      handle.shift(const Offset(2, 3)),
      _fill(const Color(0x40200020)),
    );
    canvas.drawRRect(
      handle,
      _grad(handle.outerRect, [
        const Color(0xFFD98A4E),
        const Color(0xFF9C5527),
      ], vertical: false),
    );
    canvas.drawRRect(handle, _stroke(const Color(0xFF6B3412), 3));
    canvas.drawLine(
      const Offset(-3, 12),
      const Offset(-3, 40),
      _stroke(const Color(0x66FFFFFF), 3),
    );
    // Ferrule.
    final ferrule = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -10, 22, 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      ferrule,
      _grad(ferrule.outerRect, [
        const Color(0xFFF1F3F8),
        const Color(0xFF9AA3B8),
      ], vertical: false),
    );
    canvas.drawRRect(ferrule, _stroke(const Color(0xFF5E6680), 3));
    // Bristles dipped in paint.
    final bristles = Path()
      ..moveTo(-11, -10)
      ..quadraticBezierTo(-14, -30, 0, -46)
      ..quadraticBezierTo(14, -30, 11, -10)
      ..close();
    canvas.drawPath(bristles, _fill(const Color(0xFFF5E6C8)));
    final paint = Path()
      ..moveTo(-12.5, -22)
      ..quadraticBezierTo(-12, -34, 0, -46)
      ..quadraticBezierTo(12, -34, 12.5, -22)
      ..quadraticBezierTo(6, -18, 0, -23)
      ..quadraticBezierTo(-6, -18, -12.5, -22)
      ..close();
    canvas.drawPath(
      paint,
      _grad(const Rect.fromLTWH(-12, -46, 24, 28), [
        const Color(0xFFFF7AB8),
        const Color(0xFFE8368F),
      ]),
    );
    canvas.drawPath(bristles, _stroke(const Color(0xFF8A3A5E), 3));
    canvas.drawLine(
      const Offset(-4, -36),
      const Offset(-6, -26),
      _stroke(const Color(0xAAFFFFFF), 3),
    );
    canvas.restore();
    // Paint drops.
    canvas.drawCircle(const Offset(80, 30), 6, _fill(const Color(0xFFE8368F)));
    canvas.drawCircle(
      const Offset(88, 46),
      3.5,
      _fill(const Color(0xFFE8368F)),
    );
    TileArtSparkle.draw(canvas, const Offset(22, 26), 9);
  }

  static void _swap(Canvas canvas) {
    TileArt.paint(
      canvas,
      const Offset(32, 36),
      20,
      color: TileColor.red,
      special: Special.none,
    );
    TileArt.paint(
      canvas,
      const Offset(68, 66),
      20,
      color: TileColor.blue,
      special: Special.none,
    );
    void arrow(Offset from, Offset ctrl, Offset to) {
      final p = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
      canvas.drawPath(p, _stroke(const Color(0xFF3B1A63), 13));
      canvas.drawPath(p, _stroke(Colors.white, 7));
      final dir = (to - ctrl) / (to - ctrl).distance;
      final nrm = Offset(-dir.dy, dir.dx);
      final head = Path()
        ..moveTo(to.dx + dir.dx * 10, to.dy + dir.dy * 10)
        ..lineTo(to.dx + nrm.dx * 9, to.dy + nrm.dy * 9)
        ..lineTo(to.dx - nrm.dx * 9, to.dy - nrm.dy * 9)
        ..close();
      canvas.drawPath(head, _stroke(const Color(0xFF3B1A63), 6));
      canvas.drawPath(head, _fill(Colors.white));
    }

    arrow(const Offset(56, 22), const Offset(80, 22), const Offset(82, 42));
    arrow(const Offset(44, 80), const Offset(20, 80), const Offset(18, 60));
  }

  static void _splash(Canvas canvas) {
    // A paint roller leaving a rainbow stripe: "paint the whole row".
    final stripe = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6, 62, 74, 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      stripe.shift(const Offset(0, 3)),
      _fill(const Color(0x40200040)),
    );
    canvas.drawRRect(
      stripe,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(6, 0),
          const Offset(80, 0),
          const [
            Color(0xFFFF3B5C),
            Color(0xFFFFC21A),
            Color(0xFF1FC46B),
            Color(0xFF2F7BFF),
          ],
          const [0.0, 0.35, 0.7, 1.0],
        ),
    );
    canvas.drawRRect(stripe, _stroke(const Color(0xFF3B1A63), 3));
    // Drips.
    for (final d in const [Offset(22, 84), Offset(52, 84)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(d.dx - 3.5, d.dy - 4, 7, 12),
          const Radius.circular(3.5),
        ),
        _fill(d.dx < 40 ? const Color(0xFFFFA020) : const Color(0xFF1FB8A0)),
      );
    }
    // Handle.
    final handle = Path()
      ..moveTo(70, 50)
      ..lineTo(84, 50)
      ..lineTo(84, 30)
      ..lineTo(56, 30)
      ..lineTo(56, 14);
    canvas.drawPath(handle, _stroke(const Color(0xFF3B1A63), 9));
    canvas.drawPath(handle, _stroke(const Color(0xFFC9D1E4), 4.5));
    final grip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(49, 0, 14, 22),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      grip,
      _grad(grip.outerRect, [
        const Color(0xFFFF6FB0),
        const Color(0xFFD12A7A),
      ], vertical: false),
    );
    canvas.drawRRect(grip, _stroke(const Color(0xFF7A1446), 3));
    // Roller.
    final roller = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 38, 60, 26),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      roller.shift(const Offset(0, 3)),
      _fill(const Color(0x40200040)),
    );
    canvas.drawRRect(
      roller,
      _grad(roller.outerRect, [
        const Color(0xFFFFE680),
        const Color(0xFFFF8A1F),
      ]),
    );
    _gloss(
      canvas,
      Path()..addRRect(roller),
      const Rect.fromLTWH(18, 38, 50, 12),
    );
    canvas.drawRRect(roller, _stroke(const Color(0xFF9C4A00), 3.5));
    for (final x in const [30.0, 44.0, 58.0]) {
      canvas.drawLine(
        Offset(x, 44),
        Offset(x, 58),
        _stroke(const Color(0x55FFFFFF), 3),
      );
    }
    TileArtSparkle.draw(canvas, const Offset(88, 72), 8);
    TileArtSparkle.draw(canvas, const Offset(10, 34), 6);
  }
}

class TileArtSparkle {
  static void draw(Canvas canvas, Offset c, double s) {
    final p = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white);
  }
}
