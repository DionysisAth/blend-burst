import 'dart:convert';

import 'package:blend_burst/app/app_state.dart';
import 'package:blend_burst/app/cloud.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGames implements GamesBackend {
  bool configured = true;
  bool signedIn = true;
  bool listFails = false;
  bool loadFails = false;
  final cloud = <String, String>{};
  final submitted = <Board, int>{};
  int saves = 0;
  int shown = 0;

  @override
  Future<bool> init() async => configured;
  @override
  Future<bool> isSignedIn() async => signedIn;
  @override
  Future<String?> signIn() async {
    signedIn = true;
    return 'Tester';
  }

  @override
  Future<String?> playerName() async => signedIn ? 'Tester' : null;
  @override
  Future<List<String>?> saveNames() async =>
      listFails ? null : cloud.keys.toList();
  @override
  Future<String?> load(String name) async => loadFails ? null : cloud[name];
  @override
  Future<bool> save(String name, String data) async {
    saves++;
    cloud[name] = data;
    return true;
  }

  @override
  Future<void> submit(Board board, int value) async => submitted[board] = value;
  final unlocked = <String>{};
  @override
  Future<void> unlock(String key) async => unlocked.add(key);
  @override
  Future<bool> showAchievements() async => true;

  @override
  Future<bool> showLeaderboards() async {
    shown++;
    return true;
  }
}

SaveData progress({
  int unlocked = 1,
  Map<int, int> stars = const {},
  int coins = 500,
  int savedAt = 0,
}) => SaveData()
  ..unlocked = unlocked
  ..stars = Map.of(stars)
  ..best = {for (final k in stars.keys) k: 1000 * k}
  ..coins = coins
  ..savedAt = savedAt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('merge', () {
    test('progress is the best of both copies', () {
      final local = progress(unlocked: 5, stars: {1: 3, 2: 1, 3: 2, 4: 1})
        ..tutorialsSeen = {1, 2}
        ..purchases = {'starter'};
      final cloud = progress(unlocked: 7, stars: {1: 1, 2: 3, 5: 2, 6: 1})
        ..tutorialsSeen = {3}
        ..adsRemoved = true;
      final m = SaveData.merge(local, cloud);
      expect(m.unlocked, 7);
      expect(m.stars, {1: 3, 2: 3, 3: 2, 4: 1, 5: 2, 6: 1});
      expect(m.tutorialsSeen, {1, 2, 3});
      expect(m.purchases, {'starter'});
      expect(m.adsRemoved, isTrue);
    });

    test('coins come from the newer copy', () {
      final local = progress(unlocked: 3, stars: {1: 1}, coins: 100)
        ..savedAt = 2000;
      final cloud = progress(unlocked: 3, stars: {1: 1}, coins: 900)
        ..savedAt = 1000;
      expect(SaveData.merge(local, cloud).coins, 100);
      cloud.savedAt = 3000;
      expect(SaveData.merge(local, cloud).coins, 900);
    });

    test('a fresh install takes everything from the cloud', () {
      final local = SaveData()
        ..savedAt = 99999
        ..music = false;
      final cloud = progress(unlocked: 20, stars: {1: 3}, coins: 4321)
        ..savedAt = 10
        ..music = true;
      final m = SaveData.merge(local, cloud);
      expect(m.unlocked, 20);
      expect(m.coins, 4321);
      // Settings stay as on this device.
      expect(m.music, isFalse);
    });

    test('tryParse rejects junk', () {
      expect(SaveData.tryParse('nope'), isNull);
      expect(SaveData.tryParse('[1,2]'), isNull);
      expect(SaveData.tryParse('{"a": 1}'), isNull);
      expect(SaveData.tryParse('{"unlocked": 4}')!.unlocked, 4);
    });
  });

  group('sync', () {
    late AppState app;
    late FakeGames games;
    setUp(() {
      app = AppState();
      app.totalLevels = 120;
      games = FakeGames();
    });

    test('nothing happens when Play Games is not set up', () async {
      games.configured = false;
      final c = CloudSync(games, app);
      await c.start();
      expect(c.status, CloudStatus.unavailable);
      expect(games.saves, 0);
      expect(await c.openLeaderboards(), CloudSync.notSetUp);
      expect(games.shown, 0);
      c.dispose();
    });

    test('a signed-in player gets the cloud progress merged in', () async {
      app.data = progress(unlocked: 3, stars: {1: 3, 2: 2});
      games.cloud[GamesConfig.saveName] = jsonEncode(
        progress(unlocked: 9, stars: {1: 1, 5: 3}, savedAt: 1).toJson(),
      );
      final c = CloudSync(games, app);
      await c.start();
      expect(c.status, CloudStatus.signedIn);
      expect(c.player, 'Tester');
      expect(app.data.unlocked, 9);
      expect(app.data.stars, {1: 3, 2: 2, 5: 3});
      // The merged copy went back up.
      final up = SaveData.tryParse(games.cloud[GamesConfig.saveName]!)!;
      expect(up.stars, {1: 3, 2: 2, 5: 3});
      expect(games.submitted[Board.stars], 8);
      expect(games.submitted[Board.levels], 5);
      c.dispose();
    });

    test('an unreadable cloud save is never overwritten', () async {
      app.data = SaveData();
      final original = jsonEncode(
        progress(unlocked: 50, stars: {1: 3}).toJson(),
      );
      games.cloud[GamesConfig.saveName] = original;
      games.loadFails = true;
      final c = CloudSync(games, app);
      await c.start();
      expect(games.saves, 0);
      expect(games.cloud[GamesConfig.saveName], original);
      expect(c.message, isNotNull);
      games.loadFails = false;
      games.listFails = true;
      expect(await c.sync(), isFalse);
      expect(games.saves, 0);
      games.listFails = false;
      expect(await c.sync(), isTrue);
      expect(app.data.unlocked, 50);
      c.dispose();
    });

    test('signing in later syncs, and leaderboards open', () async {
      games.signedIn = false;
      final c = CloudSync(games, app);
      await c.start();
      expect(c.status, CloudStatus.signedOut);
      expect(await c.signIn(), isTrue);
      expect(c.status, CloudStatus.signedIn);
      expect(games.saves, 1);
      expect(await c.openLeaderboards(), isNull);
      expect(games.shown, 1);
      c.dispose();
    });
  });
}
