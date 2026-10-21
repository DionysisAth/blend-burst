import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app/audio.dart';
import '../core/board.dart';
import '../core/models.dart';
import '../ui/art_cache.dart';
import '../l10n/l10n.dart';
import '../ui/tile_art.dart';
import 'game_controller.dart';
import 'sprites.dart';

/// Board placement inside the widget: cell size and top-left corner.
class BoardGeometry {
  final double cell;
  final Offset origin;
  final int rows;
  final int cols;

  const BoardGeometry(this.cell, this.origin, this.rows, this.cols);

  /// Leaves a margin of [marginCells] around the board for the frame and
  /// the gravity arrows.
  static const marginCells = 0.5;

  factory BoardGeometry.fit(Size size, int rows, int cols) {
    final cell = max(
      1.0,
      min(
        size.width / (cols + 2 * marginCells),
        size.height / (rows + 2 * marginCells),
      ),
    );
    final w = cell * cols, h = cell * rows;
    return BoardGeometry(
      cell,
      Offset((size.width - w) / 2, (size.height - h) / 2),
      rows,
      cols,
    );
  }

  Rect get rect =>
      Rect.fromLTWH(origin.dx, origin.dy, cell * cols, cell * rows);

  Offset center(double r, double c) =>
      origin + Offset((c + 0.5) * cell, (r + 0.5) * cell);

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell);

  Pos? hit(Offset local) {
    final r = ((local.dy - origin.dy) / cell).floor();
    final c = ((local.dx - origin.dx) / cell).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return Pos(r, c);
  }
}

enum _PKind { drop, star, shard, ring }

class _Particle {
  Offset pos; // in cell units (row, col)
  Offset vel;
  final Color color;
  final double size;
  final double life;
  final _PKind kind;
  final double spin;
  double age = 0;
  _Particle(
    this.pos,
    this.vel,
    this.color,
    this.size,
    this.life,
    this.kind,
    this.spin,
  );
}

class _Fx {
  final EffectKind kind;
  final Offset at;
  final Color color;
  final List<Offset> targets;
  final double life;
  double age = 0;
  _Fx(this.kind, this.at, this.color, this.targets, this.life);
}

class _Popup {
  final Offset at;
  final String text;
  final Color color;
  double age = 0;
  _Popup(this.at, this.text, this.color);
}

class _Callout {
  final String text;
  final List<Color> colors;
  double age = 0;
  _Callout(this.text, this.colors);
}

/// The interactive, animated board.
class BoardView extends StatefulWidget {
  final GameController controller;
  final bool interactive;
  final void Function(Pos a, Pos b) onSwipe;
  final void Function(Pos p) onTap;
  final Hint? hint;
  final Pos? selected;
  final bool haptics;
  final GameAudio? audio;

  /// Called after a "Spectacular!" combo.
  final VoidCallback? onSpectacular;

  const BoardView({
    super.key,
    required this.controller,
    required this.onSwipe,
    required this.onTap,
    this.interactive = true,
    this.hint,
    this.selected,
    this.haptics = true,
    this.audio,
    this.onSpectacular,
  });

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final _rng = Random();
  Duration _last = Duration.zero;
  double time = 0;
  final particles = <_Particle>[];
  final fx = <_Fx>[];
  final popups = <_Popup>[];
  final callouts = <_Callout>[];
  double shake = 0;
  double gravityFlash = 0;
  Gravity? _gravityFrom;
  int _calloutLevel = 0;

  Pos? dragStart;
  Offset drag = Offset.zero;
  bool _dragDone = false;
  BoardGeometry? geometry;
  final sprites = SpriteCache();
  double devicePixelRatio = 1;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    controller.onStepStart = _onStepStart;
    controller.addListener(_wake);
    _wake();
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_wake);
      controller.onStepStart = _onStepStart;
      controller.addListener(_wake);
    }
    _wake();
  }

  @override
  void dispose() {
    controller.removeListener(_wake);
    if (controller.onStepStart == _onStepStart) controller.onStepStart = null;
    _ticker.dispose();
    _repaint.dispose();
    sprites.clear();
    super.dispose();
  }

  bool get _hasLivelyTiles => controller.shown.tiles.values.any(
    (t) => t.special != Special.none || t.gravitySwitch,
  );

  bool get _needsTicks =>
      controller.animating ||
      particles.isNotEmpty ||
      fx.isNotEmpty ||
      popups.isNotEmpty ||
      callouts.isNotEmpty ||
      shake > 0 ||
      gravityFlash > 0 ||
      widget.hint != null ||
      dragStart != null ||
      _hasLivelyTiles;

  void _wake() {
    if (!mounted) return;
    if (_needsTicks && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    _repaint.value++;
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    time += dt;
    controller.advance(dt);
    for (final p in particles) {
      p.age += dt;
      if (p.kind != _PKind.ring) {
        p.vel += Offset((p.kind == _PKind.star ? 3 : 10) * dt, 0);
      }
      p.vel *= p.kind == _PKind.star ? 0.94 : 0.985;
      p.pos += p.vel * dt;
    }
    particles.removeWhere((p) => p.age >= p.life);
    for (final f in fx) {
      f.age += dt;
    }
    fx.removeWhere((f) => f.age >= f.life);
    for (final p in popups) {
      p.age += dt;
    }
    popups.removeWhere((p) => p.age >= 1.0);
    for (final c in callouts) {
      c.age += dt;
    }
    callouts.removeWhere((c) => c.age >= 1.3);
    shake = max(0, shake - dt * 2.5);
    gravityFlash = max(0, gravityFlash - dt / 1.2);
    _repaint.value++;
    if (!_needsTicks) _ticker.stop();
  }

  // ------------------------------------------------------------ effects

  void _emit(
    Offset at,
    Color color,
    int n, {
    double speed = 3,
    _PKind kind = _PKind.drop,
    double size = 0.09,
    double life = 0.7,
  }) {
    if (particles.length > 450) return;
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final v = speed * (0.35 + _rng.nextDouble());
      particles.add(
        _Particle(
          at,
          Offset(sin(a) - (kind == _PKind.drop ? 0.9 : 0.2), cos(a)) * v,
          color,
          size * (0.6 + _rng.nextDouble() * 0.8),
          life * (0.7 + _rng.nextDouble() * 0.6),
          kind,
          (_rng.nextDouble() - 0.5) * 12,
        ),
      );
    }
  }

  void _haptic(int strength) {
    if (!widget.haptics) return;
    try {
      switch (strength) {
        case 0:
          HapticFeedback.selectionClick();
        case 1:
          HapticFeedback.lightImpact();
        case 2:
          HapticFeedback.mediumImpact();
        default:
          HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Haptics are optional.
    }
  }

  /// Praise for a cascade of [level] 1..4 (4 is "Spectacular!").
  void _callout(int level, List<Color> colors) {
    final words = [
      '',
      tr.gamePraiseGreat,
      tr.gamePraiseAmazing,
      tr.gamePraiseBrilliant,
      tr.gamePraiseSpectacular,
    ];
    callouts
      ..clear()
      ..add(_Callout(words[level], colors));
    widget.audio?.sfx(Sfx.praise);
    if (level == 4) widget.onSpectacular?.call();
  }

  void _onStepStart(Step step, BoardSnapshot before) {
    final audio = widget.audio;
    Offset at(Pos p) => Offset(p.r.toDouble(), p.c.toDouble());
    var strength = -1;

    if (step.kind == StepKind.swap || step.kind == StepKind.blend) {
      _calloutLevel = 0;
    }

    for (final c in step.cleared) {
      if (step.kind == StepKind.blend) continue;
      final color = Palette.of(c.color);
      _emit(at(c.at), color, c.special == Special.none ? 6 : 12);
      _emit(
        at(c.at),
        Colors.white,
        c.special == Special.none ? 2 : 6,
        kind: _PKind.star,
        speed: 2.4,
        size: 0.12,
      );
      particles.add(
        _Particle(at(c.at), Offset.zero, color, 0.5, 0.35, _PKind.ring, 0),
      );
      strength = max(strength, 1);
    }
    for (final g in step.glassHit) {
      _emit(
        at(g),
        const Color(0xFFDFF7FF),
        10,
        speed: 4,
        kind: _PKind.shard,
        size: 0.12,
      );
      strength = max(strength, 1);
    }
    for (final g in step.lockHit) {
      _emit(
        at(g),
        const Color(0xFFC9D2E3),
        12,
        speed: 4.5,
        kind: _PKind.shard,
        size: 0.13,
      );
      strength = max(strength, 1);
    }
    for (final g in step.inkHit) {
      _emit(at(g), const Color(0xFF2A1640), 12, speed: 3.5, size: 0.16);
      strength = max(strength, 1);
    }

    Sfx? big;
    for (final e in step.effects) {
      final color = Palette.of(e.color);
      final (life, power) = switch (e.kind) {
        EffectKind.board => (0.9, 1.0),
        EffectKind.bigBomb || EffectKind.cross3 => (0.65, 0.8),
        EffectKind.bomb || EffectKind.whiteBurst => (0.55, 0.55),
        EffectKind.prism => (0.65, 0.5),
        EffectKind.splash => (0.5, 0.0),
        _ => (0.45, 0.35),
      };
      fx.add(_Fx(e.kind, at(e.at), color, e.targets.map(at).toList(), life));
      shake = max(shake, power);
      strength = max(strength, power >= 0.8 ? 3 : (power > 0 ? 2 : 1));
      final s = switch (e.kind) {
        EffectKind.board => Sfx.combo,
        EffectKind.whiteBurst => Sfx.whiteburst,
        EffectKind.prism => Sfx.prism,
        EffectKind.bomb || EffectKind.bigBomb || EffectKind.cross3 => Sfx.bomb,
        EffectKind.lineH || EffectKind.lineV || EffectKind.rowCol => Sfx.line,
        EffectKind.splash => null,
        EffectKind.inkSpread => Sfx.ink,
        EffectKind.drop => Sfx.drop,
      };
      if (s != null && (big == null || s.index > big.index)) big = s;
      if (e.kind == EffectKind.bomb ||
          e.kind == EffectKind.bigBomb ||
          e.kind == EffectKind.board) {
        _emit(at(e.at), color, 18, speed: 6, size: 0.12);
      }
    }

    // Score popups take the color of what was cleared.
    final color = step.cleared.isEmpty
        ? Colors.white
        : Palette.of(step.cleared.first.color);
    for (final p in step.popups) {
      popups.add(_Popup(Offset(p.at.r, p.at.c), '+${p.amount}', color));
    }

    switch (step.kind) {
      case StepKind.clear:
        if (step.cleared.isNotEmpty) audio?.pop(step.cascade);
        if (big != null) audio?.sfx(big);
        if (step.glassHit.isNotEmpty) audio?.sfx(Sfx.glass);
        if (step.lockHit.isNotEmpty) audio?.sfx(Sfx.chain);
        if (step.inkHit.isNotEmpty) audio?.sfx(Sfx.ink);
        if (step.effects.any((e) => e.kind == EffectKind.drop)) {
          for (final e in step.effects) {
            _emit(
              at(e.at),
              const Color(0xFF7CF2B0),
              14,
              kind: _PKind.star,
              speed: 4,
              size: 0.16,
            );
          }
        }
        final stainsGone = before.stainsLeft - step.after.stainsLeft;
        if (stainsGone > 0) audio?.sfx(Sfx.stain);
        final made = step.after.tiles.values.where(
          (t) => t.special != Special.none && !before.tiles.containsKey(t.id),
        );
        if (made.isNotEmpty) {
          audio?.sfx(Sfx.special);
          for (final t in made) {
            _emit(
              at(t.pos),
              const Color(0xFFFFF3B0),
              10,
              kind: _PKind.star,
              speed: 3,
              size: 0.14,
            );
          }
        }
        final level = step.cascade >= 6
            ? 4
            : (step.cascade >= 5
                  ? 3
                  : (step.cascade >= 4 ? 2 : (step.cascade >= 3 ? 1 : 0)));
        if (step.effects.any((e) => e.kind == EffectKind.board)) {
          _callout(4, const [Color(0xFFFFF07A), Color(0xFFFF8A1F)]);
          _calloutLevel = 4;
        } else if (level > _calloutLevel) {
          _calloutLevel = level;
          const palettes = [
            [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            [Color(0xFF9CFF8A), Color(0xFF22B84C)],
            [Color(0xFF8FE3FF), Color(0xFF2F7BFF)],
            [Color(0xFFFFB3E0), Color(0xFFE8368F)],
            [Color(0xFFFFF07A), Color(0xFFFF8A1F)],
          ];
          _callout(level, palettes[level]);
        }
      case StepKind.blend:
        final to = step.to;
        if (to != null) {
          for (final c in step.cleared) {
            _emit(at(c.at), Palette.of(c.color), 8, speed: 1.6);
          }
          final made = step.after.tiles.values.where(
            (t) => !before.tiles.containsKey(t.id),
          );
          for (final t in made) {
            final mc = Palette.of(t.color);
            particles.add(
              _Particle(at(to), Offset.zero, mc, 0.8, 0.55, _PKind.ring, 0),
            );
            _emit(at(to), mc, 12, speed: 3);
            _emit(
              at(to),
              Colors.white,
              6,
              kind: _PKind.star,
              speed: 2,
              size: 0.14,
            );
          }
        }
        audio?.sfx(Sfx.blend);
        strength = max(strength, 1);
      case StepKind.gravity:
        _gravityFrom = before.gravity;
        gravityFlash = 1;
        strength = 2;
        audio?.sfx(Sfx.gravity);
      case StepKind.swap:
        strength = max(strength, 0);
        audio?.sfx(Sfx.swap);
      case StepKind.swapBack:
        audio?.sfx(Sfx.invalid);
      case StepKind.shuffle:
        audio?.sfx(Sfx.shuffle);
      case StepKind.transform:
        audio?.sfx(Sfx.special);
        for (final e in step.effects) {
          for (final t in e.targets) {
            _emit(at(t), Palette.of(e.color), 4, speed: 2);
          }
        }
      case StepKind.fall:
        break;
    }
    if (strength >= 0) _haptic(strength);
    _wake();
  }

  // --------------------------------------------------------------- input

  bool get _canInput => widget.interactive && !controller.animating;

  void _onPanStart(DragStartDetails d) {
    if (!_canInput) return;
    final p = geometry?.hit(d.localPosition);
    if (p == null || !controller.board.canHoldTile(p)) return;
    dragStart = p;
    drag = Offset.zero;
    _dragDone = false;
    _wake();
  }

  Pos? _dragTarget() {
    final g = geometry, s = dragStart;
    if (g == null || s == null) return null;
    if (drag.distance < g.cell * 0.18) return null;
    final horizontal = drag.dx.abs() > drag.dy.abs();
    final d = horizontal
        ? Pos(0, drag.dx > 0 ? 1 : -1)
        : Pos(drag.dy > 0 ? 1 : -1, 0);
    return s + d;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (dragStart == null || _dragDone) return;
    drag += d.delta;
    final g = geometry;
    if (g != null && max(drag.dx.abs(), drag.dy.abs()) > g.cell * 0.6) {
      _commitDrag();
    }
    _repaint.value++;
  }

  void _onPanEnd(DragEndDetails d) {
    final g = geometry;
    if (dragStart != null &&
        !_dragDone &&
        g != null &&
        max(drag.dx.abs(), drag.dy.abs()) > g.cell * 0.28) {
      _commitDrag();
    }
    _cancelDrag();
  }

  void _commitDrag() {
    final a = dragStart, b = _dragTarget();
    _dragDone = true;
    _cancelDrag();
    if (a != null && b != null && controller.board.canHoldTile(b)) {
      widget.onSwipe(a, b);
    }
  }

  void _cancelDrag() {
    dragStart = null;
    drag = Offset.zero;
    _repaint.value++;
  }

  void _onTapUp(TapUpDetails d) {
    if (!_canInput) return;
    final p = geometry?.hit(d.localPosition);
    if (p != null && controller.board.isPlayable(p)) widget.onTap(p);
  }

  /// Blend preview while dragging a primary onto another primary.
  (TileColor?, Special)? get blendPreview {
    final a = dragStart, b = _dragTarget();
    if (a == null || b == null || controller.animating) return null;
    return controller.board.blendPreview(a, b);
  }

  @override
  Widget build(BuildContext context) {
    devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        geometry = BoardGeometry.fit(
          size,
          controller.board.rows,
          controller.board.cols,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _cancelDrag,
          onTapUp: _onTapUp,
          child: Semantics(
            label: tr.gameBoardLabel,
            container: true,
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _BoardPainter(this, _repaint),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final BoardViewState s;
  _BoardPainter(this.s, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final g = s.geometry;
    if (g == null) return;
    final ctrl = s.controller;
    final board = ctrl.board;
    final before = ctrl.shown;
    final step = ctrl.current;
    final p = ctrl.progress;
    final cell = g.cell;

    canvas.save();
    if (s.shake > 0) {
      final m = s.shake * cell * 0.12;
      canvas.translate(sin(s.time * 70) * m, cos(s.time * 53) * m);
    }

    _paintFrame(canvas, g, board);

    // Obstacles switch from the old to the new state half-way through a step.
    final obstacles = (step != null && p >= 0.5) ? step.after : before;
    final dpr = s.devicePixelRatio;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final i = r * g.cols + c;
        final rect = g.cellRect(r, c);
        final pos = Pos(r, c);
        final f = board.filterAt(pos);
        if (f != null) {
          ArtCache.paint(
            canvas,
            'filter:${f.name}',
            rect,
            dpr,
            (cv, sz) => TileArt.filter(cv, Offset.zero & sz, f),
          );
        }
        final z = board.zoneAt(pos);
        if (z != null) TileArt.zoneArrow(canvas, rect, z);
        if (obstacles.stain[i]) {
          TileArt.stain(canvas, rect);
        }
        if (obstacles.ink.isNotEmpty && obstacles.ink[i]) {
          // Ink wobbles a little: it is alive.
          final wob = 1 + 0.03 * sin(s.time * 3 + r * 1.3 + c);
          final seed = (r * 7 + c) % 4;
          ArtCache.paint(
            canvas,
            'ink:$seed',
            Rect.fromCenter(
              center: rect.center,
              width: rect.width * wob,
              height: rect.height * (2 - wob),
            ),
            dpr,
            (cv, sz) => TileArt.ink(cv, Offset.zero & sz, seed: seed),
            pad: 0.1,
          );
        }
      }
    }

    // Tiles.
    final ids = <int>{
      ...before.tiles.keys,
      if (step != null) ...step.after.tiles.keys,
    };
    final frames = <TileFrame>[];
    for (final id in ids) {
      final f = GameController.frameFor(id, before, step, p);
      if (f != null) frames.add(f);
    }
    final gravity = step?.after.gravity ?? before.gravity;
    final radius = cell * 0.44;
    s.sprites.configure(radius, cell, s.devicePixelRatio);
    final dragPos = s.dragStart;
    final hint = s.widget.hint;
    for (final f in frames) {
      var center = g.center(f.r, f.c);
      final isDragged =
          dragPos != null && step == null && f.look.pos == dragPos;
      if (isDragged) {
        final lim = cell * 0.5;
        final d = s.drag.dx.abs() > s.drag.dy.abs()
            ? Offset(s.drag.dx.clamp(-lim, lim), 0)
            : Offset(0, s.drag.dy.clamp(-lim, lim));
        center += d;
      }
      final entry = f.entry;
      canvas.save();
      if (entry != null) canvas.clipRect(_entryClip(g, entry, gravity));
      if (f.rotation != 0) {
        canvas.translate(center.dx, center.dy);
        canvas.rotate(f.rotation);
        canvas.translate(-center.dx, -center.dy);
      }
      final look = f.look;
      var scale = f.scale * (isDragged ? 1.1 : 1);
      // Hinted tiles breathe.
      if (hint != null &&
          step == null &&
          (look.pos == hint.a || look.pos == hint.b)) {
        scale *= 1 + 0.07 * sin(s.time * 7);
      }
      var spin = 0.0;
      switch (look.special) {
        case Special.prism:
          spin = s.time * 0.6;
        case Special.whiteBurst:
          spin = s.time * 0.8;
        case Special.bomb:
          scale *= 1 + 0.05 * sin(s.time * 6);
        default:
          break;
      }
      if (look.bucket) {
        // Buckets sway as if they were heavy.
        spin = sin(s.time * 2.4 + look.id) * 0.08;
      }
      final drawn = s.sprites.drawTile(
        canvas,
        center,
        scale,
        look.color,
        look.special,
        rotation: spin,
        bucket: look.bucket,
      );
      if (!drawn) {
        TileArt.paint(
          canvas,
          center,
          radius * scale,
          color: look.color,
          special: look.special,
          bucket: look.bucket,
          time: s.time,
        );
      }
      if (look.gravitySwitch) {
        TileArt.switchBadge(canvas, center, radius * scale, s.time);
      }
      canvas.restore();
    }

    // Glass, chains and filter badges sit on top of the tiles.
    final hasBuckets = board.bucketsToSpawn > 0 || board.bucketsOnBoard > 0;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final i = r * g.cols + c;
        final rect = g.cellRect(r, c);
        final layers = obstacles.glass[i];
        if (layers > 0 && !s.sprites.drawGlass(canvas, rect, layers)) {
          TileArt.glass(canvas, rect, layers);
        }
        final locks = obstacles.lock.isEmpty ? 0 : obstacles.lock[i];
        if (locks > 0) {
          ArtCache.paint(
            canvas,
            'chains:$locks',
            rect,
            dpr,
            (cv, sz) => TileArt.chains(cv, Offset.zero & sz, locks),
            pad: 0.05,
          );
        }
        final f = board.filterAt(Pos(r, c));
        if (f != null) TileArt.filterBadge(canvas, rect, f);
        final z = board.zoneAt(Pos(r, c));
        if (z != null) TileArt.zoneBadge(canvas, rect, z);
        if (hasBuckets &&
            board.isPlayable(Pos(r, c)) &&
            board.isExit(Pos(r, c))) {
          _paintExit(canvas, g, Pos(r, c), board.dirAt(Pos(r, c)));
        }
      }
    }

    final sel = s.widget.selected;
    if (sel != null) {
      final pulse = 0.5 + 0.5 * sin(s.time * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          g.cellRect(sel.r, sel.c).deflate(cell * 0.02),
          Radius.circular(cell * 0.2),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * (0.07 + 0.03 * pulse)
          ..color = const Color(0xFFFFE14D),
      );
    }

    _paintFx(canvas, g);
    canvas.restore();

    _paintGravity(
      canvas,
      g,
      before.gravity,
      step,
      chevrons: !(board.bucketsToSpawn > 0 || board.bucketsOnBoard > 0),
    );
    if (hint != null && step == null && s.dragStart == null) {
      _paintHand(canvas, g, hint);
    }
    _paintPreview(canvas, g);
    _paintCallouts(canvas, g);
  }

  /// A glowing strip on the edge where paint buckets leave the board.
  void _paintExit(Canvas canvas, BoardGeometry g, Pos p, Gravity d) {
    final rect = g.cellRect(p.r, p.c);
    final w = g.cell;
    final t = w * 0.12;
    final strip = switch (d) {
      Gravity.down => Rect.fromLTWH(
        rect.left + w * 0.1,
        rect.bottom - t,
        w * 0.8,
        t,
      ),
      Gravity.up => Rect.fromLTWH(rect.left + w * 0.1, rect.top, w * 0.8, t),
      Gravity.left => Rect.fromLTWH(rect.left, rect.top + w * 0.1, t, w * 0.8),
      Gravity.right => Rect.fromLTWH(
        rect.right - t,
        rect.top + w * 0.1,
        t,
        w * 0.8,
      ),
    };
    final glow = 0.6 + 0.3 * sin(s.time * 4 + p.r + p.c);
    canvas.drawRRect(
      RRect.fromRectAndRadius(strip, Radius.circular(t)),
      Paint()..color = const Color(0xFF7CF2B0).withValues(alpha: glow),
    );
    // A green arrow just outside the board, pointing out.
    final out = Offset(d.dc.toDouble(), d.dr.toDouble());
    final mark = rect.center + out * (w * 0.5 + g.cell * 0.36);
    TileArt.exitMark(canvas, mark, w * 0.6, d, s.time);
  }

  void _paintFrame(Canvas canvas, BoardGeometry g, Board board) {
    final cell = g.cell;
    final playable = <Rect>[];
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (board.isPlayable(Pos(r, c))) playable.add(g.cellRect(r, c));
      }
    }
    void layer(double inflate, Paint paint, {Offset shift = Offset.zero}) {
      for (final rect in playable) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(cell * inflate).shift(shift),
            Radius.circular(cell * (0.22 + inflate)),
          ),
          paint,
        );
      }
    }

    layer(
      0.16,
      Paint()..color = const Color(0x40301040),
      shift: Offset(0, cell * 0.1),
    );
    layer(0.15, Paint()..color = const Color(0xFFFFFFFF));
    layer(0.1, Paint()..color = const Color(0xFFFFC94D));
    layer(0.05, Paint()..color = const Color(0xFF6B3FB0));
    layer(0.0, Paint()..color = const Color(0xFF3B1A63));
    final light = Paint()..color = const Color(0x2EFFFFFF);
    final dark = Paint()..color = const Color(0x14FFFFFF);
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (!board.isPlayable(Pos(r, c))) continue;
        final rect = g.cellRect(r, c).deflate(cell * 0.035);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.16)),
          (r + c).isEven ? light : dark,
        );
      }
    }
  }

  Rect _entryClip(BoardGeometry g, Pos e, Gravity gravity) {
    final r = g.cellRect(e.r, e.c);
    const big = 1e5;
    switch (gravity) {
      case Gravity.down:
        return Rect.fromLTRB(-big, r.top, big, big);
      case Gravity.up:
        return Rect.fromLTRB(-big, -big, big, r.bottom);
      case Gravity.left:
        return Rect.fromLTRB(-big, -big, r.right, big);
      case Gravity.right:
        return Rect.fromLTRB(r.left, -big, big, big);
    }
  }

  void _beam(
    Canvas canvas,
    BoardGeometry g, {
    int? row,
    int? col,
    required Color color,
    required double t,
  }) {
    final cell = g.cell;
    final grow = Curves.easeOut.transform((t * 3).clamp(0.0, 1.0));
    final w = cell * 0.9 * (1 - t) * (0.4 + 0.6 * grow);
    final rect = row != null
        ? Rect.fromLTWH(
            g.rect.left - cell * 0.3,
            g.origin.dy + (row + 0.5) * cell - w / 2,
            g.rect.width + cell * 0.6,
            w,
          )
        : Rect.fromLTWH(
            g.origin.dx + (col! + 0.5) * cell - w / 2,
            g.rect.top - cell * 0.3,
            w,
            g.rect.height + cell * 0.6,
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(w * 0.35), Radius.circular(w)),
      Paint()..color = color.withValues(alpha: 0.35 * (1 - t)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w / 2)),
      Paint()
        ..color = Palette.shade(color, 0.2).withValues(alpha: 0.8 * (1 - t)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(w * 0.3), Radius.circular(w / 3)),
      Paint()..color = Colors.white.withValues(alpha: (1 - t)),
    );
  }

  void _paintFx(Canvas canvas, BoardGeometry g) {
    final cell = g.cell;
    for (final f in s.fx) {
      final t = (f.age / f.life).clamp(0.0, 1.0);
      final center = g.center(f.at.dx, f.at.dy);
      final r = f.at.dx.round(), c = f.at.dy.round();
      switch (f.kind) {
        case EffectKind.lineH:
          _beam(canvas, g, row: r, color: f.color, t: t);
        case EffectKind.lineV:
          _beam(canvas, g, col: c, color: f.color, t: t);
        case EffectKind.rowCol:
          _beam(canvas, g, row: r, color: f.color, t: t);
          _beam(canvas, g, col: c, color: f.color, t: t);
        case EffectKind.cross3:
          for (var d = -1; d <= 1; d++) {
            if (r + d >= 0 && r + d < g.rows) {
              _beam(canvas, g, row: r + d, color: f.color, t: t);
            }
            if (c + d >= 0 && c + d < g.cols) {
              _beam(canvas, g, col: c + d, color: f.color, t: t);
            }
          }
        case EffectKind.bomb:
        case EffectKind.bigBomb:
          final reach = f.kind == EffectKind.bomb ? 1.9 : 3.1;
          final e = Curves.easeOutCubic.transform(t);
          canvas.drawCircle(
            center,
            cell * reach * e,
            Paint()..color = f.color.withValues(alpha: 0.3 * (1 - t)),
          );
          canvas.drawCircle(
            center,
            cell * (0.3 + reach * e),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.4 * (1 - t)
              ..color = Colors.white.withValues(alpha: 0.9 * (1 - t)),
          );
          canvas.drawCircle(
            center,
            cell * reach * 0.55 * (1 - e),
            Paint()..color = Colors.white.withValues(alpha: 0.85 * (1 - t)),
          );
        case EffectKind.prism:
          final rnd = Random(
            (f.at.dx * 31 + f.at.dy).round() + (t * 12).floor(),
          );
          for (final target in f.targets) {
            final end = g.center(target.dx, target.dy);
            final path = Path()..moveTo(center.dx, center.dy);
            const segs = 5;
            for (var k = 1; k < segs; k++) {
              final q = Offset.lerp(center, end, k / segs)!;
              final n = Offset(-(end - center).dy, (end - center).dx);
              final len = n.distance == 0 ? 1.0 : n.distance;
              path.lineTo(
                q.dx + n.dx / len * (rnd.nextDouble() - 0.5) * cell * 0.4,
                q.dy + n.dy / len * (rnd.nextDouble() - 0.5) * cell * 0.4,
              );
            }
            path.lineTo(end.dx, end.dy);
            canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell * 0.3 * (1 - t)
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..color = f.color.withValues(alpha: 0.5 * (1 - t)),
            );
            canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = cell * 0.1 * (1 - t)
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white.withValues(alpha: 1 - t),
            );
          }
          canvas.drawCircle(
            center,
            cell * (0.6 + t),
            Paint()..color = Colors.white.withValues(alpha: 0.5 * (1 - t)),
          );
        case EffectKind.whiteBurst:
          _beam(canvas, g, row: r, color: const Color(0xFFFFE27A), t: t);
          _beam(canvas, g, col: c, color: const Color(0xFFFFE27A), t: t);
          final rays = Paint()
            ..color = const Color(0xFFFFF4C2).withValues(alpha: 0.8 * (1 - t));
          for (var i = 0; i < 12; i++) {
            final a = i * pi / 6 + t * 1.5;
            final len = cell * 3.2 * Curves.easeOut.transform(t);
            canvas.drawPath(
              Path()
                ..moveTo(
                  center.dx + cos(a - 0.08) * cell * 0.3,
                  center.dy + sin(a - 0.08) * cell * 0.3,
                )
                ..lineTo(center.dx + cos(a) * len, center.dy + sin(a) * len)
                ..lineTo(
                  center.dx + cos(a + 0.08) * cell * 0.3,
                  center.dy + sin(a + 0.08) * cell * 0.3,
                )
                ..close(),
              rays,
            );
          }
        case EffectKind.inkSpread:
          for (final src in f.targets) {
            final from = g.center(src.dx, src.dy);
            final e = Curves.easeOut.transform(t);
            canvas.drawCircle(
              Offset.lerp(from, center, e)!,
              cell * (0.2 + 0.25 * (1 - t)),
              Paint()
                ..color = const Color(0xFF2A1640)
                    .withValues(alpha: 0.8 * (1 - t)),
            );
          }
        case EffectKind.drop:
          final e = Curves.easeOut.transform(t);
          canvas.drawCircle(
            center,
            cell * (0.3 + 0.9 * e),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.16 * (1 - t)
              ..color = const Color(0xFF7CF2B0).withValues(alpha: 1 - t),
          );
        case EffectKind.splash:
          for (final target in f.targets) {
            final e = Curves.easeOut.transform(t);
            canvas.drawCircle(
              g.center(target.dx, target.dy),
              cell * (0.25 + 0.55 * e),
              Paint()..color = f.color.withValues(alpha: 0.45 * (1 - t)),
            );
          }
        case EffectKind.board:
          final rr = RRect.fromRectAndRadius(
            g.rect.inflate(cell * 0.2),
            Radius.circular(cell * 0.4),
          );
          canvas.drawRRect(
            rr,
            Paint()..color = Colors.white.withValues(alpha: 0.85 * (1 - t)),
          );
      }
    }
    for (final p in s.particles) {
      final a = (1 - p.age / p.life).clamp(0.0, 1.0);
      final c = g.center(p.pos.dx, p.pos.dy);
      switch (p.kind) {
        case _PKind.drop:
          final r = cell * p.size * (0.6 + 0.4 * a);
          canvas.drawCircle(
            c,
            r,
            Paint()..color = p.color.withValues(alpha: a),
          );
          canvas.drawCircle(
            c - Offset(r * 0.35, r * 0.35),
            r * 0.35,
            Paint()..color = Colors.white.withValues(alpha: 0.6 * a),
          );
        case _PKind.star:
          final r = cell * p.size * (0.5 + 0.5 * a);
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(p.spin * p.age * 0.3);
          final path = Path()
            ..moveTo(0, -r)
            ..quadraticBezierTo(0, 0, r, 0)
            ..quadraticBezierTo(0, 0, 0, r)
            ..quadraticBezierTo(0, 0, -r, 0)
            ..quadraticBezierTo(0, 0, 0, -r);
          canvas.drawPath(path, Paint()..color = p.color.withValues(alpha: a));
          canvas.restore();
        case _PKind.shard:
          final r = cell * p.size;
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(p.spin * p.age);
          canvas.drawPath(
            Path()
              ..moveTo(0, -r)
              ..lineTo(r * 0.7, r * 0.6)
              ..lineTo(-r * 0.6, r * 0.4)
              ..close(),
            Paint()..color = p.color.withValues(alpha: a * 0.95),
          );
          canvas.restore();
        case _PKind.ring:
          final e = Curves.easeOut.transform(1 - a);
          canvas.drawCircle(
            c,
            cell * p.size * (0.5 + 0.9 * e),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.1 * a
              ..color = Palette.shade(p.color, 0.25).withValues(alpha: a * 0.9),
          );
      }
    }
    for (final pop in s.popups) {
      final t = (pop.age / 1.0).clamp(0.0, 1.0);
      final scale = t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1.0;
      final alpha = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
      final pos = g.center(pop.at.dx - t * 0.9, pop.at.dy);
      _outlinedText(
        canvas,
        pop.text,
        pos,
        cell * 0.42 * scale,
        Colors.white,
        Palette.shade(pop.color, -0.25),
        alpha: alpha,
      );
    }
  }

  void _outlinedText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color fill,
    Color stroke, {
    double alpha = 1,
    List<Color>? gradient,
  }) {
    if (size <= 1 || alpha <= 0) return;
    TextPainter make(Paint paint) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Lilita',
          fontFamilyFallback: const ['LilitaFallback'],
          fontSize: size,
          foreground: paint,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final outline = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.2
        ..strokeJoin = StrokeJoin.round
        ..color = stroke.withValues(alpha: alpha),
    );
    final off = center - Offset(outline.width / 2, outline.height / 2);
    final shadow = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.2
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.3 * alpha),
    );
    shadow.paint(canvas, off + Offset(0, size * 0.08));
    outline.paint(canvas, off);
    final fillPaint = Paint();
    if (gradient != null) {
      fillPaint.shader = ui.Gradient.linear(
        off,
        off + Offset(0, outline.height),
        [
          gradient.first.withValues(alpha: alpha),
          gradient.last.withValues(alpha: alpha),
        ],
      );
    } else {
      fillPaint.color = fill.withValues(alpha: alpha);
    }
    make(fillPaint).paint(canvas, off);
  }

  void _paintCallouts(Canvas canvas, BoardGeometry g) {
    for (final c in s.callouts) {
      final t = (c.age / 1.3).clamp(0.0, 1.0);
      final pop = t < 0.25 ? Curves.elasticOut.transform(t / 0.25) : 1.0;
      final alpha = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
      final center = g.rect.center - Offset(0, g.cell * (0.5 + t * 0.6));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.08);
      _outlinedText(
        canvas,
        c.text,
        Offset.zero,
        g.cell * 1.15 * pop,
        Colors.white,
        const Color(0xFF3B1A63),
        alpha: alpha,
        gradient: c.colors,
      );
      canvas.restore();
    }
  }

  double _angle(Gravity g) => switch (g) {
    Gravity.down => pi / 2,
    Gravity.left => pi,
    Gravity.up => -pi / 2,
    Gravity.right => 0,
  };

  void _paintGravity(
    Canvas canvas,
    BoardGeometry g,
    Gravity current,
    Step? step, {
    bool chevrons = true,
  }) {
    final gravity = step?.kind == StepKind.gravity
        ? step!.after.gravity
        : current;
    final cell = g.cell;
    final rect = g.rect;
    final m = cell * 0.36;
    final (a, b) = switch (gravity) {
      Gravity.down => (
        Offset(rect.left, rect.bottom + m),
        Offset(rect.right, rect.bottom + m),
      ),
      Gravity.up => (
        Offset(rect.left, rect.top - m),
        Offset(rect.right, rect.top - m),
      ),
      Gravity.left => (
        Offset(rect.left - m, rect.top),
        Offset(rect.left - m, rect.bottom),
      ),
      Gravity.right => (
        Offset(rect.right + m, rect.top),
        Offset(rect.right + m, rect.bottom),
      ),
    };
    final ang = _angle(gravity);
    final dir = Offset(cos(ang), sin(ang));
    final side = Offset(-dir.dy, dir.dx);
    // Bucket levels show exit arrows instead.
    final n = chevrons ? 3 : 0;
    final bob = sin(s.time * 4) * cell * 0.04;
    for (var i = 0; i < n; i++) {
      final c = Offset.lerp(a, b, (i + 1) / (n + 1))! + dir * bob;
      final sz = cell * 0.2;
      final path = Path()
        ..moveTo(
          c.dx - dir.dx * sz + side.dx * sz,
          c.dy - dir.dy * sz + side.dy * sz,
        )
        ..lineTo(c.dx + dir.dx * sz * 0.4, c.dy + dir.dy * sz * 0.4)
        ..lineTo(
          c.dx - dir.dx * sz - side.dx * sz,
          c.dy - dir.dy * sz - side.dy * sz,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF3B1A63),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.07
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }

    if (s.gravityFlash > 0) {
      final t = 1 - s.gravityFlash;
      final from = _angle(s._gravityFrom ?? gravity);
      var to = ang;
      while (to < from) {
        to += 2 * pi;
      }
      if (to - from > pi * 1.01) to -= 2 * pi;
      final cur =
          from +
          (to - from) * Curves.easeInOut.transform((t * 1.6).clamp(0, 1));
      final c = rect.center;
      final len = min(rect.width, rect.height) * 0.3;
      final alpha = sin(pi * s.gravityFlash).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(cur);
      final arrow = Path()
        ..moveTo(len, 0)
        ..lineTo(len * 0.3, -len * 0.5)
        ..lineTo(len * 0.3, -len * 0.2)
        ..lineTo(-len, -len * 0.2)
        ..lineTo(-len, len * 0.2)
        ..lineTo(len * 0.3, len * 0.2)
        ..lineTo(len * 0.3, len * 0.5)
        ..close();
      canvas.drawPath(
        arrow,
        Paint()
          ..color = const Color(0xFFFFE14D).withValues(alpha: 0.85 * alpha),
      );
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.09
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF3B1A63).withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  /// A cartoon glove hand that demonstrates the hinted swipe.
  void _paintHand(Canvas canvas, BoardGeometry g, Hint hint) {
    final cell = g.cell;
    final cycle = (s.time % 1.6) / 1.6;
    final a = g.center(hint.a.r.toDouble(), hint.a.c.toDouble());
    final b = g.center(hint.b.r.toDouble(), hint.b.c.toDouble());
    double alpha;
    Offset pos;
    if (cycle < 0.2) {
      alpha = cycle / 0.2;
      pos = a;
    } else if (cycle < 0.65) {
      alpha = 1;
      pos = Offset.lerp(
        a,
        b,
        Curves.easeInOut.transform((cycle - 0.2) / 0.45),
      )!;
    } else if (cycle < 0.85) {
      alpha = 1 - (cycle - 0.65) / 0.2;
      pos = b;
    } else {
      return;
    }
    final press = cycle > 0.15 && cycle < 0.7;
    if (press) {
      canvas.drawCircle(
        pos,
        cell * 0.28,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha),
      );
    }
    canvas.save();
    canvas.translate(pos.dx + cell * 0.12, pos.dy + cell * 0.18);
    canvas.rotate(-0.35);
    final u = cell * 0.5;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.1
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3B1A63).withValues(alpha: alpha);
    final fill = Paint()..color = Colors.white.withValues(alpha: alpha);
    final finger = RRect.fromRectAndRadius(
      Rect.fromLTWH(-u * 0.17, -u * 0.05, u * 0.34, u * 0.95),
      Radius.circular(u * 0.17),
    );
    final palm = RRect.fromRectAndRadius(
      Rect.fromLTWH(-u * 0.28, u * 0.55, u * 0.95, u * 0.85),
      Radius.circular(u * 0.32),
    );
    final knuckles = [
      RRect.fromRectAndRadius(
        Rect.fromLTWH(u * 0.12, u * 0.42, u * 0.3, u * 0.5),
        Radius.circular(u * 0.15),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(u * 0.36, u * 0.5, u * 0.28, u * 0.46),
        Radius.circular(u * 0.14),
      ),
    ];
    final thumb = RRect.fromRectAndRadius(
      Rect.fromLTWH(-u * 0.5, u * 0.7, u * 0.4, u * 0.28),
      Radius.circular(u * 0.14),
    );
    for (final r in [palm, ...knuckles, thumb, finger]) {
      canvas.drawRRect(r, outline);
    }
    for (final r in [palm, ...knuckles, thumb, finger]) {
      canvas.drawRRect(r, fill);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-u * 0.32, u * 1.3, u * 1.03, u * 0.26),
        Radius.circular(u * 0.1),
      ),
      Paint()..color = const Color(0xFFFF4FA3).withValues(alpha: alpha),
    );
    canvas.restore();
  }

  void _paintPreview(Canvas canvas, BoardGeometry g) {
    final preview = s.blendPreview;
    final a = s.dragStart;
    if (preview == null || a == null) return;
    final cell = g.cell;
    final at =
        g.center(a.r.toDouble(), a.c.toDouble()) - Offset(0, cell * 1.05);
    // Speech-bubble preview of the blend result.
    final bubble = RRect.fromRectAndRadius(
      Rect.fromCircle(center: at, radius: cell * 0.5),
      Radius.circular(cell * 0.5),
    );
    canvas.drawRRect(
      bubble.shift(Offset(0, cell * 0.05)),
      Paint()..color = const Color(0x55301040),
    );
    canvas.drawRRect(bubble, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - cell * 0.14, at.dy + cell * 0.42)
        ..lineTo(at.dx, at.dy + cell * 0.62)
        ..lineTo(at.dx + cell * 0.14, at.dy + cell * 0.42)
        ..close(),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06
        ..color = const Color(0xFF6B3FB0),
    );
    TileArt.paint(
      canvas,
      at,
      cell * 0.34,
      color: preview.$1,
      special: preview.$2,
      time: s.time,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
