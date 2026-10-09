import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/scope.dart';
import '../core/level.dart';
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

class _MapScreenState extends State<MapScreen> {
  static const spacing = 96.0;
  static const headerHeight = 90.0;
  final _scroll = ScrollController();
  Timer? _clock;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Only rebuild while a life is refilling, to show the countdown.
      if (AppScope.read(context).app.nextLifeIn != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openLevel(LevelDef level) async {
    final app = AppScope.read(context).app;
    if (!app.isUnlocked(level.id)) return;
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

  /// Layout: list of (y from bottom, level) with episode headers in between.
  double _yOf(int index, int episode) =>
      40 + index * spacing + (episode + 1) * headerHeight;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final episodes = scope.levels.episodes;
    final levels = scope.levels.levels;
    final total = levels.isEmpty
        ? 400.0
        : _yOf(levels.length - 1, episodes.length - 1) + spacing + 60;

    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final current = min(app.data.unlocked, levels.length) - 1;
        final ep = current < 0 ? 0 : levels[current].episode;
        final y =
            _yOf(max(0, current), ep) -
            _scroll.position.viewportDimension * 0.4;
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
                  final nodes = <Widget>[];
                  final points = <Offset>[];
                  double headerBottom(int e) =>
                      _yOf(levels.indexOf(episodes[e].levels.first), e) - 116;
                  for (final e in episodes) {
                    final bgBottom = e.index == 0
                        ? 0.0
                        : headerBottom(e.index) - 8;
                    final bgTop = e.index + 1 < episodes.length
                        ? headerBottom(e.index + 1) - 8
                        : total;
                    nodes.add(
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: bgBottom,
                        height: bgTop - bgBottom,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: Palette.episode(e.index),
                            ),
                          ),
                        ),
                      ),
                    );
                    nodes.add(
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: headerBottom(e.index),
                        height: 64,
                        child: _EpisodeBanner(index: e.index, name: e.name),
                      ),
                    );
                  }
                  for (var i = 0; i < levels.length; i++) {
                    final l = levels[i];
                    final x = w / 2 + sin(i * 0.85) * w * 0.27;
                    final y = _yOf(i, l.episode);
                    points.add(Offset(x, total - y));
                    nodes.add(
                      Positioned(
                        left: x - 32,
                        bottom: y - 32,
                        child: _LevelNode(
                          level: l,
                          stars: app.starsFor(l.id),
                          unlocked: app.isUnlocked(l.id),
                          current: l.id == app.data.unlocked,
                          onTap: () => _openLevel(l),
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: total,
                    child: Stack(
                      children: [
                        ...nodes.take(episodes.length * 2),
                        Positioned.fill(
                          child: CustomPaint(painter: _PathPainter(points)),
                        ),
                        ...nodes.skip(episodes.length * 2),
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
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppState app;
  const _TopBar({required this.app});

  @override
  Widget build(BuildContext context) {
    final next = app.nextLifeIn;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Pill(
              icon: const Icon(Icons.favorite, color: Colors.pink),
              text: next == null
                  ? '${app.lives} Full'
                  : '${app.lives}  ${formatDuration(next)}',
              textKey: const Key('lives'),
              onTap: app.lives < AppState.maxLives
                  ? () => showOutOfLives(context)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: Pill(
              icon: const Icon(Icons.monetization_on, color: Colors.amber),
              text: '${app.coins}',
              textKey: const Key('coins'),
            ),
          ),
          const Spacer(),
          Flexible(
            flex: 2,
            child: Pill(
              icon: const Icon(Icons.star_rounded, color: Colors.amber),
              text: '${app.totalStars}',
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.white.withValues(alpha: 0.9),
            shape: const CircleBorder(),
            child: IconButton(
              key: const Key('settings'),
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeBanner extends StatelessWidget {
  final int index;
  final String name;
  const _EpisodeBanner({required this.index, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF4A148C).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'EPISODE ${index + 1}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
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
  final VoidCallback onTap;

  const _LevelNode({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !unlocked
        ? Colors.grey.shade400
        : level.hard
        ? const Color(0xFFD32F2F)
        : const Color(0xFF7B1FA2);
    return GestureDetector(
      key: Key('level-${level.id}'),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 84,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: current ? const Color(0xFFFFEB3B) : Colors.white,
                  width: current ? 5 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: current ? 14 : 4,
                    color: current ? Colors.yellow : Colors.black26,
                  ),
                ],
              ),
              child: unlocked
                  ? Text(
                      '${level.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : const Icon(Icons.lock, color: Colors.white),
            ),
            if (unlocked) StarRow(stars: stars, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> points;
  _PathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      const dots = 6;
      for (var k = 1; k < dots; k++) {
        canvas.drawCircle(Offset.lerp(a, b, k / dots)!, 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.points != points;
}
