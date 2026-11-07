#!/usr/bin/env bash
# Checks a built Runner.app for what the App Store asks of it, and prints which
# required-reason APIs each bundled framework references, next to whether that
# framework has a privacy manifest. Runs on a Mac (the Device builds workflow).
#
# Usage: tool/inspect_ios_product.sh <path to Runner.app>
set -u

app="${1:?Usage: inspect_ios_product.sh <path to Runner.app>}"
failed=0

fail() {
  echo "FAILED: $1"
  failed=1
}

echo "=== Info.plist"
for key in CFBundleIdentifier CFBundleDisplayName MinimumOSVersion GADApplicationIdentifier \
  NSLocalNetworkUsageDescription NSUserTrackingUsageDescription; do
  value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$app/Info.plist" 2>/dev/null) ||
    fail "Info.plist has no $key"
  echo "$key = $value"
done

echo "=== bundled resources"
[ -f "$app/PrivacyInfo.xcprivacy" ] || fail "no PrivacyInfo.xcprivacy in the app"
plutil -lint "$app/PrivacyInfo.xcprivacy" || fail "PrivacyInfo.xcprivacy doesn't parse"
[ -f "$app/ms.lproj/InfoPlist.strings" ] || fail "no Malay InfoPlist.strings in the app"
plutil -lint "$app/ms.lproj/InfoPlist.strings" || fail "the Malay InfoPlist.strings doesn't parse"

# The symbols of Apple's required-reason API list that a C library can reach.
symbols='_stat$|_stat\$|_lstat|_fstat|_fstatat|_getattrlist|_fgetattrlist|_getattrlistat|_getattrlistbulk|_statfs|_fstatfs|_statvfs|_fstatvfs|_mach_absolute_time'

echo "=== frameworks"
for framework in "$app"/Frameworks/*.framework; do
  name=$(basename "$framework" .framework)
  manifest=no
  [ -n "$(find "$framework" -name PrivacyInfo.xcprivacy -print -quit)" ] && manifest=yes
  used=$(nm -u "$framework/$name" 2>/dev/null | grep -E "$symbols" | tr -d ' ' | sort -u | tr '\n' ' ')
  echo "$name: manifest=$manifest references=[$used]"
done

echo "=== the app binary"
nm -u "$app/Runner" 2>/dev/null | grep -E "$symbols" | tr -d ' ' | sort -u | tr '\n' ' '
echo

if [ "$failed" -ne 0 ]; then
  echo "The iOS product is missing something."
  exit 1
fi
echo "The iOS product has what the App Store needs."
