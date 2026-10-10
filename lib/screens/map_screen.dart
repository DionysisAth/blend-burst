import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/audio.dart';
import '../app/level_repository.dart';
import '../app/scope.dart';
import '../core/level.dart';
import '../core/models.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';
import 'dialogs.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// The scrolling level map. Level 1 is at the bottom, like a climb.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const spacing = 104.0;
  static const headerGap = 130.0;
  static const bottomPad = 150.0;
  final _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  Timer? _clock;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.read(context);
    scope.audio.music(Music.map);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Only rebuild while a life is refilling, to show the countdown.
      if (AppScope.read(context).app.nextLifeIn != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openLevel(LevelDef level) async {
    final scope = AppScope.read(context);
    final app = scope.app;
    if (!app.isUnlocked(level.id)) {
      scope.audio.sfx(Sfx.invalid);
      return;
    }
    scope.audio.sfx(Sfx.click);
    final play = await showLevelStart(context, level);
    if (!play || !mounted) return;
    if (app.lives <= 0) {
      final ok = await showOutOfLives(context);
      if (!ok || !mounted) return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(level: level)));
    if (mounted) setState(() {});
  }

  /// y (from the bottom) of a level node's center.
  double _yOf(int index, int episode) =>
      bottomPad + index * spacing + episode * headerGap;

  double _xOf(int index, double w) => w / 2 + sin(index * 0.9) * w * 0.28;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final repo = scope.levels;
    final levels = repo.levels;
    final current = min(app.data.unlocked, levels.length);
    final total = levels.isEmpty
        ? 600.0
        : _yOf(levels.length - 1, repo.episodes.length - 1) + 260;

    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients || levels.isEmpty) return;
        final i = current - 1;
        final y =
            _yOf(i, levels[i].episode) -
            _scroll.position.viewportDimension * 0.42;
        _scroll.jumpTo(y.clamp(0.0, _scroll.position.maxScrollExtent));
      });
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              key: const Key('map-scroll'),
              controller: _scroll,
              reverse: true,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final points = <Offset>[
                    for (var i = 0; i < levels.length; i++)
                      Offset(_xOf(i, w), total - _yOf(i, levels[i].episode)),
                  ];
                  return SizedBox(
                    height: total,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _WorldPainter(repo, total, _yOf, points),
                            ),
                          ),
                        ),
                        ..._decorations(repo, w, total),
                        for (final e in repo.episodes) _banner(e, w, total),
                        for (var i = 0; i < levels.length; i++)
                          Positioned(
                            left: points[i].dx - 44,
                            top: points[i].dy - 44,
                            child: _LevelNode(
                              level: levels[i],
                              stars: app.starsFor(levels[i].id),
                              unlocked: app.isUnlocked(levels[i].id),
                              current: levels[i].id == current,
                              pulse: _pulse,
                              onTap: () => _openLevel(levels[i]),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(bottom: false, child: _TopBar(app: app)),
          ),
          if (levels.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 60, 14),
                  child: CandyButton.label(
                    'Level $current',
                    key: const Key('play-current'),
                    icon: GameIcons.play,
                    height: 60,
                    fontSize: 28,
                    onTap: () => _openLevel(levels[current - 1]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _banner(Episode e, double w, double total) {
    final first = e.levels.first;
    final y = _yOf(first.id - 1, e.index) - headerGap * 0.62 - 6;
    return Positioned(
      left: 0,
      right: 0,
      top: total - y - 40,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ribbon(
              e.name,
              color: [
                Palette.candyPink,
                const Color(0xFF1FB86B),
                Palette.grape,
              ][e.index % 3],
              fontSize: 28,
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: GameText(
                'EPISODE ${e.index + 1}',
                size: 14,
                family: 'Fredoka',
                strokeWidth: 3.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _decorations(LevelRepository repo, double w, double total) {
    final rnd = Random(11);
    final out = <Widget>[];
    for (var i = 0; i < repo.levels.length; i += 2) {
      final level = repo.levels[i];
      final y = total - _yOf(i, level.episode) - rnd.nextDouble() * 60;
      final nodeX = _xOf(i, w);
      // Put decorations on the side away from the path.
      final left = nodeX > w / 2;
      final x = left
          ? 8 + rnd.nextDouble() * w * 0.16
          : w - 56 - rnd.nextDouble() * w * 0.16;
      final color = level.colors[rnd.nextInt(level.colors.length)];
      out.add(
        Positioned(
          left: x,
          top: y,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.9,
              child: Transform.rotate(
                angle: (rnd.nextDouble() - 0.5) * 0.8,
                child: MiniTile(
                  color: rnd.nextInt(7) == 0 ? null : color,
                  special: rnd.nextInt(7) == 0 ? Special.prism : Special.none,
                  size: 34 + rnd.nextDouble() * 18,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }
}

class _WorldPainter extends CustomPainter {
  final LevelRepository repo;
  final double total;
  final double Function(int, int) yOf;
  final List<Offset> points;
  _WorldPainter(this.repo, this.total, this.yOf, this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final eps = repo.episodes;
    for (final e in eps) {
      final startY = e.index == 0
          ? 0.0
          : yOf(e.levels.first.id - 1, e.index) - 110;
      final endY = e.index == eps.length - 1
          ? total
          : yOf(eps[e.index + 1].levels.first.id - 1, e.index + 1) - 110;
      final rect = Rect.fromLTRB(0, total - endY, size.width, total - startY);
      canvas.save();
      canvas.clipRect(rect);
      BackgroundPainter.paintTheme(canvas, rect, e.index, seed: 3);
      canvas.restore();
    }
    if (points.length < 2) return;
    // A smooth road through all nodes (Catmull-Rom spline).
    final road = Path()..moveTo(points.first.dx, points.first.dy + 120);
    road.lineTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[0] : points[i - 1];
      final p1 = points[i], p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      road.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(
      road.shift(const Offset(0, 6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x33301040),
    );
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE9C9A0),
    );
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 32
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF4DF),
    );
    // Paint dots along the road.
    const dotColors = [
      Color(0xFFFF3B5C),
      Color(0xFFFFC21A),
      Color(0xFF2F7BFF),
      Color(0xFF1FC46B),
      Color(0xFFA24BF2),
    ];
    var k = 0;
    for (final metric in road.computeMetrics()) {
      for (var d = 20.0; d < metric.length; d += 26) {
        final t = metric.getTangentForOffset(d);
        if (t == null) continue;
        canvas.drawCircle(
          t.position,
          4.2,
          Paint()
            ..color = dotColors[k++ % dotColors.length].withValues(alpha: 0.75),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) =>
      old.total != total || old.points.length != points.length;
}

class _TopBar extends StatelessWidget {
  final AppState app;
  const _TopBar({required this.app});

  @override
  Widget build(BuildContext context) {
    final next = app.nextLifeIn;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC3B1A63), Color(0x003B1A63)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatPill(
                    icon: GameIcons.heart,
                    text: next == null
                        ? '${app.lives} Full'
                        : '${app.lives} ${formatDuration(next)}',
                    textKey: const Key('lives'),
                    onTap: () => showOutOfLives(context),
                  ),
                  const SizedBox(width: 6),
                  StatPill(
                    icon: GameIcons.coin,
                    text: '${app.coins}',
                    textKey: const Key('coins'),
                  ),
                  const SizedBox(width: 6),
                  StatPill(icon: GameIcons.star, text: '${app.totalStars}'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoundButton(
            GameIcons.gear,
            key: const Key('settings'),
            label: 'Settings',
            size: 44,
            colors: CandyColors.blue,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  final LevelDef level;
  final int stars;
  final bool unlocked;
  final bool current;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _LevelNode({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (top, bottom, edge) = !unlocked
        ? (
            const Color(0xFFD9D4E6),
            const Color(0xFFA59DBA),
            const Color(0xFF6E6684),
          )
        : level.hard
        ? (
            const Color(0xFFFF8A8A),
            const Color(0xFFE01E3C),
            const Color(0xFF8A0F25),
          )
        : switch (level.episode) {
            0 => (
              const Color(0xFFFFA3D1),
              const Color(0xFFE8368F),
              const Color(0xFF8E1A55),
            ),
            1 => (
              const Color(0xFF8FF0C0),
              const Color(0xFF14A866),
              const Color(0xFF0B6B40),
            ),
            _ => (
              const Color(0xFFC79BFF),
              const Color(0xFF7B3FC4),
              const Color(0xFF4A2183),
            ),
          };
    final size = current ? 70.0 : 60.0;
    return GestureDetector(
      key: Key('level-${level.id}'),
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Level ${level.id}',
        excludeSemantics: true,
        child: SizedBox(
          width: 88,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (current)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => Container(
                    width: size + 18 + 14 * pulse.value,
                    height: size + 18 + 14 * pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: 0.5 * (1 - pulse.value),
                      ),
                    ),
                  ),
                ),
              // 3D base.
              Positioned(
                top: 44 - size / 2 + 6,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: edge,
                  ),
                ),
              ),
              Positioned(
                top: 44 - size / 2,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [top, bottom],
                    ),
                    border: Border.all(
                      color: current ? Palette.sun : Colors.white,
                      width: current ? 5 : 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55301040),
                        blurRadius: 6,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 4,
                        left: size * 0.18,
                        right: size * 0.18,
                        height: size * 0.3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(size),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.6),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      unlocked
                          ? GameText(
                              '${level.id}',
                              size: current ? 30 : 26,
                              stroke: edge,
                            )
                          : const GameIcon(GameIcons.lock, size: 34),
                    ],
                  ),
                ),
              ),
              if (unlocked && stars > 0)
                Positioned(
                  top: -12,
                  child: StarRow(stars: stars, size: 22, arc: true),
                ),
              if (level.hard && unlocked)
                Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE01E3C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const GameText(
                      'HARD',
                      size: 11,
                      family: 'Fredoka',
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              if (current)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => Positioned(
                    top: -44 - 8 * sin(pulse.value * 2 * pi).abs(),
                    child: const _Marker(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "You are here" pin with a paint drop.
class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(40, 48), painter: _MarkerPainter());
}

class _MarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final pin = Path()
      ..moveTo(w / 2, size.height)
      ..cubicTo(w * 0.1, size.height * 0.6, 0, size.height * 0.45, 0, w / 2)
      ..arcToPoint(Offset(w, w / 2), radius: Radius.circular(w / 2))
      ..cubicTo(
        w,
        size.height * 0.45,
        w * 0.9,
        size.height * 0.6,
        w / 2,
        size.height,
      )
      ..close();
    canvas.drawPath(
      pin.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x55301040),
    );
    canvas.drawPath(pin, Paint()..color = Colors.white);
    canvas.drawPath(
      pin,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Palette.plum,
    );
    TileArt.paint(
      canvas,
      Offset(w / 2, w / 2),
      w * 0.3,
      color: TileColor.red,
      special: Special.none,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
