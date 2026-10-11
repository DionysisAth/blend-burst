// Captures the raw Play Store screenshots (1080x1920) from the real game.
//
//   flutter test tool/store/shots_test.dart --update-goldens
//   python3 tool/store/compose.py     # adds captions -> store/screenshots/
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:io';

import 'package:blend_burst/app/economy.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/main.dart';
import 'package:blend_burst/screens/game_screen.dart';
import 'package:blend_burst/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  Future<ByteData> f(String p) async =>
      ByteData.view(File(p).readAsBytesSync().buffer);
  await (FontLoader(
    'Lilita',
  )..addFont(f('assets/fonts/LilitaOne-Regular.ttf'))).load();
  await (FontLoader('Fredoka')
        ..addFont(f('assets/fonts/Fredoka-Medium.ttf'))
        ..addFont(f('assets/fonts/Fredoka-SemiBold.ttf'))
        ..addFont(f('assets/fonts/Fredoka-Bold.ttf')))
      .load();
}

Future<void> run(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> shot(WidgetTester t, String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('raw/$name.png'));

String save() {
  final stars = {for (var i = 1; i <= 79; i++) '$i': i % 4 == 0 ? 2 : 3};
  final s = stars.entries.map((e) => '"${e.key}": ${e.value}').join(',');
  return '{"unlocked": 80, "coins": 2450, "gold": 85, '
      '"dailyLast": ${dayNumber(DateTime.now())}, "dailyStreak": 3, '
      '"tutorialsSeen": [${List.generate(120, (i) => i + 1).join(',')}], '
      '"stars": {$s}}';
}

Future<GameScreenState> openLevel(WidgetTester tester, int id) async {
  final node = find.byKey(Key('level-$id'));
  unawaited(Scrollable.ensureVisible(tester.element(node), alignment: 0.5));
  await run(tester, 400);
  await tester.tap(node);
  await run(tester, 500);
  await tester.tap(find.byKey(const Key('play-level')));
  await run(tester, 700);
  if (find.byKey(const Key('tutorial-ok')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('tutorial-ok')));
    await run(tester, 800);
  }
  return tester.state<GameScreenState>(find.byType(GameScreen));
}

Future<void> leave(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pause')));
  await run(tester, 500);
  await tester.tap(find.byKey(const Key('pause-quit')));
  await run(tester, 1200);
}

void main() {
  testWidgets('store screenshots', (tester) async {
    await tester.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({'blend_burst_save_v1': save()});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    await tester.pumpWidget(const BlendBurstApp());
    for (var i = 0; i < 60 && find.byType(MapScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run(tester, 1500);
    await shot(tester, '1_map');

    // Specials on a glass level.
    var g = await openLevel(tester, 27);
    for (final s in [
      Special.lineH,
      Special.lineV,
      Special.bomb,
      Special.prism,
      Special.lineV,
    ]) {
      g.session.board.placeSpecial(s);
    }
    g.controller.shown = g.session.board.snapshot();
    g.setState(() {});
    await run(tester, 600);
    await shot(tester, '2_specials');
    await leave(tester);

    // A big cascade on a chained level.
    g = await openLevel(tester, 54);
    g.session.board.placeSpecial(Special.bomb);
    g.session.board.placeSpecial(Special.lineH);
    g.controller.shown = g.session.board.snapshot();
    g.setState(() {});
    await run(tester, 300);
    g.playHintMove();
    await run(tester, 450);
    await shot(tester, '3_cascade');
    await run(tester, 4000);
    await leave(tester);

    // Ink, glass and chains.
    g = await openLevel(tester, 74);
    g.session.board.placeSpecial(Special.whiteBurst);
    g.session.board.placeSpecial(Special.prism);
    g.controller.shown = g.session.board.snapshot();
    g.setState(() {});
    await run(tester, 600);
    await shot(tester, '4_obstacles');
    await leave(tester);

    await tester.tap(find.byKey(const Key('side-shop')));
    await run(tester, 1200);
    await shot(tester, '5_shop');
    await tester.tap(find.bySemanticsLabel('Back'));
    await run(tester, 1000);

    await tester.tap(find.byKey(const Key('side-pass')));
    await run(tester, 1200);
    await shot(tester, '6_pass');
  });
}
