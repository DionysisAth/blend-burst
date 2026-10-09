import 'dart:collection';
import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/level.dart';
import '../core/models.dart';
import '../core/session.dart';

/// Bridges the pure game session and the animated view.
///
/// Moves are applied to the session immediately; the resulting steps are
/// queued and played back one by one. [shown] is the last snapshot that has
/// finished animating, so the HUD always matches what the player sees.
class GameController extends ChangeNotifier {
  final GameSession session;
  BoardSnapshot shown;
  final Queue<Step> _queue = Queue();
  Step? current;
  double _t = 0;
  double _duration = 1;

  /// Called when a step starts playing (particles, haptics).
  void Function(Step step, BoardSnapshot before)? onStepStart;

  /// Called when the queue runs dry.
  VoidCallback? onIdle;

  double speed = 1;

  GameController(this.session) : shown = session.board.snapshot();

  LevelDef get level => session.level;
  Board get board => session.board;

  bool get animating => current != null || _queue.isNotEmpty;

  /// 0..1 progress of the current step.
  double get progress => current == null ? 1 : (_t / _duration).clamp(0, 1);

  void play(List<Step> steps) {
    if (steps.isEmpty) return;
    _queue.addAll(steps);
    if (current == null) _startNext();
    notifyListeners();
  }

  void _startNext() {
    if (_queue.isEmpty) {
      current = null;
      return;
    }
    final step = _queue.removeFirst();
    current = step;
    _t = 0;
    _duration = durationOf(step, shown) / speed;
    onStepStart?.call(step, shown);
  }

  /// Advances the animation by [dt] seconds.
  void advance(double dt) {
    if (current == null) return;
    _t += dt;
    var finishedAny = false;
    while (current != null && _t >= _duration) {
      _t -= _duration;
      shown = current!.after;
      finishedAny = true;
      _startNext();
    }
    if (current == null) {
      _t = 0;
      notifyListeners();
      onIdle?.call();
      return;
    }
    if (finishedAny) notifyListeners();
  }

  /// Skips all pending animation (used by tests and when leaving a level).
  void finishAll() {
    while (current != null) {
      shown = current!.after;
      _startNext();
    }
    _t = 0;
    notifyListeners();
  }

  List<GoalProgress> get goals => session.progress(shown);
  int get score => shown.score;

  static double durationOf(Step step, BoardSnapshot before) {
    switch (step.kind) {
      case StepKind.swap:
      case StepKind.swapBack:
        return 0.16;
      case StepKind.blend:
        return 0.34;
      case StepKind.clear:
        return step.effects.isEmpty ? 0.22 : 0.3;
      case StepKind.transform:
        return 0.32;
      case StepKind.gravity:
        return 0.45;
      case StepKind.shuffle:
        return 0.5;
      case StepKind.fall:
        var maxDist = 1.0;
        step.after.tiles.forEach((id, t) {
          final from = before.tiles[id]?.pos;
          final double dist;
          if (from != null) {
            dist = ((from.r - t.pos.r).abs() + (from.c - t.pos.c).abs())
                .toDouble();
          } else {
            final s = step.spawnFrom[id];
            dist = s == null
                ? 0
                : (s.r - t.pos.r).abs() + (s.c - t.pos.c).abs();
          }
          maxDist = max(maxDist, dist);
        });
        return min(0.5, 0.1 + 0.045 * maxDist);
    }
  }

  /// Where a tile should be drawn right now, in fractional cell units, plus
  /// its scale and opacity. Returns null when the tile is not visible.
  static TileFrame? frameFor(
    int id,
    BoardSnapshot before,
    Step? step,
    double p,
  ) {
    final prev = before.tiles[id];
    if (step == null) {
      if (prev == null) return null;
      return TileFrame(prev, prev.pos.r.toDouble(), prev.pos.c.toDouble());
    }
    final next = step.after.tiles[id];
    double lerp(double a, double b, double t) => a + (b - a) * t;

    if (prev != null && next != null) {
      final t = switch (step.kind) {
        StepKind.fall => p * p,
        StepKind.shuffle => Curves.easeInOutCubic.transform(p),
        _ => Curves.easeInOut.transform(p),
      };
      final changed =
          prev.color != next.color ||
          prev.special != next.special ||
          prev.gravitySwitch != next.gravitySwitch;
      final look = changed && p >= 0.5 ? next : prev;
      final bump = changed ? 1 + 0.25 * sin(p * pi) : 1.0;
      return TileFrame(
        look,
        lerp(prev.pos.r.toDouble(), next.pos.r.toDouble(), t),
        lerp(prev.pos.c.toDouble(), next.pos.c.toDouble(), t),
        scale: bump,
      );
    }
    if (next != null) {
      final spawn = step.spawnFrom[id];
      if (spawn != null) {
        final t = p * p;
        return TileFrame(
          next,
          lerp(spawn.r, next.pos.r.toDouble(), t),
          lerp(spawn.c, next.pos.c.toDouble(), t),
          entry: step.spawnEntry[id],
        );
      }
      // A freshly created tile (special from a match, blend result).
      final delay = step.kind == StepKind.blend ? 0.55 : 0.35;
      if (p < delay) return null;
      final q = (p - delay) / (1 - delay);
      return TileFrame(
        next,
        next.pos.r.toDouble(),
        next.pos.c.toDouble(),
        scale: Curves.elasticOut.transform(q.clamp(0, 1)) * 1.0,
      );
    }
    if (prev != null) {
      if (step.kind == StepKind.blend && step.to != null) {
        final t = Curves.easeIn.transform((p / 0.6).clamp(0, 1));
        if (t >= 1) return null;
        return TileFrame(
          prev,
          lerp(prev.pos.r.toDouble(), step.to!.r.toDouble(), t),
          lerp(prev.pos.c.toDouble(), step.to!.c.toDouble(), t),
          scale: 1 - 0.5 * t,
          rotation: t * pi,
        );
      }
      // Tile being cleared: pop and fade.
      final s = p < 0.25 ? 1 + p : max(0.0, 1.25 - (p - 0.25) / 0.75 * 1.25);
      if (s <= 0.01) return null;
      return TileFrame(
        prev,
        prev.pos.r.toDouble(),
        prev.pos.c.toDouble(),
        scale: s,
        opacity: (1 - p).clamp(0, 1),
      );
    }
    return null;
  }
}

class TileFrame {
  final TileView look;
  final double r;
  final double c;
  final double scale;
  final double opacity;
  final double rotation;
  final Pos? entry;
  const TileFrame(
    this.look,
    this.r,
    this.c, {
    this.scale = 1,
    this.opacity = 1,
    this.rotation = 0,
    this.entry,
  });
}
