import 'dart:async';

import 'package:blend_burst/app/app_state.dart';
import 'package:blend_burst/app/scope.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/core/session.dart';
import 'package:blend_burst/game/board_view.dart';
import 'package:blend_burst/main.dart';
import 'package:blend_burst/screens/editor_screen.dart';
import 'package:blend_burst/screens/game_screen.dart';
import 'package:blend_burst/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps frames for [ms] milliseconds of fake time.
Future<void> run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const unlockedAll = {
  'blend_burst_save_v1': '{"unlocked": 40, "lives": 5, "coins": 500}',
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
  testWidgets('app boots to the map with 40 levels', (tester) async {
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
      // Leave via the pause menu (or whatever end dialog is showing).
      if (find.byKey(const Key('pause-quit')).evaluate().isEmpty &&
          find.byKey(const Key('win-map')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('pause')));
        await run(tester, 400);
      }
      if (find.byKey(const Key('win-map')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('win-map')));
      } else {
        await tester.tap(find.byKey(const Key('pause-quit')));
      }
      await run(tester, 1000);
      expect(find.byType(MapScreen), findsOneWidget, reason: 'level $id');
      // Refill lives so the next level can start.
      final app = AppScope.read(tester.element(find.byType(MapScreen))).app;
      app.addLives(5);
      await run(tester, 200);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings, analytics and the level editor open', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('settings')));
    await run(tester, 600);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Analytics'));
    await run(tester, 600);
    expect(find.textContaining('Sessions'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await run(tester, 600);
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
