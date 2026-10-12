// On-device smoke test, run on an Android emulator in CI:
//   flutter test integration_test/app_test.dart
// Boots the real app, plays level 1 with real swipes, uses a booster,
// leaves the level and visits settings, the editor, the shop, the event and
// the season pass, and schedules (then cancels) a reminder notification.
import 'package:blend_burst/app/notifications.dart';
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
import 'package:integration_test/integration_test.dart';

Future<void> run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> waitFor(WidgetTester tester, Finder f, {int ms = 30000}) async {
  for (var t = 0; t < ms; t += 100) {
    if (f.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return f.evaluate().isNotEmpty;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot, play level 1, use a booster, quit, open tools', (
    tester,
  ) async {
    installErrorHandlers();
    await tester.pumpWidget(const BlendBurstApp());
    expect(
      await waitFor(tester, find.byType(MapScreen)),
      isTrue,
      reason: 'map never appeared',
    );
    await run(tester, 1000);

    final node = find.byKey(const Key('level-1'));
    await Scrollable.ensureVisible(tester.element(node), alignment: 0.5);
    await run(tester, 500);
    await tester.tap(node);
    expect(await waitFor(tester, find.byKey(const Key('play-level'))), isTrue);
    await tester.ensureVisible(find.byKey(const Key('play-level')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('play-level')));
    expect(await waitFor(tester, find.byType(GameScreen)), isTrue);
    await run(tester, 800);
    if (find.byKey(const Key('tutorial-ok')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('tutorial-ok')));
      await run(tester, 800);
    }

    final game = tester.state<GameScreenState>(find.byType(GameScreen));
    final box = tester.getRect(find.byKey(const Key('board')));
    final g = BoardGeometry.fit(box.size, game.level.rows, game.level.cols);
    Offset at(Pos p) => box.topLeft + g.center(p.r.toDouble(), p.c.toDouble());

    // Three real swipes on the board.
    for (var i = 0; i < 3; i++) {
      for (var w = 0; w < 100 && game.busy; w++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (game.session.status != SessionStatus.playing) break;
      final h = game.session.board.findHint();
      if (h == null || h.a == h.b) break;
      final moves = game.session.movesLeft;
      await tester.timedDragFrom(
        at(h.a),
        at(h.b) - at(h.a),
        const Duration(milliseconds: 250),
      );
      await run(tester, 2500);
      expect(
        game.session.movesLeft,
        lessThan(moves),
        reason: 'swipe ${h.a}->${h.b} did not register',
      );
    }

    // The brush booster.
    if (game.session.status == SessionStatus.playing) {
      for (var w = 0; w < 100 && game.busy; w++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const Key('booster-brush')));
      await run(tester, 300);
      await tester.tapAt(at(const Pos(4, 4)));
      await run(tester, 3000);
    }
    expect(game.session.board.checkInvariants(), isNull);

    // Leave the level (pause menu, or the end dialog if the level ended).
    await run(tester, 2000);
    if (find.byKey(const Key('win-map')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('win-map')));
    } else {
      if (find.byKey(const Key('give-up')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('give-up')));
        expect(
          await waitFor(tester, find.byKey(const Key('fail-map'))),
          isTrue,
        );
        await tester.tap(find.byKey(const Key('fail-map')));
      } else {
        await tester.tap(find.byKey(const Key('pause')));
        expect(
          await waitFor(tester, find.byKey(const Key('pause-quit'))),
          isTrue,
        );
        await tester.tap(find.byKey(const Key('pause-quit')));
      }
    }
    expect(await waitFor(tester, find.byType(MapScreen)), isTrue);
    await run(tester, 1000);

    // Play Games is not set up in this build: the Ranks button explains
    // that instead of calling it.
    // Where Play Games can't start (no Google Play services), the Ranks
    // button explains that instead of calling it. Where it can, tapping it
    // would open Google's sign-in screen, so only check it is there.
    final cloud = AppScope.read(tester.element(find.byType(MapScreen))).cloud;
    expect(find.byKey(const Key('side-ranks')), findsOneWidget);
    if (cloud != null && !cloud.available) {
      await tester.tap(find.byKey(const Key('side-ranks')));
      expect(await waitFor(tester, find.textContaining('not set up')), isTrue);
      await tester.tap(find.text('OK'));
      await run(tester, 800);
    }

    await tester.tap(find.byKey(const Key('settings')));
    expect(await waitFor(tester, find.text('Google Play Games')), isTrue);
    await tester.scrollUntilVisible(
      find.text('Level editor'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await run(tester, 500);
    await tester.tap(find.text('Level editor'));
    expect(await waitFor(tester, find.byType(EditorScreen)), isTrue);
    await run(tester, 1000);
    await tester.pageBack();
    await run(tester, 800);
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(await waitFor(tester, find.byType(MapScreen)), isTrue);
    await run(tester, 800);

    for (final key in ['side-shop', 'side-event', 'side-pass']) {
      await tester.tap(find.byKey(Key(key)));
      await run(tester, 1500);
      expect(find.bySemanticsLabel('Back'), findsWidgets, reason: key);
      await tester.tap(find.bySemanticsLabel('Back').last);
      expect(await waitFor(tester, find.byType(MapScreen)), isTrue);
      await run(tester, 800);
    }

    // The notification plugin works on the device (no permission is needed
    // to schedule; it only shows once the player allows it).
    final notifier = LocalNotifier();
    await tester.runAsync(
      () => notifier.schedule([
        Reminder(
          9,
          'Test',
          'Integration test reminder',
          DateTime.now().add(const Duration(hours: 5)),
        ),
      ]),
    );
    await tester.runAsync(notifier.cancelAll);
  });
}
