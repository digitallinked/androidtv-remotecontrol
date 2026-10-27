#!/bin/sh
# Copies the git-ignored Firebase config for the current flavor into the app
# bundle (Ruling P6-R2). The flavor is the suffix of the build configuration
# name, e.g. "Debug-dev" -> "dev". Without the file Firebase stays off and the
# build still succeeds.
set -e

flavor="${CONFIGURATION##*-}"
plist="$SRCROOT/config/$flavor/GoogleService-Info.plist"

if [ -f "$plist" ]; then
  cp "$plist" "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/"
  echo "Copied Firebase config for $flavor"
else
  echo "note: no Firebase config for $flavor; Firebase stays off"
fi
exit 0
