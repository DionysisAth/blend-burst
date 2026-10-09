import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BoosterType { brush, freeSwap, colorSplash }

extension BoosterInfo on BoosterType {
  String get label => const {
    BoosterType.brush: 'Brush',
    BoosterType.freeSwap: 'Free Swap',
    BoosterType.colorSplash: 'Color Splash',
  }[this]!;

  String get help => const {
    BoosterType.brush: 'Tap a tile to wipe it away.',
    BoosterType.freeSwap: 'Tap two tiles to swap them.',
    BoosterType.colorSplash: "Tap a tile to paint its whole row in its color.",
  }[this]!;
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
  Map<BoosterType, int> boosters = {for (final b in BoosterType.values) b: 3};
  bool haptics = true;
  bool hints = true;
  bool tapActivate = true;
  int winStreak = 0;
  Set<int> tutorialsSeen = {};
  Map<int, int> attempts = {};
  Map<int, int> wins = {};
  int sessions = 0;
  List<Map<String, dynamic>> events = [];

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
    'hints': hints,
    'tapActivate': tapActivate,
    'winStreak': winStreak,
    'tutorialsSeen': tutorialsSeen.toList(),
    'attempts': attempts.map((k, v) => MapEntry('$k', v)),
    'wins': wins.map((k, v) => MapEntry('$k', v)),
    'sessions': sessions,
    'events': events,
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
        s.boosters[t] = max(0, asInt(b[t.name], 3));
      }
    }
    s.haptics = asBool(j['haptics'], true);
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
    final ev = j['events'];
    if (ev is List) {
      s.events = ev
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return s;
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
    log('session_start');
    _tickLives();
    _persist();
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

  void loseLife() {
    _tickLives();
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
      gift = BoosterType.values[(levelId ~/ 4) % BoosterType.values.length];
      data.boosters[gift] = boosterCount(gift) + 1;
    }
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

  void markTutorialSeen(int levelId) {
    if (data.tutorialsSeen.add(levelId)) _changed();
  }

  // ------------------------------------------------------------ settings

  void setHaptics(bool v) {
    data.haptics = v;
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
