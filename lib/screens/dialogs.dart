import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/scope.dart';
import '../core/level.dart';
import '../ui/widgets.dart';

/// Offers ways to get lives back. Returns true if the player now has a life.
Future<bool> showOutOfLives(BuildContext context) async {
  final scope = AppScope.read(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AppScope(
      app: scope.app,
      levels: scope.levels,
      ads: scope.ads,
      child: const _OutOfLivesDialog(),
    ),
  );
  return (result ?? false) || scope.app.lives > 0;
}

class _OutOfLivesDialog extends StatefulWidget {
  const _OutOfLivesDialog();

  @override
  State<_OutOfLivesDialog> createState() => _OutOfLivesDialogState();
}

class _OutOfLivesDialogState extends State<_OutOfLivesDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final next = app.nextLifeIn;
    return AlertDialog(
      title: const Text('Out of lives'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, color: Colors.pink, size: 56),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Your lives are full!'
                : 'Next life in ${formatDuration(next)}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Wait'),
        ),
        TextButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            final ok = await scope.ads.showRewarded(context, reward: '+1 life');
            if (ok) {
              app.addLives(1);
              app.logAndSave('ad_reward', {'reward': 'life'});
              nav.pop(true);
            }
          },
          child: const Text('Watch ad: +1 life'),
        ),
        FilledButton(
          onPressed: app.coins >= AppState.refillCost
              ? () {
                  if (app.buyRefill()) Navigator.of(context).pop(true);
                }
              : null,
          child: Text('Refill (${AppState.refillCost} coins)'),
        ),
      ],
    );
  }
}

/// Level info before starting. Returns true if the player pressed Play.
Future<bool> showLevelStart(BuildContext context, LevelDef level) async {
  final scope = AppScope.read(context);
  final stars = scope.app.starsFor(level.id);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Level ${level.id}')),
          if (level.hard)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'HARD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            level.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          StarRow(stars: stars, size: 28),
          const SizedBox(height: 12),
          const Text('Goals', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final g in level.goals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  goalIcon(g, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goalText(
                        g,
                        g.type == GoalType.stains && g.target == 0
                            ? level.stainCount
                            : g.type == GoalType.glass && g.target == 0
                            ? level.glassCount
                            : g.target,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('${level.moves} moves'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const Key('play-level'),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String ok = 'OK',
  String cancel = 'Cancel',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}
