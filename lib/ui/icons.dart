import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'art_cache.dart';
import 'tile_art.dart';

/// Hand-drawn game icons (no icon fonts), drawn in a 100x100 box.
enum GameIcons {
  heart,
  heartBroken,
  unlimited,
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
  gravity,
  gold,
  shop,
  gift,
  trophy,
  ticket,
  podium,
  cloud,
}

class GameIcon extends StatelessWidget {
  final GameIcons icon;
  final double size;
  const GameIcon(this.icon, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => CachedArt(
    id: 'icon:${icon.name}',
    size: Size.square(size),
    pad: 0.15,
    draw: (canvas, size) {
      canvas.scale(size.width / 100);
      IconArt.draw(canvas, icon);
    },
  );
}

class IconArt {
  static Paint _fill(Color c) => Paint()..color = c;
  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _grad(
    Rect r,
    List<Color> colors, {
    bool vertical = true,
  }) => Paint()
    ..shader = ui.Gradient.linear(
      vertical ? r.topCenter : r.centerLeft,
      vertical ? r.bottomCenter : r.centerRight,
      colors,
      colors.length == 2
          ? null
          : [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)],
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
      case GameIcons.unlimited:
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
        if (icon == GameIcons.unlimited) {
          // An infinity loop across the heart.
          final loop = Path()
            ..moveTo(50, 50)
            ..cubicTo(60, 36, 78, 36, 78, 50)
            ..cubicTo(78, 64, 60, 64, 50, 50)
            ..cubicTo(40, 36, 22, 36, 22, 50)
            ..cubicTo(22, 64, 40, 64, 50, 50);
          canvas.drawPath(loop, _stroke(const Color(0xFF9C0F35), 13));
          canvas.drawPath(loop, _stroke(Colors.white, 7));
        }
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
      case GameIcons.gravity:
        _gravity(canvas);
      case GameIcons.gold:
        _gold(canvas);
      case GameIcons.shop:
        _shop(canvas);
      case GameIcons.gift:
        _gift(canvas);
      case GameIcons.trophy:
        _trophy(canvas);
      case GameIcons.ticket:
        _ticket(canvas);
      case GameIcons.podium:
        _podium(canvas);
      case GameIcons.cloud:
        _cloud(canvas);
    }
  }

  /// Leaderboards: a three-step podium with a star over first place.
  static void _podium(Canvas canvas) {
    const steps = [
      (Rect.fromLTWH(8, 52, 28, 38), [Color(0xFFF4F6FF), Color(0xFFAEB6D0)]),
      (Rect.fromLTWH(64, 62, 28, 28), [Color(0xFFFFD6A8), Color(0xFFD9823A)]),
      (Rect.fromLTWH(34, 38, 32, 52), [Color(0xFFFFF0A0), Color(0xFFF2A50C)]),
    ];
    for (final (r, colors) in steps) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
      canvas.drawRRect(
        rr.shift(const Offset(0, 4)),
        _fill(const Color(0x40301040)),
      );
      canvas.drawRRect(rr, _grad(r, colors));
      canvas.drawRRect(rr, _stroke(const Color(0xFF5B2A86), 4));
    }
    // Rank marks: one, two and three dots.
    final dot = _fill(const Color(0xFF5B2A86));
    canvas.drawCircle(const Offset(50, 56), 4.5, dot);
    for (final x in [17.0, 27.0]) {
      canvas.drawCircle(Offset(x, 68), 3.5, dot);
    }
    for (final x in [70.0, 78.0, 86.0]) {
      canvas.drawCircle(Offset(x, 76), 3, dot);
    }
    final star = starPath(50, 20, 15, 5);
    canvas.drawPath(
      star.shift(const Offset(0, 3)),
      _fill(const Color(0x40301040)),
    );
    canvas.drawPath(
      star,
      _grad(const Rect.fromLTWH(35, 5, 30, 30), [
        const Color(0xFFFFF6B0),
        const Color(0xFFFFB81E),
      ]),
    );
    canvas.drawPath(star, _stroke(const Color(0xFFB36B00), 3.5));
  }

  /// Cloud save: a puffy cloud with an up arrow.
  static void _cloud(Canvas canvas) {
    final cloud = Path()
      ..addOval(Rect.fromCircle(center: const Offset(32, 58), radius: 20))
      ..addOval(Rect.fromCircle(center: const Offset(54, 44), radius: 26))
      ..addOval(Rect.fromCircle(center: const Offset(74, 60), radius: 18))
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 56, 76, 24),
          const Radius.circular(12),
        ),
      );
    final shape = Path.combine(PathOperation.union, cloud, Path());
    canvas.drawPath(
      shape.shift(const Offset(0, 4)),
      _fill(const Color(0x40301040)),
    );
    canvas.drawPath(
      shape,
      _grad(const Rect.fromLTWH(10, 18, 80, 62), [
        Colors.white,
        const Color(0xFFBFE6FF),
      ]),
    );
    canvas.drawPath(shape, _stroke(const Color(0xFF1F6FB8), 4));
    final arrow = Path()
      ..moveTo(50, 36)
      ..lineTo(64, 52)
      ..lineTo(56, 52)
      ..lineTo(56, 68)
      ..lineTo(44, 68)
      ..lineTo(44, 52)
      ..lineTo(36, 52)
      ..close();
    canvas.drawPath(arrow, _fill(const Color(0xFF2E9BFF)));
    canvas.drawPath(arrow, _stroke(const Color(0xFF1F6FB8), 3));
  }

  /// Hard currency: a faceted gold gem.
  static void _gold(Canvas canvas) {
    final gem = Path()
      ..moveTo(26, 30)
      ..lineTo(74, 30)
      ..lineTo(90, 46)
      ..lineTo(50, 88)
      ..lineTo(10, 46)
      ..close();
    canvas.drawPath(
      gem.shift(const Offset(0, 4)),
      _fill(const Color(0x40402000)),
    );
    canvas.drawPath(
      gem,
      _grad(const Rect.fromLTWH(10, 30, 80, 58), [
        const Color(0xFFFFF0A0),
        const Color(0xFFFFB61E),
        const Color(0xFFE07A00),
      ]),
    );
    final facets = _stroke(const Color(0xAAFFF6CC), 2.5);
    canvas.drawLine(const Offset(10, 46), const Offset(90, 46), facets);
    canvas.drawLine(const Offset(38, 30), const Offset(30, 46), facets);
    canvas.drawLine(const Offset(62, 30), const Offset(70, 46), facets);
    canvas.drawLine(const Offset(30, 46), const Offset(50, 88), facets);
    canvas.drawLine(const Offset(70, 46), const Offset(50, 88), facets);
    canvas.drawPath(gem, _stroke(const Color(0xFF9A4E00), 4.5));
    canvas.drawPath(
      Path()
        ..moveTo(28, 34)
        ..lineTo(40, 34)
        ..lineTo(32, 44)
        ..close(),
      _fill(const Color(0xCCFFFFFF)),
    );
    TileArtSparkle.draw(canvas, const Offset(82, 22), 9);
  }

  static void _shop(Canvas canvas) {
    // A striped shopping bag.
    final bag = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 34, 68, 56),
      const Radius.circular(10),
    );
    canvas.drawArc(
      const Rect.fromLTWH(32, 12, 36, 40),
      pi,
      pi,
      false,
      _stroke(const Color(0xFF8E1A55), 7),
    );
    canvas.drawRRect(
      bag.shift(const Offset(0, 4)),
      _fill(const Color(0x40301040)),
    );
    canvas.drawRRect(
      bag,
      _grad(bag.outerRect, [const Color(0xFFFF8FCB), const Color(0xFFE8368F)]),
    );
    canvas.save();
    canvas.clipRRect(bag);
    for (var x = 22.0; x < 84; x += 16) {
      canvas.drawRect(
        Rect.fromLTWH(x, 34, 7, 56),
        _fill(const Color(0x33FFFFFF)),
      );
    }
    canvas.restore();
    canvas.drawRRect(bag, _stroke(const Color(0xFF8E1A55), 4));
    final star = starPath(50, 62, 14, 6);
    canvas.drawPath(star, _fill(const Color(0xFFFFE14D)));
    canvas.drawPath(star, _stroke(const Color(0xFFC77D00), 2.5));
  }

  static void _gift(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 44, 68, 46),
      const Radius.circular(8),
    );
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 32, 80, 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      box.shift(const Offset(0, 4)),
      _fill(const Color(0x40301040)),
    );
    canvas.drawRRect(
      box,
      _grad(box.outerRect, [const Color(0xFF8FE3FF), const Color(0xFF1F8EF0)]),
    );
    canvas.drawRRect(
      lid,
      _grad(lid.outerRect, [const Color(0xFFB8EEFF), const Color(0xFF3FA8F5)]),
    );
    final ribbon = _fill(const Color(0xFFFF4FA3));
    canvas.drawRect(const Rect.fromLTWH(44, 32, 12, 58), ribbon);
    // Bow.
    for (final s in [-1.0, 1.0]) {
      final loop = Path()
        ..moveTo(50, 32)
        ..cubicTo(50 + s * 30, 6, 50 + s * 34, 30, 50, 32);
      canvas.drawPath(loop, ribbon);
      canvas.drawPath(loop, _stroke(const Color(0xFFB0186A), 3));
    }
    canvas.drawRRect(box, _stroke(const Color(0xFF0D4F96), 4));
    canvas.drawRRect(lid, _stroke(const Color(0xFF0D4F96), 4));
  }

  static void _trophy(Canvas canvas) {
    final cup = Path()
      ..moveTo(26, 16)
      ..lineTo(74, 16)
      ..quadraticBezierTo(74, 60, 50, 64)
      ..quadraticBezierTo(26, 60, 26, 16)
      ..close();
    final handles = _stroke(const Color(0xFFC77D00), 6);
    canvas.drawArc(
      const Rect.fromLTWH(10, 20, 24, 26),
      pi / 2,
      pi,
      false,
      handles,
    );
    canvas.drawArc(
      const Rect.fromLTWH(66, 20, 24, 26),
      -pi / 2,
      pi,
      false,
      handles,
    );
    canvas.drawRect(
      const Rect.fromLTWH(44, 62, 12, 14),
      _fill(const Color(0xFFE09A10)),
    );
    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 76, 44, 14),
      const Radius.circular(4),
    );
    canvas.drawRRect(base, _fill(const Color(0xFF8E5A2A)));
    canvas.drawRRect(base, _stroke(const Color(0xFF5A3410), 3));
    canvas.drawPath(
      cup,
      _grad(const Rect.fromLTWH(26, 16, 48, 48), [
        const Color(0xFFFFF0A0),
        const Color(0xFFF2A50C),
      ]),
    );
    canvas.drawPath(cup, _stroke(const Color(0xFFB36B00), 4));
    final star = starPath(50, 36, 11, 5);
    canvas.drawPath(star, _fill(Colors.white));
  }

  static void _ticket(Canvas canvas) {
    final t = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 26, 84, 50),
          const Radius.circular(10),
        ),
      );
    final notch = Path()
      ..addOval(Rect.fromCircle(center: const Offset(8, 51), radius: 9))
      ..addOval(Rect.fromCircle(center: const Offset(92, 51), radius: 9));
    final shape = Path.combine(PathOperation.difference, t, notch);
    canvas.save();
    canvas.translate(50, 51);
    canvas.rotate(-0.18);
    canvas.translate(-50, -51);
    canvas.drawPath(
      shape.shift(const Offset(0, 4)),
      _fill(const Color(0x40301040)),
    );
    canvas.drawPath(
      shape,
      _grad(const Rect.fromLTWH(8, 26, 84, 50), [
        const Color(0xFFC79BFF),
        const Color(0xFF7B3FC4),
      ]),
    );
    canvas.drawPath(shape, _stroke(const Color(0xFF4A2183), 4));
    final dash = _stroke(const Color(0x99FFFFFF), 3);
    for (var y = 32.0; y < 72; y += 9) {
      canvas.drawLine(Offset(30, y), Offset(30, y + 4), dash);
    }
    final star = starPath(62, 51, 15, 7);
    canvas.drawPath(star, _fill(const Color(0xFFFFE14D)));
    canvas.drawPath(star, _stroke(const Color(0xFFC77D00), 2.5));
    canvas.restore();
  }

  static void _gravity(Canvas canvas) {
    // A star tile inside a big turning arrow: "choose where tiles fall".
    const c = Offset(50, 52);
    final ring = Rect.fromCircle(center: c, radius: 34);
    canvas.drawArc(
      ring,
      -pi * 0.35,
      pi * 1.55,
      false,
      _stroke(const Color(0xFF3B1A63), 15),
    );
    canvas.drawArc(
      ring,
      -pi * 0.35,
      pi * 1.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          c,
          const [
            Color(0xFF7CF2B0),
            Color(0xFF2F9BFF),
            Color(0xFFA24BF2),
            Color(0xFF7CF2B0),
          ],
          const [0, 0.4, 0.8, 1],
        ),
    );
    final a = -pi * 0.35;
    final tip = c + Offset(cos(a), sin(a)) * 34;
    final dir = Offset(-sin(a), cos(a)) * -1;
    final nrm = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(tip.dx + dir.dx * 13, tip.dy + dir.dy * 13)
      ..lineTo(tip.dx + nrm.dx * 12, tip.dy + nrm.dy * 12)
      ..lineTo(tip.dx - nrm.dx * 12, tip.dy - nrm.dy * 12)
      ..close();
    canvas.drawPath(head, _stroke(const Color(0xFF3B1A63), 6));
    canvas.drawPath(head, _fill(const Color(0xFF7CF2B0)));
    TileArt.paint(
      canvas,
      c,
      18,
      color: TileColor.yellow,
      special: Special.none,
    );
    for (final y in [80.0, 90.0]) {
      final p = Path()
        ..moveTo(42, y - 4)
        ..lineTo(50, y + 2)
        ..lineTo(58, y - 4);
      canvas.drawPath(p, _stroke(const Color(0xFF3B1A63), 7));
      canvas.drawPath(p, _stroke(Colors.white, 3.5));
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
