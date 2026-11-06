#!/usr/bin/env bash
# Regenerates packages/atv_remote/lib/src/proto from packages/atv_remote/proto/*.proto.
# Needs protoc (tool/bin/bin/protoc[.exe] or on PATH) and protoc-gen-dart on PATH.
#
# protoc 36.2: https://github.com/protocolbuffers/protobuf/releases/tag/v36.2
#   download protoc-36.2-linux-x86_64.zip (Linux) or
#   protoc-36.2-osx-universal_binary.zip (macOS) and unzip it into tool/bin/
#   (git-ignored), which gives tool/bin/bin/protoc.
# protoc_plugin 25.1.0: dart pub global activate protoc_plugin 25.1.0
set -euo pipefail

cd "$(dirname "$0")/.."

PROTOC=protoc
for candidate in tool/bin/bin/protoc tool/bin/bin/protoc.exe; do
  if [ -x "$candidate" ]; then PROTOC="$candidate"; break; fi
done

# Warn (don't fail) when protoc isn't the release the checked-in code came from.
EXPECTED="libprotoc 36.2"
VERSION="$("$PROTOC" --version | tr -d "\r")"
if [ "$VERSION" != "$EXPECTED" ]; then
  echo "warning: protoc is $VERSION; the generated code was made with libprotoc 36.2" >&2
fi

# Make sure the pub-global executables (protoc-gen-dart) are reachable.
export PATH="$PATH:$HOME/.pub-cache/bin:${LOCALAPPDATA:-}/Pub/Cache/bin"

OUT=packages/atv_remote/lib/src/proto
mkdir -p "$OUT"
"$PROTOC" --dart_out="$OUT" -Ipackages/atv_remote/proto packages/atv_remote/proto/*.proto
dart format "$OUT"
echo "Generated protobuf code in $OUT"
