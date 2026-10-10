import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/game_ui.dart';
import '../ui/icons.dart';
import '../ui/tile_art.dart';

/// Ads: rewarded videos (the player chooses to watch) and short
/// interstitials between levels.
///
/// This build ships without an ads SDK, so both are placeholders. Swap in a
/// mediation SDK implementation later without touching the game code.
abstract class AdService {
  Future<bool> showRewarded(BuildContext context, {required String reward});
  Future<void> showInterstitial(BuildContext context);
}

class PlaceholderAdService implements AdService {
  const PlaceholderAdService();

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required String reward,
  }) async {
    final ok = await showGameDialog<bool>(
      context,
      builder: (_) => _PlaceholderAd(reward: reward),
    );
    return ok ?? false;
  }

  @override
  Future<void> showInterstitial(BuildContext context) =>
      showGameDialog<void>(context, builder: (_) => const _PlaceholderAd());
}

class _PlaceholderAd extends StatefulWidget {
  /// The reward for a rewarded ad; null for an interstitial.
  final String? reward;
  const _PlaceholderAd({this.reward});

  @override
  State<_PlaceholderAd> createState() => _PlaceholderAdState();
}

class _PlaceholderAdState extends State<_PlaceholderAd> {
  late int _left = widget.reward == null ? 2 : 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rewarded = widget.reward != null;
    return GamePanel(
      title: rewarded ? 'Rewarded ad' : 'Ad break',
      ribbonColor: Palette.sky,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIcons.video, size: 72),
          const SizedBox(height: 10),
          Text(
            rewarded
                ? 'No ads SDK in this build: this placeholder stands in for a '
                      'rewarded video.\n\nReward: ${widget.reward}'
                : 'No ads SDK in this build: this placeholder stands in for a '
                      'short ad between levels. Any purchase removes ad breaks.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Palette.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          CandyButton.label(
            _left > 0
                ? (rewarded ? 'Reward in $_left…' : 'Close in $_left…')
                : (rewarded ? 'Claim reward' : 'Continue'),
            key: const Key('ad-done'),
            colors: CandyColors.green,
            onTap: _left > 0 ? null : () => Navigator.of(context).pop(true),
          ),
          if (rewarded) ...[
            const SizedBox(height: 8),
            CandyButton.label(
              'Skip',
              key: const Key('ad-skip'),
              colors: CandyColors.gray,
              height: 40,
              fontSize: 18,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ],
      ),
    );
  }
}
