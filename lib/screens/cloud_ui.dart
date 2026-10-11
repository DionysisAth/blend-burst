import 'package:flutter/material.dart';

import '../app/cloud.dart';
import '../app/scope.dart';
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
    'Leaderboards',
    problem == CloudSync.notSetUp
        ? 'Leaderboards need Google Play Games, which is not set up for '
              'this version yet. They will appear in a later update.'
        : problem,
    ok: 'OK',
    cancel: 'Close',
  );
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
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
            sub = 'Cloud save and leaderboards are coming in a later update.';
          case CloudStatus.signedOut:
            sub =
                'Sign in to keep your progress safe in the cloud and '
                'compete on the leaderboards.';
          case CloudStatus.busy:
            sub = 'Signing in…';
          case CloudStatus.signedIn:
            final last = cloud.lastSync;
            sub = [
              'Signed in as ${cloud.player ?? 'Player'}',
              if (cloud.syncing)
                'Saving…'
              else if (last != null)
                'Saved ${_ago(last)}',
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
                        'Sign in',
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
                        'Save now',
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
                      'Leaderboards',
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
          ],
        );
      },
    );
  }
}
