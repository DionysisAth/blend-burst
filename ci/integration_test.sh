#!/usr/bin/env bash
# Runs the on-device integration test. If it fails because the emulator
# itself went away (not the app), leaves an EMULATOR_DIED marker so CI can
# retry on a fresh emulator.
set -uo pipefail
OUT="${1:-smoke-results}"
mkdir -p "$OUT"
timeout 60 adb logcat -c < /dev/null || true
(adb logcat -v time > "$OUT/integration-logcat.txt" 2>&1 < /dev/null &)
timeout 900 flutter test integration_test/app_test.dart -d emulator-5554 --reporter expanded < /dev/null
status=$?
if [ $status -ne 0 ]; then
  if [ "$(timeout 10 adb get-state 2>/dev/null < /dev/null)" != "device" ]; then
    echo "!! The emulator itself is gone (not an app crash)."
    touch "$OUT/EMULATOR_DIED"
  else
    timeout 30 adb logcat -d -b crash < /dev/null | tail -100 || true
  fi
fi
exit $status
