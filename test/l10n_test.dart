import 'dart:io';

import 'package:blend_burst/app/economy.dart';
import 'package:blend_burst/app/scope.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/l10n/l10n.dart';
import 'package:blend_burst/main.dart';
import 'package:blend_burst/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> boot(WidgetTester tester, {String? language}) async {
  SharedPreferences.setMockInitialValues({
    'blend_burst_save_v1':
        '{"unlocked": 5, "dailyLast": ${dayNumber(DateTime.now())}'
        '${language == null ? '' : ', "language": "$language"'}}',
  });
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const BlendBurstApp());
  for (var i = 0; i < 50 && find.byType(MapScreen).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await run(tester, 300);
}

AppStrings strings(String code) => lookupAppStrings(Locale(code));

void main() {
  tearDown(() => Lang.use(const Locale('en')));

  test('every translation file is compiled in and listed', () {
    final files = Directory('lib/l10n')
        .listSync()
        .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?.group(1))
        .whereType<String>()
        .toSet();
    expect(Lang.codes.toSet(), files);
  });

  test('every language has every text', () {
    for (final code in Lang.codes) {
      final t = strings(code);
      expect(t.localeName, code);
      expect(Lang.names[code], isNotNull);
      for (final s in [t.play, t.settings, t.levelN(7), t.dlgMoves(5)]) {
        expect(s.trim(), isNotEmpty, reason: code);
      }
      if (code != 'en') {
        expect(t.settings, isNot(strings('en').settings), reason: code);
      }
    }
  });

  test('the phone language is used unless one is chosen', () {
    expect(Lang.resolve(null, const [Locale('de', 'AT')]), const Locale('de'));
    expect(
      Lang.resolve(null, const [Locale('sv'), Locale('el', 'GR')]),
      const Locale('el'),
    );
    expect(Lang.resolve(null, const [Locale('sv')]), const Locale('en'));
    expect(Lang.resolve('ja', const [Locale('de')]), const Locale('ja'));
    expect(Lang.resolve('xx', const [Locale('fr')]), const Locale('fr'));
  });

  testWidgets('starts in the phone language', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await boot(tester);
    expect(tr.localeName, 'fr');
    expect(find.text(strings('fr').mapShop), findsOneWidget);
    expect(find.text(strings('fr').episode1), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a language picked in Settings applies at once', (tester) async {
    await boot(tester);
    expect(find.text('Shop'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings')));
    await run(tester, 600);
    await tester.tap(find.byKey(const Key('settings-language')));
    await run(tester, 600);
    await tester.tap(find.byKey(const Key('lang-el')));
    await run(tester, 800);
    final el = strings('el');
    expect(find.text(el.settings), findsWidgets);
    final app = AppScope.read(tester.element(find.byType(MaterialApp))).app;
    expect(app.data.language, 'el');
    // Back on the map, the side buttons and the world name are Greek too.
    await tester.tap(find.bySemanticsLabel(el.back));
    await run(tester, 600);
    expect(find.text(el.mapShop), findsOneWidget);
    expect(find.text(el.episode1), findsOneWidget);
    // Back to the phone language.
    app.setLanguage(null);
    await run(tester, 600);
    expect(find.text('Shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chosen language is kept after a restart', (tester) async {
    await boot(tester, language: 'de');
    expect(tr.localeName, 'de');
    expect(find.text(strings('de').mapShop), findsOneWidget);
    expect(TileColor.red.label, strings('de').colorRed);
  });
}
