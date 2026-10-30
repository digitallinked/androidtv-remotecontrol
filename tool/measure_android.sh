#!/usr/bin/env bash
# Cold start, startup trace and battery measurements on an Android device
# (Ruling P8-R5); the twin of measure_android.ps1. Raw output goes to
# build/measurements/<yyyyMMdd-HHmmss>-<mode>/ and a summary is printed.
# Results belong in docs/knowledge/device-matrix.md; write down only what a run
# measured.
#
#   tool/measure_android.sh --mode startup [--runs 10] [--package com.digitallinked.atvremote.dev]
#   tool/measure_android.sh --mode trace
#   tool/measure_android.sh --mode battery [--minutes 30]
#
# startup  Needs an installed profile build, from app/:
#            flutter build apk --profile --flavor dev -t lib/main_dev.dart
#            adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk
#          Each run force-stops the app, waits 2 s and starts it with
#          `am start -W`; prints every TotalTime and the median.
# trace    Runs `flutter run --profile --trace-startup` (it builds and installs
#          the profile build) and prints the time to the first frame.
# battery  Resets batterystats, waits --minutes and saves the app's stats. Run
#          it twice: once with the remote open and connected (keep-awake on),
#          once as the baseline with the app force-stopped, screen on in both.
#
# With more than one device attached, set ANDROID_SERIAL to pick one.
set -euo pipefail

activity='com.digitallinked.atvremote.MainActivity'
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "measure_android: $*" >&2
  exit 1
}

mode=''
runs=10
minutes=30
package='com.digitallinked.atvremote.dev'
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --runs) runs="${2:-}"; shift 2 ;;
    --minutes) minutes="${2:-}"; shift 2 ;;
    --package) package="${2:-}"; shift 2 ;;
    *) fail "unknown argument '$1' (use --mode startup|trace|battery [--runs N] [--minutes N] [--package ID])" ;;
  esac
done
case "$mode" in
  startup | trace | battery) ;;
  *) fail "--mode must be startup, trace or battery" ;;
esac
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || fail "--runs must be a positive whole number"
[[ "$minutes" =~ ^[1-9][0-9]*$ ]] || fail "--minutes must be a positive whole number"

find_adb() {
  if command -v adb > /dev/null 2>&1; then
    command -v adb
    return
  fi
  local root
  for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "${LOCALAPPDATA:-}/Android/Sdk"; do
    if [ -n "$root" ] && [ -x "$root/platform-tools/adb" ]; then
      echo "$root/platform-tools/adb"
      return
    fi
  done
  fail 'adb not found. Put platform-tools on PATH or set ANDROID_HOME.'
}

adb_bin="$(find_adb)"

# The serial of the one device to measure on; fails when there is none.
listing="$("$adb_bin" devices)" || fail 'adb devices failed.'
# "List of devices attached" has more than two words, so it never matches.
ready="$(printf '%s\n' "$listing" | awk 'NF == 2 && $2 == "device" { print $1 }')"
not_ready="$(printf '%s\n' "$listing" | awk 'NF == 2 && $2 != "device" { printf "%s (%s) ", $1, $2 }')"
if [ -n "${ANDROID_SERIAL:-}" ]; then
  printf '%s\n' "$ready" | grep -qxF "$ANDROID_SERIAL" ||
    fail "No device attached: ANDROID_SERIAL=$ANDROID_SERIAL is not among the ready devices ($(echo $ready))."
  serial="$ANDROID_SERIAL"
else
  count="$(printf '%s\n' "$ready" | grep -c . || true)"
  if [ "$count" -eq 0 ]; then
    detail=''
    [ -n "$not_ready" ] && detail=" Not ready: $not_ready"
    fail "No device attached. Connect a phone with USB debugging on (or start an emulator) and check 'adb devices'.$detail"
  fi
  [ "$count" -eq 1 ] ||
    fail "More than one device attached ($(echo $ready)). Set ANDROID_SERIAL to the one to measure."
  serial="$ready"
fi

adb_s() { "$adb_bin" -s "$serial" "$@"; }
model="$(adb_s shell getprop ro.product.model | tr -d '\r')"
release="$(adb_s shell getprop ro.build.version.release | tr -d '\r')"
echo "Device: $serial ($model, Android $release)"

out="$repo_root/build/measurements/$(date +%Y%m%d-%H%M%S)-$mode"

case "$mode" in
  startup)
    adb_s shell pm path "$package" | grep -q '^package:' ||
      fail "$package is not installed on $serial. From app/: flutter build apk --profile --flavor dev -t lib/main_dev.dart, then adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk"
    # Profile builds are debuggable too, so the flags can't tell them from a
    # debug build: installing the profile APK is up to the operator.
    mkdir -p "$out"
    times=()
    for run in $(seq 1 "$runs"); do
      adb_s shell am force-stop "$package"
      sleep 2
      adb_s shell am start -W -n "$package/$activity" | tr -d '\r' > "$out/run-$run.txt"
      total="$(sed -n 's/^TotalTime:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$out/run-$run.txt")"
      [ -n "$total" ] || fail "Run $run printed no TotalTime (see $out/run-$run.txt)."
      times+=("$total")
      printf 'Run %2d: TotalTime %s ms\n' "$run" "$total"
    done
    adb_s shell am force-stop "$package"
    median="$(printf '%s\n' "${times[@]}" | sort -n | awk '{ v[NR] = $1 } END { if (NR % 2) print v[(NR + 1) / 2]; else print (v[NR / 2] + v[NR / 2 + 1]) / 2 }')"
    summary="Cold start of $package on $serial ($model, Android $release): median TotalTime $median ms over $runs runs ($(IFS=,; echo "${times[*]}" | sed 's/,/, /g') ms)"
    echo "$summary" > "$out/summary.txt"
    echo "$summary"
    echo "Raw output: $out"
    ;;
  trace)
    mkdir -p "$out"
    info="$repo_root/app/build/start_up_info.json"
    rm -f "$info"
    (cd "$repo_root/app" && flutter run --profile --trace-startup --flavor dev -t lib/main_dev.dart -d "$serial") 2>&1 |
      tee "$out/flutter_run.txt" || fail "flutter run failed (see $out/flutter_run.txt)."
    [ -f "$info" ] || fail "flutter run wrote no $info."
    cp "$info" "$out/start_up_info.json"
    field() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*[0-9]*" "$info" | grep -o '[0-9]*$'; }
    summary="Startup trace of $package on $serial ($model, Android $release): timeToFirstFrameMicros $(field timeToFirstFrameMicros), timeToFirstFrameRasterizedMicros $(field timeToFirstFrameRasterizedMicros)"
    echo "$summary" > "$out/summary.txt"
    echo "$summary"
    echo "Raw output: $out"
    ;;
  battery)
    mkdir -p "$out"
    adb_s shell dumpsys batterystats --reset > /dev/null || fail 'dumpsys batterystats --reset failed.'
    echo "Unplug, open the remote connected to the TV, leave it for $minutes minutes."
    echo '(For the baseline run: force-stop the app instead, screen on.) Plug back in before the time is up; the stats are read once the device is back.'
    for left in $(seq "$minutes" -1 1); do
      echo "  $left min left"
      sleep 60
    done
    echo 'Waiting for the device...'
    adb_s wait-for-device
    adb_s shell dumpsys batterystats --charged "$package" | tr -d '\r' > "$out/batterystats.txt"
    awk '/Estimated power use/ { on = 1; print; next } on && /^[[:space:]]*$/ { on = 0 } on { print }' \
      "$out/batterystats.txt" > "$out/estimated_power_use.txt"
    if [ ! -s "$out/estimated_power_use.txt" ]; then
      echo "WARNING: no 'Estimated power use' section in the stats (see $out/batterystats.txt). Was the device charging the whole time?" >&2
    fi
    echo "Battery, $minutes min, $package on $serial ($model, Android $release):"
    cat "$out/estimated_power_use.txt"
    echo "Raw output: $out"
    ;;
esac
