# Rename checklist: app name and bundle id

Choosing the final app name and bundle id is the owner's call (Ruling P9-R1). Until then the app uses the placeholders from decision #12:

| | Dev flavor | Prod flavor |
|---|---|---|
| App name | `Remotely Dev` | `Remotely for Android TV` |
| Android application id / iOS bundle id | `com.digitallinked.atvremote.dev` | `com.digitallinked.atvremote` |
| Short brand (purpose strings, the TV's client name, the feature graphic) | `Remotely` | `Remotely` |

This page lists every place those strings live and what to change. `app/test/release/store_forms_test.dart` (`rename_checklist_names_every_file_that_holds_the_name_or_id`) scans `app/android`, `app/ios` and `app/lib` and fails if a file holding one of them isn't named here.

## Read this first

- **The Play package name is permanent.** Once the first build is uploaded to Google Play (any track, even internal testing), the application id `com.digitallinked.atvremote` can never change for that listing; a new id means a new app with no installs, ratings or reviews. Decide the prod id **before the first upload**.
- **The iOS bundle id is effectively permanent too.** Once an App Store Connect record uses it, it can't be changed or reused for another app.
- **The display name can change later** on both stores (with a new release), but keep the store name, the home-screen name and the store art in step.
- **Trademarks:** no "Google" in the name or icon (CLAUDE.md). "Android TV" in the App Store name risks Guideline 2.3.10 / 5.2 questions (owner list); a name without it is safer, with "for Android TV" kept in the descriptions. `feature_graphic.title` must contain no third-party mark at all (P9-R13).
- **Order:** change the code and the store copy, run `powershell -File tool/check.ps1`, re-render the store art, then register the new ids in Firebase, AdMob, RevenueCat and the stores, and only then build for upload.

## App code and native projects

| File | What it holds | What to change |
|---|---|---|
| `app/lib/app/flavor.dart` | `displayName` (`Remotely Dev`, `Remotely for Android TV`) and `applicationId` for both flavors | The new names and ids. The release checker (`app/tool/release_check.dart`) reads the prod id from here and compares it with the Firebase configs. |
| `app/android/app/build.gradle.kts` | `applicationId = "com.digitallinked.atvremote"` (dev adds `.dev`), `namespace`, and the `appName` manifest placeholders `Remotely Dev` / `Remotely for Android TV` | `applicationId` and both `appName` values. `namespace` is the Kotlin package, not the store id: keep it unless you also move `MainActivity.kt` (below). |
| `app/android/app/src/main/kotlin/com/digitallinked/atvremote/MainActivity.kt` | `package com.digitallinked.atvremote` and its folder path | Nothing, if `namespace` stays. If you change `namespace`, move the file to the matching folder and change the `package` line. |
| `app/ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` for every Runner configuration (`com.digitallinked.atvremote`, `.dev`) and RunnerTests (`com.digitallinked.atvremote.RunnerTests`), and `APP_DISPLAY_NAME` (`Remotely Dev`, `Remotely for Android TV`) in the six flavor configurations | Every `PRODUCT_BUNDLE_IDENTIFIER` and `APP_DISPLAY_NAME`. Edit in Xcode (Runner target → Build Settings, per configuration) or with a careful search-and-replace; then build on a Mac. **(unverified, Mac)** |
| `app/ios/Runner/Info.plist` | `NSLocalNetworkUsageDescription` and `NSUserTrackingUsageDescription`, both starting "Remotely uses…"; `CFBundleDisplayName` comes from `$(APP_DISPLAY_NAME)` | Both purpose strings: the short brand. Apple reviews these (Guideline 5.1.1). |
| `app/ios/Runner/ms.lproj/InfoPlist.strings` | The Malay purpose strings, starting "Remotely menggunakan…" | The short brand; the Malay text needs the owner's sign-off (DM-068). |
| `app/ios/Runner/AppDelegate.swift` | The storage channel name `com.digitallinked.atvremote/storage` | Optional: it is an internal channel name, never shown. If you change it, change `app/lib/core/storage/database_location.dart` in the same commit; the two must match or the database won't open on iPhone. |
| `app/lib/core/storage/database_location.dart` | The same channel name, Dart side | Only together with `AppDelegate.swift`. |
| `app/lib/core/session/remote_client_factory.dart` | `kRemoteClientName = 'Remotely'`: the client name the TV shows in its list of connected remotes (`DeviceInfo`) | The short brand. TVs already paired keep the old name until the phone pairs again. |

**Follows automatically:** the merged-manifest permission `com.digitallinked.atvremote.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (AndroidX Core builds it from the application id; see `forms/permissions.md`).

**Not holding the name:** the ARB files (`app/lib/app/l10n/app_en.arb`, `app_ms.arb`) have no app name in any value; the feedback e-mail subject's `{appName}` is filled from `Flavor.displayName`, and the About page reads the installed app's label. `CFBundleName` (`tv_remote`) and the Dart package name `tv_remote` are internal and can stay. After a rename, search the ARB values once more anyway: `git grep -n "Remotely" -- app/lib/app/l10n`.

## Firebase, AdMob, RevenueCat and the stores (consoles) **[owner]**

| Where | What holds the id or name | What to do |
|---|---|---|
| Firebase console | One Android app and one iOS app per flavor, registered with the package / bundle id | Register apps for the new ids (an app's id can't be edited), download new configs, and delete the old apps when nothing uses them. |
| `app/android/app/src/dev/google-services.json`, `app/android/app/src/prod/google-services.json` | `package_name` (git-ignored; only on the owner's machine) | Replace with the files for the new ids. The build's Google Services plugin fails if the package doesn't match. |
| `app/ios/config/dev/GoogleService-Info.plist`, `app/ios/config/prod/GoogleService-Info.plist` | `BUNDLE_ID` (git-ignored) | Replace with the files for the new ids; the release check compares `BUNDLE_ID` with `flavor.dart`. |
| AdMob console | The app records (linked to the store listings) and their ad units; the app ids in `app/android/secrets.properties` (`admobAppIdProd`) and `app/ios/Flutter/Secrets.xcconfig` (`ADMOB_APP_ID_PROD`) | A new store listing needs its AdMob app re-linked (Apps → App settings → link to store). The ad unit ids in `app/env/prod.json` stay valid for the same AdMob app. `app-ads.txt` doesn't change (`forms/app-ads-txt.md`). |
| RevenueCat dashboard | The Play app (package name, service credentials) and the App Store app (bundle id, shared secret / API key); the public SDK keys in `app/env/prod.json` | Set the new package and bundle id; if RevenueCat issues new app-specific keys, update `REVENUECAT_ANDROID_KEY` / `REVENUECAT_IOS_KEY`. Products `premium_monthly`, `premium_yearly`, `premium_lifetime` must exist under the new store records. |
| Google Play Console | The app's package (permanent after the first upload) and its store name | Create the app with the new name; the package is taken from the first upload. |
| App Store Connect and the Apple Developer portal | The registered bundle id (Identifiers), the app record's name and bundle id | Register the bundle ids, create the record with the new name. |

## Store copy, store art, legal docs and placeholders

| File | What to change |
|---|---|
| `docs/release/placeholders.json` | `APP_NAME` (`Remotely for Android TV`) and `PLAY_PACKAGE` (`com.digitallinked.atvremote`). Every use of these two tokens in the store copy and the legal pages follows; run `dart tool/fill_release_docs.dart` from `app/`. `app/test/release/placeholders_test.dart` pins today's values: update it with them. |
| `docs/release/store-listing/en.md` and `docs/release/store-listing/ms.md` | `feature_graphic.title` is the short brand `Remotely`, written out (not a token, because the full placeholder name is too long and contains "Android"). Change it in both files. The names (`play.title`, `appstore.name`) are the `APP_NAME` token. Re-check the 30-character limits after filling (`app/test/release/store_copy_test.dart`). |
| `docs/release/store-assets/feature_graphic.png` | The feature graphic shows `feature_graphic.title`. Re-render it: `flutter test --update-goldens --tags golden test/store_assets/feature_graphic_golden_test.dart` from `app/`, and update that test's `find.text('Remotely')`. Inspect the PNG. |
| Store screenshots (`build/store-screenshots/`, not committed) | Captions don't name the app; the screens show it only where the app does. Regenerate with `tool/store_screenshots.ps1` after the rename to be sure. |
| `docs/release/legal/privacy-policy.md`, `docs/release/legal/terms.md` | They use the `APP_NAME` and `PLAY_PACKAGE` tokens only: nothing to edit, but re-read the filled copies, and re-host them. |
| `docs/release/forms/*.md`, `docs/release/review/*.md` | `forms/permissions.md` names the `DYNAMIC_RECEIVER` permission with today's id; update it after the next merged-manifest check. The review notes and the demo video show the app's name on screen: re-record the video if the home-screen name changed. |

## Tests, tools and project docs

| File | What to change |
|---|---|
| `app/test/app/flavor_test.dart`, `app/test/platform/branding_test.dart`, `app/test/platform/ios_malay_test.dart`, `app/test/platform/ads_config_test.dart`, `app/test/release/placeholders_test.dart`, `app/test/core/session/remote_client_factory_test.dart` | These assert today's real names and ids: update them with the code. |
| `app/test/tool/release_fixture.dart`, `app/test/tool/release_check_test.dart`, and the other tests that mention the name in fakes (`git grep -l "Remotely\|atvremote" -- app/test`) | Fixtures and fake app info: they may keep the old values, but update `release_fixture.dart`'s prod id if the checker should be exercised with the real one. Goldens don't change unless a test renders a changed value. |
| `tool/measure_android.ps1`, `tool/measure_android.sh` | The default package `com.digitallinked.atvremote.dev` and the activity `com.digitallinked.atvremote.MainActivity` (the activity follows `namespace`, the package follows `applicationId`). |
| `.claude/skills/store-release/SKILL.md`, `docs/knowledge/decisions.md` (#12) and `docs/knowledge/status.md` | The ids and names in the project knowledge; update them and record the rename as a decision. |

## After the rename

- [ ] `git grep -n -e "com.digitallinked.atvremote" -e "Remotely"` shows only what you chose to keep (internal channel names, fakes, history). **[owner]**
- [ ] `powershell -File tool/check.ps1` prints "All checks passed." **[owner]**
- [ ] `flutter build apk --release --flavor prod -t lib/main_prod.dart`, then `dart tool/release_check.dart --platform android --stage manifest` from `app/`. **[owner]**
- [ ] On a Mac: `flutter build ios --flavor prod -t lib/main_prod.dart --no-codesign`; the home-screen name and the purpose strings show the new name. **(unverified, Mac)** **[owner]**
