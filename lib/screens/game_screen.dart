import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/audio.dart';
import '../app/scope.dart';
import '../core/board.dart';
import '../core/level.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../game/board_view.dart';
import '../game/game_controller.dart';
import '../ui/art_cache.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';
import 'dialogs.dart';

/// Plays one level. In [testMode] (from the level editor) nothing is saved:
/// no lives, coins, stars or boosters are used.
class GameScreen extends StatefulWidget {
  final LevelDef level;
  final bool testMode;
  final int? seed;

  /// Pre-level boosters chosen on the level start card.
  final Set<BoosterType> preBoosters;

  const GameScreen({
    super.key,
    required this.level,
    this.testMode = false,
    this.seed,
    this.preBoosters = const {},
  });

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  static int _alive = 0;

  late final GameSession session;
  late final GameController controller;
  late final AppScope _scope;

  BoosterType? activeBooster;
  Pos? freeSwapFirst;
  Hint? hint;
  Timer? _hintTimer;
  bool _finaleStarted = false;
  bool _ended = false;
  bool _dialogOpen = false;
  bool _adUsed = false;
  bool _failed = false;

  AppState get app => _scope.app;
  GameAudio get audio => _scope.audio;
  LevelDef get level => widget.level;

  @override
  void initState() {
    super.initState();
    _alive++;
    _scope = AppScope.read(context);
    session = GameSession(level, seed: widget.seed);
    for (final b in widget.preBoosters) {
      final special = switch (b) {
        BoosterType.startLine =>
          Random().nextBool() ? Special.lineH : Special.lineV,
        BoosterType.startBomb => Special.bomb,
        BoosterType.startPrism => Special.prism,
        _ => null,
      };
      if (special == null) continue;
      if (session.board.placeSpecial(special) != null && !widget.testMode) {
        app.useBooster(b, level.id);
      }
    }
    controller = GameController(session);
    controller.onIdle = _onIdle;
    controller.addListener(_onController);
    if (!widget.testMode) app.startLevel(level.id);
    audio.music(Music.game);
    _restartHintTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
  }

  @override
  void dispose() {
    _alive--;
    if (_alive == 0) audio.music(Music.map);
    _hintTimer?.cancel();
    controller.removeListener(_onController);
    controller.onIdle = null;
    controller.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  bool get busy => controller.animating || _dialogOpen || _ended;

  // ------------------------------------------------------------- tutorial

  Future<void> _showTutorial() async {
    if (!mounted) return;
    final text = level.tutorial;
    final seen = !widget.testMode && app.data.tutorialsSeen.contains(level.id);
    if (text != null && !seen) {
      _dialogOpen = true;
      await showTutorialCard(context, level);
      _dialogOpen = false;
      if (!widget.testMode) app.markTutorialSeen(level.id);
    }
    if (mounted) audio.sfx(Sfx.start);
    _restartHintTimer();
  }

  // ---------------------------------------------------------------- hints

  void _restartHintTimer() {
    _hintTimer?.cancel();
    if (hint != null) setState(() => hint = null);
    if (!app.data.hints) return;
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || busy || session.status != SessionStatus.playing) return;
      setState(() => hint = session.board.findHint());
    });
  }

  // ---------------------------------------------------------------- input

  void _play(MoveOutcome o) {
    if (o.steps.isEmpty) return;
    controller.play(o.steps);
    _restartHintTimer();
  }

  void onSwipe(Pos a, Pos b) {
    if (busy) return;
    if (activeBooster != null) {
      if (activeBooster == BoosterType.freeSwap) {
        _useBooster(BoosterType.freeSwap, session.freeSwap(a, b));
      }
      return;
    }
    _play(session.swipe(a, b));
  }

  void onTap(Pos p) {
    if (busy) return;
    switch (activeBooster) {
      case BoosterType.brush:
        _useBooster(BoosterType.brush, session.brush(p));
      case BoosterType.colorSplash:
        _useBooster(BoosterType.colorSplash, session.colorSplash(p));
      case BoosterType.freeSwap:
        if (session.board.tileAt(p) == null) return;
        final first = freeSwapFirst;
        if (first == null) {
          audio.sfx(Sfx.click);
          setState(() => freeSwapFirst = p);
        } else if (first == p) {
          setState(() => freeSwapFirst = null);
        } else {
          _useBooster(BoosterType.freeSwap, session.freeSwap(first, p));
        }
      case BoosterType.gravityFlip:
      case BoosterType.startLine:
      case BoosterType.startBomb:
      case BoosterType.startPrism:
        break;
      case null:
        final t = session.board.tileAt(p);
        if (app.data.tapActivate && t != null && t.special != Special.none) {
          _play(session.tapSpecial(p));
        }
    }
  }

  void _useBooster(BoosterType type, MoveOutcome o) {
    if (o.steps.isEmpty) return;
    if (!widget.testMode) app.useBooster(type, level.id);
    audio.sfx(Sfx.booster);
    setState(() {
      activeBooster = null;
      freeSwapFirst = null;
    });
    _play(o);
  }

  Future<void> _selectBooster(BoosterType type) async {
    if (busy) return;
    audio.sfx(Sfx.click);
    if (activeBooster == type) {
      setState(() {
        activeBooster = null;
        freeSwapFirst = null;
      });
      return;
    }
    if (!widget.testMode && app.boosterCount(type) <= 0) {
      final buy = await confirm(
        context,
        'Get ${type.label}',
        'Buy one ${type.label} for ${AppState.boosterCost} coins?',
        ok: 'Buy',
      );
      if (!buy || !mounted) return;
      if (!app.buyBooster(type)) {
        await confirm(
          context,
          'Not enough coins',
          'Win levels to earn more coins!',
          ok: 'OK',
          cancel: 'Close',
        );
        return;
      }
      audio.sfx(Sfx.coin);
    }
    if (type == BoosterType.gravityFlip) {
      _dialogOpen = true;
      final g = await showGravityPicker(context, session.board.gravity);
      _dialogOpen = false;
      if (g != null && mounted) {
        _useBooster(type, session.flipGravity(g));
        audio.sfx(Sfx.gravity);
      }
      return;
    }
    setState(() {
      activeBooster = type;
      freeSwapFirst = null;
      hint = null;
    });
  }

  // ------------------------------------------------------------- end game

  void _onIdle() {
    // Never open dialogs from inside the animation tick.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEnd());
    if (mounted) _restartHintTimer();
  }

  Future<void> _checkEnd() async {
    if (!mounted || _ended || _dialogOpen || controller.animating) return;
    switch (session.status) {
      case SessionStatus.playing:
        return;
      case SessionStatus.won:
        if (!_finaleStarted) {
          _finaleStarted = true;
          final steps = session.finale();
          if (steps.isNotEmpty) {
            audio.sfx(Sfx.praise);
            // The finale is a reward, not a wait: play it fast.
            controller.speed = 2.2;
            controller.play(steps);
            return;
          }
        }
        _ended = true;
        await _showWin();
      case SessionStatus.outOfMoves:
        await _showOutOfMoves();
    }
  }

  Future<void> _showWin() async {
    final score = session.score;
    final stars = session.starsFor(score);
    final reward = widget.testMode
        ? null
        : app.completeLevel(level.id, stars, score, session.movesLeft);
    final next = _scope.levels.byId(level.id + 1);
    audio.sfx(Sfx.win);
    _dialogOpen = true;
    final choice = await showWinDialog(
      context,
      stars: stars,
      score: score,
      reward: reward,
      hasNext: next != null,
      testMode: widget.testMode,
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (choice == 'next' && next != null) {
      await _openLevel(next);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openLevel(LevelDef next) async {
    final nav = Navigator.of(context);
    if (app.lives <= 0 && !await showOutOfLives(context)) {
      if (mounted) nav.pop();
      return;
    }
    if (!mounted) return;
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: next, testMode: widget.testMode),
      ),
    );
  }

  Future<void> _showOutOfMoves() async {
    final cost = AppState.extraMovesCost(session.extraMovesBought);
    audio.sfx(Sfx.lose, volume: 0.7);
    _dialogOpen = true;
    final choice = await showOutOfMovesDialog(
      context,
      goals: session.progress(),
      cost: cost,
      canAfford: app.coins >= cost,
      adAvailable: !_adUsed,
      testMode: widget.testMode,
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'coins':
        if (widget.testMode || app.spendCoins(cost)) {
          if (!widget.testMode) {
            app.logAndSave('extra_moves', {'level': level.id, 'cost': cost});
          }
          audio.sfx(Sfx.coin);
          setState(() => session.addMoves(5));
          _restartHintTimer();
        }
      case 'ad':
        final ok = await _scope.ads.showRewarded(context, reward: '+5 moves');
        if (!mounted) return;
        if (ok) {
          _adUsed = true;
          if (!widget.testMode) {
            app.logAndSave('ad_reward', {'reward': 'moves', 'level': level.id});
          }
          audio.sfx(Sfx.booster);
          setState(() => session.addMoves(5));
          _restartHintTimer();
        } else {
          await _showOutOfMoves();
        }
      default:
        await _fail('out_of_moves');
    }
  }

  Future<void> _fail(String reason) async {
    _ended = true;
    if (!widget.testMode && !_failed) {
      _failed = true;
      app.failLevel(level.id, reason: reason);
    }
    if (reason == 'quit') {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _dialogOpen = true;
    final retry = await showFailDialog(
      context,
      livesLeft: app.lives,
      testMode: widget.testMode,
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (retry) {
      await _openLevel(level);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pause() async {
    if (_dialogOpen || _ended) return;
    final willLose = !widget.testMode && session.movesUsed > 0;
    _dialogOpen = true;
    final quit = await showPauseDialog(context, willLose: willLose);
    _dialogOpen = false;
    if (!mounted) return;
    if (quit) {
      controller.finishAll();
      if (willLose) {
        await _fail('quit');
      } else {
        _ended = true;
        Navigator.of(context).pop();
      }
    } else {
      _restartHintTimer();
    }
  }

  /// Plays the hinted move. Used by tests and the integration smoke test.
  @visibleForTesting
  bool playHintMove() {
    if (busy || session.status != SessionStatus.playing) return false;
    final h = session.board.findHint();
    if (h == null) return false;
    if (h.a == h.b) {
      _play(session.tapSpecial(h.a));
    } else {
      _play(session.swipe(h.a, h.b));
    }
    return true;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: PaintedBackground(
          theme: level.episode,
          child: SafeArea(
            child: Column(
              children: [
                _hud(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: BoardView(
                      key: const Key('board'),
                      controller: controller,
                      onSwipe: onSwipe,
                      onTap: onTap,
                      interactive: !busy,
                      hint: hint,
                      selected: freeSwapFirst,
                      haptics: app.data.haptics,
                      audio: audio,
                    ),
                  ),
                ),
                _boosterBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    final low =
        session.movesLeft <= 5 && session.status == SessionStatus.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RoundButton(
              GameIcons.pause,
              key: const Key('pause'),
              onTap: _pause,
              size: 48,
              label: 'Pause',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CachedDecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF1E3FF)],
                ),
                border: Border.all(color: Palette.plum, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55301040),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GameText(
                              widget.testMode
                                  ? 'Test level'
                                  : 'Level ${level.id}',
                              size: 16,
                              color: Palette.sun,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _GravityChip(
                          controller.shown.gravity,
                          shiftIn: controller.shown.shiftIn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final g in controller.goals)
                            GoalChip(progress: g, size: 44),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    _scoreBar(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _MovesBadge(moves: session.movesLeft, low: low),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar() {
    final s = level.stars;
    final top = s[2] * 1.08;
    final score = controller.score;
    final frac = (score / top).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: GameText('$score', key: const Key('score'), size: 18),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 34,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 10,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xAA3B1A63),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            // The gradient is cached at full width and
                            // revealed by a clip, so a moving fill does not
                            // render a new gradient every frame.
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: max(frac, 0.02)),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              builder: (context, f, child) => ClipRect(
                                clipper: _WidthClipper(f),
                                child: child,
                              ),
                              child: const SizedBox.expand(
                                child: CachedDecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFE14D),
                                        Color(0xFFFF8A1F),
                                        Color(0xFFFF4FA3),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final t in s)
                      Positioned(
                        left: (t / top).clamp(0.0, 1.0) * w - 16,
                        top: 2,
                        child: AnimatedScale(
                          scale: score >= t ? 1.15 : 0.9,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          child: GameIcon(
                            score >= t ? GameIcons.star : GameIcons.starEmpty,
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _boosterBar() {
    final active = activeBooster;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed height, so the board does not jump when a booster is
          // selected.
          SizedBox(
            height: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: active == null
                  ? const SizedBox.shrink()
                  : FittedBox(
                      key: ValueKey(active),
                      fit: BoxFit.scaleDown,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEE3B1A63),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Palette.sun, width: 2),
                        ),
                        child: Text(
                          active == BoosterType.freeSwap &&
                                  freeSwapFirst != null
                              ? 'Now tap the second tile.'
                              : active.help,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final b in BoosterInfo.inLevel)
                if (b != BoosterType.gravityFlip || level.usesGravity)
                  // Each button gets a third of the width and shrinks to fit
                  // on narrow phones.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _BoosterButton(
                        type: b,
                        count: widget.testMode ? 99 : app.boosterCount(b),
                        selected: active == b,
                        onTap: () => _selectBooster(b),
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GravityChip extends StatelessWidget {
  final Gravity gravity;

  /// Moves until a timed gravity shift (shown as a badge), if any.
  final int? shiftIn;
  const _GravityChip(this.gravity, {this.shiftIn});

  @override
  Widget build(BuildContext context) {
    final angle = switch (gravity) {
      Gravity.down => pi / 2,
      Gravity.up => -pi / 2,
      Gravity.left => pi,
      Gravity.right => 0.0,
    };
    final arrow = AnimatedRotation(
      turns: angle / (2 * pi),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutBack,
      child: const GameIcon(GameIcons.arrow, size: 22),
    );
    final n = shiftIn;
    return Tooltip(
      message: n == null
          ? 'Gravity ${gravity.name}'
          : 'Gravity turns in $n move${n == 1 ? '' : 's'}',
      child: n == null
          ? arrow
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                arrow,
                const SizedBox(width: 2),
                CountBadge('$n', key: const Key('gravity-timer')),
              ],
            ),
    );
  }
}

class _MovesBadge extends StatelessWidget {
  final int moves;
  final bool low;
  const _MovesBadge({required this.moves, required this.low});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: CachedDecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: low
                ? const [Color(0xFFFF8A8A), Color(0xFFE01E3C)]
                : const [Color(0xFFC79BFF), Color(0xFF7B3FC4)],
          ),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66301040),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'MOVES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            GameText('$moves', key: const Key('moves-left'), size: 30),
          ],
        ),
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  final BoosterType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _BoosterButton({
    required this.type,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (type) {
      BoosterType.brush => const [Color(0xFFFFA3D1), Color(0xFFE8368F)],
      BoosterType.freeSwap => const [Color(0xFF8FE3FF), Color(0xFF1F8EF0)],
      BoosterType.colorSplash => const [Color(0xFF9CF5B8), Color(0xFF1FB86B)],
      BoosterType.gravityFlip => const [Color(0xFFC79BFF), Color(0xFF6A3FD0)],
      _ => const [Color(0xFFFFE27A), Color(0xFFFF9F1C)],
    };
    return Semantics(
      button: true,
      label: type.label,
      child: GestureDetector(
        key: Key('booster-${type.name}'),
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CachedDecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: colors,
                        ),
                        border: Border.all(
                          color: selected ? Palette.sun : Colors.white,
                          width: selected ? 5 : 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: selected
                                ? const Color(0xAAFFE14D)
                                : const Color(0x66301040),
                            blurRadius: selected ? 16 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(child: boosterArt(type, size: 56)),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -4,
                    child: count > 0
                        ? CountBadge('$count')
                        : const CountBadge('+', color: Color(0xFF22B84C)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 104,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GameText(
                    type.label,
                    size: 15,
                    family: 'Fredoka',
                    strokeWidth: 3.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clips its child to the left [fraction] of its width.
class _WidthClipper extends CustomClipper<Rect> {
  final double fraction;
  _WidthClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WidthClipper old) => old.fraction != fraction;
}
