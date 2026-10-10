import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Tuning that can change without an app update: move limits per level,
/// the weekly event color, the ad cadence and the extra-moves gold prices.
///
/// The config is a JSON file (remote_config.json in the repository). The app
/// uses the copy cached on the previous launch, then fetches a fresh copy
/// in the background for the next one, so values never change mid-session
/// and a missing network costs nothing.
class RemoteConfig {
  final Map<String, dynamic> values;
  const RemoteConfig([this.values = const {}]);

  static const url =
      'https://raw.githubusercontent.com/DionysisAth/blend-burst/main/remote_config.json';

  factory RemoteConfig.parse(String? text) {
    if (text == null || text.isEmpty) return const RemoteConfig();
    try {
      final j = jsonDecode(text);
      return RemoteConfig(j is Map<String, dynamic> ? j : const {});
    } catch (_) {
      return const RemoteConfig();
    }
  }

  /// Move limit overrides, by level id.
  Map<int, int> get moves {
    final m = values['moves'];
    if (m is! Map) return const {};
    final out = <int, int>{};
    m.forEach((k, v) {
      final id = int.tryParse('$k');
      if (id != null && v is num && v >= 5 && v <= 99) out[id] = v.toInt();
    });
    return out;
  }

  /// Color of the weekly event, if set (e.g. "purple").
  String? get eventColor {
    final c = values['eventColor'];
    return c is String && c.isNotEmpty ? c : null;
  }

  /// Wins between interstitial ad breaks.
  int get adEvery {
    final v = values['adEvery'];
    return v is num && v >= 1 ? v.toInt() : 3;
  }

  /// Gold prices of +5 moves (1st, 2nd, 3rd+ purchase).
  List<int>? get extraMovesGold {
    final v = values['extraMovesGold'];
    if (v is! List || v.length != 3 || v.any((e) => e is! num || e < 1)) {
      return null;
    }
    return [for (final e in v) (e as num).toInt()];
  }

  /// Downloads the config text, or null on any failure.
  static Future<String?> download({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      // Only keep it if it parses.
      return jsonDecode(text) is Map ? text : null;
    } catch (e) {
      debugPrint('Remote config not fetched: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
