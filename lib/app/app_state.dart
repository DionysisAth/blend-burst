import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'economy.dart';
import 'notifications.dart';
import 'remote_config.dart';

enum BoosterType {
  brush,
  freeSwap,
  colorSplash,
  gravityFlip,

  /// Pre-level boosters: the level starts with this special on the board.
  startLine,
  startBomb,
  startPrism,
}

extension BoosterInfo on BoosterType {
  String get label => const {
    BoosterType.brush: 'Brush',
    BoosterType.freeSwap: 'Free Swap',
    BoosterType.colorSplash: 'Color Splash',
    BoosterType.gravityFlip: 'Gravity Flip',
    BoosterType.startLine: 'Line Blaster',
    BoosterType.startBomb: 'Paint Bomb',
    BoosterType.startPrism: 'Prism',
  }[this]!;

  String get help => const {
    BoosterType.brush: 'Tap a tile to wipe it away.',
    BoosterType.freeSwap: 'Tap two tiles to swap them.',
    BoosterType.colorSplash: "Tap a tile to paint its whole row in its color.",
    BoosterType.gravityFlip: 'Pick where tiles fall during your next move.',
    BoosterType.startLine: 'Start the level with a Line Blaster.',
    BoosterType.startBomb: 'Start the level with a Paint Bomb.',
    BoosterType.startPrism: 'Start the level with a Prism.',
  }[this]!;

  bool get isPreLevel =>
      this == BoosterType.startLine ||
      this == BoosterType.startBomb ||
      this == BoosterType.startPrism;

  /// How many a new player gets for free.
  int get starting => switch (this) {
    BoosterType.gravityFlip => 2,
    BoosterType.startLine || BoosterType.startBomb => 2,
    BoosterType.startPrism => 1,
    _ => 3,
  };

  static const inLevel = [
    BoosterType.brush,
    BoosterType.freeSwap,
    BoosterType.colorSplash,
    BoosterType.gravityFlip,
  ];
  static const preLevel = [
    BoosterType.startLine,
    BoosterType.startBomb,
    BoosterType.startPrism,
  ];
}

/// Everything that is persisted on the device.
class SaveData {
  int unlocked = 1;
  Map<int, int> stars = {};
  Map<int, int> best = {};
  int coins = 500;
  int lives = AppState.maxLives;

  /// Epoch ms at which the life currently refilling started charging.
  int lifeClock = 0;
  Map<BoosterType, int> boosters = {
    for (final b in BoosterType.values) b: b.starting,
  };
  bool haptics = true;
  bool sound = true;
  bool music = true;
  bool hints = true;
  bool tapActivate = true;
  int winStreak = 0;
  Set<int> tutorialsSeen = {};
  Map<int, int> attempts = {};
  Map<int, int> wins = {};
  int sessions = 0;
  List<Map<String, dynamic>> events = [];

  // Economy and live ops.
  int gold = 20;
  int unlimitedUntil = 0;
  bool adsRemoved = false;
  Set<String> purchases = {};

  /// Google Play order IDs already delivered (so none is granted twice).
  Set<String> orders = {};
  int dailyStreak = 0;
  int dailyLast = -1000;
  int eventWeek = -1;
  int eventProgress = 0;
  int eventClaimed = 0;
  int seasonNo = -1;
  int seasonPoints = 0;
  bool premiumPass = false;
  Set<int> seasonFree = {};
  Set<int> seasonPremium = {};
  int levelsSinceAd = 0;
  int freeBoosterDay = -1;

  /// Retention metrics: first day played and the days played since.
  int firstDay = -1;
  Set<int> playDays = {};

  /// How often each analytics event happened (never trimmed).
  Map<String, int> counters = {};

  /// Opt-in reminders.
  bool notifications = false;

  /// Remote config text cached from the previous launch.
  String remoteConfig = '';

  /// Epoch ms of the last change, to tell which copy is newer when the
  /// cloud save is merged.
  int savedAt = 0;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'unlocked': unlocked,
    'stars': stars.map((k, v) => MapEntry('$k', v)),
    'best': best.map((k, v) => MapEntry('$k', v)),
    'coins': coins,
    'lives': lives,
    'lifeClock': lifeClock,
    'boosters': boosters.map((k, v) => MapEntry(k.name, v)),
    'haptics': haptics,
    'sound': sound,
    'music': music,
    'hints': hints,
    'tapActivate': tapActivate,
    'winStreak': winStreak,
    'tutorialsSeen': tutorialsSeen.toList(),
    'attempts': attempts.map((k, v) => MapEntry('$k', v)),
    'wins': wins.map((k, v) => MapEntry('$k', v)),
    'sessions': sessions,
    'events': events,
    'gold': gold,
    'unlimitedUntil': unlimitedUntil,
    'adsRemoved': adsRemoved,
    'purchases': purchases.toList(),
    'orders': orders.toList(),
    'dailyStreak': dailyStreak,
    'dailyLast': dailyLast,
    'eventWeek': eventWeek,
    'eventProgress': eventProgress,
    'eventClaimed': eventClaimed,
    'seasonNo': seasonNo,
    'seasonPoints': seasonPoints,
    'premiumPass': premiumPass,
    'seasonFree': seasonFree.toList(),
    'seasonPremium': seasonPremium.toList(),
    'levelsSinceAd': levelsSinceAd,
    'freeBoosterDay': freeBoosterDay,
    'firstDay': firstDay,
    'playDays': playDays.toList(),
    'counters': counters,
    'notifications': notifications,
    'remoteConfig': remoteConfig,
    'savedAt': savedAt,
  };

  /// Tolerant parser: anything missing or malformed falls back to defaults.
  static SaveData fromJson(Map<String, dynamic> j) {
    final s = SaveData();
    int asInt(dynamic v, int fallback) => v is num ? v.toInt() : fallback;
    bool asBool(dynamic v, bool fallback) => v is bool ? v : fallback;
    Map<int, int> intMap(dynamic v) {
      final out = <int, int>{};
      if (v is Map) {
        v.forEach((k, val) {
          final key = int.tryParse('$k');
          if (key != null && val is num) out[key] = val.toInt();
        });
      }
      return out;
    }

    s.unlocked = max(1, asInt(j['unlocked'], 1));
    s.stars = intMap(j['stars']);
    s.best = intMap(j['best']);
    s.coins = max(0, asInt(j['coins'], 500));
    s.lives = asInt(j['lives'], AppState.maxLives).clamp(0, AppState.maxLives);
    s.lifeClock = asInt(j['lifeClock'], 0);
    final b = j['boosters'];
    if (b is Map) {
      for (final t in BoosterType.values) {
        s.boosters[t] = max(0, asInt(b[t.name], t.starting));
      }
    }
    s.haptics = asBool(j['haptics'], true);
    s.sound = asBool(j['sound'], true);
    s.music = asBool(j['music'], true);
    s.hints = asBool(j['hints'], true);
    s.tapActivate = asBool(j['tapActivate'], true);
    s.winStreak = max(0, asInt(j['winStreak'], 0));
    final seen = j['tutorialsSeen'];
    if (seen is List) {
      s.tutorialsSeen = seen.whereType<num>().map((e) => e.toInt()).toSet();
    }
    s.attempts = intMap(j['attempts']);
    s.wins = intMap(j['wins']);
    s.sessions = max(0, asInt(j['sessions'], 0));
    Set<int> intSet(dynamic v) =>
        v is List ? v.whereType<num>().map((e) => e.toInt()).toSet() : {};
    s.gold = max(0, asInt(j['gold'], 20));
    s.unlimitedUntil = asInt(j['unlimitedUntil'], 0);
    s.adsRemoved = asBool(j['adsRemoved'], false);
    final bought = j['purchases'];
    if (bought is List) s.purchases = bought.whereType<String>().toSet();
    final orders = j['orders'];
    if (orders is List) s.orders = orders.whereType<String>().toSet();
    s.dailyStreak = max(0, asInt(j['dailyStreak'], 0));
    s.dailyLast = asInt(j['dailyLast'], -1000);
    s.eventWeek = asInt(j['eventWeek'], -1);
    s.eventProgress = max(0, asInt(j['eventProgress'], 0));
    s.eventClaimed = max(0, asInt(j['eventClaimed'], 0));
    s.seasonNo = asInt(j['seasonNo'], -1);
    s.seasonPoints = max(0, asInt(j['seasonPoints'], 0));
    s.premiumPass = asBool(j['premiumPass'], false);
    s.seasonFree = intSet(j['seasonFree']);
    s.seasonPremium = intSet(j['seasonPremium']);
    s.levelsSinceAd = max(0, asInt(j['levelsSinceAd'], 0));
    s.freeBoosterDay = asInt(j['freeBoosterDay'], -1);
    s.firstDay = asInt(j['firstDay'], -1);
    s.playDays = intSet(j['playDays']);
    final cs = j['counters'];
    if (cs is Map) {
      cs.forEach((k, v) {
        if (v is num) s.counters['$k'] = v.toInt();
      });
    }
    s.notifications = asBool(j['notifications'], false);
    final rc = j['remoteConfig'];
    if (rc is String) s.remoteConfig = rc;
    s.savedAt = asInt(j['savedAt'], 0);
    final ev = j['events'];
    if (ev is List) {
      s.events = ev
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return s;
  }

  /// Parses a save from text, or null if it is not one.
  static SaveData? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || !decoded.containsKey('unlocked')) return null;
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  SaveData copy() => fromJson(jsonDecode(jsonEncode(toJson())));

  bool get isFresh => stars.isEmpty && unlocked <= 1;

  /// Combines this device's save with the cloud copy.
  ///
  /// Progress never goes backwards: levels, stars, best scores, tutorials
  /// and purchases are the best of both. Coins, lives, boosters and the
  /// live-ops state come from the newer copy (a fresh install counts as
  /// older than any real progress). Settings stay as on this device.
  static SaveData merge(SaveData local, SaveData cloud) {
    final cloudNewer =
        local.isFresh || (!cloud.isFresh && cloud.savedAt > local.savedAt);
    final out = (cloudNewer ? cloud : local).copy();
    final other = cloudNewer ? local : cloud;
    void maxInto(Map<int, int> into, Map<int, int> from) {
      from.forEach((k, v) => into[k] = max(v, into[k] ?? 0));
    }

    out.unlocked = max(out.unlocked, other.unlocked);
    maxInto(out.stars, other.stars);
    maxInto(out.best, other.best);
    maxInto(out.attempts, other.attempts);
    maxInto(out.wins, other.wins);
    out.tutorialsSeen.addAll(other.tutorialsSeen);
    out.purchases.addAll(other.purchases);
    out.orders.addAll(other.orders);
    out.adsRemoved = out.adsRemoved || other.adsRemoved;
    if (out.seasonNo == other.seasonNo) {
      out.premiumPass = out.premiumPass || other.premiumPass;
    }
    out.unlimitedUntil = max(out.unlimitedUntil, other.unlimitedUntil);
    out.playDays.addAll(other.playDays);
    if (other.firstDay >= 0 &&
        (out.firstDay < 0 || other.firstDay < out.firstDay)) {
      out.firstDay = other.firstDay;
    }
    out.sessions = max(out.sessions, other.sessions);
    other.counters.forEach(
      (k, v) => out.counters[k] = max(v, out.counters[k] ?? 0),
    );
    // Device settings and local-only data.
    out.haptics = local.haptics;
    out.sound = local.sound;
    out.music = local.music;
    out.hints = local.hints;
    out.tapActivate = local.tapActivate;
    out.notifications = local.notifications;
    out.remoteConfig = local.remoteConfig;
    out.events = List.of(local.events);
    out.savedAt = max(local.savedAt, cloud.savedAt);
    return out;
  }
}

class LevelReward {
  final int coins;
  final bool firstClear;
  final BoosterType? booster;
  const LevelReward(this.coins, this.firstClear, this.booster);
}

/// App-wide state: progress, economy, lives, settings and analytics.
class AppState extends ChangeNotifier {
  static const maxLives = 5;
  static const lifeRefill = Duration(minutes: 30);
  static const refillCost = 600;
  static const boosterCost = 250;
  static const _key = 'blend_burst_save_v1';
  static const _maxEvents = 300;

  final DateTime Function() _now;
  SharedPreferences? _prefs;
  SaveData data = SaveData();
  int totalLevels = 0;

  /// Live tuning, from the copy cached on the previous launch.
  RemoteConfig config = const RemoteConfig();

  AppState({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  /// Loads saved progress. Never throws: on any problem the game starts
  /// with fresh progress instead of crashing.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
      );
      final raw = _prefs!.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          data = SaveData.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (e, st) {
      debugPrint('Could not load save data: $e\n$st');
    }
    data.sessions++;
    final today = dayNumber(_now());
    if (data.firstDay < 0) data.firstDay = today;
    data.playDays.add(today);
    if (data.playDays.length > 400) {
      data.playDays.remove(data.playDays.reduce(min));
    }
    log('session_start');
    config = RemoteConfig.parse(data.remoteConfig);
    _tickLives();
    _persist();
  }

  /// Fetches a fresh remote config for the next launch.
  Future<void> refreshRemoteConfig() async {
    final text = await RemoteConfig.download();
    if (text == null || text == data.remoteConfig) return;
    data.remoteConfig = text;
    _persist();
  }

  /// Reminders to schedule while the app is in the background.
  List<Reminder> reminders() {
    final now = _now();
    final out = <Reminder>[];
    final next = nextLifeIn;
    if (next != null && !hasUnlimited) {
      final full = next + lifeRefill * (maxLives - data.lives - 1);
      out.add(
        Reminder(
          1,
          'Your lives are full!',
          'Come back and blend some colors.',
          now.add(full),
        ),
      );
    }
    final e = event;
    if (eventProgress < WeeklyEvent.tiers.last) {
      out.add(
        Reminder(
          2,
          'Paint Collector ends soon',
          'Only 3 hours left to collect ${e.colorName} tiles!',
          e.ends.subtract(const Duration(hours: 3)),
        ),
      );
    }
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 10);
    out.add(
      Reminder(
        3,
        'Your daily gift is ready',
        'Open Blend Burst to claim it.',
        daily.claimable ? now.add(const Duration(hours: 20)) : tomorrow,
      ),
    );
    return out;
  }

  void setNotifications(bool v) {
    data.notifications = v;
    log('notifications', {'on': v});
    _changed();
  }

  /// Replaces all progress (after merging the cloud save).
  void replaceData(SaveData merged) {
    data = merged;
    if (totalLevels > 0) data.unlocked = min(data.unlocked, totalLevels);
    _tickLives();
    _changed();
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      unawaited(
        prefs.setString(_key, jsonEncode(data.toJson())).catchError((Object e) {
          debugPrint('Could not save: $e');
          return false;
        }),
      );
    } catch (e) {
      debugPrint('Could not save: $e');
    }
  }

  bool _notifyScheduled = false;

  void _changed() {
    data.savedAt = _now().millisecondsSinceEpoch;
    _persist();
    // Screens may change state while widgets are building (e.g. in
    // initState). Notifying then is an error, so wait for the frame to end.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } else {
      notifyListeners();
    }
  }

  // --------------------------------------------------------------- lives

  void _tickLives() {
    if (data.lives >= maxLives) {
      data.lifeClock = 0;
      return;
    }
    final now = _now().millisecondsSinceEpoch;
    if (data.lifeClock <= 0 || data.lifeClock > now) data.lifeClock = now;
    final gained = (now - data.lifeClock) ~/ lifeRefill.inMilliseconds;
    if (gained > 0) {
      data.lives = min(maxLives, data.lives + gained);
      data.lifeClock += gained * lifeRefill.inMilliseconds;
      if (data.lives >= maxLives) data.lifeClock = 0;
    }
  }

  int get lives {
    final before = data.lives;
    _tickLives();
    if (data.lives != before) _persist();
    return data.lives;
  }

  /// Time until the next life, or null when lives are full.
  Duration? get nextLifeIn {
    _tickLives();
    if (data.lives >= maxLives) return null;
    final due = data.lifeClock + lifeRefill.inMilliseconds;
    return Duration(milliseconds: max(0, due - _now().millisecondsSinceEpoch));
  }

  /// Time left on unlimited lives, or null.
  Duration? get unlimitedLeft {
    final left = data.unlimitedUntil - _now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : null;
  }

  bool get hasUnlimited => unlimitedLeft != null;

  /// Whether a level can be started (a life, or unlimited lives).
  bool get canPlay => hasUnlimited || lives > 0;

  void loseLife() {
    _tickLives();
    if (hasUnlimited) return;
    if (data.lives <= 0) return;
    if (data.lives >= maxLives) data.lifeClock = _now().millisecondsSinceEpoch;
    data.lives--;
    _changed();
  }

  void addLives(int n) {
    _tickLives();
    data.lives = min(maxLives, data.lives + n);
    if (data.lives >= maxLives) data.lifeClock = 0;
    _changed();
  }

  bool buyRefill() {
    if (!spendCoins(refillCost)) return false;
    addLives(maxLives);
    log('lives_refill', {'cost': refillCost});
    return true;
  }

  // ------------------------------------------------------------- economy

  int get coins => data.coins;

  bool spendCoins(int amount) {
    if (data.coins < amount) return false;
    data.coins -= amount;
    _changed();
    return true;
  }

  void addCoins(int amount) {
    data.coins += amount;
    _changed();
  }

  /// Price of the next +5 moves on the current attempt.
  static int extraMovesCost(int alreadyBought) =>
      const [300, 500, 800][min(alreadyBought, 2)];

  int boosterCount(BoosterType t) => data.boosters[t] ?? 0;

  bool useBooster(BoosterType t, int levelId) {
    if (boosterCount(t) <= 0) return false;
    data.boosters[t] = boosterCount(t) - 1;
    log('booster_used', {'booster': t.name, 'level': levelId});
    _changed();
    return true;
  }

  bool buyBooster(BoosterType t) {
    if (!spendCoins(boosterCost)) return false;
    data.boosters[t] = boosterCount(t) + 1;
    log('booster_bought', {'booster': t.name});
    _changed();
    return true;
  }

  // ------------------------------------------------------------ progress

  bool isUnlocked(int levelId) => levelId <= data.unlocked;
  int starsFor(int levelId) => data.stars[levelId] ?? 0;
  int get totalStars => data.stars.values.fold(0, (a, b) => a + b);

  void startLevel(int levelId) {
    data.attempts[levelId] = (data.attempts[levelId] ?? 0) + 1;
    log('level_start', {'level': levelId});
    _changed();
  }

  LevelReward completeLevel(int levelId, int stars, int score, int movesLeft) {
    final firstClear = !data.stars.containsKey(levelId);
    data.stars[levelId] = max(stars, data.stars[levelId] ?? 0);
    data.best[levelId] = max(score, data.best[levelId] ?? 0);
    data.wins[levelId] = (data.wins[levelId] ?? 0) + 1;
    if (levelId >= data.unlocked) {
      data.unlocked = totalLevels > 0
          ? min(levelId + 1, totalLevels)
          : levelId + 1;
    }
    data.winStreak++;
    var coins = 10 + 10 * stars;
    if (firstClear) coins += 40;
    data.coins += coins;
    BoosterType? gift;
    if (firstClear && levelId % 4 == 0) {
      const gifts = BoosterType.values;
      gift = gifts[(levelId ~/ 4) % gifts.length];
      data.boosters[gift] = boosterCount(gift) + 1;
    }
    _syncLiveOps();
    data.seasonPoints += Season.pointsFor(stars);
    data.levelsSinceAd++;
    log('level_win', {
      'level': levelId,
      'stars': stars,
      'score': score,
      'movesLeft': movesLeft,
    });
    _changed();
    return LevelReward(coins, firstClear, gift);
  }

  void failLevel(int levelId, {required String reason}) {
    data.winStreak = 0;
    log('level_fail', {'level': levelId, 'reason': reason});
    loseLife();
  }

  // ------------------------------------------------------------- economy

  int get gold => data.gold;

  bool spendGold(int amount) {
    if (data.gold < amount) return false;
    data.gold -= amount;
    log('gold_spent', {'amount': amount});
    _changed();
    return true;
  }

  void addGold(int amount) {
    data.gold += amount;
    _changed();
  }

  /// Hands out a reward (daily, event, season, shop).
  void grant(Reward r, String source) {
    data.coins += r.coins;
    data.gold += r.gold;
    for (final e in r.boosters.entries) {
      data.boosters[e.key] = boosterCount(e.key) + e.value;
    }
    if (r.unlimitedMinutes > 0) {
      final now = _now().millisecondsSinceEpoch;
      data.unlimitedUntil =
          max(data.unlimitedUntil, now) + r.unlimitedMinutes * 60000;
    }
    if (r.lives > 0) {
      _tickLives();
      data.lives = min(maxLives, data.lives + r.lives);
      if (data.lives >= maxLives) data.lifeClock = 0;
    }
    log('reward', {'source': source, 'reward': '$r'});
    _changed();
  }

  /// Whether [p] can be bought now (one-time items only once).
  bool canBuy(Product p) {
    if (p.once && data.purchases.contains(p.id)) return false;
    if (p.pay == PayWith.ad) return data.freeBoosterDay != dayNumber(_now());
    return true;
  }

  /// Buys a gold, coin or ad item. Real-money items go through the store
  /// (see [completePurchase]). Returns false if it cannot be afforded.
  bool buyWithCurrency(Product p) {
    if (!canBuy(p)) return false;
    switch (p.pay) {
      case PayWith.gold:
        if (!spendGold(p.price)) return false;
      case PayWith.coins:
        if (!spendCoins(p.price)) return false;
      case PayWith.ad:
        data.freeBoosterDay = dayNumber(_now());
      case PayWith.money:
        return false;
    }
    grant(p.reward, 'shop:${p.id}');
    return true;
  }

  /// Delivers a real-money purchase after the store confirmed it.
  /// [order] is the store's order ID, remembered so it is never delivered
  /// twice.
  void completePurchase(Product p, {String? order}) {
    if (order != null) data.orders.add(order);
    data.purchases.add(p.id);
    // Any purchase also turns off ad breaks.
    data.adsRemoved = true;
    if (p.id == 'pass') {
      _syncLiveOps();
      data.premiumPass = true;
    }
    log('purchase', {'product': p.id, 'price': p.price});
    grant(p.reward, 'purchase:${p.id}');
  }

  /// A one-time item the store reports as already owned (e.g. after a
  /// reinstall): it is remembered, but its contents are not granted again.
  void restorePurchase(Product p, String order) {
    data.orders.add(order);
    if (data.purchases.add(p.id)) {
      data.adsRemoved = true;
      log('purchase_restored', {'product': p.id});
    }
    _changed();
  }

  bool get spentMoney => data.purchases.isNotEmpty;

  // --------------------------------------------------------------- ads

  /// Interstitial cadence: only after a win, every 3rd level, never for
  /// players who removed ads or bought anything.
  bool takeInterstitialSlot() {
    if (data.adsRemoved || spentMoney) return false;
    if (data.levelsSinceAd < config.adEvery) return false;
    data.levelsSinceAd = 0;
    log('interstitial');
    _changed();
    return true;
  }

  // -------------------------------------------------------------- daily

  DailyState get daily => dailyState(
    today: dayNumber(_now()),
    lastDay: data.dailyLast,
    streak: data.dailyStreak,
  );

  /// Claims today's login reward ([doubled] after a rewarded ad).
  Reward? claimDaily({bool doubled = false}) {
    final d = daily;
    if (!d.claimable) return null;
    final today = dayNumber(_now());
    data.dailyStreak = data.dailyLast == today - 1 ? data.dailyStreak + 1 : 1;
    data.dailyLast = today;
    final r = dailyRewards[d.index] * (doubled ? 2 : 1);
    grant(r, 'daily');
    return r;
  }

  // ------------------------------------------------------ event, season

  /// Starts a fresh event or season when the calendar moved on.
  void _syncLiveOps() {
    final now = _now();
    final week = WeeklyEvent.at(now).week;
    if (data.eventWeek != week) {
      data.eventWeek = week;
      data.eventProgress = 0;
      data.eventClaimed = 0;
    }
    final season = Season.at(now).number;
    if (data.seasonNo != season) {
      data.seasonNo = season;
      data.seasonPoints = 0;
      data.premiumPass = false;
      data.seasonFree.clear();
      data.seasonPremium.clear();
      data.purchases.remove('pass');
    }
  }

  WeeklyEvent get event {
    _syncLiveOps();
    final e = WeeklyEvent.at(_now());
    final color = config.eventColor;
    if (color == null || !WeeklyEvent.colors.contains(color)) return e;
    return WeeklyEvent(e.week, color, e.ends);
  }

  /// Gold price of the next +5 moves.
  int extraMovesGoldCost(int alreadyBought) {
    final prices = config.extraMovesGold;
    return prices == null
        ? extraMovesGold(alreadyBought)
        : prices[alreadyBought.clamp(0, 2)];
  }

  int get eventProgress {
    _syncLiveOps();
    return data.eventProgress;
  }

  /// Counts tiles collected in a level towards the weekly event.
  void addEventTiles(Map<String, int> collectedByColorName) {
    final e = event;
    final n = collectedByColorName[e.colorName] ?? 0;
    if (n <= 0) return;
    data.eventProgress += n;
    _changed();
  }

  /// Tier rewards reached but not claimed yet, in order.
  int get eventClaimable =>
      WeeklyEvent.tiersReached(eventProgress) - data.eventClaimed;

  Reward? claimEventTier() {
    if (eventClaimable <= 0) return null;
    final r = WeeklyEvent.rewards[data.eventClaimed];
    data.eventClaimed++;
    grant(r, 'event');
    return r;
  }

  Season get season {
    _syncLiveOps();
    return Season.at(_now());
  }

  int get seasonPoints {
    _syncLiveOps();
    return data.seasonPoints;
  }

  bool get premiumPass {
    _syncLiveOps();
    return data.premiumPass;
  }

  bool seasonClaimed(int tier, {required bool premium}) =>
      (premium ? data.seasonPremium : data.seasonFree).contains(tier);

  bool canClaimSeason(int tier, {required bool premium}) =>
      tier < Season.tiersReached(seasonPoints) &&
      !seasonClaimed(tier, premium: premium) &&
      (!premium || premiumPass);

  Reward? claimSeason(int tier, {required bool premium}) {
    if (!canClaimSeason(tier, premium: premium)) return null;
    (premium ? data.seasonPremium : data.seasonFree).add(tier);
    final r = premium ? Season.premiumReward(tier) : Season.freeReward(tier);
    grant(r, premium ? 'season_premium' : 'season_free');
    return r;
  }

  int get seasonClaimable {
    var n = 0;
    for (var t = 0; t < Season.tiersReached(seasonPoints); t++) {
      if (!seasonClaimed(t, premium: false)) n++;
      if (premiumPass && !seasonClaimed(t, premium: true)) n++;
    }
    return n;
  }

  /// Free starting boosters earned by the current win streak.
  Set<BoosterType> get streakBoosters => streakBonus(data.winStreak);

  void markTutorialSeen(int levelId) {
    if (data.tutorialsSeen.add(levelId)) _changed();
  }

  // ------------------------------------------------------------ settings

  void setHaptics(bool v) {
    data.haptics = v;
    _changed();
  }

  void setSound(bool v) {
    data.sound = v;
    _changed();
  }

  void setMusic(bool v) {
    data.music = v;
    _changed();
  }

  void setHints(bool v) {
    data.hints = v;
    _changed();
  }

  void setTapActivate(bool v) {
    data.tapActivate = v;
    _changed();
  }

  void resetProgress() {
    data = SaveData();
    log('progress_reset');
    _changed();
  }

  // ----------------------------------------------------------- analytics

  void log(String name, [Map<String, dynamic> params = const {}]) {
    data.counters[name] = (data.counters[name] ?? 0) + 1;
    data.events.add({
      'e': name,
      't': _now().millisecondsSinceEpoch,
      if (params.isNotEmpty) 'p': params,
    });
    if (data.events.length > _maxEvents) {
      data.events.removeRange(0, data.events.length - _maxEvents);
    }
  }

  void logAndSave(String name, [Map<String, dynamic> params = const {}]) {
    log(name, params);
    _persist();
  }
}
