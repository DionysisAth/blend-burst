import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'app_state.dart';
import 'audio.dart';
import 'level_repository.dart';
import 'notifications.dart';
import 'store.dart';

/// Makes the app state, levels and services available to every screen.
class AppScope extends InheritedNotifier<AppState> {
  final LevelRepository levels;
  final AdService ads;
  final GameAudio audio;
  final Store store;
  final Notifier reminders;

  const AppScope({
    super.key,
    required AppState app,
    required this.levels,
    required this.ads,
    required this.audio,
    this.store = const TestStore(),
    this.reminders = const NoNotifier(),
    required super.child,
  }) : super(notifier: app);

  AppState get app => notifier!;

  /// Subscribes the caller to app state changes.
  static AppScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'No AppScope above this widget');
    return s!;
  }

  /// Reads without subscribing (safe in initState and callbacks).
  static AppScope read(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'No AppScope above this widget');
    return s!;
  }
}
