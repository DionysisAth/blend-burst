import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/admob.dart';
import '../app/economy.dart';
import '../app/metrics.dart';
import '../app/scope.dart';
import '../l10n/l10n.dart';
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
                      label: tr.back,
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
      title: tr.settings,
      child: ListView(
        children: [
          _Card(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SoundToggles(),
              ),
              ListTile(
                key: const Key('settings-language'),
                leading: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [CandyColors.green.top, CandyColors.green.bottom],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const GameIcon(GameIcons.map),
                ),
                title: Text(tr.language, style: _labelStyle),
                subtitle: Text(
                  d.language == null
                      ? tr.languageSystem
                      : Lang.names[d.language] ?? d.language!,
                  style: _subStyle,
                ),
                onTap: () => showLanguagePicker(context),
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
                tr.settingsMoveHints,
                tr.settingsMoveHintsSub,
                d.hints,
                app.setHints,
              ),
              sw(
                tr.settingsTapActivate,
                tr.settingsTapActivateSub,
                d.tapActivate,
                app.setTapActivate,
              ),
              sw(
                tr.settingsReminders,
                tr.settingsRemindersSub,
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
                      tr.settingsReminders,
                      tr.settingsRemindersOff,
                      ok: tr.ok,
                      cancel: tr.close,
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
                tr.settingsEditor,
                tr.settingsEditorSub,
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const EditorScreen())),
              ),
              link(
                GameIcons.star,
                CandyColors.yellow,
                tr.settingsAnalytics,
                tr.settingsAnalyticsSub,
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
                          tr.settingsPrivacyChoices,
                          tr.settingsPrivacyChoicesSub,
                          ads.showPrivacyOptions,
                        )
                      : const SizedBox.shrink(),
                ),
              link(
                GameIcons.lock,
                CandyColors.purple,
                tr.settingsPrivacyPolicy,
                tr.settingsPrivacyPolicySub,
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
                tr.settingsReset,
                tr.settingsResetSub,
                () async {
                  final cloud = scope.cloud;
                  final ok = await confirm(
                    context,
                    tr.settingsResetTitle,
                    cloud != null && cloud.signedIn
                        ? tr.settingsResetCloud
                        : tr.settingsResetLocal,
                    ok: tr.settingsResetOk,
                  );
                  if (!ok) return;
                  app.resetProgress();
                  await cloud?.replaceCloud();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Blend Burst by NWBN • nwbn.online\n${tr.settingsCredits}',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
      true => tr.settingsAnalyticsYes,
      false => tr.settingsAnalyticsNo,
      null => tr.settingsAnalyticsNotYet,
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
      title: tr.settingsAnalytics,
      child: ListView(
        children: [
          _Card(
            children: [
              ListTile(
                title: Text(tr.settingsAnalyticsKeyMetrics, style: _labelStyle),
              ),
              row(
                tr.settingsAnalyticsRetention,
                '${day(1)} / ${day(7)} / ${day(30)}',
              ),
              row(
                tr.settingsAnalyticsLevelsPerSession,
                m.levelsPerSession.toStringAsFixed(1),
              ),
              row(
                tr.settingsAnalyticsSessionsPerDay,
                m.sessionsPerDay.toStringAsFixed(1),
              ),
              row(tr.settingsAnalyticsWinRate, pct(m.winRate)),
              row(
                tr.settingsAnalyticsAttemptsPerWin,
                m.attemptsPerWonLevel.toStringAsFixed(1),
              ),
              row(tr.settingsAnalyticsExtraMoves, pct(m.extraMovesRate)),
              row(
                tr.settingsAnalyticsAdsPerDay,
                m.adsPerDay.toStringAsFixed(1),
              ),
              row(tr.settingsAnalyticsTutorialsSeen, '${m.tutorialsSeen}'),
              row(tr.settingsAnalyticsPurchases, '${m.purchases}'),
              if (m.hardestLevels().isNotEmpty)
                row(
                  tr.settingsAnalyticsHardest,
                  m.hardestLevels().map((id) => '$id').join(', '),
                ),
            ],
          ),
          _Card(
            children: [
              ListTile(
                title: Text(
                  tr.settingsAnalyticsSessions(d.sessions, d.winStreak),
                  style: _labelStyle,
                ),
              ),
              if (played.isEmpty)
                ListTile(
                  title: Text(tr.settingsAnalyticsNoLevels, style: _subStyle),
                ),
              for (final id in played)
                ListTile(
                  dense: true,
                  title: Text(tr.levelN(id), style: _labelStyle),
                  trailing: Text(
                    tr.settingsAnalyticsWins(
                      d.wins[id] ?? 0,
                      d.attempts[id]!,
                      (100 * (d.wins[id] ?? 0) / d.attempts[id]!)
                          .toStringAsFixed(0),
                    ),
                    style: _subStyle,
                  ),
                ),
            ],
          ),
          _Card(
            children: [
              ListTile(
                title: Text(tr.settingsAnalyticsRecent, style: _labelStyle),
              ),
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

/// Lets the player pick the game's language, or follow the phone's.
Future<void> showLanguagePicker(BuildContext context) {
  final app = AppScope.read(context).app;
  final chosen = app.data.language;
  final phone = Lang.names[Lang.resolve(null).languageCode]!;
  return showGameDialog<void>(
    context,
    dismissible: true,
    builder: (ctx) {
      Widget option(String? code, String name, {String? sub}) {
        final selected = code == chosen;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: selected ? const Color(0xFFE6F7EC) : const Color(0xFFFFFBF4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected ? Palette.mint : const Color(0xFFFFD9A8),
                width: selected ? 3 : 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('lang-${code ?? 'system'}'),
              onTap: () {
                UiSounds.click?.call();
                Navigator.of(ctx).pop();
                if (code != chosen) app.setLanguage(code);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: _labelStyle),
                          if (sub != null) Text(sub, style: _subStyle),
                        ],
                      ),
                    ),
                    if (selected)
                      const GameIcon(GameIcons.check, size: 28)
                    else
                      const SizedBox(width: 28, height: 28),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final height = MediaQuery.sizeOf(ctx).height;
      return GamePanel(
        title: tr.language,
        ribbonColor: Palette.mint,
        onClose: () => Navigator.of(ctx).pop(),
        padding: const EdgeInsets.fromLTRB(14, 44, 14, 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (height * 0.62).clamp(220, 560),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              option(null, tr.languageSystem, sub: phone),
              for (final c in Lang.codes) option(c, Lang.names[c]!),
            ],
          ),
        ),
      );
    },
  );
}
