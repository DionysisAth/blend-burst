import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'art_cache.dart';
import 'icons.dart';
import 'tile_art.dart';

/// UI sound hook, set by the app so widgets can click without a context.
class UiSounds {
  static VoidCallback? click;
}

/// Big outlined "game" text (fill + thick outline + drop shadow).
class GameText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double? strokeWidth;
  final List<Color>? gradient;
  final TextAlign align;
  final String family;
  final double letterSpacing;

  /// Optional second, wider outline drawn behind the main one.
  final Color? outer;

  const GameText(
    this.text, {
    super.key,
    this.size = 24,
    this.color = Colors.white,
    this.stroke = Palette.ink,
    this.strokeWidth,
    this.gradient,
    this.align = TextAlign.center,
    this.family = 'Lilita',
    this.letterSpacing = 0.5,
    this.outer,
  });

  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth ?? max(2.0, size * 0.16);
    final base = TextStyle(
      fontFamily: family,
      fontSize: size,
      height: 1.1,
      letterSpacing: letterSpacing,
      fontWeight: family == 'Fredoka' ? FontWeight.w700 : FontWeight.w400,
    );
    Paint? fillPaint;
    if (gradient != null) {
      fillPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size * 0.1),
          Offset(0, size * 1.1),
          gradient!,
        );
    }
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    Widget outline(Paint paint) => RichText(
      textAlign: align,
      textScaler: scaler,
      text: TextSpan(
        text: text,
        style: base.copyWith(foreground: paint),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outline layers are decoration only; the fill Text carries semantics.
        ExcludeSemantics(
          child: Transform.translate(
            offset: Offset(0, size * 0.08),
            child: outline(
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = outer != null ? sw * 2 : sw
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black.withValues(alpha: 0.28),
            ),
          ),
        ),
        if (outer != null)
          ExcludeSemantics(
            child: outline(
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw * 2
                ..strokeJoin = StrokeJoin.round
                ..color = outer!,
            ),
          ),
        ExcludeSemantics(
          child: outline(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(
          text,
          textAlign: align,
          style: fillPaint == null
              ? base.copyWith(color: color)
              : base.copyWith(foreground: fillPaint),
        ),
      ],
    );
  }
}

/// Candy button color sets: (top, bottom, edge).
class CandyColors {
  final Color top;
  final Color bottom;
  final Color edge;
  const CandyColors(this.top, this.bottom, this.edge);

  static const green = CandyColors(
    Color(0xFF7CF06A),
    Color(0xFF22B84C),
    Color(0xFF13792F),
  );
  static const blue = CandyColors(
    Color(0xFF6FD3FF),
    Color(0xFF1F8EF0),
    Color(0xFF125FA8),
  );
  static const yellow = CandyColors(
    Color(0xFFFFE477),
    Color(0xFFFFAE12),
    Color(0xFFC06E00),
  );
  static const red = CandyColors(
    Color(0xFFFF8A8A),
    Color(0xFFF0304E),
    Color(0xFFA3122E),
  );
  static const purple = CandyColors(
    Color(0xFFC79BFF),
    Color(0xFF8A47E8),
    Color(0xFF55229E),
  );
  static const pink = CandyColors(
    Color(0xFFFFA3D1),
    Color(0xFFFF4FA3),
    Color(0xFFB3226B),
  );
  static const gray = CandyColors(
    Color(0xFFD9D4E6),
    Color(0xFFA59DBA),
    Color(0xFF6E6684),
  );
}

/// A glossy, pressable game button with a 3D bottom edge.
class CandyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final CandyColors colors;
  final double height;
  final double? width;
  final double radius;

  const CandyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.colors = CandyColors.green,
    this.height = 56,
    this.width,
    this.radius = 20,
  });

  /// Convenience: a button with a game-text label and optional icon.
  factory CandyButton.label(
    String label, {
    Key? key,
    required VoidCallback? onTap,
    CandyColors colors = CandyColors.green,
    double height = 56,
    double? width,
    GameIcons? icon,
    double fontSize = 24,
  }) => CandyButton(
    key: key,
    onTap: onTap,
    colors: colors,
    height: height,
    width: width,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          GameIcon(icon, size: fontSize * 1.2),
          const SizedBox(width: 6),
        ],
        GameText(label, size: fontSize, stroke: colors.edge),
      ],
    ),
  );

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.colors : CandyColors.gray;
    const edge = 6.0;
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                UiSounds.click?.call();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 90),
          child: SizedBox(
            height: widget.height + edge,
            width: widget.width,
            child: Stack(
              children: [
                Positioned.fill(
                  top: edge,
                  child: CachedDecoratedBox(
                    decoration: BoxDecoration(
                      color: c.edge,
                      borderRadius: r,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40301040),
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 90),
                  left: 0,
                  right: 0,
                  top: _down ? edge * 0.6 : 0,
                  height: widget.height,
                  child: CachedDecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: r,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.top, c.bottom],
                      ),
                      border: Border.all(color: c.edge, width: 2.5),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 8,
                          right: 8,
                          top: 4,
                          height: widget.height * 0.36,
                          child: CachedDecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                widget.radius,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            // Never overflow: shrink the content to fit.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: widget.child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round candy button holding an icon.
class RoundButton extends StatelessWidget {
  final GameIcons icon;
  final VoidCallback? onTap;
  final CandyColors colors;
  final double size;
  final String? label;

  const RoundButton(
    this.icon, {
    super.key,
    required this.onTap,
    this.colors = CandyColors.purple,
    this.size = 52,
    this.label,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: CandyButton(
      onTap: onTap,
      colors: colors,
      height: size,
      width: size,
      radius: size / 2,
      child: GameIcon(icon, size: size * 0.5),
    ),
  );
}

/// A ribbon banner with folded tails.
class Ribbon extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  const Ribbon(
    this.text, {
    super.key,
    this.color = Palette.candyPink,
    this.fontSize = 30,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RibbonPainter(
      color,
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        fontSize * 1.4,
        fontSize * 0.28,
        fontSize * 1.4,
        fontSize * 0.42,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GameText(
          text,
          size: fontSize,
          stroke: Palette.shade(color, -0.32),
        ),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  final Color color;
  final double dpr;
  _RibbonPainter(this.color, this.dpr);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    ArtCache.paint(
      canvas,
      'ribbon:${color.toARGB32()}',
      Offset.zero & size,
      dpr,
      _draw,
      padPx: 4,
    );
  }

  void _draw(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final dark = Palette.shade(color, -0.22);
    final tail = h * 0.55;
    // Folded tails behind the band, pointing outwards.
    for (final s in [-1.0, 1.0]) {
      final inner = s < 0 ? tail + h * 0.3 : w - tail - h * 0.3;
      final outer = s < 0 ? 0.0 : w;
      final notch = s < 0 ? tail * 0.45 : w - tail * 0.45;
      final p = Path()
        ..moveTo(inner, h * 0.22)
        ..lineTo(outer, h * 0.22)
        ..lineTo(notch, h * 0.61)
        ..lineTo(outer, h * 1.0)
        ..lineTo(inner, h * 1.0)
        ..close();
      canvas.drawPath(
        p.shift(const Offset(0, 3)),
        Paint()..color = const Color(0x33301040),
      );
      canvas.drawPath(p, Paint()..color = dark);
      final edge = s < 0 ? tail : w - tail;
      canvas.drawPath(
        Path()
          ..moveTo(edge, h * 0.86)
          ..lineTo(edge + s * h * 0.0, h * 1.0)
          ..lineTo(edge - s * h * 0.3, h * 0.86)
          ..close(),
        Paint()..color = Palette.shade(color, -0.4),
      );
    }
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(tail, 0, w - tail * 2, h * 0.86),
      Radius.circular(h * 0.2),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x40301040),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          Palette.shade(color, 0.14),
          color,
        ]),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.shade(color, -0.3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          tail + h * 0.15,
          h * 0.1,
          w - tail * 2 - h * 0.3,
          h * 0.22,
        ),
        Radius.circular(h * 0.1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) =>
      old.color != color || old.dpr != dpr;
}

/// A cream panel with a thick border and an optional ribbon title.
class GamePanel extends StatelessWidget {
  final Widget child;
  final String? title;
  final Color ribbonColor;
  final VoidCallback? onClose;
  final EdgeInsets padding;

  const GamePanel({
    super.key,
    required this.child,
    this.title,
    this.ribbonColor = Palette.candyPink,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(20, 44, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: title == null ? 0 : 26),
          child: CachedDecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Palette.plum, width: 5),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFDF7), Color(0xFFFFEFD9)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66301040),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFFFD9A8), width: 2),
              ),
              padding: title == null ? const EdgeInsets.all(20) : padding,
              child: child,
            ),
          ),
        ),
        if (title != null) Ribbon(title!, color: ribbonColor),
        if (onClose != null)
          Positioned(
            right: -6,
            top: title == null ? -10 : 14,
            child: RoundButton(
              GameIcons.close,
              onTap: onClose,
              colors: CandyColors.red,
              size: 40,
              label: 'Close',
            ),
          ),
      ],
    );
  }
}

/// Shows a dialog that pops in with a bounce.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: const Color(0x993B1A63),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final scale = CurvedAnimation(
        parent: anim,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(0, 0.4)),
        child: ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(scale),
          child: child,
        ),
      );
    },
  );
}

/// Small counter badge (booster counts, notifications).
class CountBadge extends StatelessWidget {
  final String text;
  final Color color;
  const CountBadge(
    this.text, {
    super.key,
    this.color = const Color(0xFFF0304E),
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55301040),
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: GameText(
      text,
      size: 15,
      stroke: Palette.shade(color, -0.3),
      strokeWidth: 3,
    ),
  );
}

/// A rounded "pill" counter for lives / coins / stars on the map.
class StatPill extends StatelessWidget {
  final GameIcons icon;
  final String text;
  final VoidCallback? onTap;
  final Key? textKey;
  final Widget? trailing;
  const StatPill({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.textKey,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 38,
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.fromLTRB(26, 0, 8, 0),
            decoration: BoxDecoration(
              color: const Color(0xCC3B1A63),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2.5,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  key: textKey,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontFamily: 'Lilita',
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ),
          Positioned(left: 0, top: -2, child: GameIcon(icon, size: 40)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ backgrounds

/// Painted, themed backdrop (soft paint blobs and episode motifs).
class PaintedBackground extends StatelessWidget {
  final int theme;
  final Widget? child;
  const PaintedBackground({super.key, required this.theme, this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: BackgroundPainter(
      theme,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    ),
    child: child ?? const SizedBox.expand(),
  );
}

class BackgroundPainter extends CustomPainter {
  final int theme;
  final int seed;
  final double dpr;
  BackgroundPainter(this.theme, {this.seed = 0, this.dpr = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Soft art: twice the logical size is plenty, even on dense screens.
    ArtCache.paint(
      canvas,
      'bg:$theme:$seed',
      Offset.zero & size,
      dpr,
      (c, s) => paintTheme(c, Offset.zero & s, theme, seed: seed),
      maxDpr: 2,
    );
  }

  static void paintTheme(Canvas canvas, Rect area, int theme, {int seed = 0}) {
    final colors = Palette.episode(theme);
    canvas.drawRect(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          area.topCenter,
          area.bottomCenter,
          colors,
          const [0.0, 0.55, 1.0],
        ),
    );
    final rnd = Random(theme * 1000 + seed);
    final w = area.width, h = area.height;
    // Soft light blobs.
    final blobColors = [
      Colors.white,
      Palette.shade(colors[1], 0.15),
      Palette.shade(colors[0], 0.1),
    ];
    final blobs = max(5, (h / 220).round());
    for (var i = 0; i < blobs; i++) {
      final c =
          area.topLeft + Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      canvas.drawCircle(
        c,
        w * (0.18 + rnd.nextDouble() * 0.25),
        Paint()
          ..shader = ui.Gradient.radial(c, w * 0.4, [
            blobColors[i % 3].withValues(alpha: 0.42),
            blobColors[i % 3].withValues(alpha: 0.0),
          ]),
      );
    }
    final motifs = max(6, (h / 120).round());
    for (var i = 0; i < motifs; i++) {
      final c =
          area.topLeft + Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final s = w * (0.05 + rnd.nextDouble() * 0.07);
      switch (theme) {
        case 0:
          _splat(
            canvas,
            c,
            s,
            [
              const Color(0xFFFF5C7A),
              const Color(0xFFFFD34D),
              const Color(0xFFFF9F43),
              Colors.white,
            ][i % 4],
            rnd,
          );
        case 1:
          _flower(canvas, c, s, rnd);
        default:
          _gear(canvas, c, s * 1.2, rnd.nextDouble());
      }
    }
    // Sparkles.
    final sparkles = max(14, (h / 50).round());
    for (var i = 0; i < sparkles; i++) {
      final c =
          area.topLeft + Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final s = 2.0 + rnd.nextDouble() * 5;
      final p = Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s);
      canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.4 + rnd.nextDouble() * 0.4,
          ),
      );
    }
  }

  static void _splat(
    Canvas canvas,
    Offset c,
    double s,
    Color color,
    Random rnd,
  ) {
    final p = Path()..addOval(Rect.fromCircle(center: c, radius: s));
    for (var i = 0; i < 7; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      p.addOval(
        Rect.fromCircle(
          center:
              c + Offset(cos(a), sin(a)) * s * (0.8 + rnd.nextDouble() * 0.6),
          radius: s * (0.15 + rnd.nextDouble() * 0.3),
        ),
      );
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = Color.lerp(
          color,
          Colors.white,
          0.55,
        )!.withValues(alpha: 0.32),
    );
  }

  static void _flower(Canvas canvas, Offset c, double s, Random rnd) {
    final petal = Paint()..color = Colors.white.withValues(alpha: 0.38);
    final rot = rnd.nextDouble();
    for (var i = 0; i < 5; i++) {
      final a = rot + i * 2 * pi / 5;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * s * 0.55, s * 0.42, petal);
    }
    canvas.drawCircle(
      c,
      s * 0.32,
      Paint()..color = const Color(0xFFFFE066).withValues(alpha: 0.55),
    );
  }

  static void _gear(Canvas canvas, Offset c, double s, double rot) {
    final g = Path();
    for (var i = 0; i < 8; i++) {
      final a = rot + i * pi / 4;
      g.addRect(
        Rect.fromCenter(
          center: c + Offset(cos(a), sin(a)) * s * 0.95,
          width: s * 0.42,
          height: s * 0.42,
        ),
      );
    }
    g.addOval(Rect.fromCircle(center: c, radius: s * 0.9));
    canvas.drawPath(g, Paint()..color = Colors.white.withValues(alpha: 0.13));
    canvas.drawCircle(
      c,
      s * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter old) =>
      old.theme != theme || old.seed != seed || old.dpr != dpr;
}

// ---------------------------------------------------------------- confetti

class Confetti extends StatefulWidget {
  final int count;
  const Confetti({super.key, this.count = 70});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  late final List<_Bit> _bits;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    const colors = [
      Color(0xFFFF3B5C),
      Color(0xFFFFC21A),
      Color(0xFF2F7BFF),
      Color(0xFF1FC46B),
      Color(0xFFA24BF2),
      Color(0xFFFF8A1F),
    ];
    _bits = [
      for (var i = 0; i < widget.count; i++)
        _Bit(
          x: rnd.nextDouble(),
          vx: (rnd.nextDouble() - 0.5) * 0.6,
          vy: -0.6 - rnd.nextDouble() * 0.7,
          spin: (rnd.nextDouble() - 0.5) * 14,
          color: colors[i % colors.length],
          size: 6 + rnd.nextDouble() * 7,
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(_bits, _c.value * 2.6),
        size: Size.infinite,
      ),
    ),
  );
}

class _Bit {
  final double x, vx, vy, spin, size;
  final Color color;
  _Bit({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  final double t;
  _ConfettiPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 2.6) return;
    final fade = (1 - (t - 1.8) / 0.8).clamp(0.0, 1.0);
    for (final b in bits) {
      final x = (b.x + b.vx * t) * size.width;
      final y = size.height * (0.45 + b.vy * t + 0.55 * t * t);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t);
      canvas.scale(1, cos(b.spin * t * 0.7).abs() * 0.8 + 0.2);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: b.size,
          height: b.size * 0.6,
        ),
        Paint()..color = b.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
