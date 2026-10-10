import 'dart:math';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/board.dart';
import '../core/models.dart';
import '../ui/tile_art.dart';
import 'game_controller.dart';

/// Board placement inside the widget: cell size and top-left corner.
class BoardGeometry {
  final double cell;
  final Offset origin;
  final int rows;
  final int cols;

  const BoardGeometry(this.cell, this.origin, this.rows, this.cols);

  /// Leaves a margin of [marginCells] around the board for the gravity arrows.
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

class _Particle {
  Offset pos; // in cell units
  Offset vel;
  final Color color;
  final double size;
  final double life;
  double age = 0;
  _Particle(this.pos, this.vel, this.color, this.size, this.life);
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
  double age = 0;
  _Popup(this.at, this.text);
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

  const BoardView({
    super.key,
    required this.controller,
    required this.onSwipe,
    required this.onTap,
    this.interactive = true,
    this.hint,
    this.selected,
    this.haptics = true,
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
  double shake = 0;
  double gravityFlash = 0;
  Gravity? _gravityFrom;

  Pos? dragStart;
  Offset drag = Offset.zero;
  bool _dragDone = false;
  BoardGeometry? geometry;

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
      // Positions are (row, col): "down" on screen is +row.
      p.vel += Offset(9 * dt, 0);
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
    popups.removeWhere((p) => p.age >= 0.9);
    shake = max(0, shake - dt * 2.5);
    gravityFlash = max(0, gravityFlash - dt / 1.2);
    _repaint.value++;
    if (!_needsTicks) _ticker.stop();
  }

  // ------------------------------------------------------------ effects

  void _burst(Offset at, Color color, int n, {double speed = 3}) {
    if (particles.length > 500) return;
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final v = speed * (0.4 + _rng.nextDouble());
      particles.add(
        _Particle(
          at,
          Offset(sin(a) - 0.6, cos(a)) * v,
          color,
          0.06 + _rng.nextDouble() * 0.08,
          0.45 + _rng.nextDouble() * 0.35,
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

  void _onStepStart(Step step, BoardSnapshot before) {
    Offset at(Pos p) => Offset(p.r.toDouble(), p.c.toDouble());
    var strength = -1;
    for (final c in step.cleared) {
      if (step.kind == StepKind.blend) continue;
      _burst(at(c.at), Palette.of(c.color), c.special == Special.none ? 7 : 14);
      strength = max(strength, 1);
    }
    for (final g in step.glassHit) {
      _burst(at(g), Palette.glass, 10, speed: 4);
      strength = max(strength, 1);
    }
    for (final e in step.effects) {
      final color = Palette.of(e.color);
      final (life, power) = switch (e.kind) {
        EffectKind.board => (0.8, 1.0),
        EffectKind.bigBomb || EffectKind.cross3 => (0.6, 0.8),
        EffectKind.bomb || EffectKind.whiteBurst => (0.5, 0.55),
        EffectKind.prism => (0.6, 0.5),
        EffectKind.splash => (0.45, 0.0),
        _ => (0.4, 0.35),
      };
      fx.add(_Fx(e.kind, at(e.at), color, e.targets.map(at).toList(), life));
      shake = max(shake, power);
      strength = max(strength, power >= 0.8 ? 3 : (power > 0 ? 2 : 1));
    }
    for (final p in step.popups) {
      popups.add(_Popup(Offset(p.at.r, p.at.c), '+${p.amount}'));
    }
    switch (step.kind) {
      case StepKind.blend:
        final to = step.to;
        if (to != null) {
          for (final c in step.cleared) {
            _burst(at(to), Palette.of(c.color), 8, speed: 2);
          }
        }
        strength = max(strength, 1);
      case StepKind.gravity:
        _gravityFrom = before.gravity;
        gravityFlash = 1;
        strength = 2;
      case StepKind.swap:
        strength = max(strength, 0);
      default:
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
            label: 'Game board',
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

    // Board backdrop.
    final back = Paint()..color = const Color(0xCC2B1E3F);
    final light = Paint()..color = const Color(0x33FFFFFF);
    final dark = Paint()..color = const Color(0x1AFFFFFF);
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (!board.isPlayable(Pos(r, c))) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            g.cellRect(r, c).inflate(cell * 0.07),
            Radius.circular(cell * 0.18),
          ),
          back,
        );
      }
    }
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (!board.isPlayable(Pos(r, c))) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            g.cellRect(r, c).deflate(cell * 0.03),
            Radius.circular(cell * 0.12),
          ),
          (r + c).isEven ? light : dark,
        );
      }
    }

    // Obstacles switch from the old to the new state half-way through a step.
    final obstacles = (step != null && p >= 0.5) ? step.after : before;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (obstacles.stain[r * g.cols + c]) {
          TileArt.stain(canvas, g.cellRect(r, c));
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
    final radius = cell * 0.42;
    final dragPos = s.dragStart;
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
      TileArt.paint(
        canvas,
        center,
        radius * f.scale * (isDragged ? 1.08 : 1),
        color: f.look.color,
        special: f.look.special,
        gravitySwitch: f.look.gravitySwitch,
        time: s.time,
      );
      canvas.restore();
    }

    // Glass sits on top of everything that slides underneath.
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final layers = obstacles.glass[r * g.cols + c];
        if (layers > 0) TileArt.glass(canvas, g.cellRect(r, c), layers);
      }
    }

    // Hint and selection.
    final hint = s.widget.hint;
    if (hint != null && step == null) {
      final pulse = 0.5 + 0.5 * sin(s.time * 6);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.07
        ..color = Colors.white.withValues(alpha: 0.4 + 0.6 * pulse);
      for (final q in {hint.a, hint.b}) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            g.cellRect(q.r, q.c).deflate(cell * 0.04),
            Radius.circular(cell * 0.16),
          ),
          paint,
        );
      }
    }
    final sel = s.widget.selected;
    if (sel != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          g.cellRect(sel.r, sel.c).deflate(cell * 0.02),
          Radius.circular(cell * 0.16),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.09
          ..color = const Color(0xFFFFEB3B),
      );
    }

    _paintFx(canvas, g);
    canvas.restore();

    _paintGravity(canvas, g, before.gravity, step);
    _paintPreview(canvas, g);
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
    final w = cell * 0.7 * (1 - t);
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
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w / 2));
    canvas.drawRRect(
      rr,
      Paint()..color = color.withValues(alpha: 0.7 * (1 - t)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(w * 0.28), Radius.circular(w / 3)),
      Paint()..color = Colors.white.withValues(alpha: 0.95 * (1 - t)),
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
          final reach = f.kind == EffectKind.bomb ? 1.8 : 3.0;
          canvas.drawCircle(
            center,
            cell * (0.4 + reach * Curves.easeOut.transform(t)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.35 * (1 - t)
              ..color = f.color.withValues(alpha: 0.8 * (1 - t)),
          );
          canvas.drawCircle(
            center,
            cell * reach * 0.6 * (1 - t),
            Paint()..color = Colors.white.withValues(alpha: 0.5 * (1 - t)),
          );
        case EffectKind.prism:
          final paint = Paint()
            ..strokeWidth = cell * 0.12 * (1 - t)
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.9 * (1 - t));
          final glow = Paint()
            ..strokeWidth = cell * 0.26 * (1 - t)
            ..strokeCap = StrokeCap.round
            ..color = f.color.withValues(alpha: 0.6 * (1 - t));
          for (final target in f.targets) {
            final end = g.center(target.dx, target.dy);
            canvas.drawLine(center, end, glow);
            canvas.drawLine(center, end, paint);
          }
        case EffectKind.whiteBurst:
          _beam(canvas, g, row: r, color: f.color, t: t);
          _beam(canvas, g, col: c, color: f.color, t: t);
          final rays = Paint()
            ..strokeWidth = cell * 0.1 * (1 - t)
            ..color = Colors.white.withValues(alpha: 1 - t);
          for (var i = 0; i < 8; i++) {
            final a = i * pi / 4 + t;
            canvas.drawLine(
              center,
              center + Offset(cos(a), sin(a)) * cell * 2.4 * t,
              rays,
            );
          }
        case EffectKind.splash:
          final paint = Paint()
            ..color = f.color.withValues(alpha: 0.45 * (1 - t));
          for (final target in f.targets) {
            canvas.drawCircle(
              g.center(target.dx, target.dy),
              cell * (0.3 + 0.5 * t),
              paint,
            );
          }
        case EffectKind.board:
          canvas.drawRect(
            g.rect.inflate(cell * 0.2),
            Paint()..color = Colors.white.withValues(alpha: 0.8 * (1 - t)),
          );
      }
    }
    for (final p in s.particles) {
      final a = (1 - p.age / p.life).clamp(0.0, 1.0);
      canvas.drawCircle(
        g.center(p.pos.dx, p.pos.dy),
        cell * p.size,
        Paint()..color = p.color.withValues(alpha: a),
      );
    }
    for (final pop in s.popups) {
      final t = (pop.age / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: pop.text,
          style: TextStyle(
            fontSize: cell * 0.38,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 1 - t * t),
            shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final c = g.center(pop.at.dx - t * 0.9, pop.at.dy);
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
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
    Step? step,
  ) {
    final gravity = step?.kind == StepKind.gravity
        ? step!.after.gravity
        : current;
    final cell = g.cell;
    final rect = g.rect;
    final m = cell * BoardGeometry.marginCells / 2;
    // Chevrons along the downstream edge.
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
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.9);
    const n = 3;
    for (var i = 0; i < n; i++) {
      final c = Offset.lerp(a, b, (i + 1) / (n + 1))!;
      final s = cell * 0.18;
      canvas.drawPath(
        Path()
          ..moveTo(
            c.dx - dir.dx * s + side.dx * s,
            c.dy - dir.dy * s + side.dy * s,
          )
          ..lineTo(c.dx, c.dy)
          ..lineTo(
            c.dx - dir.dx * s - side.dx * s,
            c.dy - dir.dy * s - side.dy * s,
          ),
        paint,
      );
    }

    // Big rotating arrow when gravity shifts.
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
        ..lineTo(len * 0.35, -len * 0.45)
        ..lineTo(len * 0.35, -len * 0.18)
        ..lineTo(-len, -len * 0.18)
        ..lineTo(-len, len * 0.18)
        ..lineTo(len * 0.35, len * 0.18)
        ..lineTo(len * 0.35, len * 0.45)
        ..close();
      canvas.drawPath(
        arrow,
        Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha),
      );
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06
          ..color = const Color(0xFF4A148C).withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  void _paintPreview(Canvas canvas, BoardGeometry g) {
    final preview = s.blendPreview;
    final a = s.dragStart;
    if (preview == null || a == null) return;
    final cell = g.cell;
    final at =
        g.center(a.r.toDouble(), a.c.toDouble()) - Offset(0, cell * 0.95);
    canvas.drawCircle(at, cell * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(
      at,
      cell * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05
        ..color = const Color(0xFF4A148C),
    );
    TileArt.paint(
      canvas,
      at,
      cell * 0.3,
      color: preview.$1,
      special: preview.$2,
      time: s.time,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
