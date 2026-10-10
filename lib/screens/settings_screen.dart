import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import 'dialogs.dart';
import 'editor_screen.dart';

/// Shared scaffold for menu pages: painted background, back button, ribbon.
class MenuPage extends StatelessWidget {
  final String title;
  final Widget child;
  const MenuPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaintedBackground(
        theme: 2,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    RoundButton(
                      GameIcons.back,
                      label: 'Back',
                      size: 44,
                      colors: CandyColors.blue,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Ribbon(
                          title,
                          color: Palette.grape,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 50),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Palette.plum, width: 4),
      color: const Color(0xFFFFFBF4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55301040),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}

const _labelStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 17,
  color: Palette.ink,
);
const _subStyle = TextStyle(
  fontWeight: FontWeight.w500,
  fontSize: 13,
  color: Color(0xFF6E5A8A),
);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final app = scope.app;
    final d = app.data;
    Widget sw(String title, String? sub, bool v, ValueChanged<bool> on) =>
        SwitchListTile(
          title: Text(title, style: _labelStyle),
          subtitle: sub == null ? null : Text(sub, style: _subStyle),
          value: v,
          onChanged: on,
        );
    Widget link(
      GameIcons icon,
      CandyColors colors,
      String title,
      String sub,
      VoidCallback onTap,
    ) => ListTile(
      leading: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [colors.top, colors.bottom]),
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: GameIcon(icon),
      ),
      title: Text(title, style: _labelStyle),
      subtitle: Text(sub, style: _subStyle),
      onTap: onTap,
    );
    return MenuPage(
      title: 'Settings',
      child: ListView(
        children: [
          const _Card(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SoundToggles(),
              ),
            ],
          ),
          _Card(
            children: [
              sw(
                'Move hints',
                'Show a possible move after 5 seconds',
                d.hints,
                app.setHints,
              ),
              sw(
                'Tap to activate specials',
                'Tap a special tile to fire it (uses a move)',
                d.tapActivate,
                app.setTapActivate,
              ),
            ],
          ),
          _Card(
            children: [
              link(
                GameIcons.splash,
                CandyColors.green,
                'Level editor',
                'Build, play-test and export JSON levels',
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const EditorScreen())),
              ),
              link(
                GameIcons.star,
                CandyColors.yellow,
                'Analytics',
                'Win rates and recent events on this device',
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                ),
              ),
              link(
                GameIcons.retry,
                CandyColors.red,
                'Reset progress',
                'Start over from level 1',
                () async {
                  final ok = await confirm(
                    context,
                    'Reset?',
                    'All stars, coins and boosters will be lost.',
                    ok: 'Reset',
                  );
                  if (ok) app.resetProgress();
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Blend Burst • MVP build\nMusic and sounds are synthesized for this game.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    return MenuPage(
      title: 'Analytics',
      child: ListView(
        children: [
          _Card(
            children: [
              ListTile(
                title: Text(
                  'Sessions: ${d.sessions}   Win streak: ${d.winStreak}',
                  style: _labelStyle,
                ),
              ),
              if (played.isEmpty)
                const ListTile(
                  title: Text('No levels played yet.', style: _subStyle),
                ),
              for (final id in played)
                ListTile(
                  dense: true,
                  title: Text('Level $id', style: _labelStyle),
                  trailing: Text(
                    '${d.wins[id] ?? 0}/${d.attempts[id]} wins '
                    '(${(100 * (d.wins[id] ?? 0) / d.attempts[id]!).toStringAsFixed(0)}%)',
                    style: _subStyle,
                  ),
                ),
            ],
          ),
          _Card(
            children: [
              const ListTile(title: Text('Recent events', style: _labelStyle)),
              for (final e in d.events.reversed.take(60))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Text(
                    '${DateTime.fromMillisecondsSinceEpoch((e['t'] as num?)?.toInt() ?? 0).toLocal().toString().substring(5, 19)}  '
                    '${e['e']} ${e['p'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Palette.ink),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}
