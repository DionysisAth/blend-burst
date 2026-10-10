import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';

/// Colors and per-episode themes.
class Palette {
  static const tile = {
    TileColor.red: Color(0xFFFF3B5C),
    TileColor.blue: Color(0xFF2F7BFF),
    TileColor.yellow: Color(0xFFFFC21A),
    TileColor.purple: Color(0xFFA24BF2),
    TileColor.green: Color(0xFF1FC46B),
    TileColor.orange: Color(0xFFFF8A1F),
    TileColor.brown: Color(0xFFA8704E),
    TileColor.gray: Color(0xFF66738F),
  };

  static Color of(TileColor? c) => c == null ? Colors.white : tile[c]!;

  static const stain = Color(0xFFE8368F);
  static const glass = Color(0xFFBDEEFF);

  // UI colors.
  static const ink = Color(0xFF3B1A63);
  static const plum = Color(0xFF5B2A86);
  static const grape = Color(0xFF7B3FC4);
  static const candyPink = Color(0xFFFF4FA3);
  static const sun = Color(0xFFFFC93C);
  static const mint = Color(0xFF2EDB9B);
  static const sky = Color(0xFF3FB6FF);
  static const cream = Color(0xFFFFF8EE);

  /// Background gradients (top to bottom) for each episode.
  static const episodeGradients = [
    [Color(0xFFFFB0C8), Color(0xFFFFD39A), Color(0xFFFF9EB5)], // Art Studio
    [Color(0xFF8FE3FF), Color(0xFFB8F5C8), Color(0xFF7FD6B8)], // Rainbow Garden
    [Color(0xFFB9A8FF), Color(0xFF8FB4FF), Color(0xFF6E7FD8)], // Paint Factory
  ];

  static List<Color> episode(int i) =>
      episodeGradients[i.clamp(0, episodeGradients.length - 1)];

  static Color shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color saturate(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// Draws tiles procedurally (no image assets). Each color has its own shape
/// so the game stays playable for colorblind players. The board caches these
/// as images (see SpriteCache), so they can afford a lot of detail.
class TileArt {
  // ----------------------------------------------------------- shapes

  static Path shape(TileColor color, Offset c, double r) {
    switch (color) {
      case TileColor.red:
        return _heart(c, r);
      case TileColor.blue:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 1.62, height: r * 1.62),
            Radius.circular(r * 0.4),
          ),
        );
      case TileColor.yellow:
        return _roundedPoly(
          _starPoints(c + Offset(0, r * 0.06), r * 1.04, r * 0.55, 5),
          r * 0.16,
        );
      case TileColor.purple:
        return _roundedPoly([
          c + Offset(0, -r * 0.98),
          c + Offset(r * 0.86, 0),
          c + Offset(0, r * 0.98),
          c + Offset(-r * 0.86, 0),
        ], r * 0.14);
      case TileColor.green:
        return _roundedPoly(_ngon(c, r * 0.94, 6, 0), r * 0.12);
      case TileColor.orange:
        return Path()..addOval(
          Rect.fromCircle(center: c + Offset(0, r * 0.05), radius: r * 0.86),
        );
      case TileColor.brown:
        return _roundedPoly(
          _ngon(c + Offset(0, r * 0.04), r * 0.92, 5, -pi / 2),
          r * 0.18,
        );
      case TileColor.gray:
        return _drop(c, r);
    }
  }

  static List<Offset> _ngon(Offset c, double r, int n, double start) => [
    for (var i = 0; i < n; i++)
      Offset(
        c.dx + r * cos(start + i * 2 * pi / n),
        c.dy + r * sin(start + i * 2 * pi / n),
      ),
  ];

  static List<Offset> _starPoints(
    Offset c,
    double outer,
    double inner,
    int n,
  ) => [
    for (var i = 0; i < n * 2; i++)
      Offset(
        c.dx + (i.isEven ? outer : inner) * cos(-pi / 2 + i * pi / n),
        c.dy + (i.isEven ? outer : inner) * sin(-pi / 2 + i * pi / n),
      ),
  ];

  static Path _roundedPoly(List<Offset> pts, double round) {
    final n = pts.length;
    final p = Path();
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n];
      final d1 = (prev - cur), d2 = (next - cur);
      final k = min(round, min(d1.distance, d2.distance) * 0.45);
      final a = cur + d1 / d1.distance * k;
      final b = cur + d2 / d2.distance * k;
      if (i == 0) {
        p.moveTo(a.dx, a.dy);
      } else {
        p.lineTo(a.dx, a.dy);
      }
      p.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return p..close();
  }

  static Path _heart(Offset c, double r) {
    final s = r * 0.98;
    final top = c + Offset(0, -s * 0.45);
    final bottom = c + Offset(0, s * 0.92);
    return Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..cubicTo(
        c.dx - s * 0.35,
        c.dy + s * 0.55,
        c.dx - s * 1.02,
        c.dy + s * 0.08,
        c.dx - s * 0.98,
        c.dy - s * 0.38,
      )
      ..cubicTo(
        c.dx - s * 0.95,
        c.dy - s * 0.92,
        c.dx - s * 0.3,
        c.dy - s * 1.0,
        top.dx,
        top.dy,
      )
      ..cubicTo(
        c.dx + s * 0.3,
        c.dy - s * 1.0,
        c.dx + s * 0.95,
        c.dy - s * 0.92,
        c.dx + s * 0.98,
        c.dy - s * 0.38,
      )
      ..cubicTo(
        c.dx + s * 1.02,
        c.dy + s * 0.08,
        c.dx + s * 0.35,
        c.dy + s * 0.55,
        bottom.dx,
        bottom.dy,
      )
      ..close();
  }

  static Path _drop(Offset c, double r) {
    final cc = c + Offset(0, r * 0.22);
    final rr = r * 0.7;
    final tip = c + Offset(0, -r * 1.0);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(
        cc.dx + rr * 0.35,
        tip.dy + r * 0.35,
        cc.dx + rr * 1.0,
        cc.dy - rr * 0.55,
        cc.dx + rr,
        cc.dy,
      )
      ..arcToPoint(
        cc + Offset(-rr, 0),
        radius: Radius.circular(rr),
        clockwise: true,
      )
      ..cubicTo(
        cc.dx - rr * 1.0,
        cc.dy - rr * 0.55,
        cc.dx - rr * 0.35,
        tip.dy + r * 0.35,
        tip.dx,
        tip.dy,
      )
      ..close();
  }

  // ------------------------------------------------------- rendering

  static Paint _blur(Color color, double sigma) => Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(0.1, sigma));

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
    if (r <= 0.5) return;
    switch (special) {
      case Special.prism:
        _prism(canvas, c, r);
      case Special.whiteBurst:
        _whiteBurst(canvas, c, r);
      case Special.bomb:
        _bomb(canvas, c, r, color ?? TileColor.red);
      case Special.lineH:
      case Special.lineV:
      case Special.none:
        _gem(canvas, c, r, color ?? TileColor.red);
        if (special.isLine) {
          _blasterBand(
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

  /// The glossy "jelly gem" look shared by all tiles.
  static void _jelly(
    Canvas canvas,
    Path path,
    Offset c,
    double r,
    Color base, {
    bool facets = false,
    List<Offset>? facetPoints,
  }) {
    final bounds = path.getBounds();
    // Soft drop shadow.
    canvas.drawPath(
      path.shift(Offset(0, r * 0.1)),
      _blur(const Color(0x55301040), r * 0.07),
    );
    // Body.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topCenter,
          bounds.bottomCenter,
          [Palette.shade(base, 0.16), base, Palette.shade(base, -0.12)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.save();
    canvas.clipPath(path);
    // Volume: darker towards the edges.
    canvas.drawRect(
      bounds.inflate(r),
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.1, -r * 0.25),
          r * 1.25,
          [
            const Color(0x00000000),
            Palette.shade(base, -0.22).withValues(alpha: 0.65),
          ],
          const [0.55, 1.0],
        ),
    );
    if (facets && facetPoints != null) _facets(canvas, c, r, base, facetPoints);
    // Bounce light at the bottom.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, r * 0.62),
        width: r * 1.1,
        height: r * 0.36,
      ),
      _blur(Palette.shade(base, 0.3).withValues(alpha: 0.45), r * 0.08),
    );
    // Glossy band.
    final gloss = Rect.fromCenter(
      center: c + Offset(-r * 0.08, -r * 0.46),
      width: r * 1.3,
      height: r * 0.62,
    );
    canvas.drawOval(
      gloss,
      Paint()
        ..shader = ui.Gradient.linear(gloss.topCenter, gloss.bottomCenter, [
          Colors.white.withValues(alpha: 0.8),
          Colors.white.withValues(alpha: 0.04),
        ]),
    );
    canvas.restore();
    // Outline and inner rim.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.075
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.shade(base, -0.3),
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();
    // Sparkle.
    _sparkle(canvas, c + Offset(-r * 0.44, -r * 0.42), r * 0.2, Colors.white);
  }

  static void _facets(
    Canvas canvas,
    Offset c,
    double r,
    Color base,
    List<Offset> outer,
  ) {
    final inner = [for (final p in outer) c + (p - c) * 0.5];
    for (var i = 0; i < outer.length; i++) {
      final j = (i + 1) % outer.length;
      final light = (i % 3 == 0) ? 0.14 : (i % 3 == 1 ? -0.06 : 0.04);
      canvas.drawPath(
        Path()
          ..moveTo(outer[i].dx, outer[i].dy)
          ..lineTo(outer[j].dx, outer[j].dy)
          ..lineTo(inner[j].dx, inner[j].dy)
          ..lineTo(inner[i].dx, inner[i].dy)
          ..close(),
        Paint()..color = Palette.shade(base, light).withValues(alpha: 0.55),
      );
    }
    canvas.drawPath(
      Path()..addPolygon(inner, true),
      Paint()..color = Palette.shade(base, 0.12).withValues(alpha: 0.7),
    );
    canvas.drawPath(
      Path()..addPolygon(inner, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  static void _sparkle(Canvas canvas, Offset c, double s, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: 0.95));
    canvas.drawCircle(c, s * 0.28, Paint()..color = color);
  }

  static void _gem(Canvas canvas, Offset c, double r, TileColor color) {
    final base = Palette.of(color);
    final path = shape(color, c, r);
    List<Offset>? facets;
    switch (color) {
      case TileColor.purple:
        facets = [
          c + Offset(0, -r * 0.98),
          c + Offset(r * 0.86, 0),
          c + Offset(0, r * 0.98),
          c + Offset(-r * 0.86, 0),
        ];
      case TileColor.green:
        facets = _ngon(c, r * 0.94, 6, 0);
      case TileColor.blue:
        facets = [
          c + Offset(-r * 0.74, -r * 0.74),
          c + Offset(r * 0.74, -r * 0.74),
          c + Offset(r * 0.74, r * 0.74),
          c + Offset(-r * 0.74, r * 0.74),
        ];
      default:
        break;
    }
    _jelly(
      canvas,
      path,
      c,
      r,
      base,
      facets: facets != null,
      facetPoints: facets,
    );
    // Little character details.
    if (color == TileColor.orange) {
      // A leaf on the orb.
      final leaf = Path()
        ..moveTo(c.dx + r * 0.05, c.dy - r * 0.78)
        ..quadraticBezierTo(
          c.dx + r * 0.42,
          c.dy - r * 1.12,
          c.dx + r * 0.62,
          c.dy - r * 0.82,
        )
        ..quadraticBezierTo(
          c.dx + r * 0.3,
          c.dy - r * 0.62,
          c.dx + r * 0.05,
          c.dy - r * 0.78,
        )
        ..close();
      canvas.drawPath(leaf, Paint()..color = const Color(0xFF2DBE5A));
      canvas.drawPath(
        leaf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = const Color(0xFF1B7A3A),
      );
    } else if (color == TileColor.brown) {
      final chip = Paint()..color = Palette.shade(base, -0.22);
      for (final o in const [
        Offset(0.3, -0.02),
        Offset(-0.34, 0.3),
        Offset(0.12, 0.42),
        Offset(-0.08, 0.08),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(center: c + o * r, width: r * 0.2, height: r * 0.15),
          chip,
        );
      }
    }
  }

  static void _blasterBand(
    Canvas canvas,
    Offset c,
    double r,
    TileColor color,
    bool horizontal,
  ) {
    final base = Palette.of(color);
    final len = r * 2.05, thick = r * 0.46;
    final band = horizontal
        ? Rect.fromCenter(center: c, width: len, height: thick)
        : Rect.fromCenter(center: c, width: thick, height: len);
    final rr = RRect.fromRectAndRadius(band, Radius.circular(thick / 2));
    canvas.drawRRect(
      rr.inflate(r * 0.06),
      _blur(Colors.white.withValues(alpha: 0.7), r * 0.12),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = (horizontal
            ? ui.Gradient.linear(
                band.topCenter,
                band.bottomCenter,
                [Colors.white, Palette.shade(base, 0.38), Colors.white],
                const [0, 0.5, 1],
              )
            : ui.Gradient.linear(
                band.centerLeft,
                band.centerRight,
                [Colors.white, Palette.shade(base, 0.38), Colors.white],
                const [0, 0.5, 1],
              )),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = Palette.shade(base, -0.25),
    );
    // Chevrons pointing outwards.
    for (final s in [-1.0, 1.0]) {
      for (final k in [0.42, 0.72]) {
        final tip = horizontal
            ? c + Offset(s * r * (k + 0.2), 0)
            : c + Offset(0, s * r * (k + 0.2));
        final back = horizontal
            ? c + Offset(s * r * k, 0)
            : c + Offset(0, s * r * k);
        final side = horizontal ? Offset(0, r * 0.15) : Offset(r * 0.15, 0);
        canvas.drawPath(
          Path()
            ..moveTo(back.dx + side.dx, back.dy + side.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(back.dx - side.dx, back.dy - side.dy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.09
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Palette.shade(base, -0.2),
        );
      }
    }
  }

  static void _bomb(Canvas canvas, Offset c, double r, TileColor color) {
    final base = Palette.of(color);
    // Aura.
    canvas.drawCircle(
      c,
      r * 1.08,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.08,
          [
            Palette.shade(base, 0.25).withValues(alpha: 0.75),
            Palette.shade(base, 0.25).withValues(alpha: 0.0),
          ],
          const [0.6, 1.0],
        ),
    );
    final body = Path()
      ..addOval(
        Rect.fromCircle(center: c + Offset(0, r * 0.08), radius: r * 0.78),
      );
    // Fuse cap and fuse (behind the gloss).
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c + Offset(r * 0.42, -r * 0.62),
        width: r * 0.36,
        height: r * 0.28,
      ),
      Radius.circular(r * 0.07),
    );
    canvas.save();
    canvas.translate(cap.center.dx, cap.center.dy);
    canvas.rotate(pi / 5);
    canvas.translate(-cap.center.dx, -cap.center.dy);
    canvas.drawRRect(cap, Paint()..color = const Color(0xFF4A4A5E));
    canvas.drawRRect(
      cap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = const Color(0xFF26263A),
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + r * 0.52, c.dy - r * 0.72)
        ..quadraticBezierTo(
          c.dx + r * 0.62,
          c.dy - r * 1.02,
          c.dx + r * 0.86,
          c.dy - r * 0.94,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF7A5230),
    );
    _jelly(canvas, body, c + Offset(0, r * 0.08), r * 0.86, base);
    // Paint splat emblem.
    final splat = Path();
    final sc = c + Offset(0, r * 0.18);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final rad = r * (i.isEven ? 0.34 : 0.24);
      splat.addOval(
        Rect.fromCircle(
          center: sc + Offset(cos(a), sin(a)) * rad * 0.7,
          radius: r * 0.13,
        ),
      );
    }
    splat.addOval(Rect.fromCircle(center: sc, radius: r * 0.27));
    canvas.drawPath(
      splat,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    // Spark.
    final spark = c + Offset(r * 0.9, -r * 0.95);
    canvas.drawCircle(spark, r * 0.22, _blur(const Color(0xFFFFE066), r * 0.1));
    _sparkle(canvas, spark, r * 0.26, const Color(0xFFFFF6C8));
  }

  static void _prism(Canvas canvas, Offset c, double r) {
    const hues = [
      Color(0xFFFF4D6D),
      Color(0xFFFF9F1C),
      Color(0xFFFFE14D),
      Color(0xFF2EDB7F),
      Color(0xFF3FA7FF),
      Color(0xFFB45CFF),
    ];
    final outer = _ngon(c, r * 0.98, 6, -pi / 2);
    final inner = _ngon(c, r * 0.46, 6, -pi / 2);
    final path = Path()..addPolygon(outer, true);
    canvas.drawCircle(
      c,
      r * 1.12,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.12,
          [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0.0),
          ],
          const [0.55, 1.0],
        ),
    );
    canvas.drawPath(
      path.shift(Offset(0, r * 0.09)),
      _blur(const Color(0x55301040), r * 0.07),
    );
    for (var i = 0; i < 6; i++) {
      final j = (i + 1) % 6;
      final facet = Path()
        ..moveTo(outer[i].dx, outer[i].dy)
        ..lineTo(outer[j].dx, outer[j].dy)
        ..lineTo(inner[j].dx, inner[j].dy)
        ..lineTo(inner[i].dx, inner[i].dy)
        ..close();
      final mid = (outer[i] + outer[j]) / 2;
      canvas.drawPath(
        facet,
        Paint()
          ..shader = ui.Gradient.linear(mid, c, [
            Palette.shade(hues[i], -0.05),
            Palette.shade(hues[i], 0.2),
          ]),
      );
    }
    final table = Path()..addPolygon(inner, true);
    canvas.drawPath(
      table,
      Paint()
        ..shader = ui.Gradient.linear(
          c + Offset(-r * 0.4, -r * 0.4),
          c + Offset(r * 0.4, r * 0.4),
          [Colors.white, const Color(0xFFE6E0FF)],
        ),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.035
      ..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(outer[i], inner[i], edge);
    }
    canvas.drawPath(table, edge);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF6B3FB0),
    );
    _sparkle(canvas, c + Offset(-r * 0.2, -r * 0.18), r * 0.24, Colors.white);
    _sparkle(canvas, c + Offset(r * 0.55, -r * 0.55), r * 0.14, Colors.white);
  }

  static void _whiteBurst(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 1.15,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.15,
          [
            const Color(0xFFFFF4C2).withValues(alpha: 0.95),
            const Color(0xFFFFF4C2).withValues(alpha: 0.0),
          ],
          const [0.35, 1.0],
        ),
    );
    // Rays.
    final rays = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final w = i.isEven ? 0.16 : 0.1;
      final len = i.isEven ? 1.08 : 0.86;
      rays
        ..moveTo(c.dx + cos(a - w) * r * 0.4, c.dy + sin(a - w) * r * 0.4)
        ..lineTo(c.dx + cos(a) * r * len, c.dy + sin(a) * r * len)
        ..lineTo(c.dx + cos(a + w) * r * 0.4, c.dy + sin(a + w) * r * 0.4)
        ..close();
    }
    canvas.drawPath(rays, Paint()..color = const Color(0xFFFFE27A));
    canvas.drawPath(
      rays,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0xFFF2B634),
    );
    // Tri-color ring.
    const ring = [Color(0xFFFF3B5C), Color(0xFFFFC21A), Color(0xFF2F7BFF)];
    final rect = Rect.fromCircle(center: c, radius: r * 0.64);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        rect,
        -pi / 2 + i * 2 * pi / 3 + 0.08,
        2 * pi / 3 - 0.16,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.17
          ..strokeCap = StrokeCap.round
          ..color = ring[i],
      );
    }
    // Pearl core.
    final core = Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.48));
    canvas.drawPath(
      core,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.15, -r * 0.18),
          r * 0.55,
          [Colors.white, const Color(0xFFFFF3D6), const Color(0xFFF7D98A)],
          const [0.0, 0.6, 1.0],
        ),
    );
    canvas.drawPath(
      core,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = const Color(0xFFE0A93A),
    );
    _sparkle(canvas, c + Offset(-r * 0.16, -r * 0.18), r * 0.22, Colors.white);
  }

  /// Gravity switch badge, drawn live so its arrows can spin.
  static void switchBadge(Canvas canvas, Offset c, double r, double time) {
    final bc = c + Offset(r * 0.62, r * 0.6);
    final br = r * 0.38;
    canvas.drawCircle(
      bc + Offset(0, r * 0.04),
      br,
      Paint()..color = const Color(0x55301040),
    );
    canvas.drawCircle(bc, br, Paint()..color = Colors.white);
    canvas.drawCircle(bc, br * 0.8, Paint()..color = const Color(0xFF6A3FD0));
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.085
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final rect = Rect.fromCircle(center: bc, radius: br * 0.48);
    for (var k = 0; k < 2; k++) {
      final start = time * 2.2 + k * pi;
      canvas.drawArc(rect, start, pi * 0.7, false, arc);
      final end = start + pi * 0.7;
      final tip = bc + Offset(cos(end), sin(end)) * br * 0.48;
      final dir = Offset(-sin(end), cos(end));
      final nrm = Offset(cos(end), sin(end));
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx + dir.dx * br * 0.32, tip.dy + dir.dy * br * 0.32)
          ..lineTo(tip.dx + nrm.dx * br * 0.24, tip.dy + nrm.dy * br * 0.24)
          ..lineTo(tip.dx - nrm.dx * br * 0.24, tip.dy - nrm.dy * br * 0.24)
          ..close(),
        Paint()..color = Colors.white,
      );
    }
  }

  /// A paint stain under a tile.
  static void stain(Canvas canvas, Rect cell) {
    final c = cell.center;
    final r = cell.width / 2;
    final rnd = Random(c.dx.round() * 73856093 ^ c.dy.round() * 19349663);
    final blob = Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.7));
    for (var i = 0; i < 7; i++) {
      final a = i * 2 * pi / 7 + rnd.nextDouble() * 0.5;
      blob.addOval(
        Rect.fromCircle(
          center:
              c + Offset(cos(a), sin(a)) * r * (0.6 + rnd.nextDouble() * 0.15),
          radius: r * (0.16 + rnd.nextDouble() * 0.12),
        ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      blob.addOval(
        Rect.fromCircle(
          center: c + Offset(cos(a), sin(a)) * r * 0.9,
          radius: r * (0.05 + rnd.nextDouble() * 0.05),
        ),
      );
    }
    canvas.drawPath(
      blob,
      Paint()..color = Palette.stain.withValues(alpha: 0.88),
    );
    canvas.drawPath(
      blob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = const Color(0xFFB0186A).withValues(alpha: 0.8),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.22, -r * 0.3),
        width: r * 0.5,
        height: r * 0.26,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  /// A glass (ice) block with 1..3 layers.
  static void glass(Canvas canvas, Rect cell, int layers) {
    final w = cell.width;
    final rect = cell.deflate(w * 0.05);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.16));
    canvas.drawRRect(
      rr.shift(Offset(0, w * 0.04)),
      Paint()..color = const Color(0x40203060),
    );
    final alpha = 0.72 + 0.08 * layers;
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            const Color(0xFFF2FDFF).withValues(alpha: alpha),
            const Color(0xFFA6E6FF).withValues(alpha: alpha),
            const Color(0xFF6CC7F0).withValues(alpha: alpha),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Bevel.
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRRect(
      rr.deflate(w * 0.06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    final streak = Paint()
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawLine(
      rect.topLeft + Offset(w * 0.2, w * 0.58),
      rect.topLeft + Offset(w * 0.58, w * 0.2),
      streak,
    );
    canvas.drawLine(
      rect.topLeft + Offset(w * 0.36, w * 0.7),
      rect.topLeft + Offset(w * 0.7, w * 0.36),
      streak..strokeWidth = w * 0.04,
    );
    if (layers >= 2) {
      final frost = Paint()..color = Colors.white.withValues(alpha: 0.5);
      final rnd = Random(layers * 31 + 7);
      for (var i = 0; i < 10 * layers; i++) {
        canvas.drawCircle(
          rect.topLeft +
              Offset(
                rnd.nextDouble() * rect.width,
                rnd.nextDouble() * rect.height,
              ),
          w * (0.012 + rnd.nextDouble() * 0.02),
          frost,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..color = const Color(0xFF3E9CCB),
    );
    if (layers > 1) {
      final bc = rect.bottomRight - Offset(w * 0.17, w * 0.17);
      canvas.drawCircle(bc, w * 0.14, Paint()..color = const Color(0xFF1E6FA8));
      canvas.drawCircle(
        bc,
        w * 0.14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.025
          ..color = Colors.white,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$layers',
          style: TextStyle(
            fontFamily: 'Lilita',
            fontSize: w * 0.2,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, bc - Offset(tp.width / 2, tp.height / 2));
    }
  }
}
