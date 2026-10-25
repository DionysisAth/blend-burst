import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics (the game's own events) and Crashlytics (crashes and
/// uncaught errors), on Android only: the iOS app has no Firebase config.
///
/// Data is only sent from the Google Play build (built with
/// `--dart-define=REAL_ADS=true`); test builds and CI emulators initialize
/// Firebase but keep collection off.
class GameFirebase {
  static const _collect = bool.fromEnvironment('REAL_ADS');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static FirebaseAnalytics? _analytics;

  /// Starts Firebase. Never throws: without it the game simply plays on.
  static Future<void> start() async {
    if (!supported || _analytics != null) return;
    try {
      await Firebase.initializeApp();
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(_collect);
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(_collect);
      // Analytics is for game statistics only, never for ads.
      await analytics.setConsent(
        analyticsStorageConsentGranted: true,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      _analytics = analytics;
      _reportErrors(crashlytics);
    } catch (e) {
      debugPrint('Firebase unavailable: $e');
    }
  }

  /// Sends Flutter and other uncaught errors to Crashlytics as well as to
  /// the handlers already installed (see installErrorHandlers).
  static void _reportErrors(FirebaseCrashlytics crashlytics) {
    final flutter = FlutterError.onError;
    FlutterError.onError = (details) {
      flutter?.call(details);
      unawaited(crashlytics.recordFlutterError(details));
    };
    final platform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(crashlytics.recordError(error, stack, fatal: true));
      return platform?.call(error, stack) ?? true;
    };
  }

  /// Names Firebase keeps for itself; ours get a prefix.
  static const _reserved = {
    'ad_activeview',
    'ad_click',
    'ad_exposure',
    'ad_query',
    'ad_reward',
    'adunit_exposure',
    'app_background',
    'app_clear_data',
    'app_exception',
    'app_remove',
    'app_store_refund',
    'app_store_subscription_cancel',
    'app_store_subscription_convert',
    'app_store_subscription_renew',
    'app_update',
    'app_upgrade',
    'dynamic_link_app_open',
    'dynamic_link_app_update',
    'dynamic_link_first_open',
    'error',
    'first_open',
    'first_visit',
    'in_app_purchase',
    'notification_dismiss',
    'notification_foreground',
    'notification_open',
    'notification_receive',
    'os_update',
    'purchase',
    'screen_view',
    'session_start',
    'user_engagement',
  };

  /// Logs one of the game's events (AppState.log) to Analytics.
  static void log(String name, Map<String, dynamic> params) {
    final analytics = _analytics;
    if (analytics == null) return;
    var event = name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (_reserved.contains(event)) event = 'game_$event';
    if (event.length > 40) event = event.substring(0, 40);
    final out = <String, Object>{};
    params.forEach((k, v) {
      if (out.length >= 25 || v == null) return;
      final key = k.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
      final value = switch (v) {
        num n => n,
        bool b => b ? 1 : 0,
        _ => v.toString(),
      };
      out[key.length > 40
          ? key.substring(0, 40)
          : key] = value is String && value.length > 100
          ? value.substring(0, 100)
          : value;
    });
    unawaited(
      analytics
          .logEvent(name: event, parameters: out)
          .catchError((Object e) => debugPrint('Analytics: $e')),
    );
  }
}
