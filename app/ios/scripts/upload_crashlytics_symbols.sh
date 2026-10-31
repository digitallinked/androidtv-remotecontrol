#!/bin/sh
# The last Runner build phase, "Upload Crashlytics symbols" (Ruling P9-R5). It
# uploads the dSYMs of a Release build to Crashlytics with the Firebase config
# that "Copy Firebase config" put into the app bundle. Without that config, or
# outside Release, it does nothing, so a clean clone still builds.
#
# (unverified, Mac; DM-107) the -gsp flag of FirebaseCrashlytics/run, and that
# the phase can read its inputs (ENABLE_USER_SCRIPT_SANDBOXING is NO).
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

run="${PODS_ROOT:-}/FirebaseCrashlytics/run"
if [ ! -x "$run" ]; then
  echo "warning: $run is missing or not executable (run pod install); no Crashlytics symbols uploaded"
  exit 0
fi

"$run" -gsp "$plist"
