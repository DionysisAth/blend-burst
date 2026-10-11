import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/admob.dart';
import '../app/economy.dart';
import '../app/metrics.dart';
import '../app/scope.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';
import 'cloud_ui.dart';
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

const privacyPolicyUrl = 'https://www.nwbn.online/blendburst/privacy-policy';

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
          if (scope.cloud != null)
            const _Card(
              children: [
                CloudCard(labelStyle: _labelStyle, subStyle: _subStyle),
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
              sw(
                'Reminders',
                'Full lives, daily gift and event reminders',
                d.notifications,
                (v) async {
                  if (!v) {
                    app.setNotifications(false);
                    await scope.reminders.cancelAll();
                    return;
                  }
                  final ok = await scope.reminders.enable();
                  if (ok) {
                    app.setNotifications(true);
                  } else if (context.mounted) {
                    await confirm(
                      context,
                      'Reminders',
                      'Notifications are turned off for Blend Burst. You can '
                          'allow them in your phone settings.',
                      ok: 'OK',
                      cancel: 'Close',
                    );
                  }
                },
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
              if (scope.ads case final AdMobAds ads)
                ValueListenableBuilder<bool>(
                  valueListenable: ads.privacyOptionsRequired,
                  builder: (context, required, _) => required
                      ? link(
                          GameIcons.check,
                          CandyColors.blue,
                          'Privacy choices',
                          'Change your ad consent',
                          ads.showPrivacyOptions,
                        )
                      : const SizedBox.shrink(),
                ),
              link(
                GameIcons.lock,
                CandyColors.purple,
                'Privacy policy',
                'How the game handles your data',
                () async {
                  try {
                    await launchUrl(
                      Uri.parse(privacyPolicyUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                },
              ),
              link(
                GameIcons.retry,
                CandyColors.red,
                'Reset progress',
                'Start over from level 1',
                () async {
                  final cloud = scope.cloud;
                  final ok = await confirm(
                    context,
                    'Reset?',
                    cloud != null && cloud.signedIn
                        ? 'All stars, coins and boosters will be lost, '
                              'here and in your cloud save.'
                        : 'All stars, coins and boosters will be lost.',
                    ok: 'Reset',
                  );
                  if (!ok) return;
                  app.resetProgress();
                  await cloud?.replaceCloud();
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Blend Burst by NWBN • nwbn.online\nMusic and sounds are made for this game.',
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
    final m = Metrics(d, dayNumber(DateTime.now()));
    String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
    String day(int n) => switch (m.retainedOnDay(n)) {
      true => 'yes',
      false => 'no',
      null => 'not yet',
    };
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(k, style: _labelStyle)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(v, style: _subStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
    return MenuPage(
      title: 'Analytics',
      child: ListView(
        children: [
          _Card(
            children: [
              const ListTile(title: Text('Key metrics', style: _labelStyle)),
              row(
                'Back on day 1 / 7 / 30',
                '${day(1)} / ${day(7)} / ${day(30)}',
              ),
              row('Levels per session', m.levelsPerSession.toStringAsFixed(1)),
              row('Sessions per day', m.sessionsPerDay.toStringAsFixed(1)),
              row('Win rate', pct(m.winRate)),
              row(
                'Attempts per won level',
                m.attemptsPerWonLevel.toStringAsFixed(1),
              ),
              row('Extra moves bought on fail', pct(m.extraMovesRate)),
              row('Ads watched per day', m.adsPerDay.toStringAsFixed(1)),
              row('Tutorials seen', '${m.tutorialsSeen}'),
              row('Purchases', '${m.purchases}'),
              if (m.hardestLevels().isNotEmpty)
                row(
                  'Hardest levels',
                  m.hardestLevels().map((id) => '$id').join(', '),
                ),
            ],
          ),
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
