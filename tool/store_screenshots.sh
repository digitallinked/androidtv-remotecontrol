#!/usr/bin/env bash
# Store screenshot generator (Ruling P9-R14): renders every shot of
# app/test/store_assets/store_frame.dart in English and Malay, framed at the
# store sizes, into build/store-screenshots/<set>/<locale>/<id>.png.
# build/ is git-ignored: the PNGs are never committed. Run from anywhere.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/store-screenshots"
# A fresh folder, so the generator's count of 40 sees no stale files.
rm -rf "$out"
export STORE_SCREENSHOTS_OUT="$out"

cd "$root/app"
started=$(date +%s)
flutter test test/store_assets/store_screenshots_test.dart
seconds=$(($(date +%s) - started))

count=$(find "$out" -name '*.png' | wc -l | tr -d ' ')
echo "Wrote $count store screenshots to $out in $seconds s."
