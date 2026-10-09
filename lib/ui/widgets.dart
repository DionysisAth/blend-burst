import 'package:flutter/material.dart';

import '../core/level.dart';
import '../core/models.dart';
import '../core/session.dart';
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
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MiniTilePainter(color, special, gravitySwitch),
  );
}

class _MiniTilePainter extends CustomPainter {
  final TileColor? color;
  final Special special;
  final bool gravitySwitch;
  _MiniTilePainter(this.color, this.special, this.gravitySwitch);

  @override
  void paint(Canvas canvas, Size size) {
    TileArt.paint(
      canvas,
      size.center(Offset.zero),
      size.width * 0.42,
      color: color,
      special: special,
      gravitySwitch: gravitySwitch,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTilePainter old) =>
      old.color != color ||
      old.special != special ||
      old.gravitySwitch != gravitySwitch;
}

class _CellIconPainter extends CustomPainter {
  final bool glass;
  _CellIconPainter(this.glass);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (glass) {
      TileArt.glass(canvas, rect, 1);
    } else {
      TileArt.stain(canvas, rect);
    }
  }

  @override
  bool shouldRepaint(covariant _CellIconPainter old) => old.glass != glass;
}

class ObstacleIcon extends StatelessWidget {
  final bool glass;
  final double size;
  const ObstacleIcon({super.key, required this.glass, this.size = 28});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CellIconPainter(glass));
}

Widget goalIcon(Goal g, {double size = 28}) {
  switch (g.type) {
    case GoalType.score:
      return Icon(Icons.star_rounded, size: size, color: Colors.amber);
    case GoalType.stains:
      return ObstacleIcon(glass: false, size: size);
    case GoalType.glass:
      return ObstacleIcon(glass: true, size: size);
    case GoalType.collect:
      return MiniTile(color: g.color, size: size);
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
  }
}

/// Goal with live progress, shown in the game HUD.
class GoalChip extends StatelessWidget {
  final GoalProgress progress;
  const GoalChip({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final remaining = (p.target - p.current).clamp(0, p.target);
    final label = p.goal.type == GoalType.score
        ? '${p.current}/${p.target}'
        : '$remaining';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          goalIcon(p.goal, size: 26),
          const SizedBox(width: 4),
          if (p.done)
            const Icon(Icons.check_circle, color: Colors.green, size: 22)
          else
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarRow({super.key, required this.stars, this.size = 18});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < stars ? Colors.amber : Colors.black26,
        ),
    ],
  );
}

class Pill extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback? onTap;
  final Key? textKey;
  const Pill({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.textKey,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                key: textKey,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
