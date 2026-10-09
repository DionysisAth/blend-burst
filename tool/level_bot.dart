// Automated level tester.
//
//   dart run tool/level_bot.dart                 # all levels, 20 plays each
//   dart run tool/level_bot.dart --plays 50 --level 12
//   dart run tool/level_bot.dart --tune          # rewrite move limits
//   dart run tool/level_bot.dart --calibrate     # rewrite star thresholds
//
// Plays every level with a greedy bot to estimate win rates, and checks the
// board invariants after every move, so it doubles as a fuzz test.
import 'dart:convert';
import 'dart:io';

import 'package:blend_burst/core/bot.dart';
import 'package:blend_burst/core/level.dart';
import 'package:blend_burst/core/session.dart';

const packFiles = [
  'assets/levels/episode1.json',
  'assets/levels/episode2.json',
  'assets/levels/episode3.json',
];

void main(List<String> args) {
  var plays = 20;
  int? only;
  var calibrate = false;
  var tune = false;
  var skill = 0.7;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--plays':
        plays = int.parse(args[++i]);
      case '--level':
        only = int.parse(args[++i]);
      case '--skill':
        skill = double.parse(args[++i]);
      case '--calibrate':
        calibrate = true;
      case '--tune':
        tune = true;
    }
  }

  var errors = 0;
  for (final file in packFiles) {
    final pack =
        jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
    final levels = parseLevelPack(pack);
    final rawLevels = pack['levels'] as List;
    for (var li = 0; li < levels.length; li++) {
      final level = levels[li];
      if (only != null && level.id != only) continue;
      if (tune) {
        final moves = suggestMoves(level, plays, skill);
        stdout.writeln('L${level.id}: ${level.moves} -> $moves moves');
        (rawLevels[li] as Map)['moves'] = moves;
        level.moves = moves;
      }
      final bot = LevelBot(skill: skill, seed: level.id);
      final scores = <int>[];
      var wins = 0, movesLeft = 0;
      final sw = Stopwatch()..start();
      for (var p = 0; p < plays; p++) {
        final s = bot.play(
          level,
          seed: level.id * 1000 + p,
          onError: (e) {
            errors++;
            stderr.writeln('Level ${level.id} play $p: $e');
          },
        );
        if (s.status == SessionStatus.won) {
          wins++;
          movesLeft += level.moves - s.movesUsed;
          scores.add(s.score);
        }
      }
      scores.sort();
      final rate = wins / plays;
      final avgLeft = wins == 0 ? 0 : movesLeft / wins;
      stdout.writeln(
        'L${level.id.toString().padLeft(2)} '
        '${level.name.padRight(18)} win ${(rate * 100).toStringAsFixed(0).padLeft(3)}% '
        'left ${avgLeft.toStringAsFixed(1).padLeft(4)} '
        'scores ${scores.isEmpty ? '-' : '${scores.first}..${scores.last}'} '
        '(${sw.elapsedMilliseconds} ms)',
      );
      if (calibrate && scores.length >= 4) {
        int pct(double q) => scores[((scores.length - 1) * q).round()];
        int round500(int v) => (v / 500).round() * 500;
        final first = level.goals.any((g) => g.type == GoalType.score)
            ? level.goals.firstWhere((g) => g.type == GoalType.score).target
            : round500(pct(0.05) ~/ 2);
        final second = round500(pct(0.45)).clamp(first + 500, 1 << 30);
        final third = round500(pct(0.85)).clamp(second + 500, 1 << 30);
        (rawLevels[li] as Map)['stars'] = [first, second, third];
      }
    }
    if (calibrate) rewriteField(file, rawLevels, 'stars');
    if (tune) rewriteField(file, rawLevels, 'moves');
  }
  if (errors > 0) {
    stderr.writeln('$errors invariant errors');
    exit(1);
  }
}

/// Target bot win rate for a level: generous early, harder later, and
/// clearly harder on levels marked "hard".
double targetWinRate(LevelDef level) {
  if (level.hard) return 0.65;
  if (level.id <= 5) return 1.0;
  if (level.id <= 15) return 0.95;
  if (level.id <= 30) return 0.88;
  return 0.85;
}

/// Plays the level with a huge move budget, records how many moves each win
/// needed and picks the limit that gives the target win rate.
int suggestMoves(LevelDef level, int plays, double skill) {
  final open = level.copy()..moves = 99;
  final bot = LevelBot(skill: skill, seed: level.id + 77);
  final needed = <int>[];
  for (var p = 0; p < plays; p++) {
    final s = bot.play(open, seed: level.id * 7919 + p);
    needed.add(s.status == SessionStatus.won ? s.movesUsed : 99);
  }
  needed.sort();
  final rate = targetWinRate(level);
  final idx = ((needed.length - 1) * rate).round();
  final slack = level.id <= 5 ? 3 : 0;
  return (needed[idx] + slack).clamp(10, 40);
}

/// Rewrites one top-level field per level in place, keeping the formatting.
void rewriteField(String file, List rawLevels, String field) {
  final lines = File(file).readAsLinesSync();
  var idx = 0;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('"$field"')) {
      final value = (rawLevels[idx++] as Map)[field];
      final indent = lines[i].substring(0, lines[i].indexOf('"'));
      final comma = lines[i].trimRight().endsWith(',') ? ',' : '';
      lines[i] = '$indent"$field": ${jsonEncode(value)}$comma';
    }
  }
  File(file).writeAsStringSync('${lines.join('\n')}\n');
}
