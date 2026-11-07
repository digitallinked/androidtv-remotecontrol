#!/usr/bin/env bash
# Runs the integration flows on a booted iPhone simulator (the Device builds
# workflow). No TV is involved: the flows use the fake TV inside the app.
set -u

cd "$(dirname "$0")/../app" || exit 1

udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
ios = sorted((r for r in runtimes if "iOS" in r), reverse=True)
phones = [d["udid"] for r in ios for d in runtimes[r] if d["name"].startswith("iPhone")]
print(phones[0] if phones else "")
')
if [ -z "$udid" ]; then
  echo "FAILED: no iPhone simulator is available"
  exit 1
fi
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b

failed=0
for flow in demo_mode_flow discover_pair_press_key_flow; do
  echo "=== $flow"
  flutter test "integration_test/${flow}_test.dart" -d "$udid" --flavor dev || {
    echo "FAILED: $flow"
    failed=1
  }
done

if [ "$failed" -ne 0 ]; then
  echo "The simulator flows failed."
  exit 1
fi
echo "The simulator flows passed."
