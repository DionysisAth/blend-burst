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

const _rainbow = [
  Color(0xFFFF4D6D),
  Color(0xFFFF9F1C),
  Color(0xFFFFD93D),
  Color(0xFF2EDB7F),
  Color(0xFF3FA7FF),
  Color(0xFFB45CFF),
];

/// Paints the full-bleed background on a [s] x [s] square.
void paintBackground(Canvas canvas, double s) {
  final c = Offset(s / 2, s / 2);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        s * 0.72,
        const [
          Color(0xFFFFA6DF),
          Color(0xFFD457E8),
          Color(0xFF7A33D6),
          Color(0xFF2E1078),
        ],
        const [0.0, 0.28, 0.6, 1.0],
      ),
  );
  // Sun rays, alternating white and pink.
  const n = 16;
  for (var i = 0; i < n; i++) {
    final a = i * 2 * pi / n;
    const w = pi / n * 0.5;
    final ray = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + cos(a - w) * s, c.dy + sin(a - w) * s)
      ..lineTo(c.dx + cos(a + w) * s, c.dy + sin(a + w) * s)
      ..close();
    canvas.drawPath(
      ray,
      Paint()
        ..shader = ui.Gradient.radial(c, s * 0.72, [
          (i.isEven ? Colors.white : const Color(0xFFFFD6F2)).withValues(
            alpha: i.isEven ? 0.24 : 0.12,
          ),
          Colors.white.withValues(alpha: 0.0),
        ]),
    );
  }
  // Soft light in the middle.
  canvas.drawCircle(
    c,
    s * 0.36,
    Paint()
      ..shader = ui.Gradient.radial(c, s * 0.36, [
        Colors.white.withValues(alpha: 0.45),
        Colors.white.withValues(alpha: 0.0),
      ]),
  );
  // Confetti around the edge of the visible area.
  final rng = Random(11);
  for (var i = 0; i < 30; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final d = s * (0.27 + rng.nextDouble() * 0.12);
    final p = c + Offset(cos(a), sin(a)) * d;
    final col = _rainbow[i % _rainbow.length];
    final paint = Paint()..color = col.withValues(alpha: 0.9);
    final size = s * (0.008 + rng.nextDouble() * 0.008);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(rng.nextDouble() * pi);
    if (i % 3 == 0) {
      canvas.drawCircle(Offset.zero, size, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: size * 3.2,
            height: size * 1.4,
          ),
          Radius.circular(size * 0.6),
        ),
        paint,
      );
    }
    canvas.restore();
  }
  // Vignette.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        s * 0.72,
        [const Color(0x00000000), const Color(0x66180640)],
        const [0.55, 1.0],
      ),
  );
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

/// A spiky rainbow burst: colored tips, a white-hot core.
void _paintBurst(Canvas canvas, Offset c, double s) {
  final spikes = Path();
  const n = 16;
  for (var i = 0; i < n * 2; i++) {
    final a = i * pi / n - pi / 2;
    final rad = s * (i.isEven ? (i % 4 == 0 ? 0.3 : 0.265) : 0.175);
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
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.025),
  );
  canvas.drawPath(
    spikes,
    Paint()
      ..shader = ui.Gradient.sweep(
        c,
        [..._rainbow, _rainbow.first],
        [for (var i = 0; i <= 6; i++) i / 6],
        TileMode.clamp,
        -pi / 2,
        3 * pi / 2,
      ),
  );
  canvas.drawPath(
    spikes,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        s * 0.3,
        [
          Colors.white,
          const Color(0xFFFFF6DC),
          const Color(0xFFFFF6DC).withValues(alpha: 0.0),
        ],
        const [0.0, 0.42, 0.72],
      ),
  );
  canvas.drawPath(
    spikes,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.007
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white,
  );
}

/// A glossy paint drop flying outwards along angle [a].
void _drop(Canvas canvas, Offset c, double s, double a, double d, Color col) {
  final dir = Offset(cos(a), sin(a));
  final side = Offset(-dir.dy, dir.dx);
  final head = c + dir * s * d;
  final hr = s * 0.032;
  final tail = c + dir * s * (d - 0.1);
  final drop = Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: head, radius: hr)),
    Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(head.dx + side.dx * hr * 0.97, head.dy + side.dy * hr * 0.97)
      ..lineTo(head.dx - side.dx * hr * 0.97, head.dy - side.dy * hr * 0.97)
      ..close(),
  );
  canvas.drawPath(
    drop.shift(Offset(0, s * 0.008)),
    Paint()..color = const Color(0x40301040),
  );
  canvas.drawPath(
    drop,
    Paint()
      ..shader = ui.Gradient.linear(tail, head + dir * hr, [
        Palette.shade(col, 0.35),
        col,
      ]),
  );
  canvas.drawPath(
    drop,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..color = Palette.shade(col, -0.32),
  );
  canvas.drawCircle(
    head - side * hr * 0.35 - dir * hr * 0.1,
    hr * 0.3,
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );
}

/// Paints the foreground (a rainbow paint splash with gems bursting out of
/// a prism) on a [s] x [s] square. Everything important stays inside the
/// adaptive-icon safe circle (radius 33/108 of the side).
void paintForeground(Canvas canvas, double s) {
  final c = Offset(s / 2, s / 2);
  _paintBurst(canvas, c, s);
  for (final (col, a) in const [
    (Color(0xFFB45CFF), -pi / 2),
    (Color(0xFFFF9F1C), 0.0),
    (Color(0xFFFF4FA3), pi / 2),
    (Color(0xFF3FB6FF), pi),
  ]) {
    _drop(canvas, c, s, a, 0.27, col);
  }
  // Glow behind the prism.
  canvas.drawCircle(
    c,
    s * 0.17,
    Paint()
      ..shader = ui.Gradient.radial(c, s * 0.17, [
        Colors.white,
        Colors.white.withValues(alpha: 0.0),
      ]),
  );
  final gems = [
    (TileColor.red, -2.36, 0.215, 0.092, -0.22),
    (TileColor.yellow, -0.79, 0.218, 0.098, 0.2),
    (TileColor.blue, 2.36, 0.21, 0.086, 0.2),
    (TileColor.green, 0.79, 0.212, 0.088, -0.16),
  ];
  for (final (color, a, d, r, tilt) in gems) {
    final p = c + Offset(cos(a), sin(a)) * s * d;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(tilt);
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
  _sparkle(canvas, c + Offset(s * 0.07, -s * 0.27), s * 0.034, Colors.white);
  _sparkle(canvas, c + Offset(-s * 0.29, s * 0.02), s * 0.022, Colors.white);
  _sparkle(canvas, c + Offset(s * 0.28, s * 0.07), s * 0.026, Colors.white);
  _sparkle(canvas, c + Offset(-s * 0.06, s * 0.28), s * 0.024, Colors.white);
  _sparkle(canvas, c + Offset(-s * 0.075, -s * 0.07), s * 0.03, Colors.white);
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
