import 'package:flutter/material.dart';

import '../core/level.dart';
import '../core/models.dart';
import '../core/session.dart';
import 'art_cache.dart';
import 'game_ui.dart';
import 'icons.dart';
import 'tile_art.dart';

/// A single tile drawn as a widget (goal icons, editor palette, legends).
class MiniTile extends StatelessWidget {
  final TileColor? color;
  final Special special;
  final bool gravitySwitch;
  final double size;
  const MiniTile({
    super.key,
    this.color,
    this.special = Special.none,
    this.gravitySwitch = false,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) => CachedArt(
    id: 'tile:${color?.name}:${special.name}:$gravitySwitch',
    size: Size.square(size),
    pad: 0.25,
    draw: (canvas, size) => TileArt.paint(
      canvas,
      size.center(Offset.zero),
      size.width * 0.42,
      color: color,
      special: special,
      gravitySwitch: gravitySwitch,
    ),
  );
}

enum Obstacle { stain, glass, lock, ink, bucket }

class ObstacleIcon extends StatelessWidget {
  final Obstacle kind;
  final double size;
  const ObstacleIcon(this.kind, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => CachedArt(
    id: 'cell:${kind.name}',
    size: Size.square(size),
    pad: 0.15,
    draw: (canvas, size) {
      final rect = Offset.zero & size;
      switch (kind) {
        case Obstacle.stain:
          TileArt.stain(canvas, rect);
        case Obstacle.glass:
          TileArt.glass(canvas, rect, 1);
        case Obstacle.lock:
          TileArt.paint(
            canvas,
            rect.center,
            size.width * 0.42,
            color: TileColor.blue,
            special: Special.none,
          );
          TileArt.chains(canvas, rect, 2);
        case Obstacle.ink:
          TileArt.ink(canvas, rect);
        case Obstacle.bucket:
          TileArt.bucket(canvas, rect.center, size.width * 0.42);
      }
    },
  );
}

Widget goalIcon(Goal g, {double size = 28}) {
  switch (g.type) {
    case GoalType.score:
      return GameIcon(GameIcons.star, size: size);
    case GoalType.stains:
      return ObstacleIcon(Obstacle.stain, size: size);
    case GoalType.glass:
      return ObstacleIcon(Obstacle.glass, size: size);
    case GoalType.collect:
      return MiniTile(color: g.color, size: size);
    case GoalType.locks:
      return ObstacleIcon(Obstacle.lock, size: size);
    case GoalType.ink:
      return ObstacleIcon(Obstacle.ink, size: size);
    case GoalType.drop:
      return ObstacleIcon(Obstacle.bucket, size: size);
  }
}

String goalText(Goal g, int target) {
  switch (g.type) {
    case GoalType.score:
      return 'Reach $target points';
    case GoalType.stains:
      return 'Clear $target paint stains';
    case GoalType.glass:
      return 'Break $target glass blocks';
    case GoalType.collect:
      return 'Collect $target ${g.color!.label}';
    case GoalType.locks:
      return 'Break $target chains';
    case GoalType.ink:
      return 'Clear all the ink';
    case GoalType.drop:
      return 'Bring $target paint buckets to the exit';
  }
}

/// Goal with live progress, shown in the game HUD.
class GoalChip extends StatelessWidget {
  final GoalProgress progress;
  final double size;
  const GoalChip({super.key, required this.progress, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final remaining = (p.target - p.current).clamp(0, p.target);
    final label = p.goal.type == GoalType.score
        ? _short(p.target - p.current)
        : '$remaining';
    return SizedBox(
      width: size * 1.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              goalIcon(p.goal, size: size),
              if (p.done)
                Positioned(
                  right: -6,
                  bottom: -4,
                  child: Container(
                    width: size * 0.5,
                    height: size * 0.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22B84C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const GameIcon(GameIcons.check),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (!p.done)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: GameText(label, size: size * 0.48),
            )
          else
            SizedBox(height: size * 0.53),
        ],
      ),
    );
  }

  static String _short(int v) {
    if (v <= 0) return '0';
    if (v >= 10000) {
      return '${(v / 1000).toStringAsFixed(v >= 100000 ? 0 : 1)}k';
    }
    return '$v';
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  final bool arc;
  const StarRow({
    super.key,
    required this.stars,
    this.size = 18,
    this.arc = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: EdgeInsets.only(bottom: arc && i == 1 ? size * 0.25 : 0),
          child: GameIcon(
            i < stars ? GameIcons.star : GameIcons.starEmpty,
            size: arc && i == 1 ? size * 1.2 : size,
          ),
        ),
    ],
  );
}

String formatDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Little illustration for tutorial cards ("red + blue = purple" etc.).
class TutorialArt extends StatelessWidget {
  final String? kind;
  const TutorialArt(this.kind, {super.key});

  /// A green "done" badge.
  static Widget _ok(double size) => Container(
    width: size,
    height: size,
    margin: const EdgeInsets.only(left: 4),
    padding: EdgeInsets.all(size * 0.16),
    decoration: BoxDecoration(
      color: const Color(0xFF22B84C),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
    ),
    child: const GameIcon(GameIcons.check),
  );

  static Widget _op(String s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: GameText(s, size: 30, color: Palette.sun),
  );

  static Widget _tile(
    TileColor? c, {
    Special special = Special.none,
    bool sw = false,
    double size = 48,
  }) => MiniTile(color: c, special: special, gravitySwitch: sw, size: size);

  // Shrinks the whole illustration on narrow screens instead of overflowing.
  Widget _row(List<Widget> children) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 'match':
        return _row([
          for (var i = 0; i < 3; i++) _tile(TileColor.red),
          _op('='),
          const GameIcon(GameIcons.star, size: 44),
        ]);
      case 'line':
        Widget square() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < 2; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < 2; c++) _tile(TileColor.blue, size: 30),
                ],
              ),
          ],
        );
        return _row([
          for (var i = 0; i < 4; i++) _tile(TileColor.blue, size: 34),
          _op('/'),
          square(),
          _op('='),
          _tile(TileColor.blue, special: Special.lineH),
        ]);
      case 'blendRB':
        return _row([
          _tile(TileColor.red),
          _op('+'),
          _tile(TileColor.blue),
          _op('='),
          _tile(TileColor.purple),
        ]);
      case 'blendBY':
        return _row([
          _tile(TileColor.blue),
          _op('+'),
          _tile(TileColor.yellow),
          _op('='),
          _tile(TileColor.green),
        ]);
      case 'blendRY':
        return _row([
          _tile(TileColor.red),
          _op('+'),
          _tile(TileColor.yellow),
          _op('='),
          _tile(TileColor.orange),
        ]);
      case 'bomb':
        return _row([
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              children: [
                for (final o in const [
                  Offset(0, 0),
                  Offset(0, 30),
                  Offset(0, 60),
                  Offset(30, 60),
                  Offset(60, 60),
                ])
                  Positioned(
                    left: o.dx,
                    top: o.dy,
                    child: _tile(TileColor.yellow, size: 30),
                  ),
              ],
            ),
          ),
          _op('='),
          _tile(TileColor.yellow, special: Special.bomb, size: 56),
        ]);
      case 'prism':
        return _row([
          for (var i = 0; i < 5; i++) _tile(TileColor.green, size: 32),
          _op('='),
          _tile(null, special: Special.prism, size: 52),
        ]);
      case 'whiteburst':
        return _row([
          _tile(TileColor.purple),
          _op('+'),
          _tile(TileColor.yellow),
          _op('='),
          _tile(null, special: Special.whiteBurst, size: 56),
        ]);
      case 'stain':
        return _row([
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const ObstacleIcon(Obstacle.stain, size: 64),
                _tile(TileColor.orange, size: 46),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const GameIcon(GameIcons.arrow, size: 40),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF22B84C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const GameIcon(GameIcons.check),
          ),
        ]);
      case 'glass':
      case 'glass2':
        return _row([
          _tile(TileColor.red, size: 40),
          _tile(TileColor.red, size: 40),
          _tile(TileColor.red, size: 40),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _GlassPainter(kind == 'glass2' ? 2 : 1),
            ),
          ),
        ]);
      case 'secondary':
        return _row([for (var i = 0; i < 3; i++) _tile(TileColor.purple)]);
      case 'gravityUp':
      case 'gravityLeft':
        return _row([
          _tile(TileColor.blue, size: 40),
          Transform.rotate(
            angle: kind == 'gravityUp' ? -1.5708 : 3.14159,
            child: const GameIcon(GameIcons.arrow, size: 56),
          ),
          _tile(TileColor.yellow, size: 40),
        ]);
      case 'switch':
        return _row([
          _tile(TileColor.green, sw: true, size: 56),
          _op('='),
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3FD0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const GameIcon(GameIcons.retry),
          ),
        ]);
      case 'lock':
        return _row([
          const ObstacleIcon(Obstacle.lock, size: 56),
          const GameIcon(GameIcons.arrow, size: 36),
          _tile(TileColor.blue, size: 50),
          _ok(30),
        ]);
      case 'ink':
        return _row([
          for (var i = 0; i < 3; i++) _tile(TileColor.yellow, size: 36),
          const ObstacleIcon(Obstacle.ink, size: 48),
          _op('='),
          _ok(34),
        ]);
      case 'filter':
        return _row([
          _tile(TileColor.yellow, size: 44),
          const GameIcon(GameIcons.arrow, size: 34),
          SizedBox(
            width: 52,
            height: 52,
            child: CachedArt(
              id: 'tut-filter',
              size: const Size.square(52),
              draw: (c, sz) {
                TileArt.filter(c, Offset.zero & sz, TileColor.purple);
                TileArt.filterBadge(c, Offset.zero & sz, TileColor.purple);
              },
            ),
          ),
          _op('='),
          _tile(TileColor.purple, size: 44),
        ]);
      case 'bucket':
        return _row([
          const ObstacleIcon(Obstacle.bucket, size: 54),
          Transform.rotate(
            angle: 1.5708,
            child: const GameIcon(GameIcons.arrow, size: 40),
          ),
          Container(
            width: 54,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF7CF2B0),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Palette.plum, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          _ok(30),
        ]);
      case 'zones':
        return _row([
          for (final g in const [Gravity.right, Gravity.down, Gravity.left])
            SizedBox(
              width: 52,
              height: 52,
              child: CachedArt(
                id: 'tut-zone-${g.name}',
                size: const Size.square(52),
                draw: (c, sz) {
                  c.drawRRect(
                    RRect.fromRectAndRadius(
                      (Offset.zero & sz).deflate(2),
                      const Radius.circular(10),
                    ),
                    Paint()..color = const Color(0xFF4A2183),
                  );
                  TileArt.zoneArrow(c, Offset.zero & sz, g);
                  TileArt.zoneBadge(c, Offset.zero & sz, g);
                },
              ),
            ),
        ]);
      case 'timed':
        return _row([
          const GameIcon(GameIcons.arrow, size: 44),
          const CountBadge('3'),
          _op('='),
          Transform.rotate(
            angle: 1.5708,
            child: const GameIcon(GameIcons.arrow, size: 44),
          ),
        ]);
      case 'flip':
        return _row([
          const GameIcon(GameIcons.gravity, size: 60),
          _op('='),
          for (final a in const [-1.5708, 3.14159, 0.0])
            Transform.rotate(
              angle: a,
              child: const GameIcon(GameIcons.arrow, size: 34),
            ),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _GlassPainter extends CustomPainter {
  final int layers;
  _GlassPainter(this.layers);
  @override
  void paint(Canvas canvas, Size size) =>
      TileArt.glass(canvas, Offset.zero & size, layers);
  @override
  bool shouldRepaint(covariant _GlassPainter old) => old.layers != layers;
}
