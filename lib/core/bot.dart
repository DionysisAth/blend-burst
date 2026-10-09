import 'dart:math';

import 'board.dart';
import 'level.dart';
import 'session.dart';

class BotReport {
  final int levelId;
  final int plays;
  final int wins;
  final double avgScore;
  final double avgMovesLeftOnWin;
  final double avgStars;

  const BotReport(
    this.levelId,
    this.plays,
    this.wins,
    this.avgScore,
    this.avgMovesLeftOnWin,
    this.avgStars,
  );

  double get winRate => plays == 0 ? 0 : wins / plays;

  @override
  String toString() =>
      'Level $levelId: win ${(winRate * 100).toStringAsFixed(0)}% '
      '($wins/$plays), avg score ${avgScore.toStringAsFixed(0)}, '
      'moves left on win ${avgMovesLeftOnWin.toStringAsFixed(1)}, '
      'stars ${avgStars.toStringAsFixed(2)}';
}

/// A simple greedy player used to estimate level difficulty.
///
/// It tries every legal move on a copy of the board and keeps the one that
/// advances the goals most. [skill] in 0..1 controls how often it picks the
/// best move instead of a random good one, to imitate casual players.
class LevelBot {
  final double skill;
  final Random rng;

  LevelBot({this.skill = 0.7, int seed = 1}) : rng = Random(seed);

  double _value(GameSession s) {
    var v = 0.0;
    for (final p in s.progress()) {
      final ratio = p.target == 0 ? 1.0 : min(1.0, p.current / p.target);
      v += ratio * 1000;
    }
    return v + s.score * 0.01;
  }

  MoveOutcome _apply(GameSession s, Hint m) {
    if (m.a == m.b) return s.tapSpecial(m.a);
    return s.swipe(m.a, m.b);
  }

  /// Plays one full attempt. Returns the finished session.
  GameSession play(
    LevelDef level, {
    int? seed,
    void Function(String)? onError,
  }) {
    final s = GameSession(level, seed: seed ?? rng.nextInt(1 << 30));
    var guard = 0;
    while (s.status == SessionStatus.playing && guard++ < 500) {
      final moves = s.board.allMoves();
      if (moves.isEmpty) break;
      final scored = <(Hint, double)>[];
      final base = _value(s);
      for (final m in moves) {
        final trial = s.clone(Random(rng.nextInt(1 << 30)));
        _apply(trial, m);
        var v = _value(trial) - base;
        if (trial.status == SessionStatus.won) v += 100000;
        scored.add((m, v));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final pick = rng.nextDouble() < skill
          ? scored.first.$1
          : scored[rng.nextInt(min(4, scored.length))].$1;
      final out = _apply(s, pick);
      if (out.steps.isEmpty && onError != null) {
        onError('move ${pick.a}->${pick.b} produced no steps');
      }
      final problem = s.board.checkInvariants();
      if (problem != null && onError != null) onError(problem);
    }
    if (s.status == SessionStatus.won) s.finale();
    return s;
  }

  BotReport evaluate(LevelDef level, {int plays = 20}) {
    var wins = 0, scoreSum = 0, movesSum = 0, starSum = 0;
    for (var i = 0; i < plays; i++) {
      final s = play(level, seed: rng.nextInt(1 << 30));
      if (s.status == SessionStatus.won) {
        wins++;
        movesSum += level.moves - s.movesUsed;
        starSum += s.starsFor(s.score);
      }
      scoreSum += s.score;
    }
    return BotReport(
      level.id,
      plays,
      wins,
      scoreSum / plays,
      wins == 0 ? 0 : movesSum / wins,
      starSum / plays,
    );
  }
}
