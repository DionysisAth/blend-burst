import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../screens/dialogs.dart';
import 'ad_service.dart';

/// AdMob ad units.
///
/// Builds show Google's test ads unless built with
/// `--dart-define=REAL_ADS=true` (do that only for the Play Store build:
/// tapping your own live ads can get the AdMob account suspended).
/// The AdMob app ID is in android/app/src/main/AndroidManifest.xml.
class AdUnits {
  static const real = bool.fromEnvironment('REAL_ADS');

  static const _interstitial = 'ca-app-pub-1774874652706103/3880023843';
  static const _rewarded = 'ca-app-pub-1774874652706103/4210187177';

  // Google's public test units.
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String get interstitial => real ? _interstitial : _testInterstitial;
  static String get rewarded => real ? _rewarded : _testRewarded;

  /// iOS has no AdMob app yet; ads stay off there until it does.
  static bool get supported => !kIsWeb && Platform.isAndroid;
}

/// Rewarded videos and interstitials from AdMob, after the consent form
/// (shown by Google only where the law requires it, e.g. the EU and UK).
///
/// Nothing here can stop the game: if the SDK fails, an interstitial is
/// simply skipped and a rewarded video says "no video right now".
class AdMobAds implements AdService {
  AdMobAds();

  bool _started = false;
  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  int _interstitialFails = 0;
  int _rewardedFails = 0;

  /// Whether the privacy options entry must be offered in Settings.
  final privacyOptionsRequired = ValueNotifier<bool>(false);

  /// Asks for consent if needed, then starts the SDK and preloads ads.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _gatherConsent();
      await _updatePrivacyStatus();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 20),
      );
      _ready = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('Ads unavailable: $e');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) debugPrint('Consent form: ${error.message}');
              finish();
            });
          } catch (e) {
            debugPrint('Consent form failed: $e');
            finish();
          }
        },
        (error) {
          debugPrint('Consent info: ${error.message}');
          finish();
        },
      );
    } catch (e) {
      debugPrint('Consent failed: $e');
      finish();
    }
    // The form waits for the player; give up waiting only after a while.
    return done.future.timeout(const Duration(minutes: 5), onTimeout: () {});
  }

  Future<void> _updatePrivacyStatus() async {
    try {
      privacyOptionsRequired.value =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {}
  }

  /// Opens Google's privacy options form (Settings -> Privacy choices).
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (!done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    } catch (e) {
      debugPrint('Privacy options failed: $e');
    }
    // The answer may now allow ads that were blocked before.
    if (!_ready) {
      _started = false;
      await start();
    }
  }

  static const _retry = Duration(seconds: 20);

  void _loadInterstitial() {
    if (!_ready || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    try {
      InterstitialAd.load(
        adUnitId: AdUnits.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingInterstitial = false;
            _interstitialFails = 0;
            _interstitial = ad;
          },
          onAdFailedToLoad: (error) {
            _loadingInterstitial = false;
            debugPrint('Interstitial failed to load: ${error.message}');
            if (++_interstitialFails < 5) {
              Timer(_retry * _interstitialFails, _loadInterstitial);
            }
          },
        ),
      );
    } catch (e) {
      _loadingInterstitial = false;
      debugPrint('Interstitial load failed: $e');
    }
  }

  void _loadRewarded() {
    if (!_ready || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    try {
      RewardedAd.load(
        adUnitId: AdUnits.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingRewarded = false;
            _rewardedFails = 0;
            _rewarded = ad;
          },
          onAdFailedToLoad: (error) {
            _loadingRewarded = false;
            debugPrint('Rewarded failed to load: ${error.message}');
            if (++_rewardedFails < 5) {
              Timer(_retry * _rewardedFails, _loadRewarded);
            }
          },
        ),
      );
    } catch (e) {
      _loadingRewarded = false;
      debugPrint('Rewarded load failed: $e');
    }
  }

  @override
  Future<void> showInterstitial(BuildContext context) async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) closed.complete();
      ad.dispose();
      _loadInterstitial();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial failed to show: ${error.message}');
        finish();
      },
    );
    try {
      await ad.show();
      await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    } catch (e) {
      debugPrint('Interstitial show failed: $e');
      finish();
    }
  }

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required String reward,
  }) async {
    final ad = _rewarded;
    if (ad == null) {
      if (!_ready) {
        _started = false;
        unawaited(start());
      } else {
        _rewardedFails = 0;
        _loadRewarded();
      }
      if (context.mounted) {
        await confirm(
          context,
          'No video right now',
          'There is no video to watch at the moment. Please try again in a '
              'little while.',
          ok: 'OK',
          cancel: 'Close',
        );
      }
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) closed.complete();
      ad.dispose();
      _loadRewarded();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Rewarded failed to show: ${error.message}');
        finish();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    } catch (e) {
      debugPrint('Rewarded show failed: $e');
      finish();
    }
    return earned;
  }
}
