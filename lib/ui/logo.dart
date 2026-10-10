import 'dart:math';

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'game_ui.dart';
import 'tile_art.dart';
import 'widgets.dart';

/// "Blend Burst" wordmark: each letter in a paint color, with a few tiles.
class BlendBurstLogo extends StatelessWidget {
  final double size;
  const BlendBurstLogo({super.key, this.size = 56});

  static const _colors = [
    Color(0xFFFF3B5C),
    Color(0xFFFF8A1F),
    Color(0xFFFFC21A),
    Color(0xFF1FC46B),
    Color(0xFF2F7BFF),
    Color(0xFFA24BF2),
  ];

  Widget _word(String w, int offset) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < w.length; i++)
        Transform.rotate(
          angle: sin((i + offset) * 1.7) * 0.07,
          child: Transform.translate(
            offset: Offset(0, sin((i + offset) * 1.3) * size * 0.05),
            child: GameText(
              w[i],
              size: size,
              gradient: [
                Palette.shade(_colors[(i + offset) % 6], 0.18),
                _colors[(i + offset) % 6],
              ],
              stroke: Colors.white,
              strokeWidth: size * 0.16,
              outer: Palette.ink,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Blend Burst',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -0.3,
                    child: MiniTile(color: TileColor.red, size: size * 0.8),
                  ),
                  MiniTile(
                    color: null,
                    special: Special.whiteBurst,
                    size: size * 1.1,
                  ),
                  Transform.rotate(
                    angle: 0.3,
                    child: MiniTile(color: TileColor.blue, size: size * 0.8),
                  ),
                ],
              ),
              _word('Blend', 0),
              Transform.translate(
                offset: Offset(0, -size * 0.18),
                child: _word('Burst', 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
