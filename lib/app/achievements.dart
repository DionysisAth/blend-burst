import 'app_state.dart';

/// A Play Games achievement and when it is earned. The IDs from the Play
/// Console are in games_ids.dart (written by tool/play/games_setup.py,
/// which also creates these achievements there).
class AchievementDef {
  final String key;
  final String name;
  final String description;
  final int points;
  final bool Function(SaveData d) earned;
  const AchievementDef(
    this.key,
    this.name,
    this.description,
    this.points,
    this.earned,
  );
}

bool _cleared(SaveData d, int level) => d.stars.containsKey(level);
int _stars(SaveData d) => d.stars.values.fold(0, (a, b) => a + b);

final achievements = <AchievementDef>[
  AchievementDef(
    'first_burst',
    'First Burst',
    'Complete your first level.',
    5,
    (d) => _cleared(d, 1),
  ),
  AchievementDef(
    'art_studio',
    'Art Studio Graduate',
    'Complete the Art Studio (level 15).',
    50,
    (d) => _cleared(d, 15),
  ),
  AchievementDef(
    'rainbow_garden',
    'Rainbow Gardener',
    'Complete the Rainbow Garden (level 30).',
    50,
    (d) => _cleared(d, 30),
  ),
  AchievementDef(
    'paint_factory',
    'Paint Factory Boss',
    'Complete the Paint Factory (level 45).',
    75,
    (d) => _cleared(d, 45),
  ),
  AchievementDef(
    'sky_gallery',
    'Sky Gallery Curator',
    'Complete the Sky Gallery (level 60).',
    75,
    (d) => _cleared(d, 60),
  ),
  AchievementDef(
    'ink_lagoon',
    'Ink Lagoon Diver',
    'Complete the Ink Lagoon (level 75).',
    100,
    (d) => _cleared(d, 75),
  ),
  AchievementDef(
    'prism_peaks',
    'Prism Peaks Climber',
    'Complete Prism Peaks (level 90).',
    100,
    (d) => _cleared(d, 90),
  ),
  AchievementDef(
    'bucket_brigade',
    'Bucket Brigade Captain',
    'Complete the Bucket Brigade (level 105).',
    100,
    (d) => _cleared(d, 105),
  ),
  AchievementDef(
    'gravity_galaxy',
    'Gravity Galaxy Master',
    'Complete every level.',
    150,
    (d) => _cleared(d, 120),
  ),
  AchievementDef(
    'stars_100',
    'Star Collector',
    'Earn 100 stars.',
    50,
    (d) => _stars(d) >= 100,
  ),
  AchievementDef(
    'stars_300',
    'Star Hoarder',
    'Earn 300 stars.',
    100,
    (d) => _stars(d) >= 300,
  ),
  AchievementDef(
    'spectacular',
    'Spectacular!',
    'Clear the whole board with a combo.',
    50,
    (d) => (d.counters['spectacular'] ?? 0) > 0,
  ),
];
