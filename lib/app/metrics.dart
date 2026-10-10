import 'app_state.dart';

/// The key metrics from the design doc, computed from this device's save.
/// A real analytics backend aggregates the same events over all players.
class Metrics {
  final SaveData d;
  final int today;
  const Metrics(this.d, this.today);

  int _count(String event) => d.counters[event] ?? 0;

  /// Whether the player came back on day [n] after the first day: true,
  /// false, or null when that day has not come yet.
  bool? retainedOnDay(int n) {
    if (d.firstDay < 0 || today < d.firstDay + n) return null;
    return d.playDays.contains(d.firstDay + n);
  }

  int get levelsStarted => d.attempts.values.fold(0, (a, b) => a + b);
  int get levelsWon => d.wins.values.fold(0, (a, b) => a + b);

  double get winRate => levelsStarted == 0 ? 0 : levelsWon / levelsStarted;

  double get levelsPerSession =>
      d.sessions == 0 ? 0 : levelsStarted / d.sessions;

  double get sessionsPerDay =>
      d.playDays.isEmpty ? 0 : d.sessions / d.playDays.length;

  /// Attempts per level, over the levels that were won.
  double get attemptsPerWonLevel {
    final won = d.wins.keys.toList();
    if (won.isEmpty) return 0;
    final tries = won.fold(0, (a, id) => a + (d.attempts[id] ?? 0));
    return tries / won.length;
  }

  /// Share of failed attempts where extra moves were bought.
  double get extraMovesRate {
    final fails = _count('level_fail');
    final bought = _count('extra_moves');
    return fails + bought == 0 ? 0 : bought / (fails + bought);
  }

  double get adsPerDay => d.playDays.isEmpty
      ? 0
      : (_count('ad_reward') + _count('interstitial')) / d.playDays.length;

  int get tutorialsSeen => d.tutorialsSeen.length;
  int get purchases => _count('purchase');

  /// The levels with the lowest win rate (at least 3 attempts): likely
  /// difficulty spikes.
  List<int> hardestLevels({int count = 3}) {
    final ids = d.attempts.keys.where((id) => d.attempts[id]! >= 3).toList()
      ..sort((a, b) {
        double rate(int id) => (d.wins[id] ?? 0) / d.attempts[id]!;
        return rate(a).compareTo(rate(b));
      });
    return ids.take(count).toList();
  }
}
