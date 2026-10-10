#!/usr/bin/env bash
# Installs the release APK on a running emulator and checks that it starts,
# plays level 1 with real swipes, survives a few thousand random taps and
# swipes (monkey), restarts cleanly, and never crashes.
# Usage: ci/android_smoke_test.sh path/to/app.apk out_dir
set -uo pipefail

APK="$1"
OUT="${2:-smoke}"
PKG="com.dionysisath.blend_burst"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

# adb with a timeout and no stdin (adb shell otherwise eats loop input, and
# hangs forever if the emulator dies).
A() { timeout "${T:-60}" adb "$@" < /dev/null; }

device_ok() { [ "$(T=10 A get-state 2>/dev/null)" = "device" ]; }

print_log() {
  echo "--- device log (app, Flutter, graphics, crashes) ---"
  grep -a -E "$PKG|flutter|Impeller|impeller|FATAL|F libc|F DEBUG|AndroidRuntime|gralloc|EGL|vulkan|Vulkan|lowmemorykiller|lmkd|am_kill|Process .* died|ActivityManager: Kill" \
    "$OUT/live-logcat.txt" 2>/dev/null | tail -150 || true
  echo "--- last 60 device log lines ---"
  tail -60 "$OUT/live-logcat.txt" 2>/dev/null || true
}

fail() {
  echo "SMOKE TEST FAILED: $*"
  print_log
  if ! device_ok; then
    echo "!! The emulator itself is gone (not an app crash)."
    touch "$OUT/EMULATOR_DIED"
    exit 1
  fi
  T=30 A logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
  T=20 A exec-out screencap -p > "$OUT/failure.png" 2>/dev/null || true
  T=20 A logcat -d -b crash | tail -150 || true
  grep -n -A30 "ANR in $PKG" "$OUT/logcat.txt" | head -60 || true
  exit 1
}

check_alive() {
  device_ok || fail "emulator stopped responding ($1)"
  if ! T=15 A shell pidof "$PKG" > /dev/null; then
    sleep 5
    device_ok || fail "emulator stopped responding ($1)"
    fail "$PKG is not running ($1)"
  fi
  # Only crashes of this app count; emulators often log unrelated ones.
  if T=30 A logcat -d -b crash | grep -q "$PKG" ||
     T=30 A logcat -d | grep -q "ANR in $PKG"; then
    fail "crash found in logcat ($1)"
  fi
}

shot() { T=20 A exec-out screencap -p > "$OUT/$1.png" || true; }

launch() {
  T=20 A shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null ||
    fail "launch failed"
}

# Finds a node by its accessibility label; prints "left top right bottom".
find_node() {
  for _ in 1 2 3 4 5 6 7 8; do
    T=30 A shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || true
    T=20 A pull /sdcard/ui.xml "$OUT/ui.xml" > /dev/null 2>&1 || true
    if python3 "$HERE/ui_find.py" "$OUT/ui.xml" "$1"; then return 0; fi
    sleep 2
  done
  return 1
}

tap_node() {
  local b l t r bt
  b=$(find_node "$1") || fail "could not find '$1' on screen"
  read -r l t r bt <<< "$b"
  A shell input tap $(( (l + r) / 2 )) $(( (t + bt) / 2 ))
  sleep 2
}

T=120 A wait-for-device
A shell input keyevent 82 || true   # dismiss any lock screen
A logcat -c || true
# Stream the device log to a file from the start, so it survives even when
# the app or the emulator dies before we can dump it.
adb logcat -v threadtime > "$OUT/live-logcat.txt" 2>&1 < /dev/null &
T=180 A install -r "$APK" || fail "install failed"

echo "== Launching"
launch
sleep 25
check_alive "after launch"
shot 01-launch
T=30 A logcat -d | grep -i " flutter" | tail -20 || true

echo "== Playing level 1 with real swipes"
tap_node "Level 1"
tap_node "Play"
shot 02-level-start
if find_node "Got it!" > /dev/null; then tap_node "Got it!"; fi
board=$(find_node "Game board") || fail "game board not found"
read -r BL BT BR BB <<< "$board"
python3 - "$BL" "$BT" "$BR" "$BB" > "$OUT/swipes.txt" <<'PY'
import random, sys
l, t, r, b = map(int, sys.argv[1:])
w, h, n = r - l, b - t, 8
cell = min(w / (n + 1), h / (n + 1))
ox, oy = l + (w - cell * n) / 2, t + (h - cell * n) / 2
rnd = random.Random(7)
for _ in range(40):
    row, col = rnd.randrange(n), rnd.randrange(n - 1)
    x, y = ox + (col + 0.5) * cell, oy + (row + 0.5) * cell
    if rnd.random() < 0.5:
        print(int(x), int(y), int(x + cell), int(y))
    elif row < n - 1:
        print(int(x), int(y), int(x), int(y + cell))
    else:
        print(int(x), int(y), int(x), int(y - cell))
PY
i=0
while read -r x1 y1 x2 y2; do
  A shell input swipe "$x1" "$y1" "$x2" "$y2" 150
  sleep 0.8
  i=$((i + 1))
  if [ $((i % 10)) -eq 0 ]; then
    check_alive "after $i swipes"
    shot "03-play-$i"
  fi
done < "$OUT/swipes.txt"
echo "made $i swipes"
[ "$i" -ge 40 ] || fail "only $i swipes were made"
sleep 5
check_alive "after playing"

echo "== Monkey: random taps and swipes"
# Touch/motion only, so the monkey stays inside the game.
T=600 A shell monkey -p "$PKG" --pct-touch 55 --pct-motion 45 \
    --pct-nav 0 --pct-majornav 0 --pct-syskeys 0 --pct-appswitch 0 \
    --pct-anyevent 0 --throttle 60 -s 4242 -v 3000 > "$OUT/monkey.txt" 2>&1
status=$?
tail -5 "$OUT/monkey.txt"
# The monkey also stops when *other* apps (e.g. Google Search) crash on the
# emulator; only crashes or ANRs of this app count as failures.
if grep -q -E "// (CRASH|NOT RESPONDING): $PKG" "$OUT/monkey.txt"; then
  grep -n -A30 -E "// (CRASH|NOT RESPONDING): $PKG" "$OUT/monkey.txt" | head -80
  fail "monkey: $PKG crashed or stopped responding"
fi
if [ $status -ne 0 ] || ! grep -q "Monkey finished" "$OUT/monkey.txt"; then
  grep -n -E "// (CRASH|NOT RESPONDING)" "$OUT/monkey.txt" | head -5 || true
  device_ok || fail "emulator died during the monkey run"
  echo "Monkey stopped early (exit $status) because of another app; continuing."
fi
sleep 5
launch
sleep 5
check_alive "after monkey"
shot 04-after-monkey

echo "== Cold restart (saved progress is read back)"
A shell am force-stop "$PKG"
sleep 2
launch
sleep 20
check_alive "after restart"
shot 05-restart

T=30 A logcat -d > "$OUT/logcat.txt" || true
# Leave the device clean for the integration test (it installs a debug build).
A uninstall "$PKG" > /dev/null || true
echo "SMOKE TEST PASSED"
