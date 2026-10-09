// Core value types shared by the board engine, the level format and the UI.
//
// This file (and everything else in lib/core) must stay free of Flutter
// imports so the engine can run in plain Dart: unit tests, the level bot
// (tool/level_bot.dart) and background isolates.

enum TileColor { red, blue, yellow, purple, green, orange, brown, gray }

extension TileColorInfo on TileColor {
  bool get isPrimary =>
      this == TileColor.red ||
      this == TileColor.blue ||
      this == TileColor.yellow;

  bool get isSecondary =>
      this == TileColor.purple ||
      this == TileColor.green ||
      this == TileColor.orange;

  /// Neutral ("blank") colors can be matched but never blended.
  bool get isNeutral => this == TileColor.brown || this == TileColor.gray;

  /// Single letter used in level files.
  String get code => const {
    TileColor.red: 'R',
    TileColor.blue: 'B',
    TileColor.yellow: 'Y',
    TileColor.purple: 'P',
    TileColor.green: 'G',
    TileColor.orange: 'O',
    TileColor.brown: 'N',
    TileColor.gray: 'K',
  }[this]!;

  String get label => const {
    TileColor.red: 'Red',
    TileColor.blue: 'Blue',
    TileColor.yellow: 'Yellow',
    TileColor.purple: 'Purple',
    TileColor.green: 'Green',
    TileColor.orange: 'Orange',
    TileColor.brown: 'Umber',
    TileColor.gray: 'Charcoal',
  }[this]!;
}

TileColor? tileColorFromCode(String code) {
  for (final c in TileColor.values) {
    if (c.code == code) return c;
  }
  return null;
}

TileColor? tileColorFromName(String name) {
  for (final c in TileColor.values) {
    if (c.name == name) return c;
  }
  return null;
}

/// Result of blending two different primaries, or null if they don't blend.
TileColor? blendPrimaries(TileColor a, TileColor b) {
  if (!a.isPrimary || !b.isPrimary || a == b) return null;
  final s = {a, b};
  if (s.contains(TileColor.red) && s.contains(TileColor.blue)) {
    return TileColor.purple;
  }
  if (s.contains(TileColor.blue) && s.contains(TileColor.yellow)) {
    return TileColor.green;
  }
  return TileColor.orange; // red + yellow
}

/// The primary a secondary color is missing (purple lacks yellow, etc.).
TileColor missingPrimary(TileColor secondary) {
  switch (secondary) {
    case TileColor.purple:
      return TileColor.yellow;
    case TileColor.green:
      return TileColor.red;
    case TileColor.orange:
      return TileColor.blue;
    default:
      throw ArgumentError('$secondary is not a secondary color');
  }
}

/// True when [a] and [b] are a secondary and the primary it is missing,
/// which blends into a White Burst.
bool isWhiteBurstPair(TileColor a, TileColor b) {
  if (a.isSecondary && b.isPrimary) return missingPrimary(a) == b;
  if (b.isSecondary && a.isPrimary) return missingPrimary(b) == a;
  return false;
}

enum Special { none, lineH, lineV, bomb, prism, whiteBurst }

extension SpecialInfo on Special {
  bool get isLine => this == Special.lineH || this == Special.lineV;

  /// Specials that keep a color and can take part in matches.
  bool get hasColor => this == Special.none || isLine || this == Special.bomb;
}

/// Direction tiles fall. Rotating clockwise: down -> left -> up -> right.
enum Gravity { down, left, up, right }

extension GravityInfo on Gravity {
  int get dr => const {
    Gravity.down: 1,
    Gravity.up: -1,
    Gravity.left: 0,
    Gravity.right: 0,
  }[this]!;

  int get dc => const {
    Gravity.down: 0,
    Gravity.up: 0,
    Gravity.left: -1,
    Gravity.right: 1,
  }[this]!;

  bool get isVertical => this == Gravity.down || this == Gravity.up;

  Gravity get rotatedCw => Gravity.values[(index + 1) % 4];
}

Gravity gravityFromName(String? name) {
  for (final g in Gravity.values) {
    if (g.name == name) return g;
  }
  return Gravity.down;
}

class Pos {
  final int r;
  final int c;
  const Pos(this.r, this.c);

  Pos operator +(Pos o) => Pos(r + o.r, c + o.c);

  bool isAdjacent(Pos o) => (r - o.r).abs() + (c - o.c).abs() == 1;

  @override
  bool operator ==(Object other) =>
      other is Pos && other.r == r && other.c == c;

  @override
  int get hashCode => r * 1000 + c;

  @override
  String toString() => '($r,$c)';
}

/// A fractional board position, used for tiles sliding in from outside.
class PosD {
  final double r;
  final double c;
  const PosD(this.r, this.c);
}

class Tile {
  final int id;
  TileColor? color;
  Special special;
  bool gravitySwitch;

  Tile(
    this.id,
    this.color, {
    this.special = Special.none,
    this.gravitySwitch = false,
  });

  Tile copy() =>
      Tile(id, color, special: special, gravitySwitch: gravitySwitch);

  TileView view(Pos at) => TileView(id, at, color, special, gravitySwitch);
}

/// Immutable picture of a tile, used by snapshots and the renderer.
class TileView {
  final int id;
  final Pos pos;
  final TileColor? color;
  final Special special;
  final bool gravitySwitch;
  const TileView(
    this.id,
    this.pos,
    this.color,
    this.special,
    this.gravitySwitch,
  );
}
