// Renders the app icon with the game's own tile art.
//
//   flutter test tool/icon/icon_test.dart
//
// Writes the Android adaptive layers (foreground + background), the legacy
// launcher icons, the iOS icons and a 512px store icon. The iOS icons must
// have no alpha channel afterwards:
//   python3 -c "import glob; from PIL import Image; [Image.open(f).convert('RGB').save(f) for f in glob.glob('ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png')]"
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/ui/tile_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints the full-bleed background on a [s] x [s] square.
void paintBackground(Canvas canvas, double s) {
  final c = Offset(s / 2, s / 2);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        s * 0.75,
        const [
          Color(0xFFFF7AD9),
          Color(0xFFB03CE0),
          Color(0xFF5420B0),
          Color(0xFF240A5C),
        ],
        const [0.0, 0.3, 0.62, 1.0],
      ),
  );
  // Sun rays.
  final rays = Path();
  const n = 18;
  for (var i = 0; i < n; i++) {
    final a = i * 2 * pi / n;
    const w = pi / n * 0.55;
    rays
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + cos(a - w) * s, c.dy + sin(a - w) * s)
      ..lineTo(c.dx + cos(a + w) * s, c.dy + sin(a + w) * s)
      ..close();
  }
  canvas.drawPath(
    rays,
    Paint()
      ..shader = ui.Gradient.radial(c, s * 0.7, [
        Colors.white.withValues(alpha: 0.26),
        Colors.white.withValues(alpha: 0.0),
      ]),
  );
  // Paint splats near the edges.
  final rng = Random(5);
  const splatColors = [
    Color(0xFFFF4D6D),
    Color(0xFFFFC93C),
    Color(0xFF3FB6FF),
    Color(0xFF2EDB9B),
    Color(0xFFFF9F1C),
    Color(0xFFB45CFF),
  ];
  for (var i = 0; i < 9; i++) {
    final a = i * 2 * pi / 9 + 0.3;
    final d = s * (0.31 + rng.nextDouble() * 0.06);
    final p = c + Offset(cos(a), sin(a)) * d;
    final col = splatColors[i % splatColors.length];
    final paint = Paint()..color = col.withValues(alpha: 0.7);
    final rad = s * (0.016 + rng.nextDouble() * 0.014);
    canvas.drawCircle(p, rad, paint);
    for (var k = 0; k < 5; k++) {
      final b = rng.nextDouble() * 2 * pi;
      canvas.drawCircle(
        p + Offset(cos(b), sin(b)) * rad * (1.2 + rng.nextDouble()),
        rad * (0.18 + rng.nextDouble() * 0.25),
        paint,
      );
    }
  }
  // Bokeh.
  for (var i = 0; i < 26; i++) {
    final p = Offset(rng.nextDouble() * s, rng.nextDouble() * s);
    canvas.drawCircle(
      p,
      s * (0.004 + rng.nextDouble() * 0.01),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35 + rng.nextDouble() * 0.4),
    );
  }
}

void _sparkle(Canvas canvas, Offset c, double s, Color color) {
  final p = Path()
    ..moveTo(c.dx, c.dy - s)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
    ..close();
  canvas.drawCircle(
    c,
    s * 0.7,
    Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.4),
  );
  canvas.drawPath(p, Paint()..color = color);
}

/// Paints the foreground (gems bursting out of a prism) on a [s] x [s]
/// square. Everything important stays inside the adaptive-icon safe circle
/// (radius 33/108 of the side).
void paintForeground(Canvas canvas, double s) {
  final c = Offset(s / 2, s / 2);
  // A spiky paint burst behind everything.
  final spikes = Path();
  const n = 14;
  for (var i = 0; i < n * 2; i++) {
    final a = i * pi / n - pi / 2;
    final rad = s * (i.isEven ? (i % 4 == 0 ? 0.3 : 0.27) : 0.18);
    final p = c + Offset(cos(a), sin(a)) * rad;
    if (i == 0) {
      spikes.moveTo(p.dx, p.dy);
    } else {
      spikes.lineTo(p.dx, p.dy);
    }
  }
  spikes.close();
  canvas.drawPath(
    spikes,
    Paint()
      ..color = const Color(0xFFFFE27A).withValues(alpha: 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
  );
  canvas.drawPath(
    spikes,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        s * 0.3,
        const [Color(0xFFFFFFFF), Color(0xFFFFF0B0), Color(0xFFFFB84D)],
        const [0.0, 0.55, 1.0],
      ),
  );
  canvas.drawPath(
    spikes,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.008
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFF8A2A),
  );
  // Paint drops flying out between the gems.
  const drops = [
    (Color(0xFFB45CFF), -1.57, 0.26),
    (Color(0xFFFF9F1C), 0.02, 0.27),
    (Color(0xFFFF4FA3), 1.6, 0.265),
    (Color(0xFF3FB6FF), 3.12, 0.27),
  ];
  for (final (col, a, d) in drops) {
    final dir = Offset(cos(a), sin(a));
    final side = Offset(-dir.dy, dir.dx);
    final head = c + dir * s * d;
    final hr = s * 0.03;
    final tail = c + dir * s * (d - 0.09);
    final drop = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: head, radius: hr)),
      Path()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(head.dx + side.dx * hr * 0.97, head.dy + side.dy * hr * 0.97)
        ..lineTo(head.dx - side.dx * hr * 0.97, head.dy - side.dy * hr * 0.97)
        ..close(),
    );
    canvas.drawPath(drop, Paint()..color = col);
    canvas.drawPath(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006
        ..color = Palette.shade(col, -0.3),
    );
    canvas.drawCircle(
      head + dir * hr * 0.1 - side * hr * 0.35,
      hr * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }
  final gems = [
    (TileColor.red, -2.45, 0.205, 0.092),
    (TileColor.yellow, -0.62, 0.21, 0.098),
    (TileColor.blue, 2.5, 0.2, 0.085),
    (TileColor.green, 0.7, 0.205, 0.09),
  ];
  for (final (color, a, d, r) in gems) {
    final p = c + Offset(cos(a), sin(a)) * s * d;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(a > -pi / 2 && a < pi / 2 ? 0.18 : -0.18);
    TileArt.paint(
      canvas,
      Offset.zero,
      s * r,
      color: color,
      special: Special.none,
    );
    canvas.restore();
  }
  // The prism at the heart of the burst.
  TileArt.paint(canvas, c, s * 0.15, color: null, special: Special.prism);
  _sparkle(canvas, c + Offset(s * 0.2, -s * 0.24), s * 0.03, Colors.white);
  _sparkle(canvas, c + Offset(-s * 0.27, s * 0.12), s * 0.025, Colors.white);
  _sparkle(canvas, c + Offset(s * 0.12, s * 0.27), s * 0.022, Colors.white);
  _sparkle(canvas, c + Offset(-s * 0.08, -s * 0.06), s * 0.035, Colors.white);
}

Future<void> _write(
  String path,
  int size,
  void Function(Canvas, double) paint,
) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec), size.toDouble());
  final img = await rec.endRecording().toImage(size, size);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

/// The whole icon as a square: background plus foreground, zoomed in to the
/// part an adaptive icon shows.
void paintFull(Canvas canvas, double s, {bool rounded = false}) {
  if (rounded) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92),
        Radius.circular(s * 0.22),
      ),
    );
  }
  // Adaptive icons show the middle 72/108 of the layers.
  const zoom = 108 / 76;
  canvas.save();
  canvas.translate(s / 2, s / 2);
  canvas.scale(zoom);
  canvas.translate(-s / 2, -s / 2);
  paintBackground(canvas, s);
  paintForeground(canvas, s);
  canvas.restore();
}

void main() {
  test('render icons', () async {
    const res = 'android/app/src/main/res';
    const dens = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    for (final e in dens.entries) {
      final layer = (108 * e.value).round();
      await _write(
        '$res/mipmap-${e.key}/ic_launcher_foreground.png',
        layer,
        paintForeground,
      );
      await _write(
        '$res/mipmap-${e.key}/ic_launcher_background.png',
        layer,
        paintBackground,
      );
      await _write(
        '$res/mipmap-${e.key}/ic_launcher.png',
        (48 * e.value).round(),
        (c, s) => paintFull(c, s, rounded: true),
      );
    }
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const iosSizes = {
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final e in iosSizes.entries) {
      await _write('$ios/${e.key}', e.value, paintFull);
    }
    await _write('store/icon-512.png', 512, paintFull);
  });
}
