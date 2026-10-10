import 'models.dart';

enum GoalType {
  score,
  stains,
  glass,
  collect,

  /// Break every chain on locked tiles.
  locks,

  /// Clear all the ink (which spreads when left alone).
  ink,

  /// Bring paint buckets to the exit edge.
  drop,
}

class Goal {
  final GoalType type;

  /// For stains/glass/locks/ink a target of 0 means "all of them on the
  /// board"; for drop it means all of the level's buckets.
  final int target;
  final TileColor? color;

  const Goal(this.type, this.target, {this.color});

  factory Goal.fromJson(Map<String, dynamic> j) {
    final type = GoalType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => GoalType.score,
    );
    final color = j['color'] is String ? tileColorFromName(j['color']) : null;
    if (type == GoalType.collect && color == null) {
      throw FormatException('collect goal needs a valid color: $j');
    }
    return Goal(type, (j['target'] as num?)?.toInt() ?? 0, color: color);
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (target != 0 || type == GoalType.score || type == GoalType.collect)
      'target': target,
    if (color != null) 'color': color!.name,
  };
}

/// A level as stored in the JSON level files.
///
/// `layout` rows (one char per cell):
///   `.` playable   `#` hole   `s` paint stain   `1` `2` `3` glass block layers
///   `k` `K` locked tile (one or two chains)   `i` ink
/// optional `tiles` rows place starting tiles (`.` = random):
///   color letters R B Y P G O N K, `g` = random-colored gravity switch tile,
///   `D` = paint bucket.
/// optional `filters` rows: a color letter turns tiles falling through that
///   cell into that color (`.` = none).
/// optional `zones` rows: `v` `^` `<` `>` give that cell its own gravity
///   (`.` = the level's gravity).
class LevelDef {
  int id;
  String name;
  int moves;
  List<TileColor> colors;
  List<String> layout;
  List<String>? tiles;
  Gravity gravity;
  bool blending;
  List<Goal> goals;
  List<int> stars;
  double switchChance;
  int maxSwitches;
  bool hard;
  String? tutorial;

  /// Optional illustration for the tutorial card (see TutorialArt).
  String? tutorialArt;

  List<String>? filters;
  List<String>? zones;

  /// Paint buckets that appear in the level in total (including `D` tiles),
  /// and how many may be on the board at once.
  int buckets;
  int bucketsOnBoard;

  /// Gravity rotates clockwise every this many moves (0 = never).
  int gravityEvery;

  LevelDef({
    required this.id,
    required this.name,
    required this.moves,
    required this.colors,
    required this.layout,
    this.tiles,
    this.gravity = Gravity.down,
    this.blending = true,
    required this.goals,
    required this.stars,
    this.switchChance = 0,
    this.maxSwitches = 2,
    this.hard = false,
    this.tutorial,
    this.tutorialArt,
    this.filters,
    this.zones,
    this.buckets = 0,
    this.bucketsOnBoard = 2,
    this.gravityEvery = 0,
  }) {
    validate();
  }

  int get rows => layout.length;
  int get cols => layout.isEmpty ? 0 : layout.first.length;

  void validate() {
    if (layout.isEmpty || layout.length > 12) {
      throw FormatException('Level $id: layout must have 1..12 rows');
    }
    final w = layout.first.length;
    if (w == 0 || w > 12) {
      throw FormatException('Level $id: layout must have 1..12 columns');
    }
    for (final row in layout) {
      if (row.length != w) {
        throw FormatException('Level $id: layout rows differ in length');
      }
      for (final ch in row.split('')) {
        if (!'.#s123kKi'.contains(ch)) {
          throw FormatException('Level $id: bad layout char "$ch"');
        }
      }
    }
    if (tiles != null) {
      if (tiles!.length != layout.length || tiles!.any((r) => r.length != w)) {
        throw FormatException('Level $id: tiles must match layout size');
      }
      for (final row in tiles!) {
        for (final ch in row.split('')) {
          if (ch != '.' &&
              ch != 'g' &&
              ch != 'D' &&
              tileColorFromCode(ch) == null) {
            throw FormatException('Level $id: bad tile char "$ch"');
          }
        }
      }
    }
    void grid(String name, List<String>? g, bool Function(String) ok) {
      if (g == null) return;
      if (g.length != layout.length || g.any((r) => r.length != w)) {
        throw FormatException('Level $id: $name must match layout size');
      }
      for (final row in g) {
        for (final ch in row.split('')) {
          if (ch != '.' && !ok(ch)) {
            throw FormatException('Level $id: bad $name char "$ch"');
          }
        }
      }
    }

    grid('filters', filters, (ch) => tileColorFromCode(ch) != null);
    grid('zones', zones, (ch) => gravityFromArrow(ch) != null);
    if (goals.any((g) => g.type == GoalType.drop) && buckets <= 0) {
      throw FormatException('Level $id: a drop goal needs buckets');
    }
    if (gravityEvery < 0) {
      throw FormatException('Level $id: gravityEvery must be >= 0');
    }
    if (colors.length < 3) {
      throw FormatException('Level $id: needs at least 3 colors');
    }
    if (moves <= 0) throw FormatException('Level $id: moves must be > 0');
    if (goals.isEmpty) throw FormatException('Level $id: needs a goal');
    if (stars.length != 3) {
      throw FormatException('Level $id: needs 3 star thresholds');
    }
  }

  factory LevelDef.fromJson(Map<String, dynamic> j) {
    List<String> strings(dynamic v) =>
        (v as List).map((e) => e.toString()).toList();
    return LevelDef(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? 'Level ${j['id']}').toString(),
      moves: (j['moves'] as num).toInt(),
      colors: strings(j['colors']).map((n) {
        final c = tileColorFromName(n);
        if (c == null) throw FormatException('Unknown color "$n"');
        return c;
      }).toList(),
      layout: strings(j['layout']),
      tiles: j['tiles'] == null ? null : strings(j['tiles']),
      gravity: gravityFromName(j['gravity'] as String?),
      blending: j['blending'] as bool? ?? true,
      goals: (j['goals'] as List)
          .map((g) => Goal.fromJson(Map<String, dynamic>.from(g as Map)))
          .toList(),
      stars: (j['stars'] as List).map((e) => (e as num).toInt()).toList(),
      switchChance: (j['switchChance'] as num?)?.toDouble() ?? 0,
      maxSwitches: (j['maxSwitches'] as num?)?.toInt() ?? 2,
      hard: j['hard'] as bool? ?? false,
      tutorial: j['tutorial'] as String?,
      tutorialArt: j['tutorialArt'] as String?,
      filters: j['filters'] == null ? null : strings(j['filters']),
      zones: j['zones'] == null ? null : strings(j['zones']),
      buckets: (j['buckets'] as num?)?.toInt() ?? 0,
      bucketsOnBoard: (j['bucketsOnBoard'] as num?)?.toInt() ?? 2,
      gravityEvery: (j['gravityEvery'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'moves': moves,
    'colors': colors.map((c) => c.name).toList(),
    'layout': layout,
    if (tiles != null) 'tiles': tiles,
    'gravity': gravity.name,
    'blending': blending,
    'goals': goals.map((g) => g.toJson()).toList(),
    'stars': stars,
    if (switchChance > 0) 'switchChance': switchChance,
    if (maxSwitches != 2) 'maxSwitches': maxSwitches,
    if (hard) 'hard': true,
    if (tutorial != null) 'tutorial': tutorial,
    if (tutorialArt != null) 'tutorialArt': tutorialArt,
    if (filters != null) 'filters': filters,
    if (zones != null) 'zones': zones,
    if (buckets > 0) 'buckets': buckets,
    if (bucketsOnBoard != 2) 'bucketsOnBoard': bucketsOnBoard,
    if (gravityEvery > 0) 'gravityEvery': gravityEvery,
  };

  LevelDef copy() => LevelDef.fromJson(toJson());

  int countLayout(bool Function(String ch) test) {
    var n = 0;
    for (final row in layout) {
      for (final ch in row.split('')) {
        if (test(ch)) n++;
      }
    }
    return n;
  }

  int get stainCount => countLayout((ch) => ch == 's');
  int get glassCount => countLayout((ch) => '123'.contains(ch));
  int get lockCount => countLayout((ch) => ch == 'k' || ch == 'K');
  int get inkCount => countLayout((ch) => ch == 'i');
  bool get hasZones => zones?.any((r) => r.contains(RegExp('[v^<>]'))) ?? false;
  bool get hasFilters =>
      filters?.any((r) => r.contains(RegExp('[^.]'))) ?? false;

  /// Whether gravity can change during this level (switch tiles, timed
  /// shifts, a non-default direction or zones): unlocks Gravity Flip.
  bool get usesGravity =>
      gravity != Gravity.down ||
      switchChance > 0 ||
      gravityEvery > 0 ||
      hasZones ||
      (tiles?.any((r) => r.contains('g')) ?? false);

  /// Episode index (0-based) for a level; 15 levels per episode.
  int get episode => (id - 1) ~/ 15;
}

/// Loads a level pack: `{"episode": "...", "levels": [ ... ]}`.
List<LevelDef> parseLevelPack(Map<String, dynamic> pack) =>
    (pack['levels'] as List)
        .map((l) => LevelDef.fromJson(Map<String, dynamic>.from(l as Map)))
        .toList();
