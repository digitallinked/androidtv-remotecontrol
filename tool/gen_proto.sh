#!/usr/bin/env bash
# Regenerates packages/atv_remote/lib/src/proto from packages/atv_remote/proto/*.proto.
# Needs protoc (tool/bin/bin/protoc[.exe] or on PATH) and protoc-gen-dart on PATH:
#   dart pub global activate protoc_plugin 25.1.0
set -euo pipefail

cd "$(dirname "$0")/.."

PROTOC=protoc
for candidate in tool/bin/bin/protoc tool/bin/bin/protoc.exe; do
  if [ -x "$candidate" ]; then PROTOC="$candidate"; break; fi
done

# Make sure the pub-global executables (protoc-gen-dart) are reachable.
export PATH="$PATH:$HOME/.pub-cache/bin:${LOCALAPPDATA:-}/Pub/Cache/bin"

OUT=packages/atv_remote/lib/src/proto
mkdir -p "$OUT"
"$PROTOC" --dart_out="$OUT" -Ipackages/atv_remote/proto packages/atv_remote/proto/*.proto
dart format "$OUT"
echo "Generated protobuf code in $OUT"
