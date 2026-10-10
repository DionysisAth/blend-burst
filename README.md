# Blend Burst

A match-3 puzzle game for Android and iOS with two twists: **color blending**
(red + blue = purple, and so on) and **gravity shifts**. Built with Flutter
from one codebase.

**Download the latest Android build:**
https://github.com/DionysisAth/blend-burst/releases/latest/download/blend-burst.apk

Every push to `main` is built and tested by GitHub Actions. An APK is
published only after it passes all the tests below, including running on
Android emulators.

## What's in this MVP

- 8×8 boards (any size up to 12×12, with holes for custom shapes)
- Swap, match, cascades, automatic shuffle when no moves are left
- Blending: two different primaries make a secondary, and a secondary plus
  its missing primary makes a **White Burst**
- Specials: Line Blaster (4 in a line), Paint Bomb (L/T shape), Prism
  (5 in a line), White Burst, plus combos when two specials are swapped together
- Secondary-color matches splash onto the neighboring tiles
- Gravity: fixed down/up/left/right levels and gravity switch tiles
- 40 levels in 3 episodes (Art Studio, Rainbow Garden, Paint Factory)
- Goals: score, clear stains, break glass, collect colors
- Obstacles: paint stains, glass blocks (1–3 layers)
- Lives (5 max, one refills every 30 min), stars, coins, level map
- Boosters: Brush, Free Swap, Color Splash
- +5 moves on fail (coins or a rewarded "ad"; the ad is a placeholder, since
  there is no ads SDK yet)
- In-app level editor (Settings → Level editor): paint a board, play-test it,
  run the bot on it, and copy/paste the level JSON
- Local save and a local analytics log (Settings → Analytics)
- Colorblind-friendly: each color has its own shape
- Music (map and level loops) and sound effects, with Music / Sound / Vibrate
  toggles in Settings and the pause menu. All audio is synthesized by
  `tool/audio/synth.py` (`python3 tool/audio/synth.py assets/audio`)
- Hand-drawn vector art (tiles, specials, boosters, icons), candy-style UI,
  illustrated tutorial cards for each new mechanic, praise callouts on big
  cascades
- Fonts: Fredoka and Lilita One (SIL Open Font License, in `assets/fonts/`)

## Project layout

```
lib/core/      pure-Dart game engine (no Flutter): board, rules, levels, bot
lib/game/      animation controller and the board widget (rendering, input)
lib/screens/   map, game, settings, editor, dialogs
lib/app/       save data, lives/economy, level loading, audio, ad placeholder
lib/ui/        tile art, icons, logo, buttons/panels/dialog widgets
assets/audio/  music and sound effects (WAV)
assets/levels/ level packs (JSON), one file per episode
tool/          level_bot.dart: plays levels to measure difficulty;
               audio/synth.py: generates every sound and music track
test/          engine, level and widget tests
integration_test/  on-device test (runs on the emulators in CI)
ci/            release-APK smoke test (install, launch, monkey, restart)
```

## Level format

```json
{
  "id": 7, "name": "First Stains", "moves": 16,
  "colors": ["red", "blue", "yellow", "brown", "gray"],
  "layout": ["........", "..ssss..", "..1221..", "#......#", "..."],
  "tiles":  ["........", "...g....", "..."],
  "gravity": "down", "blending": true,
  "goals": [{"type": "stains"}, {"type": "collect", "color": "purple", "target": 6}],
  "stars": [5000, 20000, 30000],
  "switchChance": 0.03, "hard": false,
  "tutorial": "Optional text shown the first time"
}
```

`layout`: `.` cell, `#` hole, `s` stain, `1`–`3` glass layers.
`tiles` (optional): `R B Y P G O N K` fixed colors, `g` gravity switch tile.
Goal types: `score`, `stains`, `glass`, `collect` (stains/glass default to "all").

## Development

```
flutter pub get
flutter test                                   # engine + level + widget tests
dart run tool/level_bot.dart                   # win rates for every level
dart run tool/level_bot.dart --tune            # re-tune move limits
dart run tool/level_bot.dart --calibrate       # re-tune star thresholds
flutter run                                    # on a device or emulator
```

Release APKs are signed with a development key that is committed to the
repo (`android/app/dev-release.keystore`), so each new build installs over
the previous one. Before publishing to Google Play, switch to a private upload key.
