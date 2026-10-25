#!/usr/bin/env bash
# Runs the on-device integration test. If it fails because the emulator
# itself went away (not the app), leaves an EMULATOR_DIED marker so CI can
# retry on a fresh emulator.
set -uo pipefail
OUT="${1:-smoke-results}"
mkdir -p "$OUT"
timeout 60 adb logcat -c < /dev/null || true
(adb logcat -v time > "$OUT/integration-logcat.txt" 2>&1 < /dev/null &)
timeout 900 flutter test integration_test/app_test.dart -d emulator-5554 --reporter expanded -v < /dev/null > "$OUT/flutter-test-verbose.txt" 2>&1
status=$?
# The test's own output (the verbose log is kept in the artifact).
grep -E "^[0-9]{2}:[0-9]{2} \+|^\s*(Expected|Actual|Which|══)|EXCEPTION|No tests ran|Some tests failed|All tests passed" "$OUT/flutter-test-verbose.txt" | tail -60
if [ $status -ne 0 ]; then
  echo "--- flutter tool, last lines ---"
  tail -80 "$OUT/flutter-test-verbose.txt"
  echo "--- app process ---"
  timeout 20 adb shell "ps -A | grep -i blendburst; dumpsys activity processes | grep -i -A4 'nwbn.blendburst' | head -40" < /dev/null || true
  echo "--- app log lines (flutter, Firebase, crashes, ANRs) ---"
  grep -E "flutter|FirebaseApp|FirebaseCrashlytics|FirebaseInitProvider|AndroidRuntime|FATAL|ANR in|Freezer|frozen" "$OUT/integration-logcat.txt" | grep -v "Impeller" | tail -60
fi
if [ $status -ne 0 ]; then
  if [ "$(timeout 10 adb get-state 2>/dev/null < /dev/null)" != "device" ]; then
    echo "!! The emulator itself is gone (not an app crash)."
    touch "$OUT/EMULATOR_DIED"
  else
    timeout 30 adb logcat -d -b crash < /dev/null | tail -100 || true
  fi
fi
exit $status
