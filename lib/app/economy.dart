// Live-ops rules: rewards, the daily login calendar, weekly events, the
// season pass and the shop catalog. No widgets, and time always comes in
// as a parameter, so every rule is unit-testable.

import '../l10n/l10n.dart';
import 'app_state.dart' show BoosterType, BoosterInfo;

/// Something the player receives.
class Reward {
  final int coins;
  final int gold;
  final int lives;
  final Map<BoosterType, int> boosters;

  /// Minutes of unlimited lives.
  final int unlimitedMinutes;

  const Reward({
    this.coins = 0,
    this.gold = 0,
    this.lives = 0,
    this.boosters = const {},
    this.unlimitedMinutes = 0,
  });

  Reward operator *(int k) => Reward(
    coins: coins * k,
    gold: gold * k,
    lives: lives * k,
    boosters: boosters.map((b, n) => MapEntry(b, n * k)),
    unlimitedMinutes: unlimitedMinutes * k,
  );

  bool get isEmpty =>
      coins == 0 &&
      gold == 0 &&
      lives == 0 &&
      boosters.isEmpty &&
      unlimitedMinutes == 0;

  /// What it contains, for players (in the current language).
  String get label => [
    if (coins > 0) tr.rewardCoins(coins),
    if (gold > 0) tr.rewardGold(gold),
    if (lives > 0) tr.rewardLives(lives),
    if (unlimitedMinutes > 0) tr.rewardUnlimited(unlimitedMinutes),
    for (final e in boosters.entries) tr.rewardBooster(e.value, e.key.label),
  ].join(', ');

  /// For analytics logs (always English).
  @override
  String toString() => [
    if (coins > 0) '$coins coins',
    if (gold > 0) '$gold gold',
    if (lives > 0) '$lives lives',
    if (unlimitedMinutes > 0) '${unlimitedMinutes}m unlimited lives',
    for (final e in boosters.entries) '${e.value}x ${e.key.name}',
  ].join(', ');
}

/// Days since the Unix epoch in local time (calendar day number).
int dayNumber(DateTime t) {
  final local = t.toLocal();
  return DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

// ------------------------------------------------------------------ daily

/// The 7-day login calendar. Day 7 is the big one; then it starts over.
const dailyRewards = [
  Reward(coins: 100),
  Reward(boosters: {BoosterType.brush: 1}),
  Reward(coins: 200),
  Reward(boosters: {BoosterType.startLine: 1, BoosterType.startBomb: 1}),
  Reward(unlimitedMinutes: 30),
  Reward(coins: 300, boosters: {BoosterType.freeSwap: 1}),
  Reward(
    gold: 10,
    boosters: {BoosterType.startPrism: 1, BoosterType.colorSplash: 1},
  ),
];

/// Where the login calendar stands on [today].
class DailyState {
  /// 0-based index into [dailyRewards] of today's reward.
  final int index;

  /// Whether today's reward can still be claimed.
  final bool claimable;
  const DailyState(this.index, this.claimable);
}

/// [streak] is how many days in a row were claimed, ending on [lastDay].
DailyState dailyState({
  required int today,
  required int lastDay,
  required int streak,
}) {
  if (lastDay == today) {
    return DailyState((streak - 1) % dailyRewards.length, false);
  }
  final continues = lastDay == today - 1;
  final next = continues ? streak : 0;
  return DailyState(next % dailyRewards.length, true);
}

// ------------------------------------------------------------------ event

/// Weekly event: collect tiles of one color while playing levels.
class WeeklyEvent {
  /// Week number (weeks start on Monday).
  final int week;
  final String colorName;
  final DateTime ends;
  const WeeklyEvent(this.week, this.colorName, this.ends);

  static const colors = ['purple', 'green', 'orange', 'red', 'blue', 'yellow'];

  /// Collected tiles needed for each reward tier, and the rewards.
  static const tiers = [40, 120, 250, 450, 700];
  static const rewards = [
    Reward(coins: 150),
    Reward(boosters: {BoosterType.brush: 1, BoosterType.startLine: 1}),
    Reward(coins: 300, unlimitedMinutes: 15),
    Reward(gold: 10, boosters: {BoosterType.colorSplash: 1}),
    Reward(
      gold: 25,
      boosters: {BoosterType.startPrism: 1, BoosterType.freeSwap: 1},
    ),
  ];

  static WeeklyEvent at(DateTime now) {
    // 1970-01-01 was a Thursday; shift so weeks start on Monday.
    final day = dayNumber(now);
    final week = (day + 3) ~/ 7;
    final endDay = week * 7 - 3 + 7;
    final end = DateTime.fromMillisecondsSinceEpoch(
      endDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return WeeklyEvent(
      week,
      colors[week % colors.length],
      DateTime(end.year, end.month, end.day),
    );
  }

  /// Number of tiers reached with [progress] collected tiles.
  static int tiersReached(int progress) =>
      tiers.where((t) => progress >= t).length;
}

// ----------------------------------------------------------------- season

/// The season pass: points from winning levels unlock tiers on a free and
/// a premium track. A season lasts 28 days.
class Season {
  final int number;
  final DateTime ends;
  const Season(this.number, this.ends);

  static const length = 28;
  static const pointsPerTier = 60;
  static const tierCount = 20;

  static Season at(DateTime now) {
    final day = dayNumber(now);
    final n = day ~/ length;
    final end = DateTime.fromMillisecondsSinceEpoch(
      (n + 1) * length * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return Season(n, DateTime(end.year, end.month, end.day));
  }

  /// Points for winning a level with [stars] stars.
  static int pointsFor(int stars) => 10 + 10 * stars;

  static int tiersReached(int points) =>
      (points ~/ pointsPerTier).clamp(0, tierCount);

  static Reward freeReward(int tier) => switch (tier % 5) {
    0 => const Reward(coins: 100),
    1 => const Reward(boosters: {BoosterType.brush: 1}),
    2 => const Reward(coins: 150),
    3 => const Reward(boosters: {BoosterType.startBomb: 1}),
    _ =>
      tier == tierCount - 1
          ? const Reward(gold: 20, unlimitedMinutes: 60)
          : const Reward(gold: 5),
  };

  static Reward premiumReward(int tier) => switch (tier % 4) {
    0 => const Reward(coins: 300),
    1 => const Reward(
      boosters: {BoosterType.freeSwap: 1, BoosterType.startLine: 1},
    ),
    2 => const Reward(unlimitedMinutes: 30),
    _ =>
      tier == tierCount - 1
          ? const Reward(
              gold: 60,
              boosters: {BoosterType.startPrism: 2, BoosterType.colorSplash: 2},
            )
          : const Reward(gold: 10),
  };
}

// ------------------------------------------------------------------- shop

enum PayWith { money, gold, coins, ad }

/// A shop item. [price] is in cents for money, otherwise in gold/coins.
class Product {
  final String id;
  final PayWith pay;
  final int price;
  final Reward reward;

  /// Only sold once (the starter pack, remove ads, premium pass).
  final bool once;
  const Product(
    this.id,
    this.pay,
    this.price,
    this.reward, {
    this.once = false,
  });

  String get priceLabel => switch (pay) {
    PayWith.money =>
      '\$${price ~/ 100}.${(price % 100).toString().padLeft(2, '0')}',
    PayWith.gold => '$price',
    PayWith.coins => '$price',
    PayWith.ad => tr.free,
  };

  /// Name shown in the shop (in the current language).
  String get title => switch (id) {
    'starter' => tr.productStarterTitle,
    'gold50' => tr.productGold50Title,
    'gold130' => tr.productGold130Title,
    'gold350' => tr.productGold350Title,
    'gold800' => tr.productGold800Title,
    'noads' => tr.productNoAdsTitle,
    'pass' => tr.productPassTitle,
    'refill' => tr.productRefillTitle,
    'unl30' || 'unl60' || 'unl180' => tr.productUnlimitedTitle,
    'boosterpack' => tr.productBoosterPackTitle,
    'startpack' => tr.productStartPackTitle,
    'freebooster' => tr.productFreeBoosterTitle,
    _ => id,
  };

  /// What it gives, under the name (in the current language).
  String get subtitle => switch (id) {
    'starter' => tr.productStarterSubtitle,
    'gold50' ||
    'gold130' ||
    'gold350' ||
    'gold800' => tr.rewardGold(reward.gold),
    'noads' => tr.productNoAdsSubtitle,
    'pass' => tr.productPassSubtitle,
    'refill' => tr.productRefillSubtitle(reward.lives),
    'unl30' => tr.productUnl30Subtitle,
    'unl60' => tr.productUnl60Subtitle,
    'unl180' => tr.productUnl180Subtitle,
    'boosterpack' => tr.productBoosterPackSubtitle,
    'startpack' => tr.productStartPackSubtitle,
    'freebooster' => tr.productFreeBoosterSubtitle,
    _ => reward.label,
  };
}

const allBoostersOne = {
  BoosterType.brush: 1,
  BoosterType.freeSwap: 1,
  BoosterType.colorSplash: 1,
  BoosterType.gravityFlip: 1,
};

const shopProducts = [
  Product(
    'starter',
    PayWith.money,
    99,
    Reward(
      gold: 100,
      unlimitedMinutes: 60,
      boosters: {
        BoosterType.brush: 3,
        BoosterType.freeSwap: 3,
        BoosterType.colorSplash: 3,
        BoosterType.gravityFlip: 3,
        BoosterType.startLine: 3,
        BoosterType.startBomb: 3,
        BoosterType.startPrism: 3,
      },
    ),
    once: true,
  ),
  Product('gold50', PayWith.money, 99, Reward(gold: 50)),
  Product('gold130', PayWith.money, 199, Reward(gold: 130)),
  Product('gold350', PayWith.money, 499, Reward(gold: 350)),
  Product('gold800', PayWith.money, 999, Reward(gold: 800)),
  Product('noads', PayWith.money, 299, Reward(), once: true),
  Product('pass', PayWith.money, 499, Reward(), once: true),
  Product('refill', PayWith.gold, 20, Reward(lives: 5)),
  Product('unl30', PayWith.gold, 30, Reward(unlimitedMinutes: 30)),
  Product('unl60', PayWith.gold, 50, Reward(unlimitedMinutes: 60)),
  Product('unl180', PayWith.gold, 120, Reward(unlimitedMinutes: 180)),
  Product(
    'boosterpack',
    PayWith.gold,
    70,
    Reward(
      boosters: {
        BoosterType.brush: 2,
        BoosterType.freeSwap: 2,
        BoosterType.colorSplash: 2,
        BoosterType.gravityFlip: 2,
      },
    ),
  ),
  Product(
    'startpack',
    PayWith.gold,
    50,
    Reward(
      boosters: {
        BoosterType.startLine: 2,
        BoosterType.startBomb: 2,
        BoosterType.startPrism: 2,
      },
    ),
  ),
  Product(
    'freebooster',
    PayWith.ad,
    0,
    Reward(boosters: {BoosterType.brush: 1}),
  ),
];

Product productById(String id) => shopProducts.firstWhere((p) => p.id == id);

/// Gold price of +5 moves on the current attempt (rises each time).
int extraMovesGold(int alreadyBought) =>
    const [12, 20, 32][alreadyBought.clamp(0, 2)];

/// Win-streak bonus: free starting boosters for the next level.
Set<BoosterType> streakBonus(int winStreak) => {
  if (winStreak >= 3) BoosterType.startLine,
  if (winStreak >= 5) BoosterType.startBomb,
  if (winStreak >= 7) BoosterType.startPrism,
};
