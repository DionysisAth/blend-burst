import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:blend_burst/core/bot.dart';
import 'package:blend_burst/core/level.dart';
import 'package:blend_burst/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

List<LevelDef> bundledLevels() => [
  for (final f in [
    'assets/levels/episode1.json',
    'assets/levels/episode2.json',
    'assets/levels/episode3.json',
  ])
    ...parseLevelPack(
      jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>,
    ),
];

void main() {
  final levels = bundledLevels();

  test('there are 40 levels numbered 1..40 in 15-level episodes', () {
    expect(levels.map((l) => l.id), [for (var i = 1; i <= 40; i++) i]);
    expect(levels.where((l) => l.episode == 0), hasLength(15));
    expect(levels.where((l) => l.episode == 1), hasLength(15));
  });

  test('every level is well formed', () {
    for (final l in levels) {
      expect(
        l.stars[0] < l.stars[1] && l.stars[1] < l.stars[2],
        isTrue,
        reason: 'level ${l.id} star thresholds must increase',
      );
      if (l.goals.any((g) => g.type == GoalType.stains)) {
        expect(l.stainCount, greaterThan(0), reason: 'level ${l.id}');
      }
      if (l.goals.any((g) => g.type == GoalType.glass)) {
        expect(l.glassCount, greaterThan(0), reason: 'level ${l.id}');
      }
      expect(LevelDef.fromJson(l.toJson()).toJson(), l.toJson());
    }
  });

  test('the bot can play every level without breaking the board', () {
    for (final l in levels) {
      final bot = LevelBot(skill: 0.6, seed: l.id);
      var wins = 0;
      for (var p = 0; p < 3; p++) {
        final s = bot.play(
          l,
          seed: l.id * 31 + p,
          onError: (e) {
            fail('level ${l.id}: $e');
          },
        );
        expect(s.board.checkInvariants(), isNull, reason: 'level ${l.id}');
        if (s.status == SessionStatus.won) wins++;
      }
      // Levels must be beatable: at least one of three bot runs wins.
      expect(wins, greaterThan(0), reason: 'level ${l.id} looks unwinnable');
    }
  });

  test('random moves never break the board', () {
    final rng = Random(42);
    for (final l in levels) {
      final s = GameSession(l, seed: rng.nextInt(1 << 30));
      for (var i = 0; i < 25 && s.status == SessionStatus.playing; i++) {
        final moves = s.board.allMoves();
        expect(moves, isNotEmpty, reason: 'level ${l.id} has a dead board');
        final m = moves[rng.nextInt(moves.length)];
        switch (rng.nextInt(10)) {
          case 0:
            s.brush(m.a);
          case 1:
            s.colorSplash(m.a);
          case 2:
            s.freeSwap(m.a, moves[rng.nextInt(moves.length)].b);
          default:
            m.a == m.b ? s.tapSpecial(m.a) : s.swipe(m.a, m.b);
        }
        expect(s.board.checkInvariants(), isNull, reason: 'level ${l.id}');
      }
      if (s.status == SessionStatus.won) {
        s.finale();
        expect(s.board.checkInvariants(), isNull);
      }
    }
  });
}
