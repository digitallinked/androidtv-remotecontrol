#!/usr/bin/env bash
# Branding pipeline (Ruling P7-R6): renders the masters from our own painter,
# then regenerates the launcher icons and the native splash. Run from anywhere;
# stops at the first failing step. Commit the generated native files.
set -euo pipefail
cd "$(dirname "$0")/../app"

echo '== masters =='
# No tag filter: the untagged brand_mark_test.dart writes brand_icon.svg.
flutter test --update-goldens test/branding

echo '== launcher icons =='
flutter pub run flutter_launcher_icons -f flutter_launcher_icons.yaml
# flutter_launcher_icons 0.14.4 sets every build setting whose name contains
# ASSETCATALOG to the icon name, including this boolean; put it back.
sed -i.bak 's/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;/'   ios/Runner.xcodeproj/project.pbxproj
rm ios/Runner.xcodeproj/project.pbxproj.bak

echo '== native splash =='
flutter pub run flutter_native_splash:create --path=flutter_native_splash.yaml

echo 'Branding generated.'
