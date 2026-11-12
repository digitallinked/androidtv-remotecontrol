#!/usr/bin/env bash
# Website screens: renders the real app (app/test/store_assets/web_screens_test.dart)
# into build/web-screens/*.png, then web/scripts/screens.mjs writes the WebP
# files the site shows to web/public/screens/. Commit only the WebP files.
# Run from anywhere; web/node_modules must be installed.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/web-screens"
rm -rf "$out"
export WEB_SCREENS_OUT="$out"

(cd "$root/app" && flutter test test/store_assets/web_screens_test.dart)
(cd "$root/web" && node scripts/screens.mjs)
