// Draws the Play Games achievement and leaderboard icons (512x512) into
// store/games/. Upload them in the Play Console (Play Games Services ->
// Achievements / Leaderboards -> the item -> Icon).
//
//   flutter test tool/icon/games_icons_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/ui/icons.dart';
import 'package:blend_burst/ui/tile_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Art = void Function(Canvas canvas, Offset c, double r);

void badge(Canvas canvas, double s, List<Color> colors, Art art) {
  final c = Offset(s / 2, s / 2);
  canvas.drawCircle(
    c,
    s * 0.5,
    Paint()
      ..shader = ui.Gradient.radial(
        c - Offset(s * 0.12, s * 0.15),
        s * 0.62,
        [colors[0], colors[1], colors[2]],
        const [0.0, 0.55, 1.0],
      ),
  );
  // Rays.
  final rays = Path();
  for (var i = 0; i < 16; i++) {
    final a = i * pi / 8;
    rays
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + cos(a - 0.09) * s, c.dy + sin(a - 0.09) * s)
      ..lineTo(c.dx + cos(a + 0.09) * s, c.dy + sin(a + 0.09) * s)
      ..close();
  }
  canvas.save();
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.5)));
  canvas.drawPath(rays, Paint()..color = Colors.white.withValues(alpha: 0.13));
  canvas.restore();
  canvas.drawCircle(
    c,
    s * 0.46,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..color = Colors.white.withValues(alpha: 0.85),
  );
  art(canvas, c, s * 0.28);
}

Art tile(TileColor? color, Special special) =>
    (canvas, c, r) =>
        TileArt.paint(canvas, c, r, color: color, special: special);

Art icon(GameIcons i) => (canvas, c, r) {
  canvas.save();
  canvas.translate(c.dx - r * 1.1, c.dy - r * 1.1);
  canvas.scale(r * 2.2 / 100);
  IconArt.draw(canvas, i);
  canvas.restore();
};

Future<void> write(String name, Art art, List<Color> colors) async {
  const s = 512.0;
  final rec = ui.PictureRecorder();
  badge(Canvas(rec), s, colors, art);
  final img = await rec.endRecording().toImage(512, 512);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File('store/games/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('games icons', () async {
    const gold = [Color(0xFFFFF0A0), Color(0xFFFFB81E), Color(0xFFB36B00)];
    const purple = [Color(0xFFE0B8FF), Color(0xFF8E4BE0), Color(0xFF3E1A7A)];
    const pink = [Color(0xFFFFB8DE), Color(0xFFFF4FA3), Color(0xFF8E1A55)];
    final episodes = [
      ('art_studio', tile(TileColor.red, Special.none)),
      ('rainbow_garden', tile(TileColor.green, Special.none)),
      ('paint_factory', tile(TileColor.purple, Special.bomb)),
      ('sky_gallery', tile(TileColor.blue, Special.lineH)),
      ('ink_lagoon', tile(TileColor.blue, Special.lineV)),
      ('prism_peaks', tile(null, Special.prism)),
      ('bucket_brigade', tile(TileColor.orange, Special.bomb)),
      ('gravity_galaxy', tile(null, Special.whiteBurst)),
    ];
    for (var i = 0; i < episodes.length; i++) {
      final (name, art) = episodes[i];
      await write('achievement_$name', art, Palette.episodeNode(i));
    }
    await write(
      'achievement_first_burst',
      tile(TileColor.yellow, Special.none),
      pink,
    );
    await write('achievement_stars_100', icon(GameIcons.star), purple);
    await write('achievement_stars_300', icon(GameIcons.trophy), pink);
    await write('achievement_spectacular', tile(null, Special.prism), purple);
    await write(
      'leaderboard_stars',
      icon(GameIcons.star),
      Palette.episodeNode(3),
    );
    await write('leaderboard_levels', icon(GameIcons.map), purple);
    await write('leaderboard_score', icon(GameIcons.podium), gold);
  });
}
