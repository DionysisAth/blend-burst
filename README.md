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
- Cloud save, leaderboards (total stars, levels completed, total score) and
  12 achievements through Google Play Games, switched off until it is set up
  (see below)
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

- **Purchases**: Google Play billing is in (`lib/app/play_store.dart`), with
  the products created by `tool/play/products.py`. Purchases are checked on
  the device only; a server could verify them later. iOS still uses the
  free `TestStore`.
- **Google Play Games** (cloud save and leaderboards, `lib/app/cloud.dart`):
  built and tested, but switched off until the game is set up in the Play
  Console. See "Setting up Google Play Games" below.
- **Teams, friends, leaderboard races, friend life gifts**: need a backend
  with player accounts (e.g. Firebase or PlayFab).
- **Shared analytics**: the metrics are computed on each device; a backend
  (e.g. Firebase Analytics) is needed to see them across all players.
- **Remote push** (e.g. "a friend sent you a life"): needs a push service.
  Local reminders already work without one.

## Ads (AdMob)

`lib/app/admob.dart` shows AdMob rewarded videos (extra moves, a life, the
doubled daily gift, the shop's free booster) and interstitials (every 3rd
win, never for players who bought anything). Google's consent form is shown
first where the law requires it, and Settings then offers "Privacy choices".

Builds show Google's **test ads** unless built with `REAL_ADS`, so testing
never touches the live ad units (tapping your own live ads can get the
AdMob account suspended). For the Play Store build:

```
flutter build appbundle --dart-define=REAL_ADS=true
```

The AdMob app ID is in `android/app/src/main/AndroidManifest.xml` and the ad
unit IDs in `AdUnits` (`lib/app/admob.dart`). iOS ads are off until an iOS
app exists in AdMob: then put its app ID in `ios/Runner/Info.plist`
(`GADApplicationIdentifier`, currently Google's sample ID) and its units in
`AdUnits`.

## Publishing to Google Play

The app is `com.nwbn.blendburst`. Releases go through the **Google Play
release** workflow (Actions → Google Play release → Run workflow: pick the
track, `completed` or `draft`, and the release notes). It builds the bundle
with real ads, signs it with the upload key and uploads it.

It needs three repository secrets (Settings → Secrets and variables →
Actions):

| Secret | What |
|---|---|
| `PLAY_UPLOAD_KEYSTORE_BASE64` | the upload keystore, base64 (`base64 -w0 upload.jks`) |
| `PLAY_UPLOAD_PASSWORD` | its password (the store and the key use the same one) |
| `PLAY_SERVICE_ACCOUNT_JSON` | the Play Console service account key (the whole JSON) |

Keep the upload keystore and the service account key out of git. Without
the secrets the workflow attaches an unsigned bundle to a GitHub release
instead.

The store listing (texts in `store/listing`, icon, feature graphic and
screenshots in `store/`) is uploaded by `python3 tool/play/listing.py`, and
the in-app products by `python3 tool/play/products.py` (both read the key
from `PLAY_SERVICE_ACCOUNT_FILE` or `PLAY_SERVICE_ACCOUNT_JSON`).
Regenerate the screenshots with `flutter test tool/store/shots_test.dart
--update-goldens` and `python3 tool/store/compose.py`.

## Setting up Google Play Games

Until these steps are done the game never calls Play Games: Settings says
cloud save is coming later and the Ranks button explains the same.

1. In the Play Console, open the app → **Play Games Services → Setup and
   management → Configuration**, create the game project and link the
   Android app (package `com.nwbn.blendburst`). Add one Android credential
   per signing key: the **app signing key** SHA-1 (Play Console → Test and
   release → App integrity), the upload key SHA-1, and, for the CI test
   APKs, the dev key in `android/app/dev-release.keystore`
   (`keytool -list -v -keystore android/app/dev-release.keystore -storepass blendburst`).
2. Turn on **Saved games** in the game project's properties.
3. Run `python3 tool/play/games_setup.py --project <project ID>` (the number
   on the Configuration page). It creates the three leaderboards (Total
   Stars, Levels Completed, Total Score) and the 12 achievements from
   `lib/app/achievements.dart`, and writes their IDs into
   `lib/app/games_ids.dart` and `res/values/games.xml`. Icons for all of them
   are in `store/games/` (drawn by `flutter test tool/icon/games_icons_test.dart`)
   to upload in the Play Console.
4. In the Play Console, publish the Play Games changes (Play Games Services
   → Review and publish). While the game is unpublished, add testers there.

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

Test APKs from CI are signed with a development key that is committed to
the repo (`android/app/dev-release.keystore`), so each new build installs
over the previous one. Google Play builds are signed with the private
upload key instead (see "Publishing to Google Play").
