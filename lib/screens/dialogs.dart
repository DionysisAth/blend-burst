import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/audio.dart';
import '../app/economy.dart';
import '../app/scope.dart';
import '../core/level.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../ui/art_cache.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';
import 'live_ops_screens.dart';

int goalTarget(LevelDef level, Goal g) {
  if (g.target > 0 && g.type != GoalType.locks) return g.target;
  switch (g.type) {
    case GoalType.stains:
      return level.stainCount;
    case GoalType.glass:
      return level.glassCount;
    case GoalType.drop:
      return level.buckets;
    case GoalType.locks:
    case GoalType.ink:
      // Chains count each link (gold locks have two): ask a fresh board.
      return GameSession(
        level,
        seed: 0,
      ).progress().firstWhere((p) => p.goal.type == g.type).target;
    default:
      return g.target;
  }
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

/// Shows the level card. Returns the chosen pre-level boosters when the
/// player taps Play, or null if they close it.
/// Shows the level card. [bonus] are free starting boosters from the win
/// streak. Returns the chosen pre-level boosters, or null if closed.
Future<Set<BoosterType>?> showLevelStart(
  BuildContext context,
  LevelDef level, {
  Set<BoosterType> bonus = const {},
  int streak = 0,
}) async {
  final scope = AppScope.read(context);
  final stars = scope.app.starsFor(level.id);
  final chosen = <BoosterType>{};
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
          if (bonus.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StreakStrip(streak: streak, bonus: bonus),
          ],
          // Pre-level boosters, once the basics have been taught.
          if (level.id >= 6) ...[
            const SizedBox(height: 12),
            _PreBoosters(chosen: chosen),
          ],
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
  return result == true ? chosen : null;
}

/// "Win streak!" strip with the free boosters it earned.
class _StreakStrip extends StatelessWidget {
  final int streak;
  final Set<BoosterType> bonus;
  const _StreakStrip({required this.streak, required this.bonus});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('streak-bonus'),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A1F), Color(0xFFFF4FA3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: GameText('Win streak $streak!  Free:', size: 18),
            ),
          ),
          const SizedBox(width: 6),
          for (final b in bonus) ...[
            boosterArt(b, size: 34),
            const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _PreBoosters extends StatefulWidget {
  final Set<BoosterType> chosen;
  const _PreBoosters({required this.chosen});

  @override
  State<_PreBoosters> createState() => _PreBoostersState();
}

class _PreBoostersState extends State<_PreBoosters> {
  Future<void> _toggle(BoosterType t) async {
    final scope = AppScope.read(context);
    final app = scope.app;
    scope.audio.sfx(Sfx.click);
    if (widget.chosen.remove(t)) {
      setState(() {});
      return;
    }
    if (app.boosterCount(t) <= 0) {
      final buy = await confirm(
        context,
        'Get ${t.label}',
        '${t.help} Buy one for ${AppState.boosterCost} coins?',
        ok: 'Buy',
      );
      if (!buy || !mounted) return;
      if (!app.buyBooster(t)) {
        await confirm(
          context,
          'Not enough coins',
          'Win levels to earn more coins!',
          ok: 'OK',
          cancel: 'Close',
        );
        return;
      }
      scope.audio.sfx(Sfx.coin);
    }
    setState(() => widget.chosen.add(t));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Start with',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Palette.plum,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final t in BoosterInfo.preLevel)
              Semantics(
                button: true,
                selected: widget.chosen.contains(t),
                label: 'Start with ${t.label}',
                child: GestureDetector(
                  key: Key('pre-${t.name}'),
                  onTap: () => _toggle(t),
                  child: _PreBoosterChip(
                    type: t,
                    count: app.boosterCount(t),
                    selected: widget.chosen.contains(t),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PreBoosterChip extends StatelessWidget {
  final BoosterType type;
  final int count;
  final bool selected;
  const _PreBoosterChip({
    required this.type,
    required this.count,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.1 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CachedDecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? const Color(0xFFFFF3B0)
                      : const Color(0xFFF3E4FF),
                  border: Border.all(
                    color: selected ? Palette.sun : const Color(0xFFD8BDF5),
                    width: selected ? 5 : 3,
                  ),
                ),
                child: Center(child: boosterArt(type, size: 46)),
              ),
            ),
            Positioned(
              right: -4,
              top: -4,
              child: selected
                  ? Container(
                      width: 28,
                      height: 28,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22B84C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const GameIcon(GameIcons.check),
                    )
                  : count > 0
                  ? CountBadge('$count')
                  : const CountBadge('+', color: Color(0xFF22B84C)),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- gravity picker

/// Lets the player choose where tiles fall during their next move.
Future<Gravity?> showGravityPicker(BuildContext context, Gravity current) {
  Widget arrow(BuildContext ctx, Gravity g) {
    final angle = switch (g) {
      Gravity.down => pi / 2,
      Gravity.up => -pi / 2,
      Gravity.left => pi,
      Gravity.right => 0.0,
    };
    final isCurrent = g == current;
    return Semantics(
      button: true,
      label: 'Fall ${g.name}',
      child: GestureDetector(
        key: Key('flip-${g.name}'),
        onTap: isCurrent ? null : () => Navigator.of(ctx).pop(g),
        child: Opacity(
          opacity: isCurrent ? 0.35 : 1,
          child: Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6A3FD0),
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Transform.rotate(
              angle: angle,
              child: const GameIcon(GameIcons.arrow, size: 44),
            ),
          ),
        ),
      ),
    );
  }

  return showGameDialog<Gravity>(
    context,
    dismissible: true,
    builder: (ctx) => GamePanel(
      title: 'Gravity Flip',
      ribbonColor: Palette.grape,
      onClose: () => Navigator.of(ctx).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Where should tiles fall during your next move?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Palette.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          arrow(ctx, Gravity.up),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              arrow(ctx, Gravity.left),
              const SizedBox(width: 78),
              arrow(ctx, Gravity.right),
            ],
          ),
          arrow(ctx, Gravity.down),
        ],
      ),
    ),
  );
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
  VoidCallback? onShare,
}) {
  return showGameDialog<String>(
    context,
    builder: (ctx) => _WinPanel(
      stars: stars,
      score: score,
      reward: reward,
      hasNext: hasNext,
      testMode: testMode,
      onShare: onShare,
    ),
  );
}

class _WinPanel extends StatefulWidget {
  final int stars;
  final int score;
  final LevelReward? reward;
  final bool hasNext;
  final bool testMode;
  final VoidCallback? onShare;
  const _WinPanel({
    required this.stars,
    required this.score,
    this.reward,
    required this.hasNext,
    required this.testMode,
    this.onShare,
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
                              boosterArt(widget.reward!.booster!),
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
                  if (widget.onShare != null) ...[
                    const SizedBox(height: 10),
                    CandyButton.label(
                      'Share',
                      key: const Key('win-share'),
                      colors: CandyColors.purple,
                      icon: GameIcons.gift,
                      height: 44,
                      fontSize: 20,
                      width: 160,
                      onTap: widget.onShare,
                    ),
                  ],
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

/// The picture of a booster: a drawn icon, or for pre-level boosters the
/// special tile the level starts with.
Widget boosterArt(BoosterType t, {double size = 34}) => switch (t) {
  BoosterType.brush => GameIcon(GameIcons.brush, size: size),
  BoosterType.freeSwap => GameIcon(GameIcons.swap, size: size),
  BoosterType.colorSplash => GameIcon(GameIcons.splash, size: size),
  BoosterType.gravityFlip => GameIcon(GameIcons.gravity, size: size),
  BoosterType.startLine => MiniTile(
    color: TileColor.blue,
    special: Special.lineH,
    size: size,
  ),
  BoosterType.startBomb => MiniTile(
    color: TileColor.red,
    special: Special.bomb,
    size: size,
  ),
  BoosterType.startPrism => MiniTile(special: Special.prism, size: size),
};

// ------------------------------------------------------------ out of moves

Future<String?> showOutOfMovesDialog(
  BuildContext context, {
  required List<GoalProgress> goals,
  required int cost,
  required bool canAfford,
  int goldCost = 0,
  bool canAffordGold = false,
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
          if (!testMode && goldCost > 0) ...[
            const SizedBox(height: 10),
            CandyButton(
              key: const Key('gold-moves'),
              colors: CandyColors.purple,
              onTap: canAffordGold ? () => Navigator.of(ctx).pop('gold') : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameText('+5 moves', size: 24),
                  const SizedBox(width: 10),
                  const GameIcon(GameIcons.gold, size: 28),
                  const SizedBox(width: 2),
                  GameText('$goldCost', size: 22),
                ],
              ),
            ),
          ],
          if (adAvailable) ...[
            const SizedBox(height: 10),
            CandyButton.label(
              'Watch ad: +3',
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
  return (result ?? false) || scope.app.canPlay;
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
    final unlimited = app.unlimitedLeft;
    Future<void> buyGold(String id) async {
      final p = productById(id);
      final nav = Navigator.of(context);
      if (app.buyWithCurrency(p)) {
        scope.audio.sfx(Sfx.coin);
        nav.pop(true);
        return;
      }
      final shop = await confirm(
        context,
        'Not enough gold',
        'Get gold in the shop?',
        ok: 'Shop',
        cancel: 'Close',
      );
      if (shop && context.mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ShopScreen()));
        if (context.mounted) setState(() {});
      }
    }

    Widget goldButton(String key, GameIcons icon, String text, String id) =>
        CandyButton(
          key: Key(key),
          colors: CandyColors.purple,
          height: 50,
          onTap: () => buyGold(id),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 28),
              const SizedBox(width: 4),
              GameText(text, size: 20),
              const SizedBox(width: 8),
              const GameIcon(GameIcons.gold, size: 24),
              const SizedBox(width: 2),
              GameText(productById(id).priceLabel, size: 20),
            ],
          ),
        );

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
          if (unlimited != null) ...[
            const GameIcon(GameIcons.unlimited, size: 40),
            const GameText('Unlimited lives!', size: 24, color: Palette.sun),
            GameText(formatDuration(unlimited), size: 30, color: Palette.sky),
          ] else if (full)
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
          if (!full && unlimited == null) ...[
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
            const SizedBox(height: 10),
            goldButton('gold-refill', GameIcons.heart, 'Refill', 'refill'),
            const SizedBox(height: 10),
            goldButton(
              'gold-unlimited',
              GameIcons.unlimited,
              '30 min',
              'unl30',
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
