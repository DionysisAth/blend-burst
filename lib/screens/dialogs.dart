import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/audio.dart';
import '../app/scope.dart';
import '../core/level.dart';
import '../core/session.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';

int goalTarget(LevelDef level, Goal g) {
  if (g.type == GoalType.stains && g.target == 0) return level.stainCount;
  if (g.type == GoalType.glass && g.target == 0) return level.glassCount;
  return g.target;
}

/// A soft inset box used inside panels.
class InsetBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const InsetBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFFF3E4FF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD8BDF5), width: 2),
    ),
    child: child,
  );
}

// ------------------------------------------------------------- level start

Future<bool> showLevelStart(BuildContext context, LevelDef level) async {
  final scope = AppScope.read(context);
  final stars = scope.app.starsFor(level.id);
  final result = await showGameDialog<bool>(
    context,
    dismissible: true,
    builder: (ctx) => GamePanel(
      title: 'Level ${level.id}',
      ribbonColor: level.hard ? const Color(0xFFF0304E) : Palette.candyPink,
      onClose: () => Navigator.of(ctx).pop(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRow(stars: stars, size: 46, arc: true),
          const SizedBox(height: 6),
          GameText(level.name, size: 24, color: Palette.sun),
          if (level.hard) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0304E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const GameText(
                'HARD LEVEL',
                size: 16,
                stroke: Color(0xFF8A0F25),
              ),
            ),
          ],
          const SizedBox(height: 12),
          InsetBox(
            child: Column(
              children: [
                const Text(
                  'Goals',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Palette.plum,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    for (final g in level.goals)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          goalIcon(g, size: 46),
                          const SizedBox(height: 2),
                          GameText(
                            g.type == GoalType.score
                                ? '${goalTarget(level, g)}'
                                : 'x${goalTarget(level, g)}',
                            size: 18,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  level.goals
                      .map((g) => goalText(g, goalTarget(level, g)))
                      .join(' • '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GameIcon(GameIcons.swap, size: 26),
              const SizedBox(width: 6),
              GameText('${level.moves} moves', size: 20, color: Palette.sky),
            ],
          ),
          const SizedBox(height: 16),
          CandyButton.label(
            'Play',
            key: const Key('play-level'),
            onTap: () => Navigator.of(ctx).pop(true),
            icon: GameIcons.play,
            width: 220,
            fontSize: 28,
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

// --------------------------------------------------------------- tutorial

Future<void> showTutorialCard(BuildContext context, LevelDef level) async {
  await showGameDialog<void>(
    context,
    builder: (ctx) => GamePanel(
      title: 'New!',
      ribbonColor: Palette.sky,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameText(level.name, size: 24, color: Palette.sun),
          const SizedBox(height: 12),
          if (level.tutorialArt != null) ...[
            InsetBox(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: TutorialArt(level.tutorialArt),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            level.tutorial ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Palette.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          CandyButton.label(
            'Got it!',
            key: const Key('tutorial-ok'),
            colors: CandyColors.blue,
            onTap: () => Navigator.of(ctx).pop(),
            width: 200,
          ),
        ],
      ),
    ),
  );
}

// -------------------------------------------------------------------- win

Future<String?> showWinDialog(
  BuildContext context, {
  required int stars,
  required int score,
  LevelReward? reward,
  required bool hasNext,
  required bool testMode,
}) {
  return showGameDialog<String>(
    context,
    builder: (ctx) => _WinPanel(
      stars: stars,
      score: score,
      reward: reward,
      hasNext: hasNext,
      testMode: testMode,
    ),
  );
}

class _WinPanel extends StatefulWidget {
  final int stars;
  final int score;
  final LevelReward? reward;
  final bool hasNext;
  final bool testMode;
  const _WinPanel({
    required this.stars,
    required this.score,
    this.reward,
    required this.hasNext,
    required this.testMode,
  });

  @override
  State<_WinPanel> createState() => _WinPanelState();
}

class _WinPanelState extends State<_WinPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();
  final _played = <int>{};
  GameAudio? _audio;

  @override
  void initState() {
    super.initState();
    _audio = AppScope.read(context).audio;
    _c.addListener(() {
      for (var i = 0; i < widget.stars; i++) {
        if (_c.value >= 0.25 + i * 0.18 && _played.add(i)) _audio?.star(i);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GamePanel(
          title: 'Level complete!',
          ribbonColor: const Color(0xFF22B84C),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              Widget star(int i, double size) {
                final start = 0.25 + i * 0.18;
                final t = ((v - start) / 0.2).clamp(0.0, 1.0);
                final earned = i < widget.stars;
                final scale = earned ? Curves.elasticOut.transform(t) : 1.0;
                return Transform.scale(
                  scale: earned ? (0.2 + 0.8 * scale) : 1,
                  child: Transform.rotate(
                    angle: earned ? (1 - t) * 0.8 : 0,
                    child: GameIcon(
                      earned && t > 0 ? GameIcons.star : GameIcons.starEmpty,
                      size: size,
                    ),
                  ),
                );
              }

              final shown =
                  (widget.score *
                          Curves.easeOut.transform((v / 0.7).clamp(0.0, 1.0)))
                      .round();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      star(0, 64),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: star(1, 84),
                      ),
                      star(2, 64),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Palette.plum,
                      fontSize: 14,
                    ),
                  ),
                  GameText('$shown', size: 40, color: Palette.sun),
                  if (widget.reward != null) ...[
                    const SizedBox(height: 8),
                    InsetBox(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GameIcon(GameIcons.coin, size: 34),
                            const SizedBox(width: 6),
                            GameText('+${widget.reward!.coins}', size: 24),
                            if (widget.reward!.booster != null) ...[
                              const SizedBox(width: 18),
                              GameIcon(
                                boosterIcon(widget.reward!.booster!),
                                size: 34,
                              ),
                              const SizedBox(width: 4),
                              const GameText('+1', size: 24),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CandyButton.label(
                          widget.testMode ? 'Editor' : 'Map',
                          key: const Key('win-map'),
                          colors: CandyColors.blue,
                          icon: GameIcons.map,
                          onTap: () => Navigator.of(context).pop('map'),
                        ),
                      ),
                      if (!widget.testMode && widget.hasNext) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: CandyButton.label(
                            'Next',
                            key: const Key('win-next'),
                            icon: GameIcons.play,
                            onTap: () => Navigator.of(context).pop('next'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const Positioned.fill(top: -200, child: Confetti()),
      ],
    );
  }
}

GameIcons boosterIcon(BoosterType t) => switch (t) {
  BoosterType.brush => GameIcons.brush,
  BoosterType.freeSwap => GameIcons.swap,
  BoosterType.colorSplash => GameIcons.splash,
};

// ------------------------------------------------------------ out of moves

Future<String?> showOutOfMovesDialog(
  BuildContext context, {
  required List<GoalProgress> goals,
  required int cost,
  required bool canAfford,
  required bool adAvailable,
  required bool testMode,
}) {
  return showGameDialog<String>(
    context,
    builder: (ctx) => GamePanel(
      title: 'Out of moves!',
      ribbonColor: const Color(0xFFFF8A1F),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameText('So close!', size: 30, color: Palette.sun),
          const SizedBox(height: 10),
          InsetBox(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final g in goals) GoalChip(progress: g, size: 44),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CandyButton(
            key: const Key('buy-moves'),
            colors: CandyColors.yellow,
            onTap: testMode || canAfford
                ? () => Navigator.of(ctx).pop('coins')
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameText('+5 moves', size: 24, stroke: Color(0xFFC06E00)),
                if (!testMode) ...[
                  const SizedBox(width: 10),
                  const GameIcon(GameIcons.coin, size: 28),
                  const SizedBox(width: 2),
                  GameText('$cost', size: 22, stroke: const Color(0xFFC06E00)),
                ],
              ],
            ),
          ),
          if (adAvailable) ...[
            const SizedBox(height: 10),
            CandyButton.label(
              'Watch ad: +5',
              key: const Key('ad-moves'),
              colors: CandyColors.blue,
              icon: GameIcons.video,
              onTap: () => Navigator.of(ctx).pop('ad'),
            ),
          ],
          const SizedBox(height: 10),
          CandyButton.label(
            'Give up',
            key: const Key('give-up'),
            colors: CandyColors.red,
            height: 44,
            fontSize: 20,
            onTap: () => Navigator.of(ctx).pop('quit'),
          ),
        ],
      ),
    ),
  );
}

// -------------------------------------------------------------- failed

Future<bool> showFailDialog(
  BuildContext context, {
  required int livesLeft,
  required bool testMode,
}) async {
  final r = await showGameDialog<bool>(
    context,
    builder: (ctx) => GamePanel(
      title: 'Level failed',
      ribbonColor: const Color(0xFF8A47E8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIcons.heartBroken, size: 90),
          const SizedBox(height: 6),
          GameText(
            testMode ? 'Try again?' : 'You lost a life',
            size: 26,
            color: Palette.sun,
          ),
          if (!testMode) ...[
            const SizedBox(height: 6),
            Text(
              'Lives left: $livesLeft',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Palette.plum,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CandyButton.label(
                  testMode ? 'Editor' : 'Map',
                  key: const Key('fail-map'),
                  colors: CandyColors.blue,
                  icon: GameIcons.map,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CandyButton.label(
                  'Retry',
                  key: const Key('fail-retry'),
                  icon: GameIcons.retry,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return r ?? false;
}

// ---------------------------------------------------------------- pause

Future<bool> showPauseDialog(
  BuildContext context, {
  required bool willLose,
}) async {
  final r = await showGameDialog<bool>(
    context,
    builder: (ctx) => GamePanel(
      title: 'Paused',
      ribbonColor: Palette.grape,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SoundToggles(),
          const SizedBox(height: 14),
          CandyButton.label(
            'Resume',
            key: const Key('pause-resume'),
            icon: GameIcons.play,
            onTap: () => Navigator.of(ctx).pop(false),
            width: 230,
          ),
          const SizedBox(height: 10),
          CandyButton.label(
            willLose ? 'Quit (-1 life)' : 'Quit',
            key: const Key('pause-quit'),
            colors: CandyColors.red,
            height: 46,
            fontSize: 20,
            onTap: () => Navigator.of(ctx).pop(true),
            width: 230,
          ),
        ],
      ),
    ),
  );
  return r ?? false;
}

/// Music / sound / vibration toggle buttons.
class SoundToggles extends StatelessWidget {
  const SoundToggles({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    Widget toggle(
      GameIcons icon,
      String label,
      bool on,
      void Function(bool) set,
    ) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            RoundButton(
              icon,
              label: label,
              colors: on ? CandyColors.purple : CandyColors.gray,
              size: 58,
              onTap: () => set(!on),
            ),
            if (!on)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _SlashPainter()),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Palette.plum,
          ),
        ),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final t in [
          toggle(GameIcons.music, 'Music', app.data.music, (v) {
            app.setMusic(v);
            scope.audio.setMusic(v);
          }),
          toggle(GameIcons.sound, 'Sound', app.data.sound, (v) {
            app.setSound(v);
            scope.audio.setSound(v);
          }),
          toggle(
            GameIcons.vibrate,
            'Vibrate',
            app.data.haptics,
            app.setHaptics,
          ),
        ])
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, child: t),
          ),
      ],
    );
  }
}

class _SlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF0304E);
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.2),
      Offset(size.width * 0.78, size.height * 0.72),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------- lives

/// Offers ways to get lives back. Returns true if the player now has a life.
Future<bool> showOutOfLives(BuildContext context) async {
  final scope = AppScope.read(context);
  final result = await showGameDialog<bool>(
    context,
    dismissible: true,
    builder: (_) => const _OutOfLivesPanel(),
  );
  return (result ?? false) || scope.app.lives > 0;
}

class _OutOfLivesPanel extends StatefulWidget {
  const _OutOfLivesPanel();

  @override
  State<_OutOfLivesPanel> createState() => _OutOfLivesPanelState();
}

class _OutOfLivesPanelState extends State<_OutOfLivesPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final next = app.nextLifeIn;
    final full = next == null;
    return GamePanel(
      title: full ? 'Lives' : 'More lives',
      ribbonColor: const Color(0xFFF0304E),
      onClose: () => Navigator.of(context).pop(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 110,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const GameIcon(GameIcons.heart, size: 100),
                GameText('${app.lives}', size: 38),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (full)
            const GameText('Your lives are full!', size: 22, color: Palette.sun)
          else ...[
            const Text(
              'Next life in',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Palette.plum,
                fontSize: 16,
              ),
            ),
            GameText(formatDuration(next), size: 34, color: Palette.sun),
          ],
          const SizedBox(height: 14),
          if (!full) ...[
            CandyButton(
              colors: CandyColors.yellow,
              onTap: app.coins >= AppState.refillCost
                  ? () {
                      if (app.buyRefill()) {
                        scope.audio.sfx(Sfx.coin);
                        Navigator.of(context).pop(true);
                      }
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameText('Refill', size: 24, stroke: Color(0xFFC06E00)),
                  const SizedBox(width: 10),
                  const GameIcon(GameIcons.coin, size: 28),
                  const SizedBox(width: 2),
                  const GameText(
                    '${AppState.refillCost}',
                    size: 22,
                    stroke: Color(0xFFC06E00),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            CandyButton.label(
              'Watch ad: +1 life',
              colors: CandyColors.blue,
              icon: GameIcons.video,
              fontSize: 20,
              onTap: () async {
                final nav = Navigator.of(context);
                final ok = await scope.ads.showRewarded(
                  context,
                  reward: '+1 life',
                );
                if (ok) {
                  app.addLives(1);
                  app.logAndSave('ad_reward', {'reward': 'life'});
                  nav.pop(true);
                }
              },
            ),
          ] else
            CandyButton.label(
              'OK',
              onTap: () => Navigator.of(context).pop(false),
              width: 180,
            ),
        ],
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'OK',
  String cancel = 'Cancel',
}) async {
  final r = await showGameDialog<bool>(
    context,
    dismissible: true,
    builder: (ctx) => GamePanel(
      title: title,
      ribbonColor: Palette.grape,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Palette.ink,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: CandyButton.label(
                  cancel,
                  colors: CandyColors.gray,
                  fontSize: 20,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CandyButton.label(
                  ok,
                  fontSize: 20,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return r ?? false;
}
