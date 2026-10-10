import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/level.dart';

class Episode {
  final int index;
  final String name;
  final List<LevelDef> levels;
  const Episode(this.index, this.name, this.levels);
}

/// Loads the bundled level packs (assets/levels/*.json).
class LevelRepository {
  static const packs = levelPackFiles;

  final List<Episode> episodes;
  final List<LevelDef> levels;

  LevelRepository._(this.episodes)
    : levels = [for (final e in episodes) ...e.levels];

  static Future<LevelRepository> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final episodes = <Episode>[];
    for (var i = 0; i < packs.length; i++) {
      final raw = await b.loadString(packs[i], cache: false);
      final pack = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      episodes.add(
        Episode(
          i,
          pack['episode']?.toString() ?? 'Episode ${i + 1}',
          parseLevelPack(pack),
        ),
      );
    }
    final repo = LevelRepository._(episodes);
    for (var i = 0; i < repo.levels.length; i++) {
      if (repo.levels[i].id != i + 1) {
        throw FormatException(
          'Levels must be numbered 1..N in order (found ${repo.levels[i].id} at ${i + 1})',
        );
      }
    }
    return repo;
  }

  LevelDef? byId(int id) =>
      id >= 1 && id <= levels.length ? levels[id - 1] : null;

  Episode episodeOf(LevelDef level) => episodes.firstWhere(
    (e) => e.levels.contains(level),
    orElse: () => episodes.first,
  );
}
