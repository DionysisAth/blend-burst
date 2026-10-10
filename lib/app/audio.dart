import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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
  chain,
  ink,
  drop,
}

/// Background tracks: the map, and one per episode.
enum Music {
  map,
  studio,
  garden,
  factory,
  sky,
  lagoon,
  peaks,
  brigade,
  galaxy;

  /// The level music of episode [index] (0-based).
  static Music forEpisode(int index) =>
      Music.values[1 + index.clamp(0, Music.values.length - 2)];

  String get file => 'music_$name.ogg';
}

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

/// Plays sounds with SoLoud, a game audio engine: every sound is decoded
/// once into memory and mixed natively, so effects start instantly and no
/// system media decoder is involved while playing. Never throws: any audio
/// failure just turns sound off.
class PlayerAudio with WidgetsBindingObserver implements GameAudio {
  static const _prefix = 'assets/audio/';
  static const _musicVolume = 0.42;
  static const _fade = Duration(milliseconds: 600);

  @override
  bool soundOn;
  @override
  bool musicOn;

  final SoLoud _engine = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};
  Future<void>? _ready;
  bool _broken = false;
  bool _paused = false;
  Music? _wanted;
  Music? _playing;
  SoundHandle? _musicHandle;
  final Map<String, int> _lastPlayed = {};

  PlayerAudio({bool sound = true, bool music = true})
    : soundOn = sound,
      musicOn = music {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  static const sfxFiles = [
    'pop0.ogg',
    'pop1.ogg',
    'pop2.ogg',
    'pop3.ogg',
    'pop4.ogg',
    'pop5.ogg',
    'pop6.ogg',
    'pop7.ogg',
    'star0.ogg',
    'star1.ogg',
    'star2.ogg',
    'swap.ogg',
    'invalid.ogg',
    'blend.ogg',
    'special.ogg',
    'line.ogg',
    'bomb.ogg',
    'prism.ogg',
    'whiteburst.ogg',
    'combo.ogg',
    'glass.ogg',
    'stain.ogg',
    'gravity.ogg',
    'shuffle.ogg',
    'win.ogg',
    'lose.ogg',
    'click.ogg',
    'coin.ogg',
    'booster.ogg',
    'praise.ogg',
    'start.ogg',
    'chain.ogg',
    'ink.ogg',
    'drop.ogg',
  ];

  void _fail(Object e) {
    debugPrint('Audio disabled: $e');
    _broken = true;
  }

  bool get _live => !_broken && _engine.isInitialized;

  @override
  Future<void> preload() => _ready ??= _start();

  Future<void> _start() async {
    try {
      await _engine.init();
      _engine.setMaxActiveVoiceCount(24);
    } catch (e) {
      _fail(e);
      return;
    }
    // The map track first, so it starts as soon as possible. Other tracks
    // load when they are first needed.
    await _loadMusic(Music.map);
    final wanted = _wanted;
    if (wanted != null) await _loadMusic(wanted);
    for (final file in sfxFiles) {
      try {
        _sources[file] = await _engine.loadAsset('$_prefix$file');
      } catch (e) {
        debugPrint('Could not load $file: $e');
      }
    }
  }

  final Set<Music> _loading = {};

  /// Music is decoded into memory (loops are sample-exact); only the map
  /// track and the current level track stay loaded.
  Future<void> _loadMusic(Music m) async {
    if (_sources.containsKey(m.file) || !_loading.add(m)) return;
    try {
      _sources[m.file] = await _engine.loadAsset('$_prefix${m.file}');
    } catch (e) {
      debugPrint('Could not load ${m.file}: $e');
    }
    _loading.remove(m);
    _sync();
  }

  void _play(String file, double volume) {
    if (!soundOn || !_live || _paused) return;
    final source = _sources[file];
    if (source == null) return;
    // Don't stack the same sound within 40 ms (big cascades).
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlayed[file] ?? 0) < 40) return;
    _lastPlayed[file] = now;
    try {
      _engine.play(source, volume: volume.clamp(0.0, 1.0));
    } catch (e) {
      _fail(e);
    }
  }

  @override
  void sfx(Sfx s, {double volume = 1}) {
    const loud = {
      Sfx.click: 0.55,
      Sfx.swap: 0.6,
      Sfx.stain: 0.7,
      Sfx.glass: 0.8,
    };
    _play('${s.name}.ogg', volume * (loud[s] ?? 0.9));
  }

  @override
  void pop(int cascade) => _play('pop${(cascade - 1).clamp(0, 7)}.ogg', 0.8);

  @override
  void star(int i) => _play('star${i.clamp(0, 2)}.ogg', 0.9);

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

  /// Cross-fades to the wanted track (or to silence).
  void _sync() {
    if (!_live) return;
    final target = (musicOn && !_paused) ? _wanted : null;
    if (target == _playing) return;
    final source = target == null ? null : _sources[target.file];
    if (target != null && source == null) {
      // Not loaded yet: start loading; _loadMusic syncs again when done.
      unawaited(_loadMusic(target));
      return;
    }
    try {
      final old = _musicHandle;
      if (old != null) {
        _engine.fadeVolume(old, 0, _fade);
        _engine.scheduleStop(old, _fade);
      }
      _musicHandle = null;
      _playing = target;
      if (source != null) {
        final h = _engine.play(source, volume: 0, looping: true);
        _engine.fadeVolume(h, _musicVolume, _fade);
        _musicHandle = h;
      }
      _freeMusicLater(keep: {Music.map, ?target});
    } catch (e) {
      _fail(e);
    }
  }

  /// Frees level tracks other than [keep] once the cross-fade is over.
  void _freeMusicLater({required Set<Music> keep}) {
    Future<void>.delayed(_fade * 2, () {
      for (final m in Music.values) {
        if (keep.contains(m) || m == _playing) continue;
        final src = _sources.remove(m.file);
        if (src == null) continue;
        try {
          unawaited(_engine.disposeSource(src));
        } catch (_) {}
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused = state != AppLifecycleState.resumed;
    if (paused == _paused) return;
    _paused = paused;
    if (!_live) return;
    final h = _musicHandle;
    if (h == null) {
      if (!paused) _sync();
      return;
    }
    try {
      // Pause in place, so the track resumes where it was.
      _engine.setPause(h, paused);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    try {
      if (_engine.isInitialized) _engine.deinit();
    } catch (_) {}
  }
}
