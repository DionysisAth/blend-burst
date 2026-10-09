import 'dart:math';

import 'board.dart';
import 'level.dart';
import 'models.dart';

enum SessionStatus { playing, won, outOfMoves }

class GoalProgress {
  final Goal goal;
  final int current;
  final int target;
  const GoalProgress(this.goal, this.current, this.target);
  bool get done => current >= target;
}

/// One attempt at a level: the board plus move count, goals and stars.
class GameSession {
  final LevelDef level;
  final Board board;
  int movesLeft;
  int movesUsed = 0;
  int extraMovesBought = 0;
  SessionStatus status = SessionStatus.playing;

  final int _initialStains;
  final int _initialGlass;

  GameSession._(this.level, this.board)
    : movesLeft = level.moves,
      _initialStains = board.stainsLeft,
      _initialGlass = board.glassLeft;

  factory GameSession(LevelDef level, {int? seed}) {
    final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    return GameSession._(level, Board.fromLevel(level, rng));
  }

  GameSession._clone(GameSession s, Random rng)
    : level = s.level,
      board = s.board.clone(rng: rng),
      movesLeft = s.movesLeft,
      movesUsed = s.movesUsed,
      extraMovesBought = s.extraMovesBought,
      status = s.status,
      _initialStains = s._initialStains,
      _initialGlass = s._initialGlass;

  GameSession clone(Random rng) => GameSession._clone(this, rng);

  List<GoalProgress> progress([BoardSnapshot? snap]) {
    final score = snap?.score ?? board.score;
    final collected = snap?.collected ?? board.collected;
    final stainsLeft = snap?.stainsLeft ?? board.stainsLeft;
    final glassLeft = snap?.glassLeft ?? board.glassLeft;
    return [
      for (final g in level.goals)
        switch (g.type) {
          GoalType.score => GoalProgress(g, score, g.target),
          GoalType.stains => GoalProgress(
            g,
            _initialStains - stainsLeft,
            g.target > 0 ? min(g.target, _initialStains) : _initialStains,
          ),
          GoalType.glass => GoalProgress(
            g,
            _initialGlass - glassLeft,
            g.target > 0 ? min(g.target, _initialGlass) : _initialGlass,
          ),
          GoalType.collect => GoalProgress(
            g,
            collected[g.color] ?? 0,
            g.target,
          ),
        },
    ];
  }

  bool get goalsComplete => progress().every((p) => p.done);

  int get score => board.score;

  int starsFor(int score) {
    if (status != SessionStatus.won) return 0;
    if (score >= level.stars[2]) return 3;
    if (score >= level.stars[1]) return 2;
    return 1;
  }

  void _afterMove(MoveOutcome o) {
    if (o.usedMove) {
      movesLeft--;
      movesUsed++;
    }
    _updateStatus();
  }

  void _updateStatus() {
    if (goalsComplete) {
      status = SessionStatus.won;
    } else if (movesLeft <= 0) {
      status = SessionStatus.outOfMoves;
    } else {
      status = SessionStatus.playing;
    }
  }

  MoveOutcome swipe(Pos a, Pos b) {
    if (status != SessionStatus.playing) return MoveOutcome.none;
    final o = board.swipe(a, b);
    _afterMove(o);
    return o;
  }

  MoveOutcome tapSpecial(Pos p) {
    if (status != SessionStatus.playing) return MoveOutcome.none;
    final o = board.tapSpecial(p);
    _afterMove(o);
    return o;
  }

  MoveOutcome brush(Pos p) {
    if (status != SessionStatus.playing) return MoveOutcome.none;
    final o = board.brush(p);
    _afterMove(o);
    return o;
  }

  MoveOutcome freeSwap(Pos a, Pos b) {
    if (status != SessionStatus.playing) return MoveOutcome.none;
    final o = board.freeSwap(a, b);
    _afterMove(o);
    return o;
  }

  MoveOutcome colorSplash(Pos p) {
    if (status != SessionStatus.playing) return MoveOutcome.none;
    final o = board.colorSplash(p);
    _afterMove(o);
    return o;
  }

  void addMoves(int n) {
    movesLeft += n;
    extraMovesBought++;
    _updateStatus();
  }

  /// Runs the finale once the level is won. Returns its animation steps.
  List<Step> finale() {
    if (status != SessionStatus.won || movesLeft <= 0) return const [];
    final steps = board.sugarRush(movesLeft);
    movesLeft = 0;
    return steps;
  }
}
