// Records promo material from the real game: gameplay clips (30 fps, with a
// log of every sound effect) and full-resolution stills.
//
//   flutter test tool/store/promo_test.dart
//   python3 tool/store/promo.py      # builds the video and the poster pack
//
// Output goes to tool/store/promo/ (not committed).
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blend_burst/app/audio.dart';
import 'package:blend_burst/app/economy.dart';
import 'package:blend_burst/core/models.dart';
import 'package:blend_burst/main.dart';
import 'package:blend_burst/screens/game_screen.dart';
import 'package:blend_burst/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const out = 'tool/store/promo';
const fps = 30;
const videoScale = 1.4; // 411x731 logical -> 576x1024 pixels

/// Logs sound effects against the clip frame they started on.
class RecAudio implements GameAudio {
  @override
  bool soundOn = true;
  @override
  bool musicOn = true;
  String? clip;
  int frame = 0;
  final events = <Map<String, Object>>[];

  void _log(String file, double volume) {
    if (clip == null || !soundOn) return;
    events.add({'clip': clip!, 'frame': frame, 'file': file, 'volume': volume});
  }

  @override
  void setSound(bool on) => soundOn = on;
  @override
  void setMusic(bool on) => musicOn = on;
  @override
  void sfx(Sfx s, {double volume = 1}) => _log('${s.name}.ogg', volume * 0.9);
  @override
  void pop(int cascade) => _log('pop${(cascade - 1).clamp(0, 7)}.ogg', 0.8);
  @override
  void star(int i) => _log('star${i.clamp(0, 2)}.ogg', 0.9);
  @override
  void music(Music? track) {}
  @override
  Future<void> preload() async {}
  @override
  void dispose() {}
}

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

String save() {
  final stars = {for (var i = 1; i <= 119; i++) '$i': i % 5 == 0 ? 2 : 3};
  final s = stars.entries.map((e) => '"${e.key}": ${e.value}').join(',');
  return '{"unlocked": 120, "coins": 3250, "gold": 140, "hints": false, '
      '"dailyLast": ${dayNumber(DateTime.now())}, "dailyStreak": 4, '
      '"stars": {$s}}';
}

Future<ui.Image> grab(WidgetTester t, double ratio) async {
  var ro = t.renderObject(find.byType(MaterialApp));
  while (!ro.isRepaintBoundary) {
    ro = ro.parent!;
  }
  final layer = ro.debugLayer! as OffsetLayer;
  return layer.toImage(ro.paintBounds, pixelRatio: ratio);
}

Future<void> still(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final img = await grab(t, 2.625);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/stills/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Records [seconds] of the app into $out/clips/[name].mp4. [onFrame] runs
/// before each frame is pumped (to start moves at chosen moments).
Future<void> record(
  WidgetTester t,
  RecAudio audio,
  String name,
  double seconds, {
  void Function(int frame)? onFrame,
  Map<int, String> stills = const {},
}) async {
  final frames = (seconds * fps).round();
  Process? ff;
  audio.clip = name;
  for (var f = 0; f < frames; f++) {
    audio.frame = f;
    onFrame?.call(f);
    await t.pump(const Duration(microseconds: 1000000 ~/ fps));
    final still0 = stills[f];
    if (still0 != null) await still(t, still0);
    await t.runAsync(() async {
      final img = await grab(t, videoScale);
      final w = img.width, h = img.height;
      if (ff == null) {
        Directory('$out/clips').createSync(recursive: true);
        ff = await Process.start('ffmpeg', [
          '-y', '-loglevel', 'error', //
          '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${w}x$h',
          '-r', '$fps', '-i', '-',
          '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
          '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '14',
          '-pix_fmt', 'yuv420p', '$out/clips/$name.mp4',
        ]);
        unawaited(ff!.stderr.drain<void>());
        unawaited(ff!.stdout.drain<void>());
      }
      final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      ff!.stdin.add(raw!.buffer.asUint8List());
      await ff!.stdin.flush();
      img.dispose();
    });
  }
  audio.clip = null;
  await t.runAsync(() async {
    await ff!.stdin.close();
    await ff!.exitCode;
  });
}

Future<void> run(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<GameScreenState> openLevel(WidgetTester t, int id) async {
  final node = find.byKey(Key('level-$id'));
  unawaited(Scrollable.ensureVisible(t.element(node), alignment: 0.5));
  await run(t, 400);
  await t.tap(node);
  await run(t, 500);
  await t.tap(find.byKey(const Key('play-level')));
  await run(t, 700);
  if (find.byKey(const Key('tutorial-ok')).evaluate().isNotEmpty) {
    await t.tap(find.byKey(const Key('tutorial-ok')));
    await run(t, 900);
  }
  return t.state<GameScreenState>(find.byType(GameScreen));
}

Future<void> leave(WidgetTester t) async {
  for (
    var i = 0;
    i < 40 && find.byType(GameScreen).evaluate().isNotEmpty;
    i++
  ) {
    for (final k in [
      'ad-done',
      'reward-ok',
      'win-map',
      'fail-map',
      'pause-quit',
    ]) {
      final f = find.byKey(Key(k));
      if (f.evaluate().isNotEmpty) {
        await t.tap(f, warnIfMissed: false);
        break;
      }
    }
    if (find.byKey(const Key('pause-quit')).evaluate().isEmpty &&
        find.byKey(const Key('pause')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('pause')), warnIfMissed: false);
    }
    await run(t, 500);
  }
  await run(t, 800);
}

void refresh(GameScreenState g) {
  g.controller.shown = g.session.board.snapshot();
  g.setState(() {});
}

/// Two neighboring movable cells holding plain tiles, near the middle.
(Pos, Pos)? pairNearMiddle(GameScreenState g, {bool vertical = false}) {
  final b = g.session.board;
  final mid = Pos(b.rows ~/ 2, b.cols ~/ 2);
  final cells = [...b.allPositions]
    ..sort(
      (x, y) => ((x.r - mid.r).abs() + (x.c - mid.c).abs()).compareTo(
        (y.r - mid.r).abs() + (y.c - mid.c).abs(),
      ),
    );
  for (final p in cells) {
    final q = vertical ? Pos(p.r + 1, p.c) : Pos(p.r, p.c + 1);
    if (!b.inBounds(q)) continue;
    final tp = b.tileAt(p), tq = b.tileAt(q);
    if (tp == null || tq == null || tp.bucket || tq.bucket) continue;
    if (!b.isMovable(p) || !b.isMovable(q)) continue;
    return (p, q);
  }
  return null;
}

/// Swipes the special of kind [s] into a neighbor.
void fire(GameScreenState g, bool Function(Special) s) {
  final b = g.session.board;
  for (final p in b.allPositions) {
    final t = b.tileAt(p);
    if (t == null || !s(t.special) || !b.isMovable(p)) continue;
    for (final d in const [Pos(0, 1), Pos(0, -1), Pos(1, 0), Pos(-1, 0)]) {
      final q = p + d;
      if (b.inBounds(q) && b.tileAt(q) != null && b.isMovable(q)) {
        g.onSwipe(p, q);
        return;
      }
    }
  }
}

void main() {
  testWidgets('promo capture', (t) async {
    await t.runAsync(loadFonts);
    SharedPreferences.setMockInitialValues({'blend_burst_save_v1': save()});
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 2.625;
    final audio = RecAudio();
    await t.pumpWidget(BlendBurstApp(audio: audio));
    for (var i = 0; i < 60 && find.byType(MapScreen).evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await run(t, 1500);

    // --- The map: a smooth flight up through the worlds.
    final scroll = t.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('map-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final max = scroll.position.maxScrollExtent;
    scroll.position.jumpTo(0);
    await run(t, 300);
    await still(t, 'map_start');
    const mapFrames = 7 * fps;
    await record(
      t,
      audio,
      'map',
      7,
      onFrame: (f) {
        final x = f / (mapFrames - 1);
        final eased = x * x * (3 - 2 * x);
        scroll.position.jumpTo(eased * max * 0.93);
      },
      stills: {60: 'map_garden', 120: 'map_sky', 200: 'map_galaxy'},
    );

    // --- Matching and blending.
    var g = await openLevel(t, 3);
    await still(t, 'level_blend');
    await record(
      t,
      audio,
      'blend',
      6,
      onFrame: (f) {
        if (f % 42 == 8) g.playHintMove();
      },
      stills: {60: 'blend_cascade'},
    );
    await leave(t);

    // --- Specials on a glass level.
    g = await openLevel(t, 27);
    for (final s in [Special.lineH, Special.bomb, Special.lineV]) {
      g.session.board.placeSpecial(s);
    }
    refresh(g);
    await run(t, 300);
    await still(t, 'specials_ready');
    await record(
      t,
      audio,
      'specials',
      7,
      onFrame: (f) {
        if (f == 10) fire(g, (s) => s == Special.lineH);
        if (f == 75 && !g.busy) fire(g, (s) => s == Special.bomb);
        if (f == 140 && !g.busy) fire(g, (s) => s.isLine);
      },
      stills: {18: 'specials_line', 84: 'specials_bomb'},
    );
    await leave(t);

    // --- Combos: two specials swiped together.
    g = await openLevel(t, 54);
    void combo(Special a, Special b, {bool vertical = false}) {
      final pair = pairNearMiddle(g, vertical: vertical);
      if (pair == null) return;
      final (p, q) = pair;
      g.session.board.tileAt(p)!.special = a;
      g.session.board.tileAt(q)!.special = b;
      refresh(g);
    }

    combo(Special.lineH, Special.bomb);
    await run(t, 300);
    await record(
      t,
      audio,
      'combo',
      7,
      onFrame: (f) {
        if (f == 12) {
          final pair = pairNearMiddle(g);
          final b = g.session.board;
          for (final p in b.allPositions) {
            final x = b.tileAt(p);
            if (x != null && x.special == Special.bomb) {
              for (final d in const [Pos(0, -1), Pos(0, 1)]) {
                final y = b.tileAt(p + d);
                if (y != null && y.special.isLine) {
                  g.onSwipe(p + d, p);
                  return;
                }
              }
            }
          }
          if (pair != null) g.onSwipe(pair.$1, pair.$2);
        }
        if (f == 110 && !g.busy) combo(Special.lineV, Special.lineH);
        if (f == 120 && !g.busy) {
          fire(g, (s) => s == Special.lineV);
        }
      },
      stills: {22: 'combo_cross', 132: 'combo_rowcol'},
    );
    await leave(t);

    // --- Spectacular: prism + prism clears the board.
    g = await openLevel(t, 40);
    final pair = pairNearMiddle(g);
    if (pair != null) {
      final b = g.session.board;
      for (final p in [pair.$1, pair.$2]) {
        b.tileAt(p)!
          ..special = Special.prism
          ..color = null;
      }
      refresh(g);
    }
    await run(t, 300);
    await still(t, 'prisms_ready');
    await record(
      t,
      audio,
      'spectacular',
      6,
      onFrame: (f) {
        if (f == 12 && pair != null) g.onSwipe(pair.$1, pair.$2);
      },
      stills: {24: 'spectacular_burst', 40: 'spectacular_clear'},
    );
    await leave(t);

    // --- A three-star win with the finale.
    g = await openLevel(t, 1);
    g.session.board.score = 74000;
    g.session.movesLeft = 4;
    g.setState(() {});
    await run(t, 300);
    await record(
      t,
      audio,
      'win',
      10,
      onFrame: (f) {
        if (f == 10) g.playHintMove();
      },
      stills: {270: 'win_stars'},
    );
    await leave(t);

    // --- Stills of every world.
    for (final (id, name) in [
      (10, 'world_1_studio'),
      (25, 'world_2_garden'),
      (38, 'world_3_factory'),
      (55, 'world_4_sky'),
      (68, 'world_5_lagoon'),
      (88, 'world_6_peaks'),
      (100, 'world_7_brigade'),
      (115, 'world_8_galaxy'),
    ]) {
      g = await openLevel(t, id);
      for (final s in [Special.lineH, Special.bomb]) {
        g.session.board.placeSpecial(s);
      }
      refresh(g);
      await run(t, 500);
      await still(t, name);
      await leave(t);
    }

    // --- Menus.
    for (final (key, name) in [
      ('side-shop', 'menu_shop'),
      ('side-event', 'menu_event'),
      ('side-pass', 'menu_pass'),
    ]) {
      await t.tap(find.byKey(Key(key)));
      await run(t, 1200);
      await still(t, name);
      await t.tap(find.bySemanticsLabel('Back').last);
      await run(t, 1000);
    }

    File('$out/sounds.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ')
          .convert({'fps': fps, 'events': audio.events}),
    );
  });
}
