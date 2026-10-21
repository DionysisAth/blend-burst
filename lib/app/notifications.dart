import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';

/// A reminder to show at a later time.
class Reminder {
  final int id;
  final String title;
  final String body;
  final DateTime at;
  const Reminder(this.id, this.title, this.body, this.at);
}

/// Opt-in local notifications ("your lives are full", "the event ends
/// soon"). Nothing touches the platform plugin until the player turns
/// notifications on, so the default path cannot fail.
abstract class Notifier {
  /// Asks for permission. True when notifications may be shown.
  Future<bool> enable();

  /// Replaces all pending reminders with [reminders].
  Future<void> schedule(List<Reminder> reminders);

  Future<void> cancelAll();
}

class NoNotifier implements Notifier {
  const NoNotifier();
  @override
  Future<bool> enable() async => false;
  @override
  Future<void> schedule(List<Reminder> reminders) async {}
  @override
  Future<void> cancelAll() async {}
}

class LocalNotifier implements Notifier {
  LocalNotifier();

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> _init() => _ready ??= () async {
    if (!supported) return false;
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_blend'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
      return false;
    }
  }();

  @override
  Future<bool> enable() async {
    if (!await _init()) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  static NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      tr.settingsReminders,
      channelDescription: tr.notificationChannelHelp,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    if (!await _init()) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final r in reminders) {
        if (!r.at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Scheduling notifications failed: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (_ready == null || !await _init()) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Cancelling notifications failed: $e');
    }
  }
}
