import 'dart:math';

import 'package:blend_burst/core/board.dart';
import 'package:blend_burst/core/level.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A match-free 8x8 background: each row cycles R B Y N shifted by 2,
/// so no row or column ever has three equal tiles in a line.
List<String> background({int rows = 8, int cols = 8}) => [
  for (var r = 0; r < rows; r++)
    [for (var c = 0; c < cols; c++) 'RBYN'[(c + 2 * r) % 4]].join(),
];

List<String> withTiles(List<String> base, Map<Pos, String> cells) {
  final grid = [for (final row in base) row.split('')];
  cells.forEach((p, ch) => grid[p.r][p.c] = ch);
  return [for (final row in grid) row.join()];
}

LevelDef levelOf(
  List<String> tiles, {
  List<String>? layout,
  Gravity gravity = Gravity.down,
  bool blending = true,
  List<Goal> goals = const [Goal(GoalType.score, 100000)],
}) {
  return LevelDef(
    id: 1,
    name: 'test',
    moves: 20,
    colors: const [
      TileColor.red,
      TileColor.blue,
      TileColor.yellow,
      TileColor.brown,
    ],
    layout: layout ?? List.filled(tiles.length, '.' * tiles.first.length),
    tiles: tiles,
    gravity: gravity,
    blending: blending,
    goals: goals,
    stars: const [1, 2, 3],
  );
}

/// Builds a board from preset tiles and checks the presets survived
/// (they would not if they formed a match or a dead board).
Board boardOf(
  List<String> tiles, {
  List<String>? layout,
  Gravity gravity = Gravity.down,
  bool blending = true,
}) {
  final b = Board.fromLevel(
    levelOf(tiles, layout: layout, gravity: gravity, blending: blending),
    Random(1),
  );
  for (final p in b.allPositions) {
    final want = tileColorFromCode(tiles[p.r][p.c]);
    if (want == null || !b.canHoldTile(p)) continue;
    expect(b.tileAt(p)?.color, want, reason: 'preset at $p changed');
  }
  return b;
}

void main() {
  group('color rules', () {
    test('primaries blend into secondaries', () {
      expect(blendPrimaries(TileColor.red, TileColor.blue), TileColor.purple);
      expect(blendPrimaries(TileColor.blue, TileColor.yellow), TileColor.green);
      expect(blendPrimaries(TileColor.yellow, TileColor.red), TileColor.orange);
      expect(blendPrimaries(TileColor.red, TileColor.red), isNull);
      expect(blendPrimaries(TileColor.red, TileColor.brown), isNull);
    });

    test('secondary + missing primary is a white burst pair', () {
      expect(isWhiteBurstPair(TileColor.purple, TileColor.yellow), isTrue);
      expect(isWhiteBurstPair(TileColor.red, TileColor.green), isTrue);
      expect(isWhiteBurstPair(TileColor.orange, TileColor.blue), isTrue);
      expect(isWhiteBurstPair(TileColor.purple, TileColor.red), isFalse);
    });

    test('gravity rotates clockwise through all directions', () {
      var g = Gravity.down;
      final seen = <Gravity>[];
      for (var i = 0; i < 4; i++) {
        seen.add(g);
        g = g.rotatedCw;
      }
      expect(seen, [Gravity.down, Gravity.left, Gravity.up, Gravity.right]);
      expect(g, Gravity.down);
    });
  });

  group('level format', () {
    test('round-trips through JSON', () {
      final l = levelOf(
        background(),
        layout: [
          '#......#',
          '.s....s.',
          '..1..2..',
          '...3....',
          ...List.filled(4, '........'),
        ],
      );
      final copy = LevelDef.fromJson(l.toJson());
      expect(copy.toJson(), l.toJson());
      expect(copy.stainCount, 2);
      expect(copy.glassCount, 3);
    });

    test('rejects malformed levels', () {
      expect(
        () => levelOf(background(), layout: ['...', '..']),
        throwsFormatException,
      );
      expect(() => levelOf(['RBX']), throwsFormatException);
      expect(
        () => LevelDef.fromJson({
          'id': 1,
          'moves': 10,
          'colors': ['red', 'blue', 'yellow'],
          'layout': ['...'],
          'goals': [
            {'type': 'collect', 'color': 'pink', 'target': 3},
          ],
          'stars': [1, 2, 3],
        }),
        throwsFormatException,
      );
    });
  });

  group('board', () {
    test('starts without matches and with a valid move', () {
      for (var seed = 0; seed < 30; seed++) {
        final b = Board.fromLevel(
          LevelDef(
            id: 1,
            name: 'r',
            moves: 10,
            colors: const [
              TileColor.red,
              TileColor.blue,
              TileColor.yellow,
              TileColor.brown,
              TileColor.gray,
            ],
            layout: List.filled(8, '........'),
            goals: const [Goal(GoalType.score, 10)],
            stars: const [1, 2, 3],
          ),
          Random(seed),
        );
        expect(b.checkInvariants(), isNull);
        expect(b.findHint(), isNotNull);
      }
    });

    test('a swap that makes no match is reversed and costs nothing', () {
      final b = boardOf(background());
      final before = b
          .snapshot()
          .tiles
          .values
          .map((t) => '${t.id}${t.pos}')
          .toSet();
      final o = b.swipe(const Pos(0, 3), const Pos(0, 4));
      expect(o.usedMove, isFalse);
      expect(o.kind, MoveKind.invalid);
      expect(o.steps.map((s) => s.kind), [StepKind.swap, StepKind.swapBack]);
      final after = b
          .snapshot()
          .tiles
          .values
          .map((t) => '${t.id}${t.pos}')
          .toSet();
      expect(after, before);
    });

    test('matching 3 clears them and refills the board', () {
      // Row 0 becomes R R _ R ; moving the R from (1,2) up completes it.
      final tiles = withTiles(background(), {
        const Pos(0, 0): 'R',
        const Pos(0, 1): 'R',
        const Pos(0, 2): 'B',
        const Pos(0, 3): 'R',
        const Pos(1, 2): 'R',
        const Pos(1, 3): 'Y',
        const Pos(1, 1): 'N',
      });
      final b = boardOf(tiles, blending: false);
      expect(b.checkInvariants(), isNull);
      final o = b.swipe(const Pos(1, 2), const Pos(0, 2));
      expect(o.usedMove, isTrue);
      expect(o.kind, MoveKind.swap);
      expect(o.steps.any((s) => s.kind == StepKind.clear), isTrue);
      expect(o.steps.any((s) => s.kind == StepKind.fall), isTrue);
      expect(b.collected[TileColor.red], greaterThanOrEqualTo(3));
      expect(b.checkInvariants(), isNull);
      expect(b.score, greaterThan(0));
    });

    test('match of 4 creates a line blaster at the moved tile', () {
      final tiles = withTiles(background(), {
        const Pos(3, 0): 'N',
        const Pos(3, 1): 'Y',
        const Pos(3, 2): 'R',
        const Pos(3, 3): 'Y',
        const Pos(3, 4): 'Y',
        const Pos(2, 2): 'Y',
        const Pos(4, 2): 'B',
      });
      final b = boardOf(tiles, blending: false);
      expect(b.checkInvariants(), isNull);
      final o = b.swipe(const Pos(2, 2), const Pos(3, 2));
      final made = o.steps.first.kind == StepKind.swap
          ? o.steps[1]
          : o.steps[0];
      final lines = made.after.tiles.values
          .where((t) => t.special.isLine)
          .toList();
      expect(lines, hasLength(1));
      expect(lines.first.pos, const Pos(3, 2));
      expect(lines.first.special, Special.lineH);
    });

    test('a 2x2 square matches and creates a line blaster', () {
      // Y Y      Y Y
      // Y R Y -> Y Y R  (swipe the right Y left)
      final tiles = withTiles(background(), {
        const Pos(3, 3): 'Y',
        const Pos(3, 4): 'Y',
        const Pos(4, 3): 'Y',
        const Pos(4, 4): 'R',
        const Pos(4, 5): 'Y',
        const Pos(4, 2): 'N',
        const Pos(5, 4): 'N',
      });
      final b = boardOf(tiles, blending: false);
      expect(b.findMatches(), isEmpty);
      expect(b.classify(const Pos(4, 5), const Pos(4, 4)), MoveKind.swap);
      final o = b.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(o.kind, MoveKind.swap);
      final made = o.steps[1];
      final lines = made.after.tiles.values
          .where((t) => t.special.isLine)
          .toList();
      expect(lines, hasLength(1));
      expect(lines.first.pos, const Pos(4, 4));
      expect(lines.first.special, Special.lineH);
      // All four tiles were cleared; the blaster replaced the moved one.
      expect(made.cleared.map((c) => c.at).toSet(), {
        const Pos(3, 3),
        const Pos(3, 4),
        const Pos(4, 3),
        const Pos(4, 4),
      });
      expect(b.checkInvariants(), isNull);
    });

    test('new boards never start with a 2x2 square', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = List.filled(8, '........');
        final b = Board.fromLevel(levelOf(random), Random(seed));
        expect(b.findMatches(), isEmpty, reason: 'seed $seed');
      }
    });

    test('match of 5 creates a prism, which clears a whole color', () {
      final tiles = withTiles(background(), {
        const Pos(5, 0): 'B',
        const Pos(5, 1): 'B',
        const Pos(5, 2): 'R',
        const Pos(5, 3): 'B',
        const Pos(5, 4): 'B',
        const Pos(4, 2): 'B',
        const Pos(4, 1): 'N',
        const Pos(6, 1): 'Y',
        const Pos(6, 2): 'N',
      });
      final b = boardOf(tiles, blending: false);
      expect(b.checkInvariants(), isNull);
      b.swipe(const Pos(4, 2), const Pos(5, 2));
      final prisms = [
        for (final p in b.allPositions)
          if (b.tileAt(p)?.special == Special.prism) p,
      ];
      expect(prisms, isNotEmpty);
      final prism = prisms.first;
      final neighbor = [
        for (final d in const [Pos(0, 1), Pos(0, -1), Pos(1, 0), Pos(-1, 0)])
          prism + d,
      ].firstWhere((q) => b.tileAt(q)?.special == Special.none);
      final color = b.tileAt(neighbor)!.color!;
      final before = b.collected[color] ?? 0;
      final o = b.swipe(prism, neighbor);
      expect(o.kind, MoveKind.special);
      expect(
        o.steps.expand((s) => s.effects).any((e) => e.kind == EffectKind.prism),
        isTrue,
      );
      expect(b.collected[color]! - before, greaterThanOrEqualTo(3));
      expect(b.checkInvariants(), isNull);
    });

    test('L shape creates a paint bomb', () {
      // Vertical R at (2..4, 0) and horizontal R at (4, 0..2): L shape.
      final tiles = withTiles(background(), {
        const Pos(2, 0): 'R',
        const Pos(3, 0): 'R',
        const Pos(4, 0): 'B',
        const Pos(5, 0): 'R',
        const Pos(4, 1): 'R',
        const Pos(4, 2): 'R',
        const Pos(3, 1): 'Y',
        const Pos(3, 2): 'Y',
        const Pos(5, 1): 'Y',
      });
      final b = boardOf(tiles, blending: false);
      expect(b.checkInvariants(), isNull);
      final o = b.swipe(const Pos(5, 0), const Pos(4, 0));
      expect(o.kind, MoveKind.swap);
      expect(
        b.tiles.whereType<Tile>().any((t) => t.special == Special.bomb),
        isTrue,
      );
    });

    test('blending red into blue makes purple and counts for collect', () {
      final tiles = withTiles(background(), {
        const Pos(7, 3): 'R',
        const Pos(7, 4): 'B',
      });
      final b = boardOf(tiles);
      expect(b.checkInvariants(), isNull);
      expect(b.classify(const Pos(7, 3), const Pos(7, 4)), MoveKind.blend);
      expect(
        b.blendPreview(const Pos(7, 3), const Pos(7, 4))!.$1,
        TileColor.purple,
      );
      final o = b.swipe(const Pos(7, 3), const Pos(7, 4));
      expect(o.usedMove, isTrue);
      expect(o.kind, MoveKind.blend);
      expect(o.steps.first.kind, StepKind.blend);
      expect(b.collected[TileColor.purple], greaterThanOrEqualTo(1));
      expect(b.checkInvariants(), isNull);
    });

    test('neutral tiles never blend', () {
      final b = boardOf(
        withTiles(background(), {const Pos(7, 3): 'R', const Pos(7, 4): 'N'}),
      );
      expect(b.classify(const Pos(7, 3), const Pos(7, 4)), MoveKind.invalid);
    });

    test('blending can be disabled per level', () {
      final b = boardOf(
        withTiles(background(), {const Pos(7, 3): 'R', const Pos(7, 4): 'B'}),
        blending: false,
      );
      expect(b.classify(const Pos(7, 3), const Pos(7, 4)), MoveKind.invalid);
    });

    test('secondary + missing primary blends into a white burst', () {
      final b = boardOf(
        withTiles(background(), {const Pos(7, 3): 'P', const Pos(7, 4): 'Y'}),
      );
      expect(
        b.classify(const Pos(7, 3), const Pos(7, 4)),
        MoveKind.whiteBurstBlend,
      );
      b.swipe(const Pos(7, 3), const Pos(7, 4));
      final wb = [
        for (final p in b.allPositions)
          if (b.tileAt(p)?.special == Special.whiteBurst) p,
      ];
      expect(wb, hasLength(1));
      // Tapping it fires a cross and keeps the board consistent.
      final o = b.tapSpecial(wb.first);
      expect(o.usedMove, isTrue);
      expect(
        o.steps
            .expand((s) => s.effects)
            .any((e) => e.kind == EffectKind.whiteBurst),
        isTrue,
      );
      expect(b.checkInvariants(), isNull);
    });

    test('two specials swapped together combine', () {
      final b = boardOf(background());
      b.tiles[0]!.special = Special.lineH;
      b.tiles[1]!.special = Special.lineV;
      final o = b.swipe(const Pos(0, 0), const Pos(0, 1));
      expect(o.kind, MoveKind.combo);
      expect(
        o.steps
            .expand((s) => s.effects)
            .any((e) => e.kind == EffectKind.rowCol),
        isTrue,
      );
      expect(b.checkInvariants(), isNull);
    });

    test('prism + prism clears the whole board', () {
      final b = boardOf(background());
      b.tiles[0]!.special = Special.prism;
      b.tiles[0]!.color = null;
      b.tiles[1]!.special = Special.prism;
      b.tiles[1]!.color = null;
      final o = b.swipe(const Pos(0, 0), const Pos(0, 1));
      final firstClear = o.steps.firstWhere((s) => s.kind == StepKind.clear);
      expect(firstClear.cleared.length, 64);
      expect(b.checkInvariants(), isNull);
    });

    test('matches next to glass break a layer; stains clear under matches', () {
      final layout = [
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '..1.....',
        'sss.....',
      ];
      final tiles = withTiles(background(), {
        const Pos(7, 0): 'R',
        const Pos(7, 1): 'R',
        const Pos(7, 2): 'B',
        const Pos(6, 2): 'R',
        const Pos(7, 3): 'Y',
        const Pos(6, 1): 'Y',
        const Pos(6, 3): 'B',
      });
      final b = boardOf(tiles, layout: layout, blending: false);
      expect(b.checkInvariants(), isNull);
      expect(b.glassAt(const Pos(6, 2)), 1);
      expect(b.tileAt(const Pos(6, 2)), isNull, reason: 'glass holds no tile');
    });

    test('glass is damaged by an adjacent match and stains get cleaned', () {
      final layout = [
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '1.......',
        'sss.....',
      ];
      final tiles = withTiles(background(), {
        const Pos(7, 0): 'R',
        const Pos(7, 1): 'R',
        const Pos(7, 2): 'B',
        const Pos(6, 2): 'R',
        const Pos(6, 1): 'Y',
        const Pos(6, 3): 'N',
        const Pos(7, 3): 'Y',
      });
      final b = boardOf(tiles, layout: layout, blending: false);
      expect(b.checkInvariants(), isNull);
      final o = b.swipe(const Pos(6, 2), const Pos(7, 2));
      expect(o.kind, MoveKind.swap);
      expect(b.glassAt(const Pos(6, 0)), 0);
      expect(b.stainAt(const Pos(7, 0)), isFalse);
      expect(b.stainAt(const Pos(7, 1)), isFalse);
      expect(b.stainAt(const Pos(7, 2)), isFalse);
      expect(b.checkInvariants(), isNull);
    });

    test('upward gravity spawns new tiles from the bottom', () {
      final tiles = withTiles(background(), {
        const Pos(7, 0): 'R',
        const Pos(7, 1): 'R',
        const Pos(7, 2): 'B',
        const Pos(6, 2): 'R',
        const Pos(6, 1): 'Y',
        const Pos(6, 3): 'N',
        const Pos(7, 3): 'Y',
      });
      final b = boardOf(tiles, gravity: Gravity.up, blending: false);
      final o = b.swipe(const Pos(6, 2), const Pos(7, 2));
      final fall = o.steps.firstWhere((s) => s.kind == StepKind.fall);
      expect(fall.spawnFrom, isNotEmpty);
      for (final origin in fall.spawnFrom.values) {
        expect(origin.r, greaterThan(7));
      }
      expect(b.checkInvariants(), isNull);
    });

    test('sideways gravity spawns from the opposite edge', () {
      for (final g in [Gravity.left, Gravity.right]) {
        final tiles = withTiles(background(), {
          const Pos(0, 3): 'R',
          const Pos(1, 3): 'R',
          const Pos(2, 3): 'B',
          const Pos(2, 4): 'R',
          const Pos(2, 2): 'Y',
          const Pos(3, 3): 'Y',
          const Pos(1, 4): 'N',
          const Pos(3, 4): 'N',
        });
        final b = boardOf(tiles, gravity: g, blending: false);
        expect(b.checkInvariants(), isNull);
        final o = b.swipe(const Pos(2, 4), const Pos(2, 3));
        expect(o.kind, MoveKind.swap);
        final fall = o.steps.firstWhere((s) => s.kind == StepKind.fall);
        for (final origin in fall.spawnFrom.values) {
          if (g == Gravity.left) {
            expect(origin.c, greaterThan(7));
          } else {
            expect(origin.c, lessThan(0));
          }
        }
        expect(b.checkInvariants(), isNull);
      }
    });

    test('clearing a gravity switch tile rotates gravity', () {
      final tiles = withTiles(background(), {
        const Pos(7, 0): 'R',
        const Pos(7, 1): 'R',
        const Pos(7, 2): 'B',
        const Pos(6, 2): 'R',
        const Pos(6, 1): 'Y',
        const Pos(6, 3): 'N',
        const Pos(7, 3): 'Y',
      });
      final b = boardOf(tiles, blending: false);
      b.tileAt(const Pos(7, 0))!.gravitySwitch = true;
      final o = b.swipe(const Pos(6, 2), const Pos(7, 2));
      expect(o.steps.any((s) => s.kind == StepKind.gravity), isTrue);
      expect(b.gravity, isNot(Gravity.down));
      expect(b.checkInvariants(), isNull);
    });

    test('holes are never filled', () {
      final layout = ['##....##', ...List.filled(7, '........')];
      final b = boardOf(background(), layout: layout);
      expect(b.tileAt(const Pos(0, 0)), isNull);
      expect(b.checkInvariants(), isNull);
      // Brush a tile under a hole column and check the hole stays empty.
      b.brush(const Pos(3, 0));
      expect(b.tileAt(const Pos(0, 0)), isNull);
      expect(b.tileAt(const Pos(0, 1)), isNull);
      expect(b.checkInvariants(), isNull);
    });

    test('boosters do not use moves', () {
      final level = levelOf(background());
      final s = GameSession(level, seed: 3);
      final moves = s.movesLeft;
      expect(s.brush(const Pos(4, 4)).steps, isNotEmpty);
      expect(s.freeSwap(const Pos(0, 0), const Pos(7, 7)).steps, isNotEmpty);
      expect(s.colorSplash(const Pos(2, 2)).steps, isNotEmpty);
      expect(s.movesLeft, moves);
      expect(s.board.checkInvariants(), isNull);
    });

    test('dead boards are shuffled', () {
      // The background has no possible move when blending is off.
      final level = levelOf(background(), blending: false);
      final b = Board.fromLevel(level, Random(2));
      expect(b.findHint(), isNotNull);
      expect(b.checkInvariants(), isNull);
      // Keep playing hints; the board must never get stuck.
      for (var i = 0; i < 40; i++) {
        final h = b.findHint();
        expect(h, isNotNull);
        h!.a == h.b ? b.tapSpecial(h.a) : b.swipe(h.a, h.b);
        expect(b.checkInvariants(), isNull);
      }
    });
  });

  group('session', () {
    test('wins when goals are met and the finale spends leftover moves', () {
      final level = levelOf(
        background(),
        goals: const [Goal(GoalType.score, 50)],
      );
      final s = GameSession(level, seed: 5);
      final h = s.board.findHint()!;
      s.swipe(h.a, h.b);
      expect(s.status, SessionStatus.won);
      final steps = s.finale();
      expect(steps, isNotEmpty);
      expect(s.movesLeft, 0);
      expect(s.starsFor(s.score), greaterThanOrEqualTo(1));
      expect(s.board.checkInvariants(), isNull);
    });

    test('runs out of moves and can buy more', () {
      final level = levelOf(background());
      final s = GameSession(level, seed: 9);
      s.movesLeft = 1;
      final h = s.board.findHint()!;
      s.swipe(h.a, h.b);
      expect(s.status, SessionStatus.outOfMoves);
      expect(s.swipe(h.a, h.b).steps, isEmpty);
      s.addMoves(5);
      expect(s.status, SessionStatus.playing);
      expect(s.movesLeft, 5);
    });
  });
}
