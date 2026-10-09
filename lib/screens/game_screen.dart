import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/scope.dart';
import '../core/board.dart';
import '../core/level.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../game/board_view.dart';
import '../game/game_controller.dart';
import '../ui/tile_art.dart';
import '../ui/widgets.dart';
import 'dialogs.dart';

/// Plays one level. In [testMode] (from the level editor) nothing is saved:
/// no lives, coins, stars or boosters are used.
class GameScreen extends StatefulWidget {
  final LevelDef level;
  final bool testMode;
  final int? seed;

  const GameScreen({
    super.key,
    required this.level,
    this.testMode = false,
    this.seed,
  });

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
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
  LevelDef get level => widget.level;

  @override
  void initState() {
    super.initState();
    _scope = AppScope.read(context);
    session = GameSession(level, seed: widget.seed);
    controller = GameController(session);
    controller.onIdle = _onIdle;
    controller.addListener(_onController);
    if (!widget.testMode) app.startLevel(level.id);
    _restartHintTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
  }

  @override
  void dispose() {
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
    final text = level.tutorial;
    if (!mounted || text == null) return;
    if (!widget.testMode && app.data.tutorialsSeen.contains(level.id)) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(level.name),
        content: Text(text, style: const TextStyle(fontSize: 17)),
        actions: [
          FilledButton(
            key: const Key('tutorial-ok'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!widget.testMode) app.markTutorialSeen(level.id);
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
          setState(() => freeSwapFirst = p);
        } else if (first == p) {
          setState(() => freeSwapFirst = null);
        } else {
          _useBooster(BoosterType.freeSwap, session.freeSwap(first, p));
        }
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
    setState(() {
      activeBooster = null;
      freeSwapFirst = null;
    });
    _play(o);
  }

  Future<void> _selectBooster(BoosterType type) async {
    if (busy) return;
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
        'Out of ${type.label}',
        'Buy one ${type.label} for ${AppState.boosterCost} coins?',
        ok: 'Buy',
      );
      if (!buy || !mounted) return;
      if (!app.buyBooster(type)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Not enough coins')));
        return;
      }
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
    _dialogOpen = true;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Level complete!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarRow(stars: stars, size: 48),
            const SizedBox(height: 12),
            Text(
              'Score $score',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (reward != null) ...[
              const SizedBox(height: 8),
              Text('+${reward.coins} coins'),
              if (reward.booster != null)
                Text('Bonus: +1 ${reward.booster!.label}!'),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('win-map'),
            onPressed: () => Navigator.of(ctx).pop('map'),
            child: Text(widget.testMode ? 'Back to editor' : 'Map'),
          ),
          if (!widget.testMode && next != null)
            FilledButton(
              key: const Key('win-next'),
              onPressed: () => Navigator.of(ctx).pop('next'),
              child: const Text('Next level'),
            ),
        ],
      ),
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
    final goals = session.progress();
    _dialogOpen = true;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Out of moves!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('So close! Keep going?'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [for (final g in goals) GoalChip(progress: g)],
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('give-up'),
            onPressed: () => Navigator.of(ctx).pop('quit'),
            child: const Text('Give up'),
          ),
          if (!_adUsed)
            TextButton(
              key: const Key('ad-moves'),
              onPressed: () => Navigator.of(ctx).pop('ad'),
              child: const Text('Watch ad: +5'),
            ),
          FilledButton(
            key: const Key('buy-moves'),
            onPressed: widget.testMode || app.coins >= cost
                ? () => Navigator.of(ctx).pop('coins')
                : null,
            child: Text(
              widget.testMode ? '+5 moves' : '+5 moves ($cost coins)',
            ),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'coins':
        if (widget.testMode || app.spendCoins(cost)) {
          if (!widget.testMode) {
            app.logAndSave('extra_moves', {'level': level.id, 'cost': cost});
          }
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
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Level failed'),
        content: Text(
          widget.testMode
              ? 'Try again?'
              : 'You lost a life. Lives left: ${app.lives}',
        ),
        actions: [
          TextButton(
            key: const Key('fail-map'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(widget.testMode ? 'Back to editor' : 'Map'),
          ),
          FilledButton(
            key: const Key('fail-retry'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (retry == true) {
      await _openLevel(level);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pause() async {
    if (_dialogOpen || _ended) return;
    final willLose = !widget.testMode && session.movesUsed > 0;
    _dialogOpen = true;
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paused'),
        content: Text(
          willLose
              ? 'Quitting now costs a life.'
              : 'Take a break or leave the level.',
        ),
        actions: [
          TextButton(
            key: const Key('pause-quit'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(willLose ? 'Quit (-1 life)' : 'Quit'),
          ),
          FilledButton(
            key: const Key('pause-resume'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (quit == true) {
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
    final colors = Palette.episode(level.episode);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                _goalsRow(),
                _scoreBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: BoardView(
                      key: const Key('board'),
                      controller: controller,
                      onSwipe: onSwipe,
                      onTap: onTap,
                      interactive: !busy,
                      hint: hint,
                      selected: freeSwapFirst,
                      haptics: app.data.haptics,
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('pause'),
            onPressed: _pause,
            icon: const Icon(Icons.pause_circle_filled, size: 34),
            color: const Color(0xFF4A148C),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.testMode ? 'Test: ${level.name}' : 'Level ${level.id}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4A148C),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      _gravityIcon(controller.shown.gravity),
                      size: 16,
                      color: const Color(0xFF4A148C),
                    ),
                    Text(
                      ' Gravity ${controller.shown.gravity.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'MOVES',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${session.movesLeft}',
                  key: const Key('moves-left'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _gravityIcon(Gravity g) => switch (g) {
    Gravity.down => Icons.arrow_downward,
    Gravity.up => Icons.arrow_upward,
    Gravity.left => Icons.arrow_back,
    Gravity.right => Icons.arrow_forward,
  };

  Widget _goalsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [for (final g in controller.goals) GoalChip(progress: g)],
      ),
    );
  }

  Widget _scoreBar() {
    final s = level.stars;
    final top = s[2] * 1.1;
    final score = controller.score;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 26,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 8,
                  bottom: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (score / top).clamp(0.0, 1.0),
                      backgroundColor: Colors.white54,
                      color: const Color(0xFF7B1FA2),
                    ),
                  ),
                ),
                for (final t in s)
                  Positioned(
                    left: (t / top).clamp(0.0, 1.0) * w - 11,
                    top: 2,
                    child: Icon(
                      Icons.star_rounded,
                      size: 22,
                      color: score >= t ? Colors.amber : Colors.white,
                    ),
                  ),
                Positioned(
                  left: 0,
                  top: -2,
                  child: Text(
                    '$score',
                    key: const Key('score'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _boosterBar() {
    final active = activeBooster;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                active == BoosterType.freeSwap && freeSwapFirst != null
                    ? 'Now tap the second tile.'
                    : active.help,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A148C),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final b in BoosterType.values) _boosterButton(b)],
          ),
        ],
      ),
    );
  }

  Widget _boosterButton(BoosterType b) {
    final selected = activeBooster == b;
    final count = widget.testMode ? 99 : app.boosterCount(b);
    final icon = switch (b) {
      BoosterType.brush => Icons.brush,
      BoosterType.freeSwap => Icons.swap_horiz,
      BoosterType.colorSplash => Icons.format_color_fill,
    };
    return GestureDetector(
      key: Key('booster-${b.name}'),
      onTap: () => _selectBooster(b),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFEB3B)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFF57F17) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 30, color: const Color(0xFF6A1B9A)),
                Positioned(
                  right: -14,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: count > 0 ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count > 0 ? '$count' : '+',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              b.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
