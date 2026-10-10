import 'package:blend_burst/app/app_state.dart';
import 'package:blend_burst/app/economy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 12, 10); // a Monday
  late AppState app;
  setUp(() {
    now = DateTime(2026, 10, 12, 10);
    app = AppState(clock: () => now);
  });

  test('daily rewards follow a streak and reset after a missed day', () {
    expect(app.daily.claimable, isTrue);
    expect(app.daily.index, 0);
    final coins = app.data.coins;
    expect(app.claimDaily(), isNotNull);
    expect(app.data.coins, coins + 100);
    expect(app.daily.claimable, isFalse);
    expect(app.claimDaily(), isNull);
    now = now.add(const Duration(days: 1));
    expect(app.daily.index, 1);
    app.claimDaily();
    now = now.add(const Duration(days: 1));
    expect(app.daily.index, 2);
    // Skip a day: back to day 1.
    now = now.add(const Duration(days: 2));
    expect(app.daily.index, 0);
    // Doubled rewards.
    final before = app.data.coins;
    app.claimDaily(doubled: true);
    expect(app.data.coins, before + 200);
  });

  test('the 7-day calendar wraps after day 7', () {
    for (var d = 0; d < 7; d++) {
      expect(app.daily.index, d);
      app.claimDaily();
      now = now.add(const Duration(days: 1));
    }
    expect(app.daily.index, 0);
  });

  test('unlimited lives stop life loss and expire', () {
    app.grant(const Reward(unlimitedMinutes: 30), 'test');
    expect(app.hasUnlimited, isTrue);
    final lives = app.lives;
    app.loseLife();
    expect(app.lives, lives);
    now = now.add(const Duration(minutes: 31));
    expect(app.hasUnlimited, isFalse);
    app.loseLife();
    expect(app.lives, lives - 1);
    // Unlimited time stacks.
    app.grant(const Reward(unlimitedMinutes: 30), 'a');
    app.grant(const Reward(unlimitedMinutes: 30), 'b');
    expect(app.unlimitedLeft!.inMinutes, greaterThanOrEqualTo(59));
  });

  test('the weekly event counts its color, pays tiers and resets weekly', () {
    final e = app.event;
    final color = e.colorName;
    app.addEventTiles({color: 30, 'brown': 100});
    expect(app.eventProgress, 30);
    expect(app.eventClaimable, 0);
    app.addEventTiles({color: 15});
    expect(app.eventClaimable, 1);
    final coins = app.data.coins;
    app.claimEventTier();
    expect(app.data.coins, coins + 150);
    expect(app.eventClaimable, 0);
    expect(e.ends.weekday, DateTime.monday);
    expect(e.ends.isAfter(now), isTrue);
    now = e.ends.add(const Duration(hours: 1));
    expect(app.event.week, e.week + 1);
    expect(app.eventProgress, 0);
    expect(app.event.colorName, isNot(color));
  });

  test('season points unlock free tiers; premium needs the pass', () {
    for (var i = 0; i < 4; i++) {
      app.completeLevel(1, 3, 1000, 0);
    }
    expect(app.seasonPoints, 160);
    expect(Season.tiersReached(160), 2);
    expect(app.canClaimSeason(0, premium: false), isTrue);
    expect(app.canClaimSeason(0, premium: true), isFalse);
    expect(app.claimSeason(0, premium: false), isNotNull);
    expect(app.claimSeason(0, premium: false), isNull);
    expect(app.canClaimSeason(2, premium: false), isFalse);
    app.completePurchase(productById('pass'));
    expect(app.premiumPass, isTrue);
    expect(app.claimSeason(1, premium: true), isNotNull);
    // A new season resets points and the pass.
    now = app.season.ends.add(const Duration(hours: 1));
    expect(app.seasonPoints, 0);
    expect(app.premiumPass, isFalse);
  });

  test('shop items cost gold or coins; one-time items sell once', () {
    app.data.gold = 100;
    expect(app.buyWithCurrency(productById('unl30')), isTrue);
    expect(app.gold, 70);
    expect(app.hasUnlimited, isTrue);
    app.data.gold = 10;
    expect(app.buyWithCurrency(productById('refill')), isFalse);
    expect(app.gold, 10);
    final starter = productById('starter');
    expect(app.canBuy(starter), isTrue);
    app.completePurchase(starter);
    expect(app.canBuy(starter), isFalse);
    expect(app.gold, 110);
    expect(app.boosterCount(BoosterType.startPrism), greaterThanOrEqualTo(4));
    // The free daily booster is once per day.
    final free = productById('freebooster');
    expect(app.buyWithCurrency(free), isTrue);
    expect(app.canBuy(free), isFalse);
    now = now.add(const Duration(days: 1));
    expect(app.canBuy(free), isTrue);
  });

  test('interstitials come every few wins and never after a purchase', () {
    expect(app.takeInterstitialSlot(), isFalse);
    for (var i = 0; i < 3; i++) {
      app.completeLevel(1, 1, 100, 0);
    }
    expect(app.takeInterstitialSlot(), isTrue);
    expect(app.takeInterstitialSlot(), isFalse);
    for (var i = 0; i < 3; i++) {
      app.completeLevel(1, 1, 100, 0);
    }
    app.completePurchase(productById('gold50'));
    expect(app.takeInterstitialSlot(), isFalse);
  });

  test('win streaks give free starting boosters', () {
    expect(app.streakBoosters, isEmpty);
    for (var i = 0; i < 5; i++) {
      app.completeLevel(1, 1, 100, 0);
    }
    expect(app.streakBoosters, {BoosterType.startLine, BoosterType.startBomb});
    app.failLevel(1, reason: 'test');
    expect(app.streakBoosters, isEmpty);
  });

  test('extra moves get pricier on the same attempt', () {
    expect(extraMovesGold(0) < extraMovesGold(1), isTrue);
    expect(extraMovesGold(1) < extraMovesGold(2), isTrue);
    expect(extraMovesGold(5), extraMovesGold(2));
  });

  test('save data round-trips the new fields', () {
    app.data.gold = 77;
    app.data.purchases.add('noads');
    app.data.seasonFree.addAll({1, 3});
    app.data.playDays.addAll({10, 11});
    final copy = SaveData.fromJson(app.data.toJson());
    expect(copy.gold, 77);
    expect(copy.purchases, {'noads'});
    expect(copy.seasonFree, {1, 3});
    expect(copy.playDays, {10, 11});
  });
}
