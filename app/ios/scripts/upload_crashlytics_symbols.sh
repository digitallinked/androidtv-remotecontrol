#!/bin/sh
# The last Runner build phase, "Upload Crashlytics symbols" (Ruling P9-R5). It
# uploads the dSYMs of a Release build to Crashlytics with the Firebase config
# that "Copy Firebase config" put into the app bundle. Without that config, or
# outside Release, it does nothing, so a clean clone still builds.
#
# (unverified, Mac; DM-107) the -gsp flag of FirebaseCrashlytics/run, and that
# the phase can read its inputs (ENABLE_USER_SCRIPT_SANDBOXING is NO). The
# phase declares no GoogleService-Info.plist input (P9-C4): nothing declares
# it as an output, so Xcode would fail every build without it; the check
# below handles a missing file instead.
#
# Messages start with error:, warning: or note: so Xcode shows them.
set -eu

config="${CONFIGURATION:-}"

case "$config" in
  Release-*) ;;
  *)
    echo "note: $config is not a Release configuration; no symbols uploaded"
    exit 0
    ;;
esac

plist="${BUILT_PRODUCTS_DIR:-}/${PRODUCT_NAME:-}.app/GoogleService-Info.plist"
if [ ! -f "$plist" ]; then
  echo "note: no Firebase config; no symbols uploaded"
  exit 0
fi

# Where FirebaseCrashlytics/run lives (Ruling P9-C4), first match wins:
#   1. CocoaPods: $PODS_ROOT/FirebaseCrashlytics/run.
#   2. Swift Package Manager, from BUILD_DIR. `flutter build ipa` (an archive)
#      leaves BUILD_DIR under DerivedData/Runner-<hash>/Build/, so stripping
#      "/Build/..." gives the DerivedData root that holds SourcePackages/.
#   3. Swift Package Manager, from OBJROOT. `flutter build ios` sets
#      BUILD_DIR=<app>/build/ios, which has no "/Build/" to strip, so
#      candidate 2 misses there; OBJROOT still points into DerivedData.
# Only archives are uploaded to the stores, so candidate 2 is the one that
# matters. (unverified, Mac; DM-107) Unset variables skip their candidate,
# so an empty PODS_ROOT never becomes /FirebaseCrashlytics/run.
run=""
try_tool() {
  if [ -z "$run" ] && [ -x "$1" ]; then
    run="$1"
  fi
}
if [ -n "${PODS_ROOT:-}" ]; then
  try_tool "$PODS_ROOT/FirebaseCrashlytics/run"
fi
spm_run="SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
if [ -n "${BUILD_DIR:-}" ]; then
  try_tool "${BUILD_DIR%/Build/*}/$spm_run"
fi
if [ -n "${OBJROOT:-}" ]; then
  try_tool "${OBJROOT%/Build/*}/$spm_run"
fi

if [ -z "$run" ]; then
  echo "warning: FirebaseCrashlytics/run not found (neither \$PODS_ROOT/FirebaseCrashlytics/run nor the Swift package checkout); no Crashlytics symbols uploaded"
  exit 0
fi

echo "note: uploading dSYMs with $run"
"$run" -gsp "$plist"
