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
    [Color(0xFF9FD8FF), Color(0xFFD6ECFF), Color(0xFFA9C8FF)], // Sky Gallery
    [Color(0xFF5FD6D0), Color(0xFF4BA3D8), Color(0xFF3F6FC4)], // Ink Lagoon
    [Color(0xFFF6B8FF), Color(0xFFC8B8FF), Color(0xFF9FD0FF)], // Prism Peaks
    [Color(0xFFFFD27A), Color(0xFFFFB27A), Color(0xFFFF8F8F)], // Bucket Brigade
    [Color(0xFF6A4FD8), Color(0xFF4A3AA8), Color(0xFF2C2770)], // Gravity Galaxy
  ];

  /// Level-node candy colors (top, bottom, edge) for each episode.
  static const episodeNodes = [
    [Color(0xFFFFA3D1), Color(0xFFE8368F), Color(0xFF8E1A55)],
    [Color(0xFF8FF0C0), Color(0xFF14A866), Color(0xFF0B6B40)],
    [Color(0xFFC79BFF), Color(0xFF7B3FC4), Color(0xFF4A2183)],
    [Color(0xFF9FE0FF), Color(0xFF1F8EF0), Color(0xFF0D4F96)],
    [Color(0xFF8EF5E8), Color(0xFF14A8A0), Color(0xFF0A5E5A)],
    [Color(0xFFFFB8F0), Color(0xFFC04BE0), Color(0xFF6E1A8A)],
    [Color(0xFFFFE08A), Color(0xFFFF9F1C), Color(0xFF9A5200)],
    [Color(0xFFB8A8FF), Color(0xFF5A3FE0), Color(0xFF241A7A)],
  ];

  /// Ribbon color of each episode's map banner.
  static const episodeRibbons = [
    candyPink,
    Color(0xFF1FB86B),
    grape,
    Color(0xFF1F8EF0),
    Color(0xFF14A8A0),
    Color(0xFFC04BE0),
    Color(0xFFFF8A1F),
    Color(0xFF5A3FE0),
  ];

  static List<Color> episodeNode(int i) =>
      episodeNodes[i.clamp(0, episodeNodes.length - 1)];
  static Color episodeRibbon(int i) =>
      episodeRibbons[i.clamp(0, episodeRibbons.length - 1)];

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
    bool bucket = false,
    double time = 0,
  }) {
    if (r <= 0.5) return;
    if (bucket) {
      TileArt.bucket(canvas, c, r);
      return;
    }
    switch (special) {
      case Special.prism:
        _prism(canvas, c, r);
      case Special.whiteBurst:
        _whiteBurst(canvas, c, r);
      case Special.bomb:
        _bomb(canvas, c, r, color ?? TileColor.red);
      case Special.lineH:
      case Special.lineV:
        _lineBlaster(
          canvas,
          c,
          r,
          color ?? TileColor.red,
          special == Special.lineH,
        );
      case Special.none:
        _gem(canvas, c, r, color ?? TileColor.red);
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

  /// Line Blaster: a candy-striped double arrow in the color of the match
  /// that made it, pointing along the line it clears.
  static void _lineBlaster(
    Canvas canvas,
    Offset c,
    double r,
    TileColor color,
    bool horizontal,
  ) {
    final base = Palette.of(color);
    // Points of a vertical arrow; swapped for a horizontal one.
    Offset p(double along, double across) => horizontal
        ? c + Offset(along * r, across * r)
        : c + Offset(across * r, along * r);
    const shaft = 0.31, head = 0.68, neck = 0.32, tip = 0.98;
    final pts = [
      p(-tip, 0),
      p(-neck, head),
      p(-neck, shaft),
      p(neck, shaft),
      p(neck, head),
      p(tip, 0),
      p(neck, -head),
      p(neck, -shaft),
      p(-neck, -shaft),
      p(-neck, -head),
    ];
    final arrow = _roundedPoly(pts, r * 0.1);
    // Aura in the tile color.
    canvas.drawCircle(
      c,
      r * 1.08,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.08,
          [
            Palette.shade(base, 0.3).withValues(alpha: 0.7),
            Palette.shade(base, 0.3).withValues(alpha: 0.0),
          ],
          const [0.45, 1.0],
        ),
    );
    _jelly(canvas, arrow, c, r * 0.95, base);
    // Diagonal candy stripes across the shaft.
    canvas.save();
    canvas.clipPath(arrow);
    canvas.clipRect(
      Rect.fromPoints(
        p(-neck - 0.02, -shaft - 0.1),
        p(neck + 0.02, shaft + 0.1),
      ),
    );
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final shadow = Paint()
      ..color = Palette.shade(base, -0.28).withValues(alpha: 0.35);
    for (var k = -3; k <= 3; k++) {
      final o = k * 0.26;
      Path band(double shift) => Path()
        ..moveTo(p(o - 0.07 + shift, -0.5).dx, p(o - 0.07 + shift, -0.5).dy)
        ..lineTo(p(o + 0.07 + shift, -0.5).dx, p(o + 0.07 + shift, -0.5).dy)
        ..lineTo(p(o + 0.27 + shift, 0.5).dx, p(o + 0.27 + shift, 0.5).dy)
        ..lineTo(p(o + 0.13 + shift, 0.5).dx, p(o + 0.13 + shift, 0.5).dy)
        ..close();
      canvas.drawPath(band(0.035), shadow);
      canvas.drawPath(band(0), stripe);
    }
    // Shine along the shaft.
    canvas.drawRect(
      Rect.fromPoints(p(-neck, -shaft * 0.75), p(neck, -shaft * 0.35)),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.restore();
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.075
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.shade(base, -0.32),
    );
    _sparkle(canvas, p(-0.62, -0.18), r * 0.15, Colors.white);
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

  // ------------------------------------------------------- new obstacles

  /// A paint bucket (drop item): tin pail with a handle, overflowing with
  /// rainbow paint.
  static void bucket(Canvas canvas, Offset c, double r) {
    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, r * 0.78),
        width: r * 1.5,
        height: r * 0.34,
      ),
      _blur(const Color(0x55301040), r * 0.06),
    );
    // Handle behind the pail.
    canvas.drawArc(
      Rect.fromCenter(
        center: c + Offset(0, -r * 0.2),
        width: r * 1.5,
        height: r * 1.3,
      ),
      pi * 1.05,
      pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6B5B7B),
    );
    final top = c.dy - r * 0.32, bottom = c.dy + r * 0.78;
    final pail = Path()
      ..moveTo(c.dx - r * 0.8, top)
      ..lineTo(c.dx + r * 0.8, top)
      ..lineTo(c.dx + r * 0.62, bottom - r * 0.08)
      ..quadraticBezierTo(
        c.dx,
        bottom + r * 0.06,
        c.dx - r * 0.62,
        bottom - r * 0.08,
      )
      ..close();
    canvas.drawPath(
      pail,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r * 0.8, 0),
          Offset(c.dx + r * 0.8, 0),
          const [
            Color(0xFF8E9BB0),
            Color(0xFFF4F7FB),
            Color(0xFFB7C1D1),
            Color(0xFF6E7A90),
          ],
          const [0, 0.35, 0.7, 1],
        ),
    );
    // Rim bands.
    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..color = const Color(0xFF5E6A80);
    canvas.drawLine(
      Offset(c.dx - r * 0.74, top + r * 0.42),
      Offset(c.dx + r * 0.74, top + r * 0.42),
      band,
    );
    // Rainbow label stripes.
    const stripes = [Color(0xFFFF3B5C), Color(0xFFFFC21A), Color(0xFF2F7BFF)];
    for (var i = 0; i < 3; i++) {
      final y = top + r * (0.58 + i * 0.16);
      final inset = r * (0.08 + i * 0.04);
      canvas.drawLine(
        Offset(c.dx - r * 0.72 + inset, y),
        Offset(c.dx + r * 0.72 - inset, y),
        Paint()
          ..strokeWidth = r * 0.12
          ..color = stripes[i],
      );
    }
    canvas.drawPath(
      pail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF3B3F5C),
    );
    // Paint dome overflowing the top, with drips.
    final dome = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(c.dx, top),
          width: r * 1.7,
          height: r * 0.62,
        ),
      );
    final paint = ui.Gradient.linear(
      Offset(c.dx - r * 0.8, top),
      Offset(c.dx + r * 0.8, top),
      const [
        Color(0xFFFF3B5C),
        Color(0xFFFF8A1F),
        Color(0xFFFFC21A),
        Color(0xFF1FC46B),
        Color(0xFF2F7BFF),
        Color(0xFFA24BF2),
      ],
      const [0, 0.2, 0.4, 0.6, 0.8, 1],
    );
    canvas.drawPath(dome, Paint()..shader = paint);
    for (final (dx, len) in const [(-0.5, 0.36), (0.12, 0.5), (0.55, 0.28)]) {
      final x = c.dx + r * dx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - r * 0.08, top, r * 0.16, r * len),
          Radius.circular(r * 0.08),
        ),
        Paint()..shader = paint,
      );
    }
    canvas.drawPath(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0xFF3B3F5C),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.3, top - r * 0.1),
        width: r * 0.5,
        height: r * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  /// Chains across a locked tile: one chain, or two crossed chains with a
  /// padlock.
  static void chains(Canvas canvas, Rect cell, int layers) {
    final w = cell.width;
    final c = cell.center;
    void chain(double angle, Color body, Color edge) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      const links = 5;
      final len = w * 1.12;
      final step = len / links;
      for (var i = 0; i < links; i++) {
        final x = -len / 2 + step * (i + 0.5);
        final horizontal = i.isEven;
        final rect = Rect.fromCenter(
          center: Offset(x, 0),
          width: step * 1.25,
          height: horizontal ? w * 0.2 : w * 0.11,
        );
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.1));
        canvas.drawRRect(
          rr.shift(Offset(0, w * 0.03)),
          Paint()..color = const Color(0x66201030),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.065
            ..color = edge,
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.04
            ..color = body,
        );
        canvas.drawLine(
          rect.topLeft + Offset(step * 0.3, w * 0.015),
          rect.topRight - Offset(step * 0.3, -w * 0.015),
          Paint()
            ..strokeWidth = w * 0.014
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.8),
        );
      }
      canvas.restore();
    }

    canvas.save();
    canvas.clipRect(cell.inflate(w * 0.02));
    chain(-pi / 4, const Color(0xFFD5DCE8), const Color(0xFF4A5268));
    if (layers >= 2) {
      chain(pi / 4, const Color(0xFFFFD45C), const Color(0xFF8A5A0A));
    }
    canvas.restore();
    if (layers >= 2) {
      // Padlock.
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, w * 0.06),
          width: w * 0.3,
          height: w * 0.24,
        ),
        Radius.circular(w * 0.05),
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: c + Offset(0, -w * 0.06),
          width: w * 0.2,
          height: w * 0.22,
        ),
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05
          ..color = const Color(0xFF4A5268),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFFFFC21A));
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03
          ..color = const Color(0xFF8A5A0A),
      );
      canvas.drawCircle(
        c + Offset(0, w * 0.06),
        w * 0.035,
        Paint()..color = const Color(0xFF5A3A06),
      );
    }
  }

  /// Spreading ink: a glossy blob of dark paint with bubbles.
  static void ink(Canvas canvas, Rect cell, {int seed = 0}) {
    final w = cell.width;
    final c = cell.center;
    final rnd = Random(seed * 7919 + 13);
    final blob = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          cell.deflate(w * 0.06),
          Radius.circular(w * 0.24),
        ),
      );
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + rnd.nextDouble() * 0.6;
      blob.addOval(
        Rect.fromCircle(
          center: c + Offset(cos(a), sin(a)) * w * 0.4,
          radius: w * (0.1 + rnd.nextDouble() * 0.06),
        ),
      );
    }
    canvas.drawPath(
      blob.shift(Offset(0, w * 0.04)),
      Paint()..color = const Color(0x55100018),
    );
    canvas.drawPath(
      blob,
      Paint()
        ..shader = ui.Gradient.radial(
          c - Offset(w * 0.15, w * 0.18),
          w * 0.75,
          const [Color(0xFF5A3A7A), Color(0xFF2A1640), Color(0xFF120820)],
          const [0, 0.55, 1],
        ),
    );
    canvas.drawPath(
      blob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = const Color(0xFF0A0412),
    );
    // Gloss and bubbles.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-w * 0.14, -w * 0.2),
        width: w * 0.36,
        height: w * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    for (var i = 0; i < 3; i++) {
      final b =
          c +
          Offset(
            (rnd.nextDouble() - 0.5) * w * 0.5,
            (rnd.nextDouble() - 0.2) * w * 0.4,
          );
      final br = w * (0.04 + rnd.nextDouble() * 0.04);
      canvas.drawCircle(
        b,
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.015
          ..color = const Color(0xFFB79BD9).withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        b - Offset(br * 0.3, br * 0.3),
        br * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  /// A color filter cell: tinted glow, dashed rim and a paint-drop badge.
  static void filter(Canvas canvas, Rect cell, TileColor color) {
    final w = cell.width;
    final col = Palette.of(color);
    final rr = RRect.fromRectAndRadius(
      cell.deflate(w * 0.04),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.radial(cell.center, w * 0.7, [
          col.withValues(alpha: 0.55),
          col.withValues(alpha: 0.15),
        ]),
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..color = Palette.shade(col, 0.25);
    final r = rr.outerRect;
    const n = 4;
    for (var i = 0; i < n; i++) {
      final t0 = i / n + 0.06, t1 = (i + 1) / n - 0.06;
      canvas.drawLine(
        Offset(r.left + r.width * t0, r.top),
        Offset(r.left + r.width * t1, r.top),
        dash,
      );
      canvas.drawLine(
        Offset(r.left + r.width * t0, r.bottom),
        Offset(r.left + r.width * t1, r.bottom),
        dash,
      );
      canvas.drawLine(
        Offset(r.left, r.top + r.height * t0),
        Offset(r.left, r.top + r.height * t1),
        dash,
      );
      canvas.drawLine(
        Offset(r.right, r.top + r.height * t0),
        Offset(r.right, r.top + r.height * t1),
        dash,
      );
    }
  }

  /// Small badge for a filter, drawn over the tile in the cell corner.
  static void filterBadge(Canvas canvas, Rect cell, TileColor color) {
    final w = cell.width;
    final col = Palette.of(color);
    final c = cell.topRight + Offset(-w * 0.16, w * 0.16);
    final drop = Path()
      ..moveTo(c.dx, c.dy - w * 0.12)
      ..quadraticBezierTo(c.dx + w * 0.1, c.dy, c.dx, c.dy + w * 0.08)
      ..quadraticBezierTo(c.dx - w * 0.1, c.dy, c.dx, c.dy - w * 0.12);
    canvas.drawPath(drop, Paint()..color = col);
    canvas.drawPath(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = Colors.white,
    );
  }

  /// A gravity zone: soft chevrons pointing the cell's way.
  static void zoneArrow(Canvas canvas, Rect cell, Gravity g) {
    final w = cell.width;
    canvas.save();
    canvas.translate(cell.center.dx, cell.center.dy);
    canvas.rotate(switch (g) {
      Gravity.down => 0,
      Gravity.left => pi / 2,
      Gravity.up => pi,
      Gravity.right => -pi / 2,
    });
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.32);
    for (final y in [-0.14, 0.12]) {
      canvas.drawPath(
        Path()
          ..moveTo(-w * 0.2, w * (y - 0.08))
          ..lineTo(0, w * (y + 0.08))
          ..lineTo(w * 0.2, w * (y - 0.08)),
        p,
      );
    }
    canvas.restore();
  }

  /// Exit marker below a column where buckets leave the board.
  static void exitMark(
    Canvas canvas,
    Offset at,
    double size,
    Gravity g,
    double time,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(switch (g) {
      Gravity.down => 0,
      Gravity.left => pi / 2,
      Gravity.up => pi,
      Gravity.right => -pi / 2,
    });
    final bob = sin(time * 4) * size * 0.08;
    final path = Path()
      ..moveTo(-size * 0.3, -size * 0.12 + bob)
      ..lineTo(0, size * 0.16 + bob)
      ..lineTo(size * 0.3, -size * 0.12 + bob);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF3B1A63),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF7CF2B0),
    );
    canvas.restore();
  }

  /// Over-tile marker for a gravity zone: a small chevron on the cell's
  /// downstream edge, so the direction stays visible under tiles.
  static void zoneBadge(Canvas canvas, Rect cell, Gravity g) {
    final w = cell.width;
    final (at, angle) = switch (g) {
      Gravity.down => (cell.bottomCenter + Offset(0, -w * 0.1), 0.0),
      Gravity.up => (cell.topCenter + Offset(0, w * 0.1), pi),
      Gravity.left => (cell.centerLeft + Offset(w * 0.1, 0), pi / 2),
      Gravity.right => (cell.centerRight + Offset(-w * 0.1, 0), -pi / 2),
    };
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.36, height: w * 0.2),
        Radius.circular(w * 0.1),
      ),
      Paint()..color = const Color(0xCC3B1A63),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-w * 0.09, -w * 0.035)
        ..lineTo(0, w * 0.04)
        ..lineTo(w * 0.09, -w * 0.035),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.restore();
  }
}
