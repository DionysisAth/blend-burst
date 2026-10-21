// Captures the main screens in every language, to check translations fit,
// and lists any layout overflow.
//
//   flutter test tool/l10n/screens_test.dart --update-goldens
//   LANGS=el,de flutter test tool/l10n/screens_test.dart --update-goldens
//
// Pictures go to tool/l10n/shots/<language>/ (not committed).
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:io';

import 'package:blend_burst/app/economy.dart';
import 'package:blend_burst/app/scope.dart';
import 'package:blend_burst/l10n/l10n.dart';
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
  await (FontLoader(
    'LilitaFallback',
  )..addFont(f('assets/fonts/RoundedFallback-ExtraBold.ttf'))).load();
  await (FontLoader(
    'FredokaFallback',
  )..addFont(f('assets/fonts/RoundedFallback-Bold.ttf'))).load();
}

Future<void> run(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

String save(String lang) {
  final stars = {for (var i = 1; i <= 29; i++) '$i': 3};
  final s = stars.entries.map((e) => '"${e.key}": ${e.value}').join(',');
  return '{"unlocked": 30, "coins": 2450, "gold": 85, "lives": 3, '
      '"lifeClock": ${DateTime.now().millisecondsSinceEpoch}, '
      '"dailyLast": ${dayNumber(DateTime.now()) - 1}, "dailyStreak": 3, '
      '"language": "$lang", "stars": {$s}}';
}

void main() {
  final only = Platform.environment['LANGS'];
  final langs = only == null || only.isEmpty
      ? Lang.codes
      : only.split(',').map((s) => s.trim()).toList();

  for (final lang in langs) {
    testWidgets('screens in $lang', (tester) async {
      await tester.runAsync(loadFonts);
      final problems = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final what = d.exceptionAsString().split('\n').first;
        final where = d.informationCollector == null
            ? ''
            : d.informationCollector!()
                  .map((e) => e.toString())
                  .where((s) => s.contains('file://') || s.contains('Text'))
                  .take(3)
                  .join(' | ');
        problems.add('$what $where');
      };
      var n = 0;
      Future<void> shot(String name) async {
        n++;
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'shots/$lang/${n.toString().padLeft(2, '0')}_$name.png',
          ),
        );
      }

      Future<void> tap(Finder f, [int ms = 700]) async {
        if (f.evaluate().isEmpty) {
          problems.add('missing $f');
          return;
        }
        await tester.tap(f.first, warnIfMissed: false);
        await run(tester, ms);
      }

      // A small phone, where long words are most likely to overflow.
      SharedPreferences.setMockInitialValues({
        'blend_burst_save_v1': save(lang),
      });
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const BlendBurstApp());
      for (
        var i = 0;
        i < 60 && find.byType(MapScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await run(tester, 1200);
      // The daily gift pops up first.
      await shot('daily');
      await tap(find.byKey(const Key('daily-claim')), 900);
      await shot('daily_reward');
      await tap(find.byKey(const Key('reward-ok')));
      await shot('map');

      // Level card and tutorial (level 3 teaches blending).
      final node = find.byKey(const Key('level-3'));
      unawaited(Scrollable.ensureVisible(tester.element(node), alignment: 0.5));
      await run(tester, 400);
      await tap(node);
      await shot('level_card');
      await tap(find.byKey(const Key('play-level')), 900);
      await shot('tutorial');
      await tap(find.byKey(const Key('tutorial-ok')), 900);
      await shot('game');
      final g = tester.state<GameScreenState>(find.byType(GameScreen));
      await tap(find.byKey(const Key('pause')));
      await shot('pause');
      await tap(find.byKey(const Key('pause-resume')));
      // Out of moves.
      g.session.movesLeft = 0;
      g.setState(() {});
      await run(tester, 300);
      g.playHintMove();
      await run(tester, 3000);
      await shot('out_of_moves');
      await tap(find.byKey(const Key('give-up')), 1200);
      await shot('failed');
      await tap(find.byKey(const Key('fail-map')), 1200);

      for (final (key, name) in [
        ('side-shop', 'shop'),
        ('side-event', 'event'),
        ('side-pass', 'pass'),
      ]) {
        await tap(find.byKey(Key(key)));
        await shot(name);
        await tap(find.bySemanticsLabel(tr.back));
      }
      await tap(find.byKey(const Key('lives')));
      await shot('lives');
      await tap(find.text(tr.ok));
      await tap(find.byKey(const Key('settings')));
      await shot('settings');
      await tap(find.byKey(const Key('settings-language')));
      await shot('language');

      FlutterError.onError = previous;
      final scope = AppScope.read(tester.element(find.byType(MaterialApp)));
      expect(scope.app.data.language, lang);
      final out = File('tool/l10n/shots/$lang/problems.txt')
        ..createSync(recursive: true);
      out.writeAsStringSync(problems.join('\n'));
      if (problems.isNotEmpty) {
        // ignore: avoid_print
        print('$lang: ${problems.length} problems\n  ${problems.join('\n  ')}');
      }
    });
  }
}
