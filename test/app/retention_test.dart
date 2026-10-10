import 'package:blend_burst/app/app_state.dart';
import 'package:blend_burst/app/economy.dart';
import 'package:blend_burst/app/metrics.dart';
import 'package:blend_burst/app/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 12, 10);
  late AppState app;
  setUp(() {
    now = DateTime(2026, 10, 12, 10);
    app = AppState(clock: () => now);
  });

  test('retention and session metrics come from the save data', () {
    final d = app.data;
    final today = dayNumber(now);
    d.firstDay = today - 8;
    d.playDays = {today - 8, today - 7, today};
    d.sessions = 4;
    d.attempts = {1: 1, 2: 3, 3: 4};
    d.wins = {1: 1, 2: 1};
    app.log('level_fail');
    app.log('level_fail');
    app.log('extra_moves');
    final m = Metrics(d, today);
    expect(m.retainedOnDay(1), isTrue);
    expect(m.retainedOnDay(7), isFalse);
    expect(m.retainedOnDay(30), isNull);
    expect(m.levelsStarted, 8);
    expect(m.levelsPerSession, 2);
    expect(m.winRate, 0.25);
    expect(m.attemptsPerWonLevel, 2);
    expect(m.extraMovesRate, closeTo(1 / 3, 1e-9));
    expect(m.hardestLevels(), [3, 2]);
  });

  test('remote config parses defensively', () {
    final c = RemoteConfig.parse(
      '{"moves": {"12": 30, "13": 2, "x": 5}, "eventColor": "green", '
      '"adEvery": 5, "extraMovesGold": [5, 6, 7]}',
    );
    expect(c.moves, {12: 30});
    expect(c.eventColor, 'green');
    expect(c.adEvery, 5);
    expect(c.extraMovesGold, [5, 6, 7]);
    final bad = RemoteConfig.parse('not json');
    expect(bad.moves, isEmpty);
    expect(bad.adEvery, 3);
    expect(bad.extraMovesGold, isNull);
  });

  test('remote config changes the event color and gold prices', () {
    app.config = RemoteConfig.parse(
      '{"eventColor": "orange", "extraMovesGold": [1, 2, 3]}',
    );
    expect(app.event.colorName, 'orange');
    expect(app.extraMovesGoldCost(0), 1);
    expect(app.extraMovesGoldCost(5), 3);
  });

  test('reminders cover lives, the event and the daily gift', () {
    app.loseLife();
    app.loseLife();
    final r = app.reminders();
    final lives = r.firstWhere((x) => x.id == 1);
    // Two lives missing: full in two refill periods.
    expect(lives.at.difference(now), AppState.lifeRefill * 2);
    expect(r.any((x) => x.id == 2), isTrue);
    expect(r.any((x) => x.id == 3), isTrue);
    // Unlimited lives: nothing to wait for.
    app.grant(const Reward(unlimitedMinutes: 30), 'test');
    expect(app.reminders().any((x) => x.id == 1), isFalse);
  });

  test('counters and new settings survive a save round-trip', () {
    app.log('share');
    app.data.notifications = true;
    app.data.remoteConfig = '{"adEvery": 4}';
    final copy = SaveData.fromJson(app.data.toJson());
    expect(copy.counters['share'], 1);
    expect(copy.notifications, isTrue);
    expect(copy.remoteConfig, '{"adEvery": 4}');
  });
}
