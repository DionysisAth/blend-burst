import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';

import 'app_state.dart';

/// Google Play Games (Android) and Game Center (iOS) settings.
///
/// Fill these in once the game is set up in the Play Console
/// (Play Games Services -> Leaderboards) and App Store Connect. On Android
/// the project ID also goes in
/// `android/app/src/main/res/values/games.xml` (`game_services_project_id`).
/// Until then cloud save and leaderboards stay switched off, and the game
/// says so instead of calling Play Games.
class GamesConfig {
  /// Leaderboard IDs from the Play Console (they look like "CgkI...").
  static const androidStars = '';
  static const androidLevels = '';
  static const androidScore = '';

  /// Leaderboard IDs from App Store Connect.
  static const iosStars = 'blendburst.stars';
  static const iosLevels = 'blendburst.levels';
  static const iosScore = 'blendburst.score';

  /// Turn on once Game Center and iCloud are set up for the iOS app.
  static const iosEnabled = false;

  /// Name of the cloud save slot.
  static const saveName = 'blend-burst-progress';
}

/// One leaderboard the game posts to.
enum Board { stars, levels, score }

/// A Play Games / Game Center connection. [PlayGames] talks to the real
/// services; tests use a fake.
abstract class GamesBackend {
  /// Starts the SDK. False when the services are not set up, or the device
  /// cannot use them: then nothing else is called.
  Future<bool> init();
  Future<bool> isSignedIn();

  /// Shows the sign-in flow. Returns the player's name, or null.
  Future<String?> signIn();
  Future<String?> playerName();

  /// Names of the saves in the cloud, or null if the list failed to load.
  Future<List<String>?> saveNames();
  Future<String?> load(String name);
  Future<bool> save(String name, String data);
  Future<void> submit(Board board, int value);

  /// Opens the leaderboards screen. False if it could not be shown.
  Future<bool> showLeaderboards();
}

/// Used where the services can never work (tests, desktop).
class NoGames implements GamesBackend {
  const NoGames();
  @override
  Future<bool> init() async => false;
  @override
  Future<bool> isSignedIn() async => false;
  @override
  Future<String?> signIn() async => null;
  @override
  Future<String?> playerName() async => null;
  @override
  Future<List<String>?> saveNames() async => null;
  @override
  Future<String?> load(String name) async => null;
  @override
  Future<bool> save(String name, String data) async => false;
  @override
  Future<void> submit(Board board, int value) async {}
  @override
  Future<bool> showLeaderboards() async => false;
}

/// The real services via the games_services plugin. Every call is guarded:
/// a failure only ever means "not available right now".
class PlayGames implements GamesBackend {
  PlayGames();

  static const _channel = MethodChannel('blend_burst/games');
  static const _timeout = Duration(seconds: 20);

  static bool get supported =>
      !kIsWeb &&
      (Platform.isAndroid || (Platform.isIOS && GamesConfig.iosEnabled));

  Future<T?> _guard<T>(Future<T?> Function() f, {Duration? timeout}) async {
    try {
      return await f().timeout(timeout ?? _timeout);
    } catch (e) {
      debugPrint('Play Games: $e');
      return null;
    }
  }

  @override
  Future<bool> init() async {
    if (!supported) return false;
    if (Platform.isIOS) return true;
    // The Android side starts Play Games only when a real project ID is set.
    return await _guard(() => _channel.invokeMethod<bool>('init')) ?? false;
  }

  @override
  Future<bool> isSignedIn() async =>
      await _guard(() => GamesServices.isSignedIn) ?? false;

  @override
  Future<String?> signIn() async {
    // The sign-in screen waits for the player, so allow plenty of time.
    await _guard(GamesServices.signIn, timeout: const Duration(minutes: 3));
    if (!await isSignedIn()) return null;
    return await playerName() ?? 'Player';
  }

  @override
  Future<String?> playerName() => _guard(GamesServices.getPlayerName);

  @override
  Future<List<String>?> saveNames() async {
    final games = await _guard(
      () => GamesServices.getSavedGames(forceRefresh: true, ignoreImages: true),
    );
    return games?.map((g) => g.name).toList();
  }

  @override
  Future<String?> load(String name) =>
      _guard(() => GamesServices.loadGame(name: name));

  @override
  Future<bool> save(String name, String data) async {
    final ok = await _guard(() async {
      await SaveGame.saveGame(
        data: data,
        name: name,
        description: 'Blend Burst progress',
      );
      return true;
    });
    return ok ?? false;
  }

  static String _id(Board b) => Platform.isIOS
      ? switch (b) {
          Board.stars => GamesConfig.iosStars,
          Board.levels => GamesConfig.iosLevels,
          Board.score => GamesConfig.iosScore,
        }
      : switch (b) {
          Board.stars => GamesConfig.androidStars,
          Board.levels => GamesConfig.androidLevels,
          Board.score => GamesConfig.androidScore,
        };

  @override
  Future<void> submit(Board board, int value) async {
    final id = _id(board);
    if (id.isEmpty) return;
    await _guard(
      () => GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: id,
          iOSLeaderboardID: id,
          value: value,
        ),
      ),
    );
  }

  @override
  Future<bool> showLeaderboards() async {
    final ok = await _guard(() async {
      await GamesServices.showLeaderboards();
      return true;
    }, timeout: const Duration(minutes: 10));
    return ok ?? false;
  }
}

enum CloudStatus {
  /// Play Games is not set up for this build (or this device).
  unavailable,
  signedOut,
  busy,
  signedIn,
}

/// Keeps the progress in the cloud save and posts leaderboard scores.
///
/// Safety rule: the cloud copy is only ever replaced by a merge of itself
/// with this device's progress. If the cloud copy could not be read, nothing
/// is uploaded, so a fresh install with a bad connection can never wipe
/// progress made on another phone.
class CloudSync extends ChangeNotifier {
  final GamesBackend backend;
  final AppState app;

  CloudSync(this.backend, this.app);

  CloudStatus status = CloudStatus.unavailable;
  String? player;
  DateTime? lastSync;
  String? message;
  bool _started = false;
  bool _available = false;

  bool _syncing = false;
  Timer? _debounce;
  final _posted = <Board, int>{};

  bool get available => _available;
  bool get signedIn => status == CloudStatus.signedIn;

  void _set(CloudStatus s, {String? msg}) {
    status = s;
    message = msg;
    notifyListeners();
  }

  /// Starts the services and syncs if the player is already signed in
  /// (Play Games signs returning players in automatically).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _available = await backend.init();
      if (!_available) {
        _set(CloudStatus.unavailable);
        return;
      }
      app.addListener(_onAppChanged);
      if (await backend.isSignedIn()) {
        player = await backend.playerName();
        _set(CloudStatus.signedIn);
        await sync();
      } else {
        _set(CloudStatus.signedOut);
      }
    } catch (e) {
      debugPrint('Cloud start failed: $e');
      _set(CloudStatus.unavailable);
    }
  }

  /// Shows the sign-in flow, then syncs.
  Future<bool> signIn() async {
    if (!_available || status == CloudStatus.busy) return false;
    _set(CloudStatus.busy);
    final name = await backend.signIn();
    if (name == null) {
      _set(CloudStatus.signedOut, msg: 'Could not sign in to Play Games.');
      return false;
    }
    player = name;
    _set(CloudStatus.signedIn);
    await sync();
    return true;
  }

  /// Merges the cloud copy into this device's progress and uploads the
  /// result. Returns true on success.
  Future<bool> sync() async {
    if (!signedIn || _syncing) return false;
    _debounce?.cancel();
    _debounce = null;
    _syncing = true;
    notifyListeners();
    try {
      final names = await backend.saveNames();
      if (names == null) {
        message = 'Could not reach the cloud save. Try again later.';
        return false;
      }
      if (names.contains(GamesConfig.saveName)) {
        final raw = await backend.load(GamesConfig.saveName);
        final cloud = raw == null ? null : SaveData.tryParse(raw);
        if (cloud == null) {
          message = 'Could not read the cloud save. Try again later.';
          return false;
        }
        final merged = SaveData.merge(app.data, cloud);
        if (_differs(merged, app.data)) app.replaceData(merged);
      }
      final ok = await backend.save(
        GamesConfig.saveName,
        jsonEncode(app.data.toJson()),
      );
      await _postScores();
      if (ok) {
        lastSync = DateTime.now();
        message = null;
      } else {
        message = 'Could not upload to the cloud save. Try again later.';
      }
      return ok;
    } catch (e) {
      debugPrint('Cloud sync failed: $e');
      message = 'Cloud save failed. Try again later.';
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  static bool _differs(SaveData a, SaveData b) {
    Map<String, dynamic> core(SaveData s) => s.toJson()..remove('savedAt');
    return jsonEncode(core(a)) != jsonEncode(core(b));
  }

  bool get syncing => _syncing;

  /// Overwrites the cloud copy with this device's progress, without
  /// merging (after "Reset progress").
  Future<void> replaceCloud() async {
    if (!signedIn) return;
    _debounce?.cancel();
    _debounce = null;
    _posted.clear();
    await backend.save(GamesConfig.saveName, jsonEncode(app.data.toJson()));
  }

  Future<void> _postScores() async {
    final scores = {
      Board.stars: app.totalStars,
      Board.levels: app.data.stars.keys.fold(0, (a, b) => b > a ? b : a),
      Board.score: app.data.best.values.fold(0, (a, b) => a + b),
    };
    for (final e in scores.entries) {
      if (e.value <= 0 || _posted[e.key] == e.value) continue;
      await backend.submit(e.key, e.value);
      _posted[e.key] = e.value;
    }
  }

  void _onAppChanged() {
    if (!signedIn || _syncing) return;
    // Batch changes: sync a while after the last one.
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 45), () => unawaited(sync()));
  }

  /// Syncs now if anything changed (e.g. when the app goes to the
  /// background).
  Future<void> flush() async {
    if (_debounce == null) return;
    await sync();
  }

  /// Opens the leaderboards, signing in first if needed. Returns a message
  /// to show when they cannot be opened.
  Future<String?> openLeaderboards() async {
    if (!_available) return notSetUp;
    if (!signedIn && !await signIn()) return 'Sign in to Play Games first.';
    unawaited(_postScores());
    if (!await backend.showLeaderboards()) {
      return 'Could not open the leaderboards.';
    }
    return null;
  }

  static const notSetUp =
      'Google Play Games is not set up for this version yet.';

  @override
  void dispose() {
    _debounce?.cancel();
    app.removeListener(_onAppChanged);
    super.dispose();
  }
}
