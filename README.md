# Blend Burst

A match-3 puzzle game for Android and iOS with two twists: **color blending**
(red + blue = purple, and so on) and **gravity shifts**. Built with Flutter
from one codebase.

**Download the latest Android build:**
https://github.com/DionysisAth/blend-burst/releases/latest/download/blend-burst.apk

Every push to `main` is built and tested by GitHub Actions. An APK is
published only after it passes all the tests below, including running on
Android emulators.

## What's in the game

**Core**
- 8×8 boards (any size up to 12×12, with holes for custom shapes)
- Swap, match, cascades, automatic shuffle when no moves are left
- Blending: two different primaries make a secondary, and a secondary plus
  its missing primary makes a **White Burst**
- Specials: Line Blaster (4 in a line or a 2×2 square), Paint Bomb (L/T
  shape), Prism (5 in a line), White Burst, plus combos when two specials are
  swapped together. Swiping a special always moves it and fires it where it
  lands
- Secondary-color matches splash onto the neighboring tiles
- Gravity: fixed down/up/left/right levels, gravity switch tiles, gravity
  zones (cells that pull in their own direction) and timed gravity that turns
  every few moves

**Content**
- 120 levels in 8 episodes of 15: Art Studio, Rainbow Garden, Paint Factory,
  Sky Gallery, Ink Lagoon, Prism Peaks, Bucket Brigade, Gravity Galaxy. Each
  episode has its own painted theme and music track
- Goals: score, clear stains, break glass, collect colors, break chains,
  clear ink, deliver paint buckets
- Obstacles: paint stains, glass (1–3 layers), chains (1–2 links), spreading
  ink, color filters, paint buckets that must reach the exit
- Illustrated tutorial cards for every new mechanic, shown each time the
  level starts
- Move limits and star thresholds tuned by a bot that plays every level

**Boosters**
- In level: Brush, Free Swap, Color Splash, Gravity Flip
- Before a level: Line Blaster, Paint Bomb, Prism start on the board
- Win streaks (3, 5, 7 wins) give free starting boosters

**Economy and live ops**
- Lives (5 max, one refills every 30 min) and unlimited-lives timers
- Coins (earned) and gold (bought or won); +5 moves on fail for coins, gold
  (price rises each time) or a rewarded ad (+3, once per level)
- Shop: starter pack, gold packs, lives, unlimited lives, booster bundles,
  remove ads, premium pass
- 7-day daily gift calendar (doubled with an ad)
- Weekly event "Paint Collector": collect tiles of the week's color for 5
  reward tiers
- 28-day season pass with a free and a premium track (20 tiers)
- Ad breaks every 3rd win, never for players who bought anything

**Retention and tech**
- Cloud save and leaderboards (total stars, levels completed, total score)
  through Google Play Games, switched off until it is set up (see below)
- Opt-in reminders (Settings → Reminders): lives full, daily gift, event ending
- Share a screenshot after a "Spectacular!" combo or a win
- Remote config (`remote_config.json` in this repo): move limits per level,
  event color, ad cadence and extra-moves prices, applied on the next launch
- Analytics screen with the key metrics: day 1/7/30 retention, levels per
  session, sessions per day, win rate, attempts per level, extra-moves rate,
  ads per day, hardest levels
- In-app level editor (Settings → Level editor): paint a board, play-test it,
  run the bot on it, and copy/paste the level JSON
- Music and sound effects synthesized by `tool/audio/synth.py`
  (`python3 tool/audio/synth.py assets/audio`), stored as OGG Vorbis
- Hand-drawn vector art, colorblind-friendly tile shapes
- Fonts: Fredoka and Lilita One (SIL Open Font License, in `assets/fonts/`)

## What still needs accounts or a backend

These parts are built as replaceable interfaces with local stand-ins, so the
game is fully playable now:

- **Real purchases**: `lib/app/store.dart` (`Store`). The test build's
  `TestStore` completes purchases for free. Needs Google Play / App Store
  developer accounts, products set up in the consoles, the `in_app_purchase`
  plugin and server-side receipt checks.
- **Real ads**: `lib/app/ad_service.dart` (`AdService`). Needs an ads account
  (e.g. AdMob) and its SDK; the placeholder shows a fake ad screen.
- **Google Play Games** (cloud save and leaderboards, `lib/app/cloud.dart`):
  built and tested, but switched off until the game is set up in the Play
  Console. See "Setting up Google Play Games" below.
- **Teams, friends, leaderboard races, friend life gifts**: need a backend
  with player accounts (e.g. Firebase or PlayFab).
- **Shared analytics**: the metrics are computed on each device; a backend
  (e.g. Firebase Analytics) is needed to see them across all players.
- **Remote push** (e.g. "a friend sent you a life"): needs a push service.
  Local reminders already work without one.

## Setting up Google Play Games

Until these steps are done the game never calls Play Games: Settings says
cloud save is coming later and the Ranks button explains the same.

1. In the Play Console, open the app → **Play Games Services → Setup and
   management → Configuration**, create the game project and link the
   Android app (package `com.dionysisath.blend_burst`) with the SHA-1 of the
   signing key. For sideloaded test builds that is the key in
   `android/app/dev-release.keystore`
   (`keytool -list -v -keystore android/app/dev-release.keystore -storepass blendburst`).
2. Turn on **Saved games** in the game project's properties.
3. Create three leaderboards: Total stars, Levels completed, Total score
   (all "higher is better").
4. Put the project ID (the number on the Configuration page) in
   `android/app/src/main/res/values/games.xml` and the three leaderboard IDs
   in `GamesConfig` at the top of `lib/app/cloud.dart`.
5. While the game is unpublished, add your Google account as a tester under
   **Testers**.

How syncing works: on launch (and when signing in from Settings), the cloud
copy is merged with the progress on the phone. Levels, stars, best scores,
tutorials and purchases are the best of both. Coins, lives and boosters come
from whichever copy changed last. The merged copy is uploaded again 45
seconds after a change and whenever the app goes to the background. If the
cloud copy cannot be read, nothing is uploaded, so a phone with a bad
connection can never overwrite progress made on another one.

For iOS, set the Game Center leaderboard IDs in `GamesConfig` and set
`iosEnabled` to true once Game Center and iCloud are on for the app.

## Project layout

```
lib/core/      pure-Dart game engine (no Flutter): board, rules, levels, bot
lib/game/      animation controller and the board widget (rendering, input)
lib/screens/   map, game, settings, editor, dialogs
lib/app/       save data, economy and live ops, level loading, audio, ads and
               store placeholders, reminders, remote config, metrics, share
lib/ui/        tile art, icons, logo, buttons/panels/dialog widgets
assets/audio/  music and sound effects (OGG)
assets/levels/ level packs (JSON), one file per episode
tool/          level_bot.dart: plays levels to measure difficulty;
               levels/make_levels.py: designs levels 41-120;
               audio/synth.py: generates every sound and music track;
               icon/icon_test.dart: draws the app icon (all sizes)
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

`layout`: `.` cell, `#` hole, `s` stain, `1`–`3` glass layers, `k` chain,
`K` double chain, `i` ink.
`tiles` (optional): `R B Y P G O N K` fixed colors, `g` gravity switch tile,
`D` paint bucket.
Optional grids: `filters` (color codes: a tile landing there takes that
color) and `zones` (`v ^ < >`: gravity direction for that cell).
Optional fields: `buckets` (total to deliver), `bucketsOnBoard`,
`gravityEvery` (timed gravity).
Goal types: `score`, `stains`, `glass`, `collect`, `locks`, `ink`, `drop`
(all but score and collect default to "all").

## Development

```
flutter pub get
flutter test                                   # engine + level + widget tests
dart run tool/level_bot.dart                   # win rates for every level
dart run tool/level_bot.dart --tune            # re-tune move limits
dart run tool/level_bot.dart --tune --level 50,54   # only some levels
python3 tool/levels/make_levels.py             # regenerate levels 41-120
                                               # (keeps tuning of unchanged ones)
dart run tool/level_bot.dart --calibrate       # re-tune star thresholds
flutter test tool/icon/icon_test.dart          # redraw the app icons
flutter run                                    # on a device or emulator
```

Release APKs are signed with a development key that is committed to the
repo (`android/app/dev-release.keystore`), so each new build installs over
the previous one. Before publishing to Google Play, switch to a private upload key.
