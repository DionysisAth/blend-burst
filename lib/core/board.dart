import 'dart:math';

import 'level.dart';
import 'models.dart';

/// What happened in one animation step. The UI animates from the previous
/// step's [Step.after] snapshot to this one.
enum StepKind {
  swap,
  swapBack,
  blend,
  clear,
  transform,
  fall,
  gravity,
  shuffle,
}

enum EffectKind {
  lineH,
  lineV,
  bomb,
  bigBomb,
  prism,
  whiteBurst,
  splash,
  rowCol,
  cross3,
  board,

  /// Ink crept from [Effect.targets] (the source cell) into [Effect.at].
  inkSpread,

  /// A paint bucket reached the exit at [Effect.at].
  drop,
}

class Effect {
  final EffectKind kind;
  final Pos at;
  final TileColor? color;
  final List<Pos> targets;
  const Effect(this.kind, this.at, {this.color, this.targets = const []});
}

class Cleared {
  final int id;
  final Pos at;
  final TileColor? color;
  final Special special;
  const Cleared(this.id, this.at, this.color, this.special);
}

class ScorePopup {
  final PosD at;
  final int amount;
  const ScorePopup(this.at, this.amount);
}

class BoardSnapshot {
  final Map<int, TileView> tiles;
  final List<int> glass;
  final List<bool> stain;
  final List<int> lock;
  final List<bool> ink;
  final Gravity gravity;
  final int score;
  final Map<TileColor, int> collected;
  final int stainsLeft;
  final int glassLeft;
  final int locksLeft;
  final int inkLeft;
  final int inkCleared;
  final int dropped;

  /// Moves until gravity rotates on its own (null if it never does).
  final int? shiftIn;

  const BoardSnapshot({
    required this.tiles,
    required this.glass,
    required this.stain,
    this.lock = const [],
    this.ink = const [],
    required this.gravity,
    required this.score,
    required this.collected,
    required this.stainsLeft,
    required this.glassLeft,
    this.locksLeft = 0,
    this.inkLeft = 0,
    this.inkCleared = 0,
    this.dropped = 0,
    this.shiftIn,
  });
}

class Step {
  final StepKind kind;
  final BoardSnapshot after;
  final List<Cleared> cleared;
  final List<Effect> effects;
  final Map<int, PosD> spawnFrom;

  /// For spawned tiles: the upstream-most cell of the segment they fill.
  /// The renderer hides them until they cross into that cell.
  final Map<int, Pos> spawnEntry;
  final Pos? from;
  final Pos? to;
  final int cascade;
  final List<ScorePopup> popups;
  final List<Pos> glassHit;

  /// Cells whose chain broke (the tile stays) and whose ink was cleared.
  final List<Pos> lockHit;
  final List<Pos> inkHit;

  const Step(
    this.kind,
    this.after, {
    this.cleared = const [],
    this.effects = const [],
    this.spawnFrom = const {},
    this.spawnEntry = const {},
    this.from,
    this.to,
    this.cascade = 0,
    this.popups = const [],
    this.glassHit = const [],
    this.lockHit = const [],
    this.inkHit = const [],
  });
}

enum MoveKind {
  none,
  invalid,
  swap,
  blend,
  whiteBurstBlend,
  combo,
  special,
  booster,
}

class MoveOutcome {
  final List<Step> steps;
  final bool usedMove;
  final MoveKind kind;
  const MoveOutcome(this.steps, this.usedMove, this.kind);

  static const none = MoveOutcome([], false, MoveKind.none);
}

/// A suggested move. When [a] == [b] the move is a tap on a special.
class Hint {
  final Pos a;
  final Pos b;
  final MoveKind kind;
  final int value;
  const Hint(this.a, this.b, this.kind, this.value);
}

enum _ActKind {
  lineH,
  lineV,
  bomb,
  bomb5,
  prism,
  whiteBurst,
  rowCol,
  cross3,
  wbCross,
  board,
}

class _Act {
  final _ActKind kind;
  final Pos at;
  final TileColor? color;
  const _Act(this.kind, this.at, [this.color]);

  static _Act fromTile(Tile t, Pos p) {
    switch (t.special) {
      case Special.lineH:
        return _Act(_ActKind.lineH, p, t.color);
      case Special.lineV:
        return _Act(_ActKind.lineV, p, t.color);
      case Special.bomb:
        return _Act(_ActKind.bomb, p, t.color);
      case Special.prism:
        return _Act(_ActKind.prism, p);
      case Special.whiteBurst:
        return _Act(_ActKind.whiteBurst, p);
      case Special.none:
        throw StateError('not a special');
    }
  }
}

class _Run {
  final List<Pos> cells;
  final bool horizontal;

  /// A 2×2 block of one color (not a line).
  final bool square;
  _Run(this.cells, this.horizontal, {this.square = false});
}

class MatchGroup {
  final Set<Pos> cells = {};
  final List<_Run> _runs = [];
  final TileColor color;
  MatchGroup(this.color);

  int get longestRun =>
      _runs.where((r) => !r.square).fold(0, (m, r) => max(m, r.cells.length));

  bool get hasSquare => _runs.any((r) => r.square);
}

/// The board model: tiles, obstacles, gravity and every rule that changes
/// them. All randomness comes from [rng] so games are reproducible.
class Board {
  final int rows;
  final int cols;
  final List<bool> playable;
  final List<int> glass;
  final List<bool> stain;

  /// Chains on locked tiles (0 = free). Locked tiles never move.
  final List<int> lock;

  /// Ink fills a cell (no tile) and spreads when left alone.
  final List<bool> ink;

  /// Color filters recolor tiles that fall into them.
  final List<TileColor?> filter;

  /// Per-cell gravity (gravity zones); null cells follow [gravity].
  final List<Gravity?> zone;
  final List<Tile?> tiles;
  Gravity gravity;
  final List<TileColor> palette;
  final bool blending;
  final double switchChance;
  final int maxSwitches;
  Random rng;

  int score = 0;
  final Map<TileColor, int> collected = {};
  int _nextId = 1;
  int _pendingRotations = 0;

  /// Buckets still to appear, how many may be on the board at once, and
  /// how many reached the exit.
  int bucketsToSpawn = 0;
  final int bucketsMax;
  int dropped = 0;

  /// Timed gravity: rotates every [gravityEvery] moves (0 = never).
  final int gravityEvery;
  int movesMade = 0;

  bool _inkCleared = false;

  /// Set after a very long chain: filters pause and new tiles avoid
  /// matches, so every cascade is guaranteed to settle.
  bool _calm = false;

  /// Ink cells cleared so far (ink can grow, so the goal counts these).
  int inkClearedTotal = 0;

  /// Gravity Flip: the direction to go back to after the next move, and the
  /// rotations switch tiles made in the meantime.
  Gravity? _flipRestore;
  int _flipTurns = 0;
  final bool hasZones;

  static const pointsPerTile = 60;
  static const pointsPerObstacle = 100;

  Board._(
    this.rows,
    this.cols, {
    required this.playable,
    required this.glass,
    required this.stain,
    required this.lock,
    required this.ink,
    required this.filter,
    required this.zone,
    required this.tiles,
    required this.gravity,
    required this.palette,
    required this.blending,
    required this.switchChance,
    required this.maxSwitches,
    required this.rng,
    this.bucketsMax = 2,
    this.gravityEvery = 0,
  }) : hasZones = zone.any((z) => z != null);

  factory Board.fromLevel(LevelDef level, Random rng) {
    final rows = level.rows, cols = level.cols, n = rows * cols;
    final b = Board._(
      rows,
      cols,
      playable: List.filled(n, true),
      glass: List.filled(n, 0),
      stain: List.filled(n, false),
      lock: List.filled(n, 0),
      ink: List.filled(n, false),
      filter: [
        for (var i = 0; i < n; i++)
          level.filters == null
              ? null
              : tileColorFromCode(level.filters![i ~/ cols][i % cols]),
      ],
      zone: [
        for (var i = 0; i < n; i++)
          level.zones == null
              ? null
              : gravityFromArrow(level.zones![i ~/ cols][i % cols]),
      ],
      tiles: List.filled(n, null),
      gravity: level.gravity,
      palette: List.of(level.colors),
      blending: level.blending,
      switchChance: level.switchChance,
      maxSwitches: level.maxSwitches,
      rng: rng,
      bucketsMax: level.bucketsOnBoard,
      gravityEvery: level.gravityEvery,
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final ch = level.layout[r][c];
        final i = r * cols + c;
        b.playable[i] = ch != '#';
        b.stain[i] = ch == 's';
        b.glass[i] = '123'.contains(ch) ? int.parse(ch) : 0;
        b.lock[i] = ch == 'k' ? 1 : (ch == 'K' ? 2 : 0);
        b.ink[i] = ch == 'i';
      }
    }
    b._fillInitial(level.tiles);
    b.bucketsToSpawn = max(0, level.buckets - b.bucketsOnBoard);
    final inkStart = b.ink.where((x) => x).length;
    b.inkLimit = max(inkStart * 2, inkStart + 6);
    return b;
  }

  Board clone({Random? rng}) {
    final b = Board._(
      rows,
      cols,
      playable: List.of(playable),
      glass: List.of(glass),
      stain: List.of(stain),
      lock: List.of(lock),
      ink: List.of(ink),
      filter: filter,
      zone: zone,
      tiles: tiles.map((t) => t?.copy()).toList(),
      gravity: gravity,
      palette: palette,
      blending: blending,
      switchChance: switchChance,
      maxSwitches: maxSwitches,
      rng: rng ?? Random(this.rng.nextInt(1 << 31)),
      bucketsMax: bucketsMax,
      gravityEvery: gravityEvery,
    );
    b.score = score;
    b.collected.addAll(collected);
    b._nextId = _nextId;
    b.bucketsToSpawn = bucketsToSpawn;
    b.dropped = dropped;
    b.inkClearedTotal = inkClearedTotal;
    b.inkLimit = inkLimit;
    b.movesMade = movesMade;
    b._flipRestore = _flipRestore;
    b._flipTurns = _flipTurns;
    return b;
  }

  // ---------------------------------------------------------------- queries

  int _i(Pos p) => p.r * cols + p.c;
  bool inBounds(Pos p) => p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols;
  bool isPlayable(Pos p) => inBounds(p) && playable[_i(p)];
  bool canHoldTile(Pos p) => isPlayable(p) && glass[_i(p)] == 0 && !ink[_i(p)];

  /// Holds a tile that can move (swap and fall): not locked.
  bool isMovable(Pos p) => canHoldTile(p) && lock[_i(p)] == 0;
  Tile? tileAt(Pos p) => inBounds(p) ? tiles[_i(p)] : null;
  int glassAt(Pos p) => inBounds(p) ? glass[_i(p)] : 0;
  bool stainAt(Pos p) => inBounds(p) && stain[_i(p)];
  int lockAt(Pos p) => inBounds(p) ? lock[_i(p)] : 0;
  bool inkAt(Pos p) => inBounds(p) && ink[_i(p)];
  TileColor? filterAt(Pos p) => inBounds(p) ? filter[_i(p)] : null;
  Gravity? zoneAt(Pos p) => inBounds(p) ? zone[_i(p)] : null;

  /// The direction tiles fall from [p].
  Gravity dirAt(Pos p) => zoneAt(p) ?? gravity;

  Iterable<Pos> get allPositions sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        yield Pos(r, c);
      }
    }
  }

  int get stainsLeft => stain.where((s) => s).length;
  int get glassLeft => glass.where((g) => g > 0).length;
  int get locksLeft => lock.where((l) => l > 0).length;
  int get inkLeft => ink.where((i) => i).length;
  int get bucketsOnBoard => tiles.where((t) => t?.bucket ?? false).length;

  /// Moves until the next timed gravity shift, or null.
  int? get shiftIn =>
      gravityEvery > 0 ? gravityEvery - movesMade % gravityEvery : null;
  int get _switchCount => tiles.where((t) => t?.gravitySwitch ?? false).length;

  static const _dirs = [Pos(0, 1), Pos(1, 0), Pos(0, -1), Pos(-1, 0)];

  Iterable<Pos> _neighbors(Pos p) => _dirs.map((d) => p + d).where(isPlayable);

  BoardSnapshot snapshot() {
    final map = <int, TileView>{};
    for (final p in allPositions) {
      final t = tiles[_i(p)];
      if (t != null) map[t.id] = t.view(p);
    }
    return BoardSnapshot(
      tiles: map,
      glass: List.unmodifiable(glass),
      stain: List.unmodifiable(stain),
      lock: List.unmodifiable(lock),
      ink: List.unmodifiable(ink),
      gravity: gravity,
      score: score,
      collected: Map.unmodifiable(collected),
      stainsLeft: stainsLeft,
      glassLeft: glassLeft,
      locksLeft: locksLeft,
      inkLeft: inkLeft,
      inkCleared: inkClearedTotal,
      dropped: dropped,
      shiftIn: shiftIn,
    );
  }

  /// Checks the structural invariants that must hold between moves.
  /// Returns a description of the first problem, or null if all is well.
  String? checkInvariants() {
    final ids = <int>{};
    for (final p in allPositions) {
      final i = _i(p);
      final t = tiles[i];
      if (!playable[i] &&
          (t != null || glass[i] > 0 || stain[i] || ink[i] || lock[i] > 0)) {
        return 'hole at $p holds content';
      }
      if (glass[i] > 0 && t != null) return 'glass at $p holds a tile';
      if (ink[i] && t != null) return 'ink at $p holds a tile';
      if (lock[i] > 0 && t == null) return 'lock at $p holds no tile';
      if (canHoldTile(p) && t == null) return 'empty cell at $p';
      if (t != null) {
        if (!ids.add(t.id)) return 'duplicate tile id ${t.id}';
        if (t.bucket) {
          if (t.color != null || t.special != Special.none) {
            return 'bucket at $p has a color or special';
          }
        } else if (t.special.hasColor && t.color == null) {
          return 'colorless $p';
        }
      }
    }
    if (findMatches().isNotEmpty) return 'unresolved match on board';
    return null;
  }

  // ------------------------------------------------------------ generation

  Tile _newTile(TileColor color, {bool allowSwitch = true}) {
    final sw =
        allowSwitch &&
        switchChance > 0 &&
        _switchCount < maxSwitches &&
        rng.nextDouble() < switchChance;
    return Tile(_nextId++, color, gravitySwitch: sw);
  }

  TileColor _randomColor() => palette[rng.nextInt(palette.length)];

  bool _wouldMatch(Pos p, TileColor color) {
    int count(int dr, int dc) {
      var n = 0;
      var q = Pos(p.r + dr, p.c + dc);
      while (true) {
        final t = tileAt(q);
        if (t == null || !t.special.hasColor || t.color != color) break;
        n++;
        q = Pos(q.r + dr, q.c + dc);
      }
      return n;
    }

    if (count(0, -1) + count(0, 1) + 1 >= 3 ||
        count(-1, 0) + count(1, 0) + 1 >= 3) {
      return true;
    }
    bool same(int dr, int dc) {
      final t = tileAt(Pos(p.r + dr, p.c + dc));
      return t != null && t.special.hasColor && t.color == color;
    }

    // Any of the four 2×2 squares that contain p.
    for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
      if (same(dr, 0) && same(0, dc) && same(dr, dc)) return true;
    }
    return false;
  }

  TileColor _safeColor(Pos p) {
    final options = palette.where((c) => !_wouldMatch(p, c)).toList();
    if (options.isEmpty) return _randomColor();
    return options[rng.nextInt(options.length)];
  }

  void _fillInitial(List<String>? preset) {
    for (var attempt = 0; attempt < 60; attempt++) {
      for (var i = 0; i < tiles.length; i++) {
        tiles[i] = null;
      }
      final randomCells = <Pos>[];
      for (final p in allPositions) {
        if (!canHoldTile(p)) continue;
        final ch = preset?[p.r][p.c] ?? '.';
        final color = tileColorFromCode(ch);
        if (color != null) {
          tiles[_i(p)] = Tile(_nextId++, color);
        } else if (ch == 'D') {
          tiles[_i(p)] = Tile(_nextId++, null, bucket: true);
        } else if (ch == 'g') {
          randomCells.add(p);
          tiles[_i(p)] = Tile(_nextId++, null, gravitySwitch: true);
        } else {
          randomCells.add(p);
        }
      }
      for (final p in randomCells) {
        final existing = tiles[_i(p)];
        final color = _safeColor(p);
        if (existing != null) {
          existing.color = color;
        } else {
          tiles[_i(p)] = Tile(_nextId++, color);
        }
      }
      if (findHint() != null || attempt == 59) break;
    }
    if (findMatches().isNotEmpty) {
      // Preset tiles formed a match: resolve it silently before play starts.
      _resolve([]);
      score = 0;
      collected.clear();
    }
    // Never start on a dead board, even if the preset tiles say so.
    if (findHint() == null) _shuffle([]);
  }

  // -------------------------------------------------------------- matching

  TileColor? _matchColor(int r, int c) {
    final t = tiles[r * cols + c];
    if (t == null || !t.special.hasColor) return null;
    return t.color;
  }

  List<MatchGroup> findMatches() {
    final runs = <_Run>[];
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < cols) {
        final color = _matchColor(r, c);
        var e = c + 1;
        if (color != null) {
          while (e < cols && _matchColor(r, e) == color) {
            e++;
          }
          if (e - c >= 3) {
            runs.add(_Run([for (var k = c; k < e; k++) Pos(r, k)], true));
          }
        }
        c = e;
      }
    }
    for (var c = 0; c < cols; c++) {
      var r = 0;
      while (r < rows) {
        final color = _matchColor(r, c);
        var e = r + 1;
        if (color != null) {
          while (e < rows && _matchColor(e, c) == color) {
            e++;
          }
          if (e - r >= 3) {
            runs.add(_Run([for (var k = r; k < e; k++) Pos(k, c)], false));
          }
        }
        r = e;
      }
    }
    // 2×2 squares of one color match too (and make a Line Blaster).
    for (var r = 0; r + 1 < rows; r++) {
      for (var c = 0; c + 1 < cols; c++) {
        final color = _matchColor(r, c);
        if (color == null ||
            _matchColor(r, c + 1) != color ||
            _matchColor(r + 1, c) != color ||
            _matchColor(r + 1, c + 1) != color) {
          continue;
        }
        runs.add(
          _Run(
            [Pos(r, c), Pos(r, c + 1), Pos(r + 1, c), Pos(r + 1, c + 1)],
            false,
            square: true,
          ),
        );
      }
    }
    if (runs.isEmpty) return const [];

    // Union runs that share a cell (L, T and + shapes).
    final parent = List<int>.generate(runs.length, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    final owner = <Pos, int>{};
    for (var i = 0; i < runs.length; i++) {
      for (final p in runs[i].cells) {
        final o = owner[p];
        if (o != null) {
          parent[find(i)] = find(o);
        } else {
          owner[p] = i;
        }
      }
    }
    final groups = <int, MatchGroup>{};
    for (var i = 0; i < runs.length; i++) {
      final root = find(i);
      final first = runs[i].cells.first;
      final g = groups.putIfAbsent(
        root,
        () => MatchGroup(tiles[_i(first)]!.color!),
      );
      g._runs.add(runs[i]);
      g.cells.addAll(runs[i].cells);
    }
    return groups.values.toList();
  }

  /// Decides which special (if any) a match group creates and where.
  (Special, Pos?) _planGroup(MatchGroup g, List<Pos> preferred) {
    final longest = g.longestRun;
    final lines = g._runs.where((r) => !r.square);
    final hasH = lines.any((r) => r.horizontal);
    final hasV = lines.any((r) => !r.horizontal);
    Special special;
    if (longest >= 5) {
      special = Special.prism;
    } else if (hasH && hasV) {
      special = Special.bomb;
    } else if (longest == 4) {
      final run = lines.firstWhere((r) => r.cells.length == 4);
      special = run.horizontal ? Special.lineH : Special.lineV;
    } else if (g.hasSquare) {
      // Like 4 in a line: the blaster follows the swipe direction.
      final horizontal = preferred.length >= 2
          ? preferred[0].r == preferred[1].r
          : rng.nextBool();
      special = horizontal ? Special.lineH : Special.lineV;
    } else {
      return (Special.none, null);
    }
    // A locked tile stays put when matched (its chain breaks), so a special
    // is never created on one.
    bool free(Pos p) => lock[_i(p)] == 0;
    for (final p in preferred) {
      if (g.cells.contains(p) && free(p)) return (special, p);
    }
    if (special == Special.bomb) {
      final h = g._runs.where((r) => r.horizontal).expand((r) => r.cells);
      final v = g._runs.where((r) => !r.horizontal).expand((r) => r.cells);
      final cross = h.toSet().intersection(v.toSet()).where(free);
      if (cross.isNotEmpty) return (special, cross.first);
    }
    final run = g._runs.reduce(
      (a, b) => a.cells.length >= b.cells.length ? a : b,
    );
    final mid = run.cells[run.cells.length ~/ 2];
    if (free(mid)) return (special, mid);
    final any = g.cells.where(free);
    if (any.isEmpty) return (Special.none, null);
    return (special, any.first);
  }

  // ------------------------------------------------------------ resolution

  /// Removes a tile and books its score, stain and color collection.
  int _consume(Pos p, Tile t, List<Cleared> into, int mult) {
    final i = _i(p);
    tiles[i] = null;
    into.add(Cleared(t.id, p, t.color, t.special));
    var gained = pointsPerTile * mult;
    if (stain[i]) {
      stain[i] = false;
      gained += pointsPerObstacle;
    }
    final color = t.color;
    if (color != null) collected[color] = (collected[color] ?? 0) + 1;
    if (t.gravitySwitch) _pendingRotations++;
    score += gained;
    return gained;
  }

  Set<Pos> _row(int r) => {for (var c = 0; c < cols; c++) Pos(r, c)};
  Set<Pos> _col(int c) => {for (var r = 0; r < rows; r++) Pos(r, c)};
  Set<Pos> _square(Pos p, int radius) => {
    for (var r = p.r - radius; r <= p.r + radius; r++)
      for (var c = p.c - radius; c <= p.c + radius; c++)
        if (inBounds(Pos(r, c))) Pos(r, c),
  };

  TileColor? mostCommonColor({bool primaryOnly = false}) {
    final counts = <TileColor, int>{};
    for (final t in tiles) {
      final color = t?.color;
      if (t == null || color == null || !t.special.hasColor) continue;
      if (primaryOnly && !color.isPrimary) continue;
      counts[color] = (counts[color] ?? 0) + 1;
    }
    if (counts.isEmpty) return primaryOnly ? mostCommonColor() : null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Set<Pos> _activate(_Act a, List<Effect> effects) {
    final p = a.at;
    switch (a.kind) {
      case _ActKind.lineH:
        effects.add(Effect(EffectKind.lineH, p, color: a.color));
        return _row(p.r);
      case _ActKind.lineV:
        effects.add(Effect(EffectKind.lineV, p, color: a.color));
        return _col(p.c);
      case _ActKind.bomb:
        effects.add(Effect(EffectKind.bomb, p, color: a.color));
        return _square(p, 1);
      case _ActKind.bomb5:
        effects.add(Effect(EffectKind.bigBomb, p, color: a.color));
        return _square(p, 2);
      case _ActKind.rowCol:
        effects.add(Effect(EffectKind.rowCol, p, color: a.color));
        return {..._row(p.r), ..._col(p.c)};
      case _ActKind.cross3:
      case _ActKind.wbCross:
        effects.add(Effect(EffectKind.cross3, p, color: a.color));
        final s = <Pos>{};
        for (var d = -1; d <= 1; d++) {
          if (p.r + d >= 0 && p.r + d < rows) s.addAll(_row(p.r + d));
          if (p.c + d >= 0 && p.c + d < cols) s.addAll(_col(p.c + d));
        }
        if (a.kind == _ActKind.wbCross) s.addAll(_square(p, 2));
        return s;
      case _ActKind.board:
        effects.add(Effect(EffectKind.board, p));
        return allPositions.toSet();
      case _ActKind.prism:
        final color = a.color ?? mostCommonColor();
        if (color == null) return {};
        final targets = [
          for (final q in allPositions)
            if (tileAt(q) case final t?
                when t.color == color && t.special.hasColor)
              q,
        ];
        effects.add(
          Effect(EffectKind.prism, p, color: color, targets: targets),
        );
        return targets.toSet();
      case _ActKind.whiteBurst:
        final color = a.color ?? mostCommonColor(primaryOnly: true);
        final cross = {..._row(p.r), ..._col(p.c)};
        if (color != null) {
          for (final q in _square(p, 2)) {
            if (cross.contains(q)) continue;
            final t = tileAt(q);
            if (t != null && t.special == Special.none && t.color != null) {
              t.color = color;
            }
          }
        }
        effects.add(Effect(EffectKind.whiteBurst, p, color: color));
        return cross;
    }
  }

  ScorePopup? _popupFor(Iterable<Pos> cells, int amount) {
    if (amount <= 0 || cells.isEmpty) return null;
    var r = 0.0, c = 0.0;
    for (final p in cells) {
      r += p.r;
      c += p.c;
    }
    return ScorePopup(PosD(r / cells.length, c / cells.length), amount);
  }

  /// Applies hits and special activations in waves: specials destroyed in
  /// one wave fire in the next, which gives chain reactions their rhythm.
  void _runWaves(
    List<Step> out,
    Set<Pos> hits,
    List<_Act> acts,
    int cascade, {
    Map<Pos, Tile> creations = const {},
    List<Effect> effects = const [],
    List<Cleared> preCleared = const [],
    int preGained = 0,
  }) {
    final protect = creations.keys.toSet();
    var effs = List<Effect>.of(effects);
    var first = true;
    final mult = min(max(cascade, 1), 6);
    for (var guard = 0; guard < 40; guard++) {
      if (!first && hits.isEmpty && acts.isEmpty) break;
      final cleared = <Cleared>[if (first) ...preCleared];
      var gained = first ? preGained : 0;
      final glassHit = <Pos>[];
      final lockHit = <Pos>[];
      final inkHit = <Pos>[];
      for (final a in acts) {
        hits.addAll(_activate(a, effs));
      }
      final nextActs = <_Act>[];
      for (final p in hits) {
        if (!isPlayable(p)) continue;
        if (!first && protect.contains(p)) continue;
        final i = _i(p);
        if (glass[i] > 0) {
          glass[i]--;
          glassHit.add(p);
          gained += pointsPerObstacle;
          score += pointsPerObstacle;
          continue;
        }
        if (ink[i]) {
          ink[i] = false;
          _inkCleared = true;
          inkClearedTotal++;
          inkHit.add(p);
          gained += pointsPerObstacle;
          score += pointsPerObstacle;
          continue;
        }
        final t = tiles[i];
        if (t == null) continue;
        // Chains break first, even on a bucket (which itself is immune).
        if (lock[i] > 0) {
          lock[i]--;
          lockHit.add(p);
          gained += pointsPerObstacle;
          score += pointsPerObstacle;
          continue;
        }
        if (t.bucket) continue;
        gained += _consume(p, t, cleared, mult);
        if (t.special != Special.none) nextActs.add(_Act.fromTile(t, p));
      }
      if (first) {
        creations.forEach((p, t) => tiles[_i(p)] = t);
      }
      if (cleared.isNotEmpty ||
          glassHit.isNotEmpty ||
          lockHit.isNotEmpty ||
          inkHit.isNotEmpty ||
          effs.isNotEmpty ||
          (first && creations.isNotEmpty)) {
        final popup = _popupFor([
          ...cleared.map((c) => c.at),
          ...glassHit,
          ...lockHit,
          ...inkHit,
        ], gained);
        out.add(
          Step(
            StepKind.clear,
            snapshot(),
            cleared: cleared,
            effects: effs,
            cascade: cascade,
            popups: [?popup],
            glassHit: glassHit,
            lockHit: lockHit,
            inkHit: inkHit,
          ),
        );
      }
      first = false;
      hits = <Pos>{};
      acts = nextActs;
      effs = [];
    }
  }

  void _afterWaves(List<Step> out, int cascade) {
    final turns = _pendingRotations % 4;
    _pendingRotations = 0;
    if (turns > 0) {
      for (var k = 0; k < turns; k++) {
        gravity = gravity.rotatedCw;
      }
      if (_flipRestore != null) _flipTurns += turns;
      out.add(Step(StepKind.gravity, snapshot(), cascade: cascade));
    }
    _fall(out, cascade);
    for (var guard = 0; guard < 12 && _collectBuckets(out, cascade); guard++) {
      _fall(out, cascade);
    }
  }

  bool _hasEmpty() {
    for (final p in allPositions) {
      if (canHoldTile(p) && tiles[_i(p)] == null) return true;
    }
    return false;
  }

  /// True when nothing playable lies beyond [p] in its gravity direction:
  /// a bucket there has reached the exit.
  bool isExit(Pos p) {
    final d = dirAt(p);
    var q = Pos(p.r + d.dr, p.c + d.dc);
    while (inBounds(q)) {
      if (isPlayable(q)) return false;
      q = Pos(q.r + d.dr, q.c + d.dc);
    }
    return true;
  }

  bool _collectBuckets(List<Step> out, int cascade) {
    final cleared = <Cleared>[];
    final effects = <Effect>[];
    for (final p in allPositions) {
      final t = tiles[_i(p)];
      if (t == null || !t.bucket || !isExit(p)) continue;
      tiles[_i(p)] = null;
      dropped++;
      score += 500;
      cleared.add(Cleared(t.id, p, null, Special.none));
      effects.add(Effect(EffectKind.drop, p));
    }
    if (cleared.isEmpty) return false;
    out.add(
      Step(
        StepKind.clear,
        snapshot(),
        cleared: cleared,
        effects: effects,
        cascade: cascade,
        popups: [
          for (final c in cleared)
            ScorePopup(PosD(c.at.r.toDouble(), c.at.c.toDouble()), 500),
        ],
      ),
    );
    return true;
  }

  /// A new tile from the top of a segment: sometimes a paint bucket.
  Tile _spawnTile(Pos at) {
    if (bucketsToSpawn > 0 &&
        bucketsOnBoard < bucketsMax &&
        rng.nextDouble() < 0.2) {
      bucketsToSpawn--;
      return Tile(_nextId++, null, bucket: true);
    }
    return _newTile(_calm ? _safeColor(at) : _randomColor());
  }

  /// Recolors [t] when it lands on a color filter at [p].
  void _filterInto(Pos p, Tile t) {
    final f = filter[_i(p)];
    if (f == null ||
        _calm ||
        t.bucket ||
        !t.special.hasColor ||
        t.color == null) {
      return;
    }
    t.color = f;
  }

  /// Moves tiles in the gravity direction and spawns new ones at the
  /// upstream end of every segment (segments are split by holes and glass).
  void _fall(List<Step> out, int cascade) {
    if (hasZones) {
      _fallZones(out, cascade);
      return;
    }
    final g = gravity;
    final spawnFrom = <int, PosD>{};
    final spawnEntry = <int, Pos>{};
    var changed = false;
    final lines = <List<Pos>>[];
    if (g.isVertical) {
      for (var c = 0; c < cols; c++) {
        lines.add([
          for (var k = 0; k < rows; k++)
            Pos(g == Gravity.down ? rows - 1 - k : k, c),
        ]);
      }
    } else {
      for (var r = 0; r < rows; r++) {
        lines.add([
          for (var k = 0; k < cols; k++)
            Pos(r, g == Gravity.right ? cols - 1 - k : k),
        ]);
      }
    }
    for (final line in lines) {
      var seg = <Pos>[];
      void flush() {
        if (seg.isEmpty) return;
        final existing = <Tile>[];
        final from = <int>[];
        for (var k = 0; k < seg.length; k++) {
          final t = tiles[_i(seg[k])];
          if (t != null) {
            existing.add(t);
            from.add(k);
          }
        }
        final missing = seg.length - existing.length;
        for (var k = 0; k < seg.length; k++) {
          final p = seg[k];
          if (k < existing.length) {
            if (!identical(tiles[_i(p)], existing[k])) changed = true;
            tiles[_i(p)] = existing[k];
            if (from[k] != k) _filterInto(p, existing[k]);
          } else {
            final t = _spawnTile(p);
            tiles[_i(p)] = t;
            _filterInto(p, t);
            final j = k + missing;
            spawnFrom[t.id] = PosD(
              (seg[0].r - j * g.dr).toDouble(),
              (seg[0].c - j * g.dc).toDouble(),
            );
            spawnEntry[t.id] = seg.last;
            changed = true;
          }
        }
        seg = <Pos>[];
      }

      for (final p in line) {
        if (isMovable(p)) {
          seg.add(p);
        } else {
          flush();
        }
      }
      flush();
    }
    if (changed) {
      out.add(
        Step(
          StepKind.fall,
          snapshot(),
          spawnFrom: spawnFrom,
          spawnEntry: spawnEntry,
          cascade: cascade,
        ),
      );
    }
  }

  /// Falling with gravity zones: every cell has its own direction, so tiles
  /// step cell by cell along it, and new tiles appear at cells nothing can
  /// fall into.
  void _fallZones(List<Step> out, int cascade) {
    final spawnFrom = <int, PosD>{};
    final spawnEntry = <int, Pos>{};
    final spawned = <Pos, int>{};
    var changed = false;
    Pos next(Pos p) {
      final d = dirAt(p);
      return Pos(p.r + d.dr, p.c + d.dc);
    }

    bool fed(Pos p) {
      for (final d in _dirs) {
        final q = p + d;
        if (isMovable(q) && next(q) == p) return true;
      }
      return false;
    }

    final moved = <Tile>{};
    void spawn(Pos p, {bool inPlace = false}) {
      final t = _spawnTile(p);
      moved.add(t);
      tiles[_i(p)] = t;
      final k = spawned[p] = (spawned[p] ?? 0) + 1;
      final d = dirAt(p);
      spawnFrom[t.id] = inPlace
          ? PosD(p.r.toDouble(), p.c.toDouble())
          : PosD((p.r - d.dr * k).toDouble(), (p.c - d.dc * k).toDouble());
      spawnEntry[t.id] = p;
    }

    for (var it = 0; it < rows * cols * 3; it++) {
      var stepped = false;
      for (final p in allPositions) {
        final t = tiles[_i(p)];
        if (t == null || !isMovable(p)) continue;
        final q = next(p);
        if (!isMovable(q) || tiles[_i(q)] != null) continue;
        // Two zones pointing at each other: the flows meet and stop there.
        if (next(q) == p) continue;
        tiles[_i(q)] = t;
        tiles[_i(p)] = null;
        moved.add(t);
        stepped = true;
      }
      for (final p in allPositions) {
        if (isMovable(p) && tiles[_i(p)] == null && !fed(p)) {
          spawn(p);
          stepped = true;
        }
      }
      if (!stepped) break;
      changed = true;
    }
    // A loop of zones with no way in would stay empty: fill it in place.
    for (final p in allPositions) {
      if (canHoldTile(p) && tiles[_i(p)] == null) {
        spawn(p, inPlace: true);
        changed = true;
      }
    }
    // Tiles that fell into a filter cell take its color.
    for (final p in allPositions) {
      final t = tiles[_i(p)];
      if (t != null && moved.contains(t)) _filterInto(p, t);
    }
    if (changed) {
      out.add(
        Step(
          StepKind.fall,
          snapshot(),
          spawnFrom: spawnFrom,
          spawnEntry: spawnEntry,
          cascade: cascade,
        ),
      );
    }
  }

  /// Clears matches and refills until the board is stable.
  void _resolve(
    List<Step> out, {
    List<Pos> preferred = const [],
    int startCascade = 1,
  }) {
    var cascade = startCascade;
    final wasCalm = _calm;
    for (var guard = 0; guard < 80; guard++) {
      if (guard == 12) _calm = true;
      final groups = findMatches();
      if (groups.isEmpty) {
        if (_hasEmpty() || _pendingRotations > 0) {
          _afterWaves(out, cascade);
          continue;
        }
        break;
      }
      final hits = <Pos>{};
      final creations = <Pos, Tile>{};
      final effects = <Effect>[];
      var bonus = 0;
      for (final g in groups) {
        hits.addAll(g.cells);
        final (special, at) = _planGroup(
          g,
          cascade == startCascade ? preferred : const [],
        );
        if (special != Special.none && at != null) {
          creations[at] = Tile(
            _nextId++,
            special == Special.prism ? null : g.color,
            special: special,
          );
          bonus += switch (special) {
            Special.lineH || Special.lineV => 120,
            Special.bomb => 200,
            _ => 300,
          };
        }
        if (g.color.isSecondary) {
          // Secondary matches splash paint onto their neighbors.
          for (final p in g.cells) {
            for (final q in _neighbors(p)) {
              if (!g.cells.contains(q) && q != at) hits.add(q);
            }
          }
          effects.add(
            Effect(
              EffectKind.splash,
              g.cells.first,
              color: g.color,
              targets: g.cells.toList(),
            ),
          );
        }
        for (final p in g.cells) {
          for (final q in _neighbors(p)) {
            if (glass[_i(q)] > 0 || ink[_i(q)]) hits.add(q);
          }
        }
      }
      score += bonus;
      _runWaves(
        out,
        hits,
        const [],
        cascade,
        creations: creations,
        effects: effects,
        preGained: bonus,
      );
      _afterWaves(out, cascade);
      cascade++;
    }
    _calm = wasCalm;
  }

  void _ensureMoves(List<Step> out) {
    if (findHint() == null) _shuffle(out);
  }

  void _shuffle(List<Step> out) {
    final cells = [
      for (final p in allPositions)
        if ((tileAt(p)?.isPlain ?? false) && lockAt(p) == 0) p,
    ];
    if (cells.length < 3) return;
    final pool = [for (final p in cells) tiles[_i(p)]!];
    for (var attempt = 0; attempt < 120; attempt++) {
      pool.shuffle(rng);
      for (var k = 0; k < cells.length; k++) {
        tiles[_i(cells[k])] = pool[k];
      }
      if (attempt >= 80) {
        // Shuffling alone is not enough: repaint the tiles as well.
        for (final p in cells) {
          tiles[_i(p)]!.color = null;
        }
        for (final p in cells) {
          tiles[_i(p)]!.color = _safeColor(p);
        }
      }
      if (findMatches().isEmpty && findHint() != null) break;
    }
    out.add(Step(StepKind.shuffle, snapshot()));
    if (findMatches().isNotEmpty) _resolve(out);
  }

  // ----------------------------------------------------------------- moves

  void _swapTiles(Pos a, Pos b) {
    final t = tiles[_i(a)];
    tiles[_i(a)] = tiles[_i(b)];
    tiles[_i(b)] = t;
  }

  MoveKind? blendKind(Tile x, Tile y) {
    if (!blending) return null;
    if (x.special != Special.none || y.special != Special.none) return null;
    final cx = x.color, cy = y.color;
    if (cx == null || cy == null) return null;
    if (blendPrimaries(cx, cy) != null) return MoveKind.blend;
    if (isWhiteBurstPair(cx, cy)) return MoveKind.whiteBurstBlend;
    return null;
  }

  /// What swiping [a] into [b] would do, without changing the board.
  MoveKind classify(Pos a, Pos b) {
    if (!a.isAdjacent(b) || !isMovable(a) || !isMovable(b)) {
      return MoveKind.none;
    }
    final ta = tileAt(a), tb = tileAt(b);
    if (ta == null || tb == null) return MoveKind.none;
    if (ta.special != Special.none && tb.special != Special.none) {
      return MoveKind.combo;
    }
    // A swiped special always moves and then fires where it landed.
    if (ta.special != Special.none || tb.special != Special.none) {
      return MoveKind.special;
    }
    _swapTiles(a, b);
    final matches = findMatches().isNotEmpty;
    _swapTiles(a, b);
    if (matches) return MoveKind.swap;
    return blendKind(ta, tb) ?? MoveKind.invalid;
  }

  /// The resulting tile of a blend between [a] and [b] (for the drag preview).
  (TileColor?, Special)? blendPreview(Pos a, Pos b) {
    final kind = classify(a, b);
    if (kind == MoveKind.blend) {
      return (
        blendPrimaries(tileAt(a)!.color!, tileAt(b)!.color!),
        Special.none,
      );
    }
    if (kind == MoveKind.whiteBurstBlend) return (null, Special.whiteBurst);
    return null;
  }

  MoveOutcome swipe(Pos a, Pos b) {
    final kind = classify(a, b);
    final out = <Step>[];
    _inkCleared = false;
    switch (kind) {
      case MoveKind.none:
        return MoveOutcome.none;
      case MoveKind.invalid:
        _swapTiles(a, b);
        out.add(Step(StepKind.swap, snapshot(), from: a, to: b));
        _swapTiles(a, b);
        out.add(Step(StepKind.swapBack, snapshot(), from: b, to: a));
        return MoveOutcome(out, false, MoveKind.invalid);
      case MoveKind.swap:
        _swapTiles(a, b);
        out.add(Step(StepKind.swap, snapshot(), from: a, to: b));
        _resolve(out, preferred: [b, a]);
      case MoveKind.blend:
      case MoveKind.whiteBurstBlend:
        _blend(a, b, kind, out);
        _resolve(out, preferred: [b]);
      case MoveKind.combo:
      case MoveKind.special:
        _swapTiles(a, b);
        out.add(Step(StepKind.swap, snapshot(), from: a, to: b));
        _specialSwap(b, a, out);
        _afterWaves(out, 1);
        _resolve(out, startCascade: 2);
      case MoveKind.booster:
        return MoveOutcome.none;
    }
    _endMove(out);
    _ensureMoves(out);
    return MoveOutcome(out, true, kind);
  }

  /// After every move that used a move: ink spreads unless some was
  /// cleared, a Gravity Flip wears off, and timed gravity may rotate.
  void _endMove(List<Step> out) {
    movesMade++;
    _spreadInk(out);
    final restore = _flipRestore;
    if (restore != null) {
      var g = restore;
      for (var k = 0; k < _flipTurns % 4; k++) {
        g = g.rotatedCw;
      }
      _flipRestore = null;
      _flipTurns = 0;
      if (g != gravity) {
        gravity = g;
        out.add(Step(StepKind.gravity, snapshot()));
        _afterWaves(out, 1);
        _resolve(out, startCascade: 2);
      }
    }
    if (gravityEvery > 0 && movesMade % gravityEvery == 0) {
      gravity = gravity.rotatedCw;
      out.add(Step(StepKind.gravity, snapshot()));
      _afterWaves(out, 1);
      _resolve(out, startCascade: 2);
    }
  }

  /// Ink stops spreading at this many cells, so it can never take over
  /// the board.
  int inkLimit = 1 << 30;

  void _spreadInk(List<Step> out) {
    if (_inkCleared || !ink.contains(true)) return;
    if (ink.where((x) => x).length >= inkLimit) return;
    final options = <(Pos, Pos)>[];
    for (final p in allPositions) {
      if (!ink[_i(p)]) continue;
      for (final q in _neighbors(p)) {
        final t = tileAt(q);
        if (t != null && t.isPlain && lockAt(q) == 0 && glassAt(q) == 0) {
          // Never onto the spawn edge: that would starve the column.
          final d = dirAt(q);
          if (!inBounds(Pos(q.r - d.dr, q.c - d.dc))) continue;
          options.add((p, q));
        }
      }
    }
    if (options.isEmpty) return;
    final (from, to) = options[rng.nextInt(options.length)];
    final t = tiles[_i(to)]!;
    tiles[_i(to)] = null;
    ink[_i(to)] = true;
    out.add(
      Step(
        StepKind.transform,
        snapshot(),
        cleared: [Cleared(t.id, to, t.color, Special.none)],
        effects: [
          Effect(EffectKind.inkSpread, to, targets: [from]),
        ],
      ),
    );
  }

  void _blend(Pos a, Pos b, MoveKind kind, List<Step> out) {
    final ta = tileAt(a)!, tb = tileAt(b)!;
    tiles[_i(a)] = null;
    final Tile made;
    if (kind == MoveKind.whiteBurstBlend) {
      made = Tile(_nextId++, null, special: Special.whiteBurst);
    } else {
      made = Tile(_nextId++, blendPrimaries(ta.color!, tb.color!));
    }
    if (ta.gravitySwitch) _pendingRotations++;
    if (tb.gravitySwitch) _pendingRotations++;
    // A blended secondary counts towards "collect" goals as soon as it is made.
    final madeColor = made.color;
    if (madeColor != null) {
      collected[madeColor] = (collected[madeColor] ?? 0) + 1;
    }
    tiles[_i(b)] = made;
    score += 50;
    out.add(
      Step(
        StepKind.blend,
        snapshot(),
        from: a,
        to: b,
        cleared: [
          Cleared(ta.id, a, ta.color, ta.special),
          Cleared(tb.id, b, tb.color, tb.special),
        ],
        popups: [ScorePopup(PosD(b.r.toDouble(), b.c.toDouble()), 50)],
      ),
    );
  }

  /// Handles a swap that involves a special: [moved] is where the swiped
  /// tile landed, [other] where the partner tile now sits.
  void _specialSwap(Pos moved, Pos other, List<Step> out) {
    final t1 = tileAt(moved)!, t2 = tileAt(other)!;
    final pre = <Cleared>[];
    final s1 = t1.special, s2 = t2.special;
    const strong = {Special.prism, Special.whiteBurst};
    final acts = <_Act>[];
    final hits = <Pos>{};
    final effects = <Effect>[];
    var gained = 0;

    if (s1 != Special.none && s2 != Special.none) {
      gained += _consume(moved, t1, pre, 1) + _consume(other, t2, pre, 1);
      if (strong.contains(s1) && strong.contains(s2)) {
        acts.add(_Act(_ActKind.board, moved));
      } else if (s1 == Special.prism || s2 == Special.prism) {
        final partner = s1 == Special.prism ? t2 : t1;
        final color = partner.color!;
        final targets = <Pos>[];
        for (final p in allPositions) {
          final t = tileAt(p);
          if (t != null && t.special == Special.none && t.color == color) {
            t.special = partner.special == Special.bomb
                ? Special.bomb
                : (rng.nextBool() ? Special.lineH : Special.lineV);
            targets.add(p);
          }
        }
        effects.add(
          Effect(EffectKind.prism, moved, color: color, targets: targets),
        );
        out.add(
          Step(
            StepKind.transform,
            snapshot(),
            cleared: List.of(pre),
            effects: List.of(effects),
          ),
        );
        pre.clear();
        effects.clear();
        hits.addAll(targets);
        acts.add(_Act.fromTile(partner, moved));
      } else if (strong.contains(s1) || strong.contains(s2)) {
        acts.add(_Act(_ActKind.wbCross, moved));
      } else if (s1.isLine && s2.isLine) {
        acts.add(_Act(_ActKind.rowCol, moved, t1.color));
      } else if (s1 == Special.bomb && s2 == Special.bomb) {
        acts.add(_Act(_ActKind.bomb5, moved, t1.color));
      } else {
        acts.add(_Act(_ActKind.cross3, moved, t1.color));
      }
    } else {
      // One special and a normal tile: the special fires at its new cell.
      // A prism or white burst takes the partner's color.
      final (sp, sPos, partner) = s1 != Special.none
          ? (t1, moved, t2)
          : (t2, other, t1);
      gained += _consume(sPos, sp, pre, 1);
      acts.add(switch (sp.special) {
        Special.prism => _Act(_ActKind.prism, sPos, partner.color),
        Special.whiteBurst => _Act(_ActKind.whiteBurst, sPos, partner.color),
        _ => _Act.fromTile(sp, sPos),
      });
    }
    _runWaves(
      out,
      hits,
      acts,
      1,
      effects: effects,
      preCleared: pre,
      preGained: gained,
    );
  }

  /// Activates a special in place (tap activation).
  MoveOutcome tapSpecial(Pos p) {
    final t = tileAt(p);
    if (t == null || t.special == Special.none || lockAt(p) > 0) {
      return MoveOutcome.none;
    }
    final out = <Step>[];
    _inkCleared = false;
    final pre = <Cleared>[];
    final gained = _consume(p, t, pre, 1);
    _runWaves(
      out,
      {},
      [_Act.fromTile(t, p)],
      1,
      preCleared: pre,
      preGained: gained,
    );
    _afterWaves(out, 1);
    _resolve(out, startCascade: 2);
    _endMove(out);
    _ensureMoves(out);
    return MoveOutcome(out, true, MoveKind.special);
  }

  // -------------------------------------------------------------- boosters

  /// Brush: removes one tile (or one glass layer). Does not use a move.
  MoveOutcome brush(Pos p) {
    if (!isPlayable(p) ||
        (tileAt(p) == null && glassAt(p) == 0 && !inkAt(p)) ||
        (tileAt(p)?.bucket ?? false)) {
      return MoveOutcome.none;
    }
    final out = <Step>[];
    _runWaves(out, {p}, const [], 1);
    _afterWaves(out, 1);
    _resolve(out, startCascade: 2);
    _ensureMoves(out);
    return MoveOutcome(out, false, MoveKind.booster);
  }

  /// Free Swap: swaps any two tiles, even far apart. Does not use a move.
  MoveOutcome freeSwap(Pos a, Pos b) {
    if (a == b ||
        tileAt(a) == null ||
        tileAt(b) == null ||
        !isMovable(a) ||
        !isMovable(b)) {
      return MoveOutcome.none;
    }
    final out = <Step>[];
    _swapTiles(a, b);
    out.add(Step(StepKind.swap, snapshot(), from: a, to: b));
    _resolve(out, preferred: [b, a]);
    _ensureMoves(out);
    return MoveOutcome(out, false, MoveKind.booster);
  }

  /// Color Splash: paints the tile's whole row in its color.
  MoveOutcome colorSplash(Pos p) {
    final t = tileAt(p);
    if (t == null) return MoveOutcome.none;
    final color = (t.special.hasColor ? t.color : null) ?? mostCommonColor();
    if (color == null) return MoveOutcome.none;
    for (final q in _row(p.r)) {
      final u = tileAt(q);
      if (u != null && !u.bucket && u.special.hasColor) u.color = color;
    }
    final out = <Step>[
      Step(
        StepKind.transform,
        snapshot(),
        effects: [
          Effect(
            EffectKind.splash,
            p,
            color: color,
            targets: _row(p.r).toList(),
          ),
        ],
      ),
    ];
    _resolve(out, preferred: [p]);
    _ensureMoves(out);
    return MoveOutcome(out, false, MoveKind.booster);
  }

  /// Gravity Flip booster: tiles fall towards [g] during the next move,
  /// then gravity goes back. Does not use a move.
  MoveOutcome flipGravity(Gravity g) {
    if (g == gravity && _flipRestore == null) return MoveOutcome.none;
    _flipRestore ??= gravity;
    gravity = g;
    final out = <Step>[Step(StepKind.gravity, snapshot())];
    _afterWaves(out, 1);
    _resolve(out, startCascade: 2);
    _ensureMoves(out);
    return MoveOutcome(out, false, MoveKind.booster);
  }

  /// Gravity the board returns to after a Gravity Flip (null if none).
  Gravity? get flipRestore => _flipRestore;

  /// Pre-level booster: turns a random plain tile into [special].
  /// Returns where, or null if there is no room.
  Pos? placeSpecial(Special special) {
    final cells = [
      for (final p in allPositions)
        if ((tileAt(p)?.isPlain ?? false) &&
            lockAt(p) == 0 &&
            !(tileAt(p)!.gravitySwitch))
          p,
    ];
    if (cells.isEmpty) return null;
    final p = cells[rng.nextInt(cells.length)];
    final t = tiles[_i(p)]!;
    t.special = special;
    if (special == Special.prism || special == Special.whiteBurst) {
      t.color = null;
    }
    return p;
  }

  /// End-of-level finale: leftover moves become line blasters that fire.
  List<Step> sugarRush(int movesLeft) {
    final out = <Step>[];
    final candidates = [
      for (final p in allPositions)
        if ((tileAt(p)?.isPlain ?? false) && lockAt(p) == 0) p,
    ]..shuffle(rng);
    final picked = candidates.take(min(movesLeft, 15)).toList();
    if (picked.isNotEmpty) {
      for (final p in picked) {
        tileAt(p)!.special = rng.nextBool() ? Special.lineH : Special.lineV;
      }
      score += 300 * movesLeft;
      out.add(
        Step(
          StepKind.transform,
          snapshot(),
          popups: [
            for (final p in picked)
              ScorePopup(PosD(p.r.toDouble(), p.c.toDouble()), 300),
          ],
        ),
      );
    }
    for (var round = 0; round < 4; round++) {
      final specials = {
        for (final p in allPositions)
          if (tileAt(p) != null && tileAt(p)!.special != Special.none) p,
      };
      if (specials.isEmpty) break;
      _runWaves(out, specials, const [], 2 + round);
      _afterWaves(out, 2 + round);
      _resolve(out, startCascade: 3 + round);
    }
    return out;
  }

  // ----------------------------------------------------------------- hints

  /// Best available move, or null if the board is dead.
  Hint? findHint({bool includeBlends = true}) {
    Hint? best;
    for (final a in allPositions) {
      for (final d in const [Pos(0, 1), Pos(1, 0)]) {
        final b = a + d;
        final kind = classify(a, b);
        int value;
        switch (kind) {
          case MoveKind.combo:
            value = 60;
          case MoveKind.special:
            value = 50;
          case MoveKind.swap:
            _swapTiles(a, b);
            final groups = findMatches();
            _swapTiles(a, b);
            value = groups.fold<int>(0, (s, g) => s + g.cells.length * 2);
          case MoveKind.whiteBurstBlend:
            value = includeBlends ? 2 : -1;
          case MoveKind.blend:
            value = includeBlends ? 1 : -1;
          default:
            value = -1;
        }
        if (value > 0 && (best == null || value > best.value)) {
          best = Hint(a, b, kind, value);
        }
      }
    }
    return best;
  }

  /// Every legal move (swipes plus taps on specials) for bots.
  List<Hint> allMoves({bool includeTaps = true}) {
    final moves = <Hint>[];
    for (final a in allPositions) {
      for (final d in const [Pos(0, 1), Pos(1, 0)]) {
        final b = a + d;
        final kind = classify(a, b);
        if (kind != MoveKind.none && kind != MoveKind.invalid) {
          moves.add(Hint(a, b, kind, 0));
        }
      }
      if (includeTaps && (tileAt(a)?.special ?? Special.none) != Special.none) {
        moves.add(Hint(a, a, MoveKind.special, 0));
      }
    }
    return moves;
  }
}
