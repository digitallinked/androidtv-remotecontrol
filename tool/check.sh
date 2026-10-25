#!/usr/bin/env bash
# Format check, static analysis and tests for the whole workspace.
set -euo pipefail

cd "$(dirname "$0")/.."

flutter pub get

echo "== format =="
dart format --output=none --set-exit-if-changed app/lib app/test packages/atv_remote/lib packages/atv_remote/test packages/atv_remote/bin

echo "== analyze =="
(cd app && flutter analyze)
(cd packages/atv_remote && dart analyze --fatal-infos)

echo "== test =="
# Goldens are Windows baselines; the `goldens` CI job runs them.
(cd app && flutter test --exclude-tags golden)
# `dart test` cannot resolve the workspace (app needs the Flutter SDK), so use flutter test.
(cd packages/atv_remote && flutter test)

echo "All checks passed."
