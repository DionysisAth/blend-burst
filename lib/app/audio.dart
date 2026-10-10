import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart';

enum Sfx {
  swap,
  invalid,
  blend,
  special,
  line,
  bomb,
  prism,
  whiteburst,
  combo,
  glass,
  stain,
  gravity,
  shuffle,
  win,
  lose,
  click,
  coin,
  booster,
  praise,
  start,
}

enum Music { map, game }

/// Game sound effects and music.
abstract class GameAudio {
  bool get soundOn;
  bool get musicOn;
  void setSound(bool on);
  void setMusic(bool on);
  void sfx(Sfx s, {double volume = 1});

  /// Match pop; pitch rises with the cascade level.
  void pop(int cascade);

  /// Star ding for the win screen (0..2).
  void star(int i);

  /// Switches the background track (null = silence).
  void music(Music? track);

  /// Loads sounds in the background.
  Future<void> preload();
  void dispose();

  /// Picks a real player, or a silent one under `flutter test`.
  static GameAudio create({bool sound = true, bool music = true}) {
    var testing = false;
    try {
      testing = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {}
    if (testing) return SilentAudio(sound: sound, music: music);
    return PlayerAudio(sound: sound, music: music);
  }
}

/// Records what would have played. Used by tests.
class SilentAudio implements GameAudio {
  @override
  bool soundOn;
  @override
  bool musicOn;
  final List<String> log = [];
  Music? current;

  SilentAudio({bool sound = true, bool music = true})
    : soundOn = sound,
      musicOn = music;

  @override
  void setSound(bool on) => soundOn = on;
  @override
  void setMusic(bool on) => musicOn = on;
  @override
  void sfx(Sfx s, {double volume = 1}) {
    if (soundOn) log.add(s.name);
  }

  @override
  void pop(int cascade) {
    if (soundOn) log.add('pop$cascade');
  }

  @override
  void star(int i) {
    if (soundOn) log.add('star$i');
  }

  @override
  void music(Music? track) => current = track;
  @override
  Future<void> preload() async {}
  @override
  void dispose() {}
}

/// Plays sounds with audioplayers. Never throws: any audio failure just
/// turns the sound off for that call (or entirely, if the plugin is missing).
class PlayerAudio with WidgetsBindingObserver implements GameAudio {
  static const _prefix = 'assets/audio/';
  static const _voices = 10;

  @override
  bool soundOn;
  @override
  bool musicOn;

  final AudioCache _cache = AudioCache(prefix: _prefix);
  final List<AudioPlayer> _sfx = [];
  AudioPlayer? _musicPlayer;
  int _next = 0;
  bool _broken = false;
  bool _paused = false;
  Music? _wanted;
  Music? _playing;
  final Map<String, int> _lastPlayed = {};

  // Sound effects must not take audio focus (that would pause our music on
  // Android); music takes it so other apps' music stops.
  static final _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
  );
  static final _musicContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
  );

  PlayerAudio({bool sound = true, bool music = true})
    : soundOn = sound,
      musicOn = music {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  static const sfxFiles = [
    'pop0.wav',
    'pop1.wav',
    'pop2.wav',
    'pop3.wav',
    'pop4.wav',
    'pop5.wav',
    'pop6.wav',
    'pop7.wav',
    'star0.wav',
    'star1.wav',
    'star2.wav',
    'swap.wav',
    'invalid.wav',
    'blend.wav',
    'special.wav',
    'line.wav',
    'bomb.wav',
    'prism.wav',
    'whiteburst.wav',
    'combo.wav',
    'glass.wav',
    'stain.wav',
    'gravity.wav',
    'shuffle.wav',
    'win.wav',
    'lose.wav',
    'click.wav',
    'coin.wav',
    'booster.wav',
    'praise.wav',
    'start.wav',
  ];

  void _fail(Object e) {
    debugPrint('Audio disabled: $e');
    if (e is MissingPluginException) _broken = true;
  }

  Future<void> _guard(Future<void> Function() f) async {
    if (_broken) return;
    try {
      await f();
    } catch (e) {
      _fail(e);
    }
  }

  Future<AudioPlayer> _voice() async {
    if (_sfx.length < _voices) {
      final p = AudioPlayer(playerId: 'sfx${_sfx.length}');
      p.audioCache = _cache;
      _sfx.add(p);
      await p.setAudioContext(_sfxContext);
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      return p;
    }
    final p = _sfx[_next % _sfx.length];
    _next++;
    return p;
  }

  void _play(String file, double volume) {
    if (!soundOn || _broken || _paused) return;
    // Don't stack the same sound within 40 ms (big cascades).
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlayed[file] ?? 0) < 40) return;
    _lastPlayed[file] = now;
    unawaited(
      _guard(() async {
        final p = await _voice();
        await p.play(AssetSource(file), volume: volume.clamp(0.0, 1.0));
      }),
    );
  }

  @override
  Future<void> preload() => _guard(() async {
    await _cache.loadAll(sfxFiles);
    // Warm up the first voices so the first sounds play without delay.
    for (var i = 0; i < 3; i++) {
      await _voice();
    }
  });

  @override
  void sfx(Sfx s, {double volume = 1}) {
    const loud = {
      Sfx.click: 0.55,
      Sfx.swap: 0.6,
      Sfx.stain: 0.7,
      Sfx.glass: 0.8,
    };
    _play('${s.name}.wav', volume * (loud[s] ?? 0.9));
  }

  @override
  void pop(int cascade) => _play('pop${(cascade - 1).clamp(0, 7)}.wav', 0.8);

  @override
  void star(int i) => _play('star${i.clamp(0, 2)}.wav', 0.9);

  @override
  void setSound(bool on) => soundOn = on;

  @override
  void setMusic(bool on) {
    musicOn = on;
    _sync();
  }

  @override
  void music(Music? track) {
    _wanted = track;
    _sync();
  }

  void _sync() {
    final target = (musicOn && !_paused) ? _wanted : null;
    if (target == _playing) return;
    _playing = target;
    unawaited(
      _guard(() async {
        final player = _musicPlayer ??= AudioPlayer(playerId: 'music')
          ..audioCache = _cache;
        if (target == null) {
          await player.pause();
          return;
        }
        await player.setAudioContext(_musicContext);
        await player.setReleaseMode(ReleaseMode.loop);
        await player.stop();
        await player.play(
          AssetSource('music_${target.name}.wav'),
          volume: 0.42,
        );
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused = state != AppLifecycleState.resumed;
    if (paused == _paused) return;
    _paused = paused;
    if (paused) {
      _playing = null;
      unawaited(_guard(() async => _musicPlayer?.pause()));
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    for (final p in [..._sfx, ?_musicPlayer]) {
      unawaited(_guard(() => p.dispose()));
    }
  }
}
