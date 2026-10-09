import 'package:flutter/material.dart';

import '../app/scope.dart';
import 'dialogs.dart';
import 'editor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final d = app.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Vibration'),
            value: d.haptics,
            onChanged: app.setHaptics,
          ),
          SwitchListTile(
            title: const Text('Move hints'),
            subtitle: const Text('Highlight a possible move after 5 seconds'),
            value: d.hints,
            onChanged: app.setHints,
          ),
          SwitchListTile(
            title: const Text('Tap to activate specials'),
            subtitle: const Text('Tap a special tile to fire it (uses a move)'),
            value: d.tapActivate,
            onChanged: app.setTapActivate,
          ),
          const ListTile(
            title: Text('Sound & music'),
            subtitle: Text('Coming in a later build'),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.grid_on),
            title: const Text('Level editor'),
            subtitle: const Text(
              'Internal tool: build, test and export JSON levels',
            ),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const EditorScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Analytics'),
            subtitle: const Text('Win rates and recent events on this device'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.red),
            title: const Text('Reset progress'),
            onTap: () async {
              final ok = await confirm(
                context,
                'Reset progress?',
                'All stars, coins and boosters will be lost.',
                ok: 'Reset',
              );
              if (ok) app.resetProgress();
            },
          ),
          const AboutListTile(
            applicationName: 'Blend Burst',
            applicationVersion: 'MVP',
            applicationLegalese: 'Match, blend and shift gravity!',
          ),
        ],
      ),
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final d = scope.app.data;
    final played = d.attempts.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Sessions: ${d.sessions}   Win streak: ${d.winStreak}'),
          const SizedBox(height: 12),
          const Text(
            'Per level',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          if (played.isEmpty) const Text('No levels played yet.'),
          for (final id in played)
            ListTile(
              dense: true,
              title: Text('Level $id'),
              trailing: Text(
                '${d.wins[id] ?? 0}/${d.attempts[id]} wins '
                '(${(100 * (d.wins[id] ?? 0) / d.attempts[id]!).toStringAsFixed(0)}%)',
              ),
            ),
          const Divider(),
          const Text(
            'Recent events',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final e in d.events.reversed.take(60))
            Text(
              '${DateTime.fromMillisecondsSinceEpoch((e['t'] as num?)?.toInt() ?? 0).toLocal().toString().substring(0, 19)}  '
              '${e['e']} ${e['p'] ?? ''}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
        ],
      ),
    );
  }
}
