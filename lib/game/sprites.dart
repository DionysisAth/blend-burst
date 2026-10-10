import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/models.dart';
import '../ui/tile_art.dart';

/// Pre-rendered tile and glass images.
///
/// Drawing every tile from paths and multi-stop gradients each frame makes
/// the renderer upload gradient textures for every tile, every frame. That
/// is wasted work on phones and crashes some Android emulators. Each look is
/// rendered once into an image and then just stamped.
class SpriteCache {
  double _radius = 0;
  double _cell = 0;
  double _dpr = 1;
  bool _failed = false;
  final _tiles = <int, ui.Image>{};
  final _glass = <int, ui.Image>{};
  final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Half-size of a tile image, in tile radii (room for arrows and shadow).
  static const _pad = 1.4;

  /// False if images could not be created; callers then draw directly.
  bool get available => !_failed;

  void configure(double radius, double cell, double dpr) {
    if ((radius - _radius).abs() < 0.01 &&
        (cell - _cell).abs() < 0.01 &&
        dpr == _dpr) {
      return;
    }
    clear();
    _radius = radius;
    _cell = cell;
    _dpr = dpr;
  }

  void clear() {
    for (final img in _tiles.values) {
      img.dispose();
    }
    for (final img in _glass.values) {
      img.dispose();
    }
    _tiles.clear();
    _glass.clear();
  }

  ui.Image? _render(int side, void Function(Canvas canvas) draw) {
    if (_failed || side <= 0) return null;
    try {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      final picture = recorder.endRecording();
      final image = picture.toImageSync(side, side);
      picture.dispose();
      return image;
    } catch (_) {
      _failed = true;
      return null;
    }
  }

  ui.Image? _tile(TileColor? color, Special special) {
    final key = (color?.index ?? 15) * 16 + special.index;
    final cached = _tiles[key];
    if (cached != null) return cached;
    final r = _radius * _dpr;
    final side = (r * 2 * _pad).ceil();
    final image = _render(side, (canvas) {
      TileArt.paint(
        canvas,
        Offset(side / 2, side / 2),
        r,
        color: color,
        special: special,
      );
    });
    if (image != null) _tiles[key] = image;
    return image;
  }

  /// Draws a tile at [center] with the given size [scale] (1 = normal).
  /// Returns false if the sprite is unavailable.
  bool drawTile(
    Canvas canvas,
    Offset center,
    double scale,
    TileColor? color,
    Special special, {
    double rotation = 0,
  }) {
    final image = _tile(color, special);
    if (image == null) return false;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.scale(scale / _dpr);
    canvas.drawImage(
      image,
      Offset(-image.width / 2, -image.height / 2),
      _paint,
    );
    canvas.restore();
    return true;
  }

  /// Draws a glass block filling [cell]. Returns false if unavailable.
  bool drawGlass(Canvas canvas, Rect cell, int layers) {
    var image = _glass[layers];
    if (image == null) {
      final side = (_cell * _dpr).ceil();
      image = _render(side, (canvas) {
        TileArt.glass(
          canvas,
          Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
          layers,
        );
      });
      if (image == null) return false;
      _glass[layers] = image;
    }
    canvas.save();
    canvas.translate(cell.left, cell.top);
    canvas.scale(cell.width / image.width);
    canvas.drawImage(image, Offset.zero, _paint);
    canvas.restore();
    return true;
  }
}
