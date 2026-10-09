import 'dart:async';

import 'package:flutter/material.dart';

/// Rewarded video ads.
///
/// The MVP ships without an ads SDK, so this shows a short placeholder
/// instead of a real ad. Swap in a mediation SDK implementation later
/// without touching the game code.
abstract class AdService {
  Future<bool> showRewarded(BuildContext context, {required String reward});
}

class PlaceholderAdService implements AdService {
  const PlaceholderAdService();

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required String reward,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PlaceholderAd(reward: reward),
    );
    return ok ?? false;
  }
}

class _PlaceholderAd extends StatefulWidget {
  final String reward;
  const _PlaceholderAd({required this.reward});

  @override
  State<_PlaceholderAd> createState() => _PlaceholderAdState();
}

class _PlaceholderAdState extends State<_PlaceholderAd> {
  int _left = 3;
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
    return AlertDialog(
      title: const Text('Sample rewarded ad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ondemand_video, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 12),
          Text(
            'No ads SDK in this build. This placeholder stands in for a '
            'rewarded video.\n\nReward: ${widget.reward}',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _left > 0 ? null : () => Navigator.of(context).pop(true),
          child: Text(_left > 0 ? 'Reward in $_left…' : 'Claim reward'),
        ),
      ],
    );
  }
}
