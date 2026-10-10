import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Static art (icons, mini tiles, backgrounds) rendered once into images.
///
/// The art is built from paths, multi-stop gradients and blurred shadows.
/// Drawn directly, all of it is rasterized again on every frame while
/// anything on screen animates, and the renderer allocates gradient and blur
/// textures each time. That is wasted battery on phones and has crashed
/// Android emulators. Each look is rendered once and then just stamped.
class ArtCache {
  ArtCache._();

  static final _images = <String, ui.Image>{}; // insertion ordered: LRU
  static int _bytes = 0;
  static const _maxBytes = 64 << 20;
  static bool _failed = false;

  /// Returns the cached image for [key] (rendering it with [draw] into a
  /// [width]×[height] pixel canvas on first use), or null if images cannot
  /// be created on this device.
  static ui.Image? image(
    String key,
    int width,
    int height,
    void Function(Canvas canvas) draw,
  ) {
    if (_failed || width <= 0 || height <= 0) return null;
    final fullKey = '$key@${width}x$height';
    final hit = _images.remove(fullKey);
    if (hit != null) {
      _images[fullKey] = hit; // most recently used
      return hit;
    }
    final ui.Image image;
    try {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      final picture = recorder.endRecording();
      image = picture.toImageSync(width, height);
      picture.dispose();
    } catch (_) {
      _failed = true;
      return null;
    }
    _images[fullKey] = image;
    _bytes += width * height * 4;
    while (_bytes > _maxBytes && _images.length > 1) {
      final oldest = _images.keys.first;
      final old = _images.remove(oldest)!;
      _bytes -= old.width * old.height * 4;
      // Pictures already recorded with it keep their own reference.
      old.dispose();
    }
    return image;
  }

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Draws [draw]'s art for [size] (logical pixels) at [dest], from the
  /// cache. [pad] (a fraction of the size) and [padPx] (logical pixels) add
  /// room around the art for shadows and sparkles that reach outside it. Falls back to drawing
  /// directly when images are unavailable.
  static void paint(
    Canvas canvas,
    String key,
    Rect dest,
    double dpr,
    void Function(Canvas canvas, Size size) draw, {
    double pad = 0,
    double padPx = 0,
    double maxDpr = 4,
  }) {
    final size = dest.size;
    final scale = min(dpr, maxDpr);
    final padX = size.width * pad + padPx, padY = size.height * pad + padPx;
    final outer = Rect.fromLTRB(
      dest.left - padX,
      dest.top - padY,
      dest.right + padX,
      dest.bottom + padY,
    );
    final w = (outer.width * scale).ceil(), h = (outer.height * scale).ceil();
    final image = ArtCache.image(key, w, h, (c) {
      c.scale(w / outer.width, h / outer.height);
      c.translate(padX, padY);
      draw(c, size);
    });
    if (image == null) {
      canvas.save();
      canvas.translate(dest.left, dest.top);
      draw(canvas, size);
      canvas.restore();
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      outer,
      _paint,
    );
  }
}

/// A widget that shows static art through [ArtCache].
///
/// [id] must uniquely describe what [draw] paints (the size is added to the
/// cache key automatically).
class CachedArt extends StatelessWidget {
  final String id;
  final Size size;
  final double pad;
  final double maxDpr;
  final void Function(Canvas canvas, Size size) draw;

  const CachedArt({
    super.key,
    required this.id,
    required this.size,
    required this.draw,
    this.pad = 0,
    this.maxDpr = 4,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: size,
    painter: _CachedArtPainter(
      id,
      pad,
      maxDpr,
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      draw,
    ),
  );
}

class _CachedArtPainter extends CustomPainter {
  final String id;
  final double pad;
  final double maxDpr;
  final double dpr;
  final void Function(Canvas canvas, Size size) draw;
  _CachedArtPainter(this.id, this.pad, this.maxDpr, this.dpr, this.draw);

  @override
  void paint(Canvas canvas, Size size) => ArtCache.paint(
    canvas,
    id,
    Offset.zero & size,
    dpr,
    draw,
    pad: pad,
    maxDpr: maxDpr,
  );

  @override
  bool shouldRepaint(covariant _CachedArtPainter old) =>
      old.id != id || old.dpr != dpr || old.pad != pad || old.maxDpr != maxDpr;
}

/// A [DecoratedBox] whose decoration (gradients, borders, shadows) is drawn
/// from [ArtCache]. Use it for static decorations; animated ones would just
/// fill the cache.
class CachedDecoratedBox extends StatelessWidget {
  final BoxDecoration decoration;
  final Widget? child;
  const CachedDecoratedBox({super.key, required this.decoration, this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CachedBoxPainter(
      decoration,
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    ),
    child: child,
  );
}

class _CachedBoxPainter extends CustomPainter {
  final BoxDecoration decoration;
  final double dpr;
  _CachedBoxPainter(this.decoration, this.dpr);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    var extent = 0.0;
    for (final s in decoration.boxShadow ?? const <BoxShadow>[]) {
      extent = max(
        extent,
        s.blurRadius * 1.5 + s.spreadRadius + s.offset.distance,
      );
    }
    ArtCache.paint(
      canvas,
      'box:${decoration.hashCode}',
      Offset.zero & size,
      dpr,
      (c, s) {
        final painter = decoration.createBoxPainter();
        painter.paint(c, Offset.zero, ImageConfiguration(size: s));
        painter.dispose();
      },
      padPx: extent.ceilToDouble(),
    );
  }

  @override
  bool shouldRepaint(covariant _CachedBoxPainter old) =>
      old.decoration != decoration || old.dpr != dpr;
}
