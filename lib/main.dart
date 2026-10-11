import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/ad_service.dart';
import 'app/admob.dart';
import 'app/app_state.dart';
import 'app/audio.dart';
import 'app/cloud.dart';
import 'app/level_repository.dart';
import 'app/notifications.dart';
import 'app/play_store.dart';
import 'app/scope.dart';
import 'app/store.dart';
import 'screens/map_screen.dart';
import 'ui/game_ui.dart';
import 'ui/logo.dart';
import 'ui/tile_art.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  // Portrait only; ignore failures (e.g. on platforms without orientation).
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).catchError((Object _) {}),
  );
  runApp(const BlendBurstApp());
}

/// Keeps uncaught errors from taking the app down. They are logged, and a
/// broken widget shows a small notice instead of a red or gray screen.
void installErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('Flutter error: ${details.exceptionAsString()}');
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
      color: Color(0xFFF3E5F5),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Oops, something went wrong here.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.grape,
      primary: Palette.grape,
    ),
    useMaterial3: true,
    fontFamily: 'Fredoka',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0xFFE6DDF5),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.mint
            : const Color(0xFFB8A9D1),
      ),
    ),
  );
}

class BlendBurstApp extends StatefulWidget {
  /// Optional pre-built state for tests.
  final AppState? state;

  /// Ads (AdMob on Android; a placeholder in tests and elsewhere).
  final AdService? ads;
  final GameAudio? audio;
  final Notifier? notifier;

  /// Play Games / Game Center connection (a fake in tests).
  final GamesBackend? games;

  /// Real-money purchases (Google Play billing on Android).
  final Store? store;

  const BlendBurstApp({
    super.key,
    this.state,
    this.ads,
    this.audio,
    this.notifier,
    this.games,
    this.store,
  });

  @override
  State<BlendBurstApp> createState() => _BlendBurstAppState();
}

class _BlendBurstAppState extends State<BlendBurstApp>
    with WidgetsBindingObserver {
  AppState? _app;
  LevelRepository? _levels;
  CloudSync? _cloud;
  Store? _store;
  late final AdService _ads =
      widget.ads ??
      (_inTests || !AdUnits.supported
          ? const PlaceholderAdService()
          : AdMobAds());
  Object? _error;
  late final GameAudio _audio = widget.audio ?? GameAudio.create();
  late final Notifier _notifier = widget.notifier ?? LocalNotifier();
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    UiSounds.click = () => _audio.sfx(Sfx.click);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = _app;
    if (app == null) return;
    final away =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (away) unawaited(_cloud?.flush());
    if (!app.data.notifications) return;
    // Reminders only make sense while the game is not on screen.
    if (away && !_inBackground) {
      _inBackground = true;
      unawaited(_notifier.schedule(app.reminders()));
    } else if (state == AppLifecycleState.resumed && _inBackground) {
      _inBackground = false;
      unawaited(_notifier.cancelAll());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UiSounds.click = null;
    _cloud?.dispose();
    final store = _store;
    if (store is PlayStore) store.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final app = widget.state ?? AppState();
      final levels = await LevelRepository.load();
      if (widget.state == null) await app.load();
      app.totalLevels = levels.levels.length;
      // Live tuning from the previous launch; fetch a fresh copy for next time.
      final moves = app.config.moves;
      for (final l in levels.levels) {
        final m = moves[l.id];
        if (m != null) l.moves = m;
      }
      if (widget.state == null) unawaited(app.refreshRemoteConfig());
      _audio.setSound(app.data.sound);
      _audio.setMusic(app.data.music);
      // Load sounds in the background; the game never waits for audio.
      unawaited(_audio.preload());
      if (!mounted) return;
      final cloud = _cloud ??= CloudSync(
        widget.games ?? (_inTests ? const NoGames() : PlayGames()),
        app,
      );
      final store = _store ??=
          widget.store ??
          (_inTests || !PlayStore.supported
              ? const TestStore()
              : PlayStore(app));
      setState(() {
        _app = app;
        _levels = levels;
      });
      // Cloud save and leaderboards start once the map is up; the game
      // never waits for them.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(cloud.start());
        if (store is PlayStore) unawaited(store.start());
        final ads = _ads;
        if (ads is AdMobAds) unawaited(ads.start());
      });
    } catch (e, st) {
      debugPrint('Startup failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app, levels = _levels;
    if (app == null || levels == null) {
      return MaterialApp(
        title: 'Blend Burst',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: LoadingScreen(error: _error, onRetry: _load),
      );
    }
    return AppScope(
      app: app,
      levels: levels,
      ads: _ads,
      audio: _audio,
      reminders: _notifier,
      cloud: _cloud,
      store: _store ?? const TestStore(),
      child: MaterialApp(
        title: 'Blend Burst',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const MapScreen(),
      ),
    );
  }
}

bool get _inTests {
  try {
    return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

class LoadingScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const LoadingScreen({super.key, this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaintedBackground(
        theme: 0,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BlendBurstLogo(size: 64),
                const SizedBox(height: 36),
                if (error == null)
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 5,
                    ),
                  )
                else ...[
                  const GameText('Could not load the game', size: 22),
                  const SizedBox(height: 16),
                  CandyButton.label('Try again', onTap: onRetry, width: 220),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
