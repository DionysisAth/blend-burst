// Live-ops rules: rewards, the daily login calendar, weekly events, the
// season pass and the shop catalog. No widgets, and time always comes in
// as a parameter, so every rule is unit-testable.

import 'app_state.dart' show BoosterType;

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
  final String title;
  final String subtitle;
  final PayWith pay;
  final int price;
  final Reward reward;

  /// Only sold once (the starter pack, remove ads, premium pass).
  final bool once;
  const Product(
    this.id,
    this.title,
    this.subtitle,
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
    PayWith.ad => 'Free',
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
    'Starter Pack',
    '100 gold, 3 of every booster, 1 hour unlimited lives',
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
  Product(
    'gold50',
    'Pouch of Gold',
    '50 gold',
    PayWith.money,
    99,
    Reward(gold: 50),
  ),
  Product(
    'gold130',
    'Bag of Gold',
    '130 gold',
    PayWith.money,
    199,
    Reward(gold: 130),
  ),
  Product(
    'gold350',
    'Chest of Gold',
    '350 gold',
    PayWith.money,
    499,
    Reward(gold: 350),
  ),
  Product(
    'gold800',
    'Vault of Gold',
    '800 gold',
    PayWith.money,
    999,
    Reward(gold: 800),
  ),
  Product(
    'noads',
    'Remove Ads',
    'No more ad breaks between levels',
    PayWith.money,
    299,
    Reward(),
    once: true,
  ),
  Product(
    'pass',
    'Premium Pass',
    'Unlocks the premium season track',
    PayWith.money,
    499,
    Reward(),
    once: true,
  ),
  Product(
    'refill',
    'Lives Refill',
    'Refill all 5 lives',
    PayWith.gold,
    20,
    Reward(lives: 5),
  ),
  Product(
    'unl30',
    'Unlimited Lives',
    '30 minutes of free play',
    PayWith.gold,
    30,
    Reward(unlimitedMinutes: 30),
  ),
  Product(
    'unl60',
    'Unlimited Lives',
    '1 hour of free play',
    PayWith.gold,
    50,
    Reward(unlimitedMinutes: 60),
  ),
  Product(
    'unl180',
    'Unlimited Lives',
    '3 hours of free play',
    PayWith.gold,
    120,
    Reward(unlimitedMinutes: 180),
  ),
  Product(
    'boosterpack',
    'Booster Bundle',
    '2 of every in-level booster',
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
    'Head Start Bundle',
    '2 of every pre-level booster',
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
    'Free Booster',
    'Watch an ad, once a day',
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
