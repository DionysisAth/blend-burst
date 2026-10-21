import 'package:flutter/material.dart';

import '../app/cloud.dart';
import '../app/scope.dart';
import '../l10n/l10n.dart';
import '../ui/game_ui.dart';
import '../ui/icons.dart';
import 'dialogs.dart';

/// Opens the Play Games leaderboards, or explains why it can't.
Future<void> openLeaderboards(BuildContext context) async {
  final cloud = AppScope.read(context).cloud;
  final problem = cloud == null
      ? CloudSync.notSetUp
      : await cloud.openLeaderboards();
  if (problem == null || !context.mounted) return;
  await confirm(
    context,
    tr.cloudLeaderboards,
    problem == CloudSync.notSetUp ? tr.cloudLeaderboardsNotSetUp : problem,
    ok: tr.ok,
    cancel: tr.close,
  );
}

/// Opens the Play Games achievements, or explains why it can't.
Future<void> openAchievements(BuildContext context) async {
  final cloud = AppScope.read(context).cloud;
  final problem = cloud == null
      ? CloudSync.notSetUp
      : await cloud.openAchievements();
  if (problem == null || !context.mounted) return;
  await confirm(
    context,
    tr.cloudAchievements,
    problem == CloudSync.notSetUp ? tr.cloudAchievementsNotSetUp : problem,
    ok: tr.ok,
    cancel: tr.close,
  );
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr.cloudJustNow;
  if (d.inMinutes < 60) return tr.cloudMinAgo(d.inMinutes);
  if (d.inHours < 24) return tr.cloudHoursAgo(d.inHours);
  return tr.cloudDaysAgo(d.inDays);
}

/// Settings card: Play Games sign-in, cloud save and leaderboards.
class CloudCard extends StatelessWidget {
  final TextStyle labelStyle;
  final TextStyle subStyle;
  const CloudCard({
    super.key,
    required this.labelStyle,
    required this.subStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cloud = AppScope.of(context).cloud;
    if (cloud == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        final String sub;
        switch (cloud.status) {
          case CloudStatus.unavailable:
            sub = tr.cloudComingLater;
          case CloudStatus.signedOut:
            sub = tr.cloudSignInPitch;
          case CloudStatus.busy:
            sub = tr.cloudSigningIn;
          case CloudStatus.signedIn:
            final last = cloud.lastSync;
            sub = [
              tr.cloudSignedInAs(cloud.player ?? tr.cloudPlayer),
              if (cloud.syncing)
                tr.cloudSaving
              else if (last != null)
                tr.cloudSavedAgo(_ago(last)),
            ].join(' • ');
        }
        final message = cloud.message;
        return Column(
          children: [
            ListTile(
              key: const Key('cloud-status'),
              leading: Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [CandyColors.blue.top, CandyColors.blue.bottom],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const GameIcon(GameIcons.cloud),
              ),
              title: Text('Google Play Games', style: labelStyle),
              subtitle: Text(sub, style: subStyle),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  message,
                  style: subStyle.copyWith(color: const Color(0xFFC0304A)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  if (cloud.status == CloudStatus.signedOut ||
                      cloud.status == CloudStatus.busy)
                    Expanded(
                      child: CandyButton.label(
                        tr.cloudSignIn,
                        key: const Key('cloud-sign-in'),
                        height: 46,
                        fontSize: 19,
                        onTap: cloud.status == CloudStatus.busy
                            ? null
                            : () => cloud.signIn(),
                      ),
                    ),
                  if (cloud.signedIn)
                    Expanded(
                      child: CandyButton.label(
                        tr.cloudSaveNow,
                        key: const Key('cloud-sync'),
                        height: 46,
                        fontSize: 19,
                        colors: CandyColors.blue,
                        onTap: cloud.syncing ? null : () => cloud.sync(),
                      ),
                    ),
                  if (cloud.status != CloudStatus.unavailable)
                    const SizedBox(width: 10),
                  Expanded(
                    child: CandyButton.label(
                      tr.cloudLeaderboards,
                      key: const Key('cloud-leaderboards'),
                      height: 46,
                      fontSize: 19,
                      colors: CandyColors.yellow,
                      onTap: () => openLeaderboards(context),
                    ),
                  ),
                ],
              ),
            ),
            if (cloud.status != CloudStatus.unavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: CandyButton.label(
                  tr.cloudAchievements,
                  key: const Key('cloud-achievements'),
                  height: 46,
                  fontSize: 19,
                  colors: CandyColors.purple,
                  onTap: () => openAchievements(context),
                ),
              ),
          ],
        );
      },
    );
  }
}
