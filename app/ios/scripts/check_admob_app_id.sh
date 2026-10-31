#!/bin/sh
# The first Runner build phase, "Check AdMob app id" (Ruling P9-R4). The Mobile
# Ads SDK stops the app at launch when GADApplicationIdentifier is empty or
# malformed, and an App Store build must not ship Google's test app id, so a
# prod configuration is checked before anything is compiled.
#
# Inputs (Xcode build settings): CONFIGURATION, ACTION, ADMOB_APP_ID. The dev
# configurations are never checked. ACTION is "install" for an archive, which
# `flutter build ipa` runs (unverified, Mac; DM-106).
#
# The id itself is never printed. Messages start with error:, warning: or
# note: so Xcode shows them.
set -eu

config="${CONFIGURATION:-}"
action="${ACTION:-}"
id="${ADMOB_APP_ID:-}"
fix="set ADMOB_APP_ID_PROD in ios/Flutter/Secrets.xcconfig (see Secrets.example.xcconfig)"

case "$config" in
  *-prod) ;;
  *) exit 0 ;;
esac

if [ -z "$id" ]; then
  echo "error: the AdMob app id of $config is empty, so the app would stop at launch; $fix"
  exit 1
fi

case "$id" in
  *XXXXXXXX* | *YYYYYYYYYY*)
    echo "error: the AdMob app id of $config is still the example placeholder; $fix"
    exit 1
    ;;
esac

# Only letters, digits, "-" and "~" may appear, which also rules out a value
# spread over several lines slipping past the line-based grep below.
case "$id" in
  *[!A-Za-z0-9~-]*) valid=no ;;
  *)
    if printf '%s\n' "$id" | grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$'; then
      valid=yes
    else
      valid=no
    fi
    ;;
esac
if [ "$valid" != yes ]; then
  echo "error: the AdMob app id of $config is not an app id (ca-app-pub-<16 digits>~<10 digits>), so the app would stop at launch; $fix"
  exit 1
fi

case "$id" in
  ca-app-pub-3940256099942544~*)
    if [ "$action" = install ]; then
      echo "error: this archive of $config would ship Google's test AdMob app id; $fix"
      exit 1
    fi
    echo "warning: prod uses Google's test AdMob app id; set ADMOB_APP_ID_PROD in ios/Flutter/Secrets.xcconfig"
    ;;
esac
exit 0
