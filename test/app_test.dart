import 'dart:async';

import 'package:blend_burst/app/app_state.dart';
import 'package:blend_burst/app/economy.dart';
import 'package:blend_burst/app/scope.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/core/session.dart';
import 'package:blend_burst/game/board_view.dart';
import 'package:blend_burst/main.dart';
import 'package:blend_burst/screens/editor_screen.dart';
import 'package:blend_burst/screens/game_screen.dart';
import 'package:blend_burst/screens/map_screen.dart';
import 'package:blend_burst/ui/game_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps frames for [ms] milliseconds of fake time.
Future<void> run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Every level unlocked; today's daily gift is already claimed so it does
/// not pop up over the map.
final unlockedAll = <String, Object>{
  'blend_burst_save_v1':
      '{"unlocked": 120, "lives": 5, "coins": 500, '
      '"dailyLast": ${dayNumber(DateTime.now())}, "dailyStreak": 1}',
};

Future<void> boot(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(1080, 2340),
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const BlendBurstApp());
  // Asset loading happens outside fake time.
  for (var i = 0; i < 50 && find.byType(MapScreen).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(MapScreen), findsOneWidget);
  await run(tester, 300);
}

Future<GameScreenState> openLevel(WidgetTester tester, int id) async {
  final node = find.byKey(Key('level-$id'));
  // Center it so the top bar does not cover it.
  unawaited(Scrollable.ensureVisible(tester.element(node), alignment: 0.5));
  await run(tester, 300);
  await tester.tap(node);
  await run(tester, 400);
  await tester.ensureVisible(find.byKey(const Key('play-level')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('play-level')));
  await run(tester, 600);
  expect(find.byType(GameScreen), findsOneWidget);
  if (find.byKey(const Key('tutorial-ok')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('tutorial-ok')));
    await run(tester, 800);
  }
  return tester.state<GameScreenState>(find.byType(GameScreen));
}

/// Pumps until [finder] shows up (or [ms] of fake time pass).
Future<bool> waitFor(
  WidgetTester tester,
  Finder finder, {
  int ms = 20000,
}) async {
  for (var t = 0; t < ms; t += 50) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 50));
  }
  return finder.evaluate().isNotEmpty;
}

/// Plays hint moves until the level is won, buying extra moves when needed.
Future<void> playToWin(WidgetTester tester, GameScreenState game) async {
  for (var i = 0; i < 200; i++) {
    for (var w = 0; w < 200 && game.busy; w++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(const Key('buy-moves')).evaluate().isNotEmpty) break;
    }
    if (find.byKey(const Key('buy-moves')).evaluate().isNotEmpty) {
      game.app.addCoins(1000);
      await tester.pump();
      await tester.tap(find.byKey(const Key('buy-moves')));
      await run(tester, 300);
      continue;
    }
    if (game.session.status == SessionStatus.won) break;
    if (!game.playHintMove()) await run(tester, 200);
    await run(tester, 100);
  }
}

void main() {
  testWidgets('app boots to the map with 120 levels', (tester) async {
    await boot(tester);
    expect(find.text('Art Studio'), findsOneWidget);
    expect(find.byKey(const Key('level-1')), findsOneWidget);
    expect(find.byKey(const Key('lives')), findsOneWidget);
    // The CI smoke test finds these through Android accessibility.
    expect(find.bySemanticsLabel('Level 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping on the board makes a move', (tester) async {
    await boot(tester);
    final game = await openLevel(tester, 1);
    expect(find.bySemanticsLabel('Game board'), findsOneWidget);
    final hint = game.session.board.findHint()!;
    final box = tester.getRect(find.byKey(const Key('board')));
    final g = BoardGeometry.fit(box.size, game.level.rows, game.level.cols);
    Offset at(Pos p) => box.topLeft + g.center(p.r.toDouble(), p.c.toDouble());
    final moves = game.session.movesLeft;
    await tester.dragFrom(at(hint.a), at(hint.b) - at(hint.a));
    await run(tester, 3000);
    expect(game.session.movesLeft, moves - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level 1 can be won and unlocks level 2', (tester) async {
    await boot(tester);
    final game = await openLevel(tester, 1);
    await playToWin(tester, game);
    expect(game.session.status, SessionStatus.won);
    expect(await waitFor(tester, find.text('Level complete!')), isTrue);
    await tester.tap(find.byKey(const Key('win-next')));
    await run(tester, 800);
    expect(find.byType(GameScreen), findsOneWidget);
    final app = tester.state<GameScreenState>(find.byType(GameScreen)).app;
    expect(app.isUnlocked(2), isTrue);
    expect(app.starsFor(1), greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('running out of moves offers extra moves, then costs a life', (
    tester,
  ) async {
    await boot(tester, prefs: unlockedAll);
    // Level 15 (lots of stains) cannot be finished by a single move.
    final game = await openLevel(tester, 15);
    game.session.movesLeft = 1;
    // Make a plain move that does not finish the level.
    game.playHintMove();
    await run(tester, 6000);
    expect(game.session.status, SessionStatus.outOfMoves);
    expect(find.text('Out of moves!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy-moves')));
    await run(tester, 600);
    expect(game.session.movesLeft, 5);
    expect(game.app.coins, 500 - 300);
    game.session.movesLeft = 1;
    game.playHintMove();
    await run(tester, 6000);
    if (game.session.status == SessionStatus.outOfMoves) {
      await tester.tap(find.byKey(const Key('give-up')));
      await run(tester, 600);
      expect(find.text('Level failed'), findsOneWidget);
      expect(game.app.lives, AppState.maxLives - 1);
      await tester.tap(find.byKey(const Key('fail-map')));
      await run(tester, 800);
      expect(find.byType(MapScreen), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('boosters work and do not use moves', (tester) async {
    await boot(tester, prefs: unlockedAll);
    // Level 15 has many stains, so boosters alone cannot finish it.
    final game = await openLevel(tester, 15);
    final moves = game.session.movesLeft;
    final box = tester.getRect(find.byKey(const Key('board')));
    final g = BoardGeometry.fit(box.size, game.level.rows, game.level.cols);
    Offset at(int r, int c) =>
        box.topLeft + g.center(r.toDouble(), c.toDouble());

    Future<void> settle() async {
      for (var w = 0; w < 600 && game.busy; w++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.tap(find.byKey(const Key('booster-brush')));
    await run(tester, 200);
    await tester.tapAt(at(4, 4));
    await run(tester, 200);
    await settle();

    await tester.tap(find.byKey(const Key('booster-colorSplash')));
    await run(tester, 200);
    await tester.tapAt(at(2, 3));
    await run(tester, 200);
    await settle();

    await tester.tap(find.byKey(const Key('booster-freeSwap')));
    await run(tester, 200);
    await tester.tapAt(at(0, 0));
    await run(tester, 200);
    await tester.tapAt(at(7, 7));
    await run(tester, 200);
    await settle();

    expect(game.session.movesLeft, moves);
    expect(game.app.boosterCount(BoosterType.brush), 2);
    expect(game.app.boosterCount(BoosterType.colorSplash), 2);
    expect(game.app.boosterCount(BoosterType.freeSwap), 2);
    expect(game.session.board.checkInvariants(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a level with a tutorial shows it every time it starts', (
    tester,
  ) async {
    await boot(tester, prefs: unlockedAll);
    for (var round = 0; round < 2; round++) {
      final node = find.byKey(const Key('level-2'));
      unawaited(Scrollable.ensureVisible(tester.element(node), alignment: 0.5));
      await run(tester, 300);
      await tester.tap(node);
      await run(tester, 400);
      await tester.tap(find.byKey(const Key('play-level')));
      await run(tester, 600);
      expect(
        find.byKey(const Key('tutorial-ok')),
        findsOneWidget,
        reason: 'round $round',
      );
      await tester.tap(find.byKey(const Key('tutorial-ok')));
      await run(tester, 800);
      await tester.tap(find.byKey(const Key('pause')));
      await run(tester, 400);
      await tester.tap(find.byKey(const Key('pause-quit')));
      await run(tester, 1000);
      expect(find.byType(MapScreen), findsOneWidget);
    }
  });

  testWidgets('quitting mid-level costs a life', (tester) async {
    await boot(tester);
    final game = await openLevel(tester, 1);
    game.playHintMove();
    await run(tester, 3000);
    await tester.tap(find.byKey(const Key('pause')));
    await run(tester, 400);
    await tester.tap(find.byKey(const Key('pause-quit')));
    await run(tester, 1000);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    final lives = tester.widget<Text>(find.byKey(const Key('lives'))).data!;
    expect(lives, startsWith('${AppState.maxLives - 1} '));
    expect(tester.takeException(), isNull);
  });

  testWidgets('every level opens and plays a few moves', (tester) async {
    // A small 320dp-wide phone, to catch layout overflows. The list covers
    // every level that shows a tutorial card.
    await boot(tester, prefs: unlockedAll, size: const Size(880, 1760));
    for (final id in [
      1, 2, 3, 4, 5, 6, 7, 9, 11, 16, 18, 21, 25, 31, 32, 33, 34, 40, //
      41, 42, 43, 46, 48, 61, 76, 91, 96, 106, 120, //
    ]) {
      final game = await openLevel(tester, id);
      for (var i = 0; i < 3; i++) {
        for (var w = 0; w < 100 && game.busy; w++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        game.playHintMove();
        await run(tester, 200);
      }
      await run(tester, 4000);
      expect(game.session.board.checkInvariants(), isNull, reason: 'level $id');
      // Leave via the pause menu, or whatever end dialog or ad break is
      // showing (a quick win can land on the every-3rd-win ad break).
      for (
        var t = 0;
        t < 40 && find.byType(GameScreen).evaluate().isNotEmpty;
        t++
      ) {
        final exit = [
          'ad-done',
          'reward-ok',
          'win-map',
          'fail-map',
          'pause-quit',
        ].map((k) => find.byKey(Key(k))).where((f) => f.evaluate().isNotEmpty);
        if (exit.isNotEmpty) {
          final f = exit.first;
          if (tester.widget<CandyButton>(f).onTap != null) await tester.tap(f);
        } else if (find.byKey(const Key('pause')).evaluate().isNotEmpty &&
            !game.busy) {
          await tester.tap(find.byKey(const Key('pause')));
        }
        await run(tester, 500);
      }
      await run(tester, 600);
      expect(find.byType(MapScreen), findsOneWidget, reason: 'level $id');
      // Refill lives so the next level can start.
      final app = AppScope.read(tester.element(find.byType(MapScreen))).app;
      app.addLives(5);
      await run(tester, 200);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the daily gift pops up and can be claimed', (tester) async {
    await boot(
      tester,
      prefs: const {
        'blend_burst_save_v1': '{"unlocked": 10, "lives": 5, "coins": 100}',
      },
    );
    await run(tester, 600);
    expect(find.text('Daily Gift'), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-claim')));
    await run(tester, 800);
    await tester.tap(find.byKey(const Key('reward-ok')));
    await run(tester, 800);
    final app = AppScope.read(tester.element(find.byType(MapScreen))).app;
    expect(app.coins, 100 + dailyRewards[0].coins);
    expect(app.daily.claimable, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shop, event and season pass open and work', (tester) async {
    // A small phone, to catch overflows.
    await boot(tester, prefs: unlockedAll, size: const Size(880, 1760));
    final app = AppScope.read(tester.element(find.byType(MapScreen))).app;
    final gold = app.gold;
    await tester.tap(find.byKey(const Key('side-shop')));
    await run(tester, 600);
    expect(find.text('Shop'), findsWidgets);
    // A test purchase of a gold pack.
    await tester.scrollUntilVisible(
      find.byKey(const Key('buy-gold50')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await run(tester, 300);
    await tester.tap(find.byKey(const Key('buy-gold50')));
    await run(tester, 600);
    await tester.tap(find.byKey(const Key('store-confirm')));
    await run(tester, 800);
    await tester.tap(find.byKey(const Key('reward-ok')));
    await run(tester, 600);
    expect(app.gold, gold + 50);
    // Spend gold on unlimited lives.
    await tester.scrollUntilVisible(
      find.byKey(const Key('buy-unl30')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await run(tester, 300);
    await tester.tap(find.byKey(const Key('buy-unl30')));
    await run(tester, 800);
    await tester.tap(find.byKey(const Key('reward-ok')));
    await run(tester, 600);
    expect(app.hasUnlimited, isTrue);
    expect(app.gold, gold + 50 - 30);
    await tester.tap(find.bySemanticsLabel('Back'));
    await run(tester, 600);

    app.addEventTiles({app.event.colorName: WeeklyEvent.tiers[0]});
    await tester.tap(find.byKey(const Key('side-event')));
    await run(tester, 600);
    await tester.tap(find.text('Claim').first);
    await run(tester, 800);
    await tester.tap(find.byKey(const Key('reward-ok')));
    await run(tester, 600);
    expect(app.eventClaimable, 0);
    await tester.tap(find.bySemanticsLabel('Back'));
    await run(tester, 600);

    app.data.seasonPoints = Season.pointsPerTier;
    await tester.tap(find.byKey(const Key('side-pass')));
    await run(tester, 600);
    await tester.tap(find.byKey(const Key('season-0-f')));
    await run(tester, 800);
    await tester.tap(find.byKey(const Key('reward-ok')));
    await run(tester, 600);
    expect(app.seasonClaimed(0, premium: false), isTrue);
    await tester.tap(find.byKey(const Key('pass-unlock')));
    await run(tester, 600);
    await tester.tap(find.byKey(const Key('store-confirm')));
    await run(tester, 800);
    expect(app.premiumPass, isTrue);
    await tester.tap(find.byKey(const Key('season-0-p')));
    await run(tester, 800);
    await tester.tap(find.byKey(const Key('reward-ok')));
    await run(tester, 600);
    expect(app.seasonClaimed(0, premium: true), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings, analytics and the level editor open', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('side-ranks')));
    await run(tester, 600);
    expect(find.textContaining('not set up'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await run(tester, 600);
    await tester.tap(find.byKey(const Key('settings')));
    await run(tester, 600);
    expect(find.text('Settings'), findsOneWidget);
    // Play Games is not set up in tests: the card says so.
    expect(find.text('Google Play Games'), findsOneWidget);
    expect(find.byKey(const Key('cloud-sign-in')), findsNothing);
    await tester.tap(find.byKey(const Key('cloud-leaderboards')));
    await run(tester, 600);
    expect(find.textContaining('not set up'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await run(tester, 600);
    await tester.scrollUntilVisible(
      find.text('Analytics'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await run(tester, 300);
    await tester.tap(find.text('Analytics'));
    await run(tester, 600);
    expect(find.text('Key metrics'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await run(tester, 600);
    await tester.scrollUntilVisible(
      find.text('Level editor'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await run(tester, 300);
    await tester.tap(find.text('Level editor'));
    await run(tester, 600);
    expect(find.byType(EditorScreen), findsOneWidget);
    // Paint some stains, then play-test the level.
    await tester.tap(find.text('Stain'));
    await run(tester, 100);
    final grid = find.byType(CustomPaint).first;
    await tester.tap(grid);
    await run(tester, 100);
    await tester.tap(find.byTooltip('Play test'));
    await run(tester, 800);
    expect(find.byType(GameScreen), findsOneWidget);
    final game = tester.state<GameScreenState>(find.byType(GameScreen));
    expect(game.widget.testMode, isTrue);
    game.playHintMove();
    await run(tester, 3000);
    expect(tester.takeException(), isNull);
  });
}
