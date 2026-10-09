import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/ad_service.dart';
import 'app/app_state.dart';
import 'app/level_repository.dart';
import 'app/scope.dart';
import 'screens/map_screen.dart';

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

ThemeData buildTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B1FA2)),
  useMaterial3: true,
);

class BlendBurstApp extends StatefulWidget {
  /// Optional pre-built state for tests.
  final AppState? state;
  final AdService ads;

  const BlendBurstApp({
    super.key,
    this.state,
    this.ads = const PlaceholderAdService(),
  });

  @override
  State<BlendBurstApp> createState() => _BlendBurstAppState();
}

class _BlendBurstAppState extends State<BlendBurstApp> {
  AppState? _app;
  LevelRepository? _levels;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final app = widget.state ?? AppState();
      final levels = await LevelRepository.load();
      if (widget.state == null) await app.load();
      app.totalLevels = levels.levels.length;
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7B1FA2), Color(0xFFFF7043)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Blend Burst',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              if (error == null)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Could not load the game.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
