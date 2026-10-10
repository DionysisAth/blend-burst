import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/ad_service.dart';
import 'app/app_state.dart';
import 'app/audio.dart';
import 'app/level_repository.dart';
import 'app/scope.dart';
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
  final AdService ads;
  final GameAudio? audio;

  const BlendBurstApp({
    super.key,
    this.state,
    this.ads = const PlaceholderAdService(),
    this.audio,
  });

  @override
  State<BlendBurstApp> createState() => _BlendBurstAppState();
}

class _BlendBurstAppState extends State<BlendBurstApp> {
  AppState? _app;
  LevelRepository? _levels;
  Object? _error;
  late final GameAudio _audio = widget.audio ?? GameAudio.create();

  @override
  void initState() {
    super.initState();
    UiSounds.click = () => _audio.sfx(Sfx.click);
    _load();
  }

  @override
  void dispose() {
    UiSounds.click = null;
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
      _audio.setSound(app.data.sound);
      _audio.setMusic(app.data.music);
      // Load sounds in the background; the game never waits for audio.
      unawaited(_audio.preload());
      if (!mounted) return;
      setState(() {
        _app = app;
        _levels = levels;
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
      ads: widget.ads,
      audio: _audio,
      child: MaterialApp(
        title: 'Blend Burst',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const MapScreen(),
      ),
    );
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
