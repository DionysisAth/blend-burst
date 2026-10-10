import 'dart:math';

import 'package:blend_burst/core/board.dart';
import 'package:blend_burst/core/level.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A match-free 8x8 background (rows cycle R B Y N shifted by 2).
List<String> background() => [
  for (var r = 0; r < 8; r++)
    [for (var c = 0; c < 8; c++) 'RBYN'[(c + 2 * r) % 4]].join(),
];

List<String> edit(List<String> base, Map<Pos, String> cells) {
  final grid = [for (final row in base) row.split('')];
  cells.forEach((p, ch) => grid[p.r][p.c] = ch);
  return [for (final row in grid) row.join()];
}

final _empty = List.filled(8, '........');

LevelDef level({
  List<String>? tiles,
  List<String>? layout,
  List<String>? filters,
  List<String>? zones,
  Gravity gravity = Gravity.down,
  List<Goal> goals = const [Goal(GoalType.score, 100000)],
  int buckets = 0,
  int gravityEvery = 0,
  List<TileColor> colors = const [
    TileColor.red,
    TileColor.blue,
    TileColor.yellow,
    TileColor.brown,
  ],
}) => LevelDef(
  id: 1,
  name: 'test',
  moves: 30,
  colors: colors,
  layout: layout ?? _empty,
  tiles: tiles,
  filters: filters,
  zones: zones,
  gravity: gravity,
  blending: false,
  goals: goals,
  stars: const [1, 2, 3],
  buckets: buckets,
  gravityEvery: gravityEvery,
);

/// Tiles for a swipe of (4,5) -> (4,4) that matches Y at row 4, cols 2..4
/// (the moved Y lands on (4,4)).
List<String> matchRow4() => edit(background(), {
  const Pos(4, 2): 'Y',
  const Pos(4, 3): 'Y',
  const Pos(4, 4): 'R',
  const Pos(4, 5): 'Y',
  const Pos(4, 1): 'N',
  const Pos(4, 6): 'B',
  const Pos(3, 4): 'B',
  const Pos(5, 4): 'B',
  const Pos(3, 5): 'N',
  const Pos(5, 5): 'N',
});

void main() {
  test('level format round-trips the new fields', () {
    final l = level(
      tiles: edit(background(), {const Pos(0, 0): 'D'}),
      layout: edit(_empty, {
        const Pos(1, 1): 'k',
        const Pos(1, 2): 'K',
        const Pos(2, 2): 'i',
      }),
      filters: edit(_empty, {const Pos(3, 3): 'P'}),
      zones: edit(_empty, {const Pos(5, 5): '>'}),
      goals: const [Goal(GoalType.drop, 0), Goal(GoalType.locks, 0)],
      buckets: 3,
      gravityEvery: 4,
    );
    final copy = LevelDef.fromJson(l.toJson());
    expect(copy.toJson(), l.toJson());
    expect(copy.lockCount, 2);
    expect(copy.inkCount, 1);
    expect(copy.hasZones, isTrue);
    expect(copy.usesGravity, isTrue);
    expect(
      () => level(goals: const [Goal(GoalType.drop, 0)]),
      throwsFormatException,
    );
    expect(
      () => level(filters: edit(_empty, {const Pos(0, 0): 'x'})),
      throwsFormatException,
    );
  });

  group('locked tiles', () {
    test('cannot be swapped, do not fall, and lose a chain when matched', () {
      final b = Board.fromLevel(
        level(
          tiles: matchRow4(),
          layout: edit(_empty, {const Pos(4, 2): 'K', const Pos(2, 2): 'k'}),
        ),
        Random(1),
      );
      expect(b.lockAt(const Pos(4, 2)), 2);
      expect(b.classify(const Pos(4, 2), const Pos(4, 1)), MoveKind.none);
      expect(b.classify(const Pos(2, 2), const Pos(2, 3)), MoveKind.none);
      final locked = b.tileAt(const Pos(4, 2))!;
      final above = b.tileAt(const Pos(2, 2))!;
      final o = b.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(o.kind, MoveKind.swap);
      // The matched locked tile stays and loses one of its two chains.
      expect(b.lockAt(const Pos(4, 2)), 1);
      expect(identical(b.tileAt(const Pos(4, 2)), locked), isTrue);
      expect(o.steps.any((s) => s.lockHit.contains(const Pos(4, 2))), isTrue);
      // The locked tile higher up did not fall into the gap.
      expect(identical(b.tileAt(const Pos(2, 2)), above), isTrue);
      expect(b.checkInvariants(), isNull);
    });

    test('count towards a locks goal', () {
      final s = GameSession(
        level(
          tiles: matchRow4(),
          layout: edit(_empty, {const Pos(4, 3): 'k'}),
          goals: const [Goal(GoalType.locks, 0)],
        ),
        seed: 3,
      );
      expect(s.progress().single.target, 1);
      s.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(s.progress().single.done, isTrue);
      expect(s.status, SessionStatus.won);
    });
  });

  group('ink', () {
    test('is cleared by an adjacent match and then does not spread', () {
      final b = Board.fromLevel(
        level(tiles: matchRow4(), layout: edit(_empty, {const Pos(5, 3): 'i'})),
        Random(1),
      );
      expect(b.inkLeft, 1);
      expect(b.tileAt(const Pos(5, 3)), isNull);
      final o = b.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(o.steps.any((s) => s.inkHit.contains(const Pos(5, 3))), isTrue);
      expect(b.inkLeft, 0);
      expect(b.inkClearedTotal, 1);
      expect(b.checkInvariants(), isNull);
    });

    test('spreads into a neighbor after a move that clears none', () {
      final b = Board.fromLevel(
        level(tiles: matchRow4(), layout: edit(_empty, {const Pos(0, 7): 'i'})),
        Random(1),
      );
      final o = b.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(b.inkLeft, 2);
      expect(
        o.steps
            .expand((s) => s.effects)
            .any((e) => e.kind == EffectKind.inkSpread),
        isTrue,
      );
      expect(b.checkInvariants(), isNull);
    });

    test('never spreads onto the spawn edge', () {
      final b = Board.fromLevel(
        level(
          tiles: matchRow4(),
          layout: edit(_empty, {const Pos(0, 0): 'i', const Pos(1, 0): '#'}),
        ),
        Random(1),
      );
      final o = b.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(
        o.steps
            .expand((s) => s.effects)
            .any((e) => e.kind == EffectKind.inkSpread),
        isFalse,
      );
      expect(b.checkInvariants(), isNull);
    });

    test('stops spreading at its limit', () {
      final b = Board.fromLevel(
        level(tiles: matchRow4(), layout: edit(_empty, {const Pos(3, 7): 'i'})),
        Random(1),
      );
      expect(b.inkLimit, 7);
      b.inkLimit = 1;
      final o = b.swipe(const Pos(4, 5), const Pos(4, 4));
      expect(
        o.steps
            .expand((s) => s.effects)
            .any((e) => e.kind == EffectKind.inkSpread),
        isFalse,
      );
    });

    test('the ink goal tracks cleared against remaining ink', () {
      final s = GameSession(
        level(
          tiles: matchRow4(),
          layout: edit(_empty, {const Pos(5, 3): 'i', const Pos(0, 7): 'i'}),
          goals: const [Goal(GoalType.ink, 0)],
        ),
        seed: 1,
      );
      expect(s.progress().single.target, 2);
      s.swipe(const Pos(4, 5), const Pos(4, 4));
      final p = s.progress().single;
      expect(p.current, 1);
      expect(p.target - p.current, s.board.inkLeft);
    });
  });

  test('a color filter recolors tiles that fall into it', () {
    // Filter at (3,3): the column above the cleared Y at (4,3) falls one
    // cell, so the tile from (2,3) lands on the filter.
    final b = Board.fromLevel(
      level(
        tiles: matchRow4(),
        filters: edit(_empty, {const Pos(3, 3): 'P'}),
        colors: const [
          TileColor.red,
          TileColor.blue,
          TileColor.yellow,
          TileColor.brown,
          TileColor.purple,
        ],
      ),
      Random(1),
    );
    final above = b.tileAt(const Pos(2, 3))!;
    expect(above.color, isNot(TileColor.purple));
    b.swipe(const Pos(4, 5), const Pos(4, 4));
    expect(above.color, TileColor.purple);
    expect(b.checkInvariants(), isNull);
  });

  group('paint buckets', () {
    test('fall and are collected at the exit, which follows gravity', () {
      for (final g in [Gravity.down, Gravity.up]) {
        // Bucket right above (down) / below (up) the matched cell (4,3).
        final at = g == Gravity.down ? const Pos(3, 3) : const Pos(5, 3);
        final s = GameSession(
          level(
            tiles: edit(matchRow4(), {at: 'D'}),
            // Column 3 is open only at the bucket and the matched cell.
            layout: edit(_empty, {
              for (var r = 0; r < 8; r++)
                if (r != 4 && r != at.r) Pos(r, 3): '#',
            }),
            gravity: g,
            goals: const [Goal(GoalType.drop, 1)],
            buckets: 1,
          ),
          seed: 2,
        );
        expect(s.board.bucketsOnBoard, 1);
        s.swipe(const Pos(4, 5), const Pos(4, 4));
        // The bucket fell into the gap and, with nothing playable beyond,
        // left through the exit.
        expect(s.board.dropped, 1, reason: '$g');
        expect(s.status, SessionStatus.won, reason: '$g');
        expect(s.board.checkInvariants(), isNull);
      }
    });

    test('a chained bucket is freed by a blast, then falls', () {
      final b = Board.fromLevel(
        level(
          tiles: edit(background(), {const Pos(0, 2): 'D'}),
          layout: edit(_empty, {const Pos(0, 2): 'k'}),
          buckets: 1,
        ),
        Random(1),
      );
      expect(b.lockAt(const Pos(0, 2)), 1);
      // A line blaster through row 0 hits the chained bucket.
      b.tileAt(const Pos(0, 5))!.special = Special.lineH;
      b.tapSpecial(const Pos(0, 5));
      expect(b.lockAt(const Pos(0, 2)), 0);
      expect(b.bucketsOnBoard + b.dropped, 1);
      expect(b.checkInvariants(), isNull);
    });

    test('are never matched, recolored or brushed away', () {
      final b = Board.fromLevel(
        level(tiles: edit(background(), {const Pos(0, 0): 'D'}), buckets: 1),
        Random(1),
      );
      expect(b.brush(const Pos(0, 0)).steps, isEmpty);
      b.colorSplash(const Pos(0, 3));
      expect(b.tileAt(const Pos(0, 0))!.bucket, isTrue);
      expect(b.tileAt(const Pos(0, 0))!.color, isNull);
      expect(b.checkInvariants(), isNull);
    });
  });

  test('gravity zones move tiles their own way and keep the board full', () {
    final zones = [for (var r = 0; r < 8; r++) r < 4 ? '>>>>>>>>' : '........'];
    final s = GameSession(level(zones: zones), seed: 5);
    final rng = Random(5);
    for (var i = 0; i < 25 && s.status == SessionStatus.playing; i++) {
      final moves = s.board.allMoves();
      if (moves.isEmpty) break;
      final m = moves[rng.nextInt(moves.length)];
      if (m.a == m.b) {
        s.tapSpecial(m.a);
      } else {
        s.swipe(m.a, m.b);
      }
      expect(s.board.checkInvariants(), isNull, reason: 'move $i');
    }
  });

  test('timed gravity rotates every N moves', () {
    final s = GameSession(level(gravityEvery: 2), seed: 4);
    expect(s.board.shiftIn, 2);
    final rng = Random(4);
    void play() {
      final m = s.board.findHint()!;
      s.swipe(m.a, m.b);
    }

    play();
    expect(s.board.gravity, Gravity.down);
    expect(s.board.shiftIn, 1);
    rng.nextInt(2);
    play();
    expect(s.board.gravity, Gravity.left);
    expect(s.board.shiftIn, 2);
    expect(s.board.checkInvariants(), isNull);
  });

  test('gravity flip lasts one move, then gravity goes back', () {
    final s = GameSession(level(), seed: 6);
    final o = s.flipGravity(Gravity.up);
    expect(o.usedMove, isFalse);
    expect(s.board.gravity, Gravity.up);
    expect(s.movesLeft, 30);
    final m = s.board.findHint()!;
    s.swipe(m.a, m.b);
    expect(s.board.gravity, Gravity.down);
    expect(s.board.checkInvariants(), isNull);
  });

  test('pre-level boosters place a special on a plain tile', () {
    final b = Board.fromLevel(level(), Random(7));
    for (final sp in [Special.lineH, Special.bomb, Special.prism]) {
      final p = b.placeSpecial(sp)!;
      expect(b.tileAt(p)!.special, sp);
    }
    expect(b.checkInvariants(), isNull);
  });

  test('random play on a board with every obstacle never breaks it', () {
    final l = level(
      tiles: edit(_empty, {const Pos(0, 2): 'D', const Pos(0, 5): 'D'}),
      layout: [
        '..k..K..',
        '.i....i.',
        '..1..s..',
        '#..kk..#',
        '........',
        '.s.ii.2.',
        '..K..k..',
        '........',
      ],
      filters: edit(_empty, {const Pos(4, 1): 'R', const Pos(4, 6): 'B'}),
      zones: edit(_empty, {const Pos(7, 0): '>', const Pos(7, 7): '<'}),
      goals: const [
        Goal(GoalType.drop, 0),
        Goal(GoalType.locks, 0),
        Goal(GoalType.ink, 0),
      ],
      buckets: 4,
      gravityEvery: 5,
    );
    for (var seed = 0; seed < 12; seed++) {
      final s = GameSession(l, seed: seed);
      expect(s.board.checkInvariants(), isNull, reason: 'seed $seed start');
      final rng = Random(seed);
      for (var i = 0; i < 30 && s.status == SessionStatus.playing; i++) {
        final moves = s.board.allMoves();
        if (moves.isEmpty) break;
        final m = moves[rng.nextInt(moves.length)];
        if (i % 7 == 3) {
          s.flipGravity(Gravity.values[rng.nextInt(4)]);
        }
        if (m.a == m.b) {
          s.tapSpecial(m.a);
        } else {
          s.swipe(m.a, m.b);
        }
        expect(s.board.checkInvariants(), isNull, reason: 'seed $seed move $i');
      }
    }
  });
}
