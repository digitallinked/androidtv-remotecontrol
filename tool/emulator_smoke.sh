#!/usr/bin/env bash
# Runs on an attached emulator (the Device builds workflow): the integration
# flows, then a prod release build from a clean install. No TV is involved: the
# flows use the fake TV inside the app, and the prod build goes as far as the
# demo. Screens and logs land in build/emulator-smoke/.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/emulator-smoke"
mkdir -p "$out"
cd "$root/app" || exit 1

package=my.newy.remotely
failed=0

fail() {
  echo "FAILED: $1"
  failed=1
}

screen() {
  adb shell screencap -p /sdcard/smoke.png
  adb pull /sdcard/smoke.png "$out/$1.png" >/dev/null
}

labels() {
  adb shell uiautomator dump /sdcard/smoke.xml >/dev/null
  adb shell cat /sdcard/smoke.xml >"$out/$1.xml"
  grep -o 'content-desc="[^"]*"\|text="[^"]*"' "$out/$1.xml" |
    grep -v '=""' | cut -d'"' -f2
}

# Taps the control with $1 as a whole line of its accessibility label. Below
# Android 9 a button's label also holds its tooltip, on a line of its own.
tap() {
  adb shell uiautomator dump /sdcard/smoke.xml >/dev/null
  adb shell cat /sdcard/smoke.xml >"$out/tap.xml"
  local bounds
  bounds=$(python3 - "$1" "$out/tap.xml" <<'PY'
import re, sys
import xml.etree.ElementTree as ET
for node in ET.parse(sys.argv[2]).getroot().iter('node'):
    label = node.get('content-desc') or node.get('text') or ''
    if sys.argv[1] in label.split('\n'):
        a, b, c, d = map(int, re.findall(r'\d+', node.get('bounds')))
        print((a + c) // 2, (b + d) // 2)
        break
PY
  )
  if [ -z "$bounds" ]; then
    fail "no control labelled $1"
    return 1
  fi
  # shellcheck disable=SC2086
  adb shell input tap $bounds
}

alive() {
  [ -n "$(adb shell pidof "$package" | tr -d '\r')" ]
}

for flow in demo_mode_flow discover_pair_press_key_flow; do
  echo "=== $flow"
  flutter test "integration_test/${flow}_test.dart" -d emulator-5554 --flavor dev ||
    fail "$flow"
done

echo "=== prod release build"
flutter build apk --release --flavor prod -t lib/main_prod.dart || {
  echo "FAILED: the prod release build"
  exit 1
}
adb install -r build/app/outputs/flutter-apk/app-prod-release.apk || {
  echo "FAILED: installing the prod release build"
  exit 1
}

echo "=== cold start on a clean install"
adb logcat -c
adb shell am start -W -n "$package/$package.MainActivity"
sleep 15
alive || fail "the app isn't running after a cold start"
labels onboarding
screen onboarding
labels onboarding | grep -q '^Try demo$' || fail "no onboarding on a clean install"

echo "=== the demo"
tap 'Try demo'
sleep 6
screen demo
labels demo
for key in 'Mute' 'Home' 'Back'; do
  tap "$key"
  sleep 1
done
alive || fail "the app died in the demo"
labels demo | grep -q '^Mute$' || fail "the remote isn't showing in the demo"

echo "=== a second cold start"
adb shell am force-stop "$package"
adb shell am start -W -n "$package/$package.MainActivity"
sleep 10
alive || fail "the app isn't running after a second cold start"
labels restart
screen restart

echo "=== the default apps follow the SIM, not the language"
sim=$(adb shell getprop gsm.sim.operator.iso-country | tr -d '\r')
adb shell pm clear "$package"
# A British language on the emulator's US SIM. Android 13 and later can set it
# for one app with no restart; the region is only proved where that works.
language=$(adb shell cmd locale set-app-locales "$package" --user 0 --locales en-GB 2>&1 | tr -d '\r')
if [ -z "$language" ]; then language=en-GB; else language=system; fi
echo "SIM country: $sim; app language: $language"
adb shell am start -W -n "$package/$package.MainActivity"
sleep 12
tap 'Skip'
sleep 5
tap 'Settings'
sleep 3
tap 'Apps'
sleep 3
screen default-apps
labels default-apps | tee "$out/default-apps.txt"
if [ "$sim" = us ] && [ "$language" = en-GB ]; then
  grep -q 'Hulu' "$out/default-apps.txt" || fail "no US row with a US SIM"
  if grep -q 'BBC iPlayer' "$out/default-apps.txt"; then
    fail "the UK row, from the language, with a US SIM"
  fi
else
  echo "This emulator can't set up the SIM and language test, so the row wasn't checked."
fi

echo "=== the system's per-app language reaches the running app"
if [ "$language" = en-GB ]; then
  adb shell cmd locale set-app-locales "$package" --user 0 --locales ms
  sleep 6
  labels per-app-language-ms >"$out/per-app-language-ms.txt"
  screen per-app-language-ms
  alive || fail "the app died when the language changed"
  grep -q '^Sunting apl$' "$out/per-app-language-ms.txt" || fail "the app didn't turn Malay"
  adb shell cmd locale set-app-locales "$package" --user 0 --locales en
  sleep 6
  labels per-app-language-en >"$out/per-app-language-en.txt"
  grep -q '^Edit apps$' "$out/per-app-language-en.txt" || fail "the app didn't turn back to English"
else
  echo "This emulator has no per-app language, so it wasn't checked."
fi

adb logcat -d >"$out/logcat.txt"
if adb logcat -d -b crash | tee "$out/crash.txt" | grep -q "$package"; then
  fail "a crash in the log"
fi

if [ "$failed" -ne 0 ]; then
  echo "Emulator smoke test failed."
  exit 1
fi
echo "Emulator smoke test passed."
