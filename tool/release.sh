#!/usr/bin/env bash
# Builds a prod store artifact, but only from a tree that passes every
# release check (Ruling P9-R2). It never signs with a key it creates, and
# never uploads anything.
#
#   tool/release.sh --platform android|ios [--dry-run] [--root <dir>]
#
# 1. Pre-checks (app/tool/release_check.dart). On refusal nothing is built.
# 2. --dry-run stops here.
# 3. iOS store builds need a Mac.
# 4. Deletes the previous artifact, builds, then runs the post-checks.
set -euo pipefail

usage() {
  echo "Usage: tool/release.sh --platform android|ios [--dry-run] [--root <dir>]" >&2
  exit 64
}

platform=""
dry_run=0
root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --platform) [ $# -ge 2 ] || usage; platform="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --root) [ $# -ge 2 ] || usage; root="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$platform" in
  android|ios) ;;
  *) usage ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checker="$script_dir/../app/tool/release_check.dart"
if [ -z "$root" ]; then root="$script_dir/.."; fi
if [ ! -d "$root" ]; then
  echo "No such directory: $root" >&2
  usage
fi
root="$(cd "$root" && pwd)"

if ! command -v dart >/dev/null 2>&1; then
  echo "dart is not on the PATH, so the release checks could not run. No build was made."
  exit 1
fi

# 1. Pre-checks.
code=0
dart "$checker" --platform "$platform" --stage pre --root "$root" || code=$?
if [ "$code" -eq 64 ]; then exit 64; fi
if [ "$code" -ne 0 ]; then
  echo "No build was made."
  exit 1
fi

# 2. Dry run.
if [ "$dry_run" -eq 1 ]; then
  echo "Dry run: every pre-build check passed. No build was made."
  exit 0
fi

# 3. iOS needs a Mac.
if [ "$platform" = ios ] && [ "$(uname -s)" != Darwin ]; then
  echo "iOS store builds need a Mac (flutter build ipa)."
  exit 1
fi

# 4. Delete the previous artifact so the post-check can't pass on a stale file.
aab="$root/app/build/app/outputs/bundle/prodRelease/app-prod-release.aab"
ipa_dir="$root/app/build/ios/ipa"
if [ "$platform" = android ]; then
  rm -f "$aab"
else
  rm -f "$ipa_dir"/*.ipa
fi

# 5. Build, then post-check.
kind=appbundle
if [ "$platform" = ios ]; then
  kind=ipa
  # Ruling P9-C4: under Swift Package Manager, firebase_analytics's
  # Package.swift links Analytics without the advertising id only when this
  # is set while packages resolve (the Podfile's
  # $FirebaseAnalyticsWithoutAdIdSupport covers CocoaPods only). Decision #39.
  export FIREBASE_ANALYTICS_WITHOUT_ADID=true
fi
code=0
(cd "$root/app" && flutter build "$kind" --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json) || code=$?
if [ "$code" -ne 0 ]; then
  echo "flutter build $kind failed (exit $code). No upload artifact was made."
  exit 1
fi

artifact="$aab"
if [ "$platform" = ios ]; then
  artifact="$(ls -t "$ipa_dir"/*.ipa 2>/dev/null | head -n 1 || true)"
  if [ -z "$artifact" ]; then artifact="$ipa_dir/*.ipa"; fi
fi

code=0
dart "$checker" --platform "$platform" --stage post --root "$root" || code=$?
if [ "$code" -ne 0 ]; then
  echo "Do not upload $artifact."
  exit 1
fi

# 6. Report.
if command -v shasum >/dev/null 2>&1; then
  hash="$(shasum -a 256 "$artifact" | cut -d ' ' -f 1)"
else
  hash="$(sha256sum "$artifact" | cut -d ' ' -f 1)"
fi
bytes="$(wc -c < "$artifact" | tr -d ' ')"
version="$(sed -n 's/^version:[[:space:]]*//p' "$root/app/pubspec.yaml" | head -n 1)"
echo "Built $artifact"
echo "Size: $bytes bytes"
echo "SHA-256: $hash"
echo "Version: ${version:-?}"
echo "Next: upload it to the internal test track (docs/release/runbook.md)."
