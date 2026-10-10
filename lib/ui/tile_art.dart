import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';

/// Colors and per-episode themes.
class Palette {
  static const tile = {
    TileColor.red: Color(0xFFE53935),
    TileColor.blue: Color(0xFF1E88E5),
    TileColor.yellow: Color(0xFFFDD835),
    TileColor.purple: Color(0xFF8E24AA),
    TileColor.green: Color(0xFF43A047),
    TileColor.orange: Color(0xFFFB8C00),
    TileColor.brown: Color(0xFF8D6E63),
    TileColor.gray: Color(0xFF546E7A),
  };

  static Color of(TileColor? c) => c == null ? Colors.white : tile[c]!;

  static const stain = Color(0xFFEC407A);
  static const glass = Color(0xFFB3E5FC);

  static const episodeGradients = [
    [Color(0xFFFFE0B2), Color(0xFFFFAB91)], // Art Studio
    [Color(0xFFC8E6C9), Color(0xFF80DEEA)], // Rainbow Garden
    [Color(0xFFD1C4E9), Color(0xFF90A4AE)], // Paint Factory
  ];

  static List<Color> episode(int i) =>
      episodeGradients[i.clamp(0, episodeGradients.length - 1)];
}

/// Draws tiles procedurally (no image assets), each color with its own
/// shape so the game stays playable for colorblind players.
class TileArt {
  static Path shape(TileColor color, Offset c, double r) {
    switch (color) {
      case TileColor.red:
        return Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.92));
      case TileColor.blue:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCircle(center: c, radius: r * 0.82),
            Radius.circular(r * 0.28),
          ),
        );
      case TileColor.yellow:
        return _polygon(c, r * 1.02, 3, -pi / 2, dy: r * 0.12, round: r * 0.1);
      case TileColor.purple:
        return _polygon(c, r * 0.98, 4, -pi / 2, round: r * 0.08);
      case TileColor.green:
        return _polygon(c, r * 0.94, 6, 0, round: r * 0.06);
      case TileColor.orange:
        return _star(c, r * 1.0, r * 0.5, 5);
      case TileColor.brown:
        return _polygon(c, r * 0.92, 5, -pi / 2, round: r * 0.06);
      case TileColor.gray:
        return _plus(c, r * 0.88);
    }
  }

  static Path _polygon(
    Offset c,
    double r,
    int n,
    double start, {
    double dy = 0,
    double round = 0,
  }) {
    final pts = [
      for (var i = 0; i < n; i++)
        Offset(
          c.dx + r * cos(start + i * 2 * pi / n),
          c.dy + dy + r * sin(start + i * 2 * pi / n),
        ),
    ];
    if (round <= 0) return Path()..addPolygon(pts, true);
    final p = Path();
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n];
      final a = cur + (prev - cur) / (prev - cur).distance * round;
      final b = cur + (next - cur) / (next - cur).distance * round;
      if (i == 0) {
        p.moveTo(a.dx, a.dy);
      } else {
        p.lineTo(a.dx, a.dy);
      }
      p.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return p..close();
  }

  static Path _star(Offset c, double outer, double inner, int points) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / points;
      final o = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }

  static Path _plus(Offset c, double r) {
    final w = r * 0.42;
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: r * 2, height: w * 2),
          Radius.circular(w * 0.6),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: w * 2, height: r * 2),
          Radius.circular(w * 0.6),
        ),
      );
  }

  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Paints one tile centered at [c] with "radius" [r] (half the tile size).
  static void paint(
    Canvas canvas,
    Offset c,
    double r, {
    required TileColor? color,
    required Special special,
    bool gravitySwitch = false,
    double time = 0,
  }) {
    // No per-tile saveLayer/opacity: offscreen layers for dozens of tiles per
    // frame are slow on phones and crash some GPU emulators. Disappearing
    // tiles shrink instead of fading.
    if (r <= 0.5) return;
    switch (special) {
      case Special.prism:
        _prism(canvas, c, r, time);
      case Special.whiteBurst:
        _whiteBurst(canvas, c, r, time);
      case Special.bomb:
        _bomb(canvas, c, r, color ?? TileColor.red, time);
      case Special.lineH:
      case Special.lineV:
      case Special.none:
        _gem(canvas, c, r, color ?? TileColor.red);
        if (special.isLine) {
          _stripes(
            canvas,
            c,
            r,
            color ?? TileColor.red,
            special == Special.lineH,
          );
        }
    }
    if (gravitySwitch) switchBadge(canvas, c, r, time);
  }

  /// Cheap drop shadow (a real blur per tile per frame is too slow).
  static void _shadow(Canvas canvas, Path path, double r) {
    canvas.drawPath(
      path.shift(Offset(0, r * 0.1)),
      Paint()..color = const Color(0x40000000),
    );
  }

  static void _gem(Canvas canvas, Offset c, double r, TileColor color) {
    final base = Palette.of(color);
    final path = shape(color, c, r);
    _shadow(canvas, path, r);
    final fill = Paint()
      ..shader = ui.Gradient.radial(
        c + Offset(-r * 0.35, -r * 0.4),
        r * 1.5,
        [_shade(base, 0.22), base, _shade(base, -0.18)],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = _shade(base, -0.25),
    );
    // Glossy highlight.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.22, -r * 0.42),
        width: r * 0.95,
        height: r * 0.5,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.38),
    );
    canvas.restore();
  }

  static void _stripes(
    Canvas canvas,
    Offset c,
    double r,
    TileColor color,
    bool horizontal,
  ) {
    final path = shape(color, c, r);
    canvas.save();
    canvas.clipPath(path);
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var k = -1; k <= 1; k++) {
      final o = k * r * 0.42;
      final rect = horizontal
          ? Rect.fromCenter(
              center: c + Offset(0, o),
              width: r * 2.2,
              height: r * 0.16,
            )
          : Rect.fromCenter(
              center: c + Offset(o, 0),
              width: r * 0.16,
              height: r * 2.2,
            );
      canvas.drawRect(rect, p);
    }
    canvas.restore();
    // Arrow tips showing the blast direction.
    final a = Paint()..color = Colors.white;
    for (final s in [-1.0, 1.0]) {
      final tip = horizontal
          ? c + Offset(s * r * 1.08, 0)
          : c + Offset(0, s * r * 1.08);
      final back = horizontal
          ? c + Offset(s * r * 0.78, 0)
          : c + Offset(0, s * r * 0.78);
      final side = horizontal ? Offset(0, r * 0.2) : Offset(r * 0.2, 0);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(back.dx + side.dx, back.dy + side.dy)
          ..lineTo(back.dx - side.dx, back.dy - side.dy)
          ..close(),
        a,
      );
    }
  }

  static void _bomb(
    Canvas canvas,
    Offset c,
    double r,
    TileColor color,
    double time,
  ) {
    final base = Palette.of(color);
    final pulse = 1 + 0.05 * sin(time * 6);
    final rr = r * 0.82 * pulse;
    canvas.drawCircle(
      c,
      rr * 1.12,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
    canvas.drawCircle(
      c,
      rr,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-rr * 0.3, -rr * 0.35),
          rr * 1.4,
          [_shade(base, 0.25), base, _shade(base, -0.25)],
          const [0, 0.5, 1],
        ),
    );
    // Paint-splat mark.
    final splat = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + time * 0.8;
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * rr * 0.45,
        rr * 0.12,
        splat,
      );
    }
    canvas.drawCircle(c, rr * 0.26, splat);
  }

  static void _prism(Canvas canvas, Offset c, double r, double time) {
    final rect = Rect.fromCircle(center: c, radius: r * 0.9);
    final path = _polygon(c, r * 0.95, 6, time * 0.6, round: r * 0.05);
    _shadow(canvas, path, r);
    canvas.drawPath(
      path,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFE53935),
            Color(0xFFFB8C00),
            Color(0xFFFDD835),
            Color(0xFF43A047),
            Color(0xFF1E88E5),
            Color(0xFF8E24AA),
            Color(0xFFE53935),
          ],
          transform: GradientRotation(time),
        ).createShader(rect),
    );
    canvas.drawCircle(c, r * 0.32, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  static void _whiteBurst(Canvas canvas, Offset c, double r, double time) {
    const ring = [Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF1E88E5)];
    final rect = Rect.fromCircle(center: c, radius: r * 0.9);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        rect,
        time + i * 2 * pi / 3,
        2 * pi / 3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.2
          ..color = ring[i],
      );
    }
    final star = _star(c, r * 0.78, r * 0.34, 8);
    _shadow(canvas, star, r);
    canvas.drawPath(star, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.18, Paint()..color = const Color(0xFFFFF59D));
  }

  static void switchBadge(Canvas canvas, Offset c, double r, double time) {
    final bc = c + Offset(r * 0.58, r * 0.58);
    final br = r * 0.36;
    canvas.drawCircle(bc, br, Paint()..color = Colors.white);
    canvas.drawCircle(
      bc,
      br,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0xFF37474F),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF37474F);
    final rect = Rect.fromCircle(center: bc, radius: br * 0.55);
    final start = time * 2;
    canvas.drawArc(rect, start, pi * 1.4, false, arc);
    final end = start + pi * 1.4;
    final tip = bc + Offset(cos(end), sin(end)) * br * 0.55;
    final dir = Offset(-sin(end), cos(end));
    final normal = Offset(cos(end), sin(end));
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + dir.dx * br * 0.35, tip.dy + dir.dy * br * 0.35)
        ..lineTo(tip.dx + normal.dx * br * 0.3, tip.dy + normal.dy * br * 0.3)
        ..lineTo(tip.dx - normal.dx * br * 0.3, tip.dy - normal.dy * br * 0.3)
        ..close(),
      Paint()..color = const Color(0xFF37474F),
    );
  }

  /// A paint stain under a tile.
  static void stain(Canvas canvas, Rect cell) {
    final c = cell.center;
    final r = cell.width / 2;
    final p = Paint()..color = Palette.stain.withValues(alpha: 0.55);
    canvas.drawCircle(c, r * 0.78, p);
    final rnd = Random(c.dx.toInt() * 31 + c.dy.toInt());
    for (var i = 0; i < 5; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * r * 0.72,
        r * (0.12 + rnd.nextDouble() * 0.12),
        p,
      );
    }
  }

  /// A glass block with 1..3 layers.
  static void glass(Canvas canvas, Rect cell, int layers) {
    final rect = cell.deflate(cell.width * 0.05);
    final rr = RRect.fromRectAndRadius(
      rect,
      Radius.circular(cell.width * 0.14),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
          Palette.glass.withValues(alpha: 0.65 + 0.1 * layers),
          const Color(0xFF4FC3F7).withValues(alpha: 0.7 + 0.1 * layers),
        ]),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell.width * (0.03 + 0.025 * layers)
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRRect(rr, edge);
    final shine = Paint()
      ..strokeWidth = cell.width * 0.06
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawLine(
      rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.55),
      rect.topLeft + Offset(rect.width * 0.55, rect.height * 0.2),
      shine,
    );
    // Layer pips.
    final pip = Paint()..color = const Color(0xFF0277BD);
    for (var i = 0; i < layers; i++) {
      canvas.drawCircle(
        Offset(
          rect.right - rect.width * (0.18 + i * 0.2),
          rect.bottom - rect.height * 0.18,
        ),
        cell.width * 0.055,
        pip,
      );
    }
  }
}
