#!/usr/bin/env bash
# Installs the release APK on a running emulator and checks that it starts,
# survives a few thousand random taps and swipes (monkey), and never crashes.
# Usage: ci/android_smoke_test.sh path/to/app.apk out_dir
set -uo pipefail

APK="$1"
OUT="${2:-smoke}"
PKG="com.dionysisath.blend_burst"
mkdir -p "$OUT"

fail() {
  echo "SMOKE TEST FAILED: $*"
  adb logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
  adb exec-out screencap -p > "$OUT/failure.png" 2>/dev/null || true
  adb logcat -d -b crash | tail -150 || true
  grep -n -A30 "ANR in $PKG" "$OUT/logcat.txt" | head -60 || true
  exit 1
}

check_alive() {
  if ! adb shell pidof "$PKG" > /dev/null; then
    fail "$PKG is not running ($1)"
  fi
  # Only crashes of this app count; emulators often log unrelated ones.
  if adb logcat -d -b crash | grep -q "$PKG" || adb logcat -d | grep -q "ANR in $PKG"; then
    fail "crash found in logcat ($1)"
  fi
}

adb wait-for-device
adb shell input keyevent 82 || true   # dismiss any lock screen
adb logcat -c || true
adb install -r "$APK" || fail "install failed"

echo "== Launching"
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null || fail "launch failed"
sleep 25
check_alive "after launch"
adb exec-out screencap -p > "$OUT/01-launch.png"
adb logcat -d | grep -i "flutter" | tail -40 || true

echo "== Monkey: random taps and swipes"
# Touch/motion only, so the monkey stays inside the game.
if ! adb shell monkey -p "$PKG" --pct-touch 55 --pct-motion 45 \
    --pct-nav 0 --pct-majornav 0 --pct-syskeys 0 --pct-appswitch 0 \
    --pct-anyevent 0 --throttle 60 -s 4242 -v 3000 > "$OUT/monkey.txt" 2>&1; then
  tail -40 "$OUT/monkey.txt"
  fail "monkey reported a crash or ANR"
fi
tail -5 "$OUT/monkey.txt"
sleep 5
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null || true
sleep 5
check_alive "after monkey"
adb exec-out screencap -p > "$OUT/02-after-monkey.png"

echo "== Cold restart (saved progress is read back)"
adb shell am force-stop "$PKG"
sleep 2
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null || fail "relaunch failed"
sleep 20
check_alive "after restart"
adb exec-out screencap -p > "$OUT/03-restart.png"

adb logcat -d > "$OUT/logcat.txt"
# Leave the device clean for the integration test (it installs a debug build).
adb uninstall "$PKG" > /dev/null || true
echo "SMOKE TEST PASSED"
