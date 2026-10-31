# Phase 9 — Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything a store release needs that can be done without the owner's accounts is ready. Phase 9 then stops before signing and store submission. That means:
- **A prod store artifact can't be built by mistake from an incomplete tree.**
  - `tool/release.ps1` / `tool/release.sh` refuse with one line per missing or wrong item. Those items are config, ids, signing, tracked secrets, placeholder links and the merged-manifest backup rules.
  - Gradle refuses a prod app bundle without the upload key or the real AdMob app id.
  - An iOS archive refuses an empty, placeholder or test AdMob app id.
- **The native release plumbing exists:**
  - Android: `key.properties` signing, and the misplaced-`google-services.json` warning.
  - iOS: the Podfile at 15.0, per-flavor Pods xcconfigs and the Crashlytics dSYM upload. These are (unverified) until the owner's Mac runs them.
- **The Phase 9 code carry-overs are closed:**
  - the fresh-database preference rule, which also fixes the Try-again edge case;
  - Android 13 per-app languages;
  - no `dart:io Platform` in `app/lib`;
  - the full-page text sweep;
  - CLI hardening;
  - the protoc release recorded in the gen scripts.
- **Store material exists as files for the owner to paste or host:**
  - privacy policy and terms;
  - store copy in English and Malay, with the Malay unreviewed;
  - the feature graphic and a screenshot generator;
  - filled drafts of every store form;
  - review notes and a demo-video script;
  - launch-ops docs and the release runbook.

  Every placeholder is filled from one file.
- **The handoff is explicit:** every step that needs the owner is in "Needs the owner" and in `docs/release/runbook.md`.

**Architecture:**
- **Release check:** one pure-Dart checker, `app/tool/release_check.dart`. It uses `dart:io` only, with no package imports, and takes `--platform`, `--stage` and `--root`. `tool/release.ps1` and `tool/release.sh` are thin wrappers: pre-checks, the build, post-checks, then a summary. Tests drive the checker as a library against fixture trees in temp directories, and drive the wrappers against the same fixtures.
- **Native guards:**
  - Gradle (`app/android/app/build.gradle.kts`) owns signing and the bundle-time AdMob refusal.
  - Two POSIX build-phase scripts in `app/ios/scripts/` own the iOS AdMob check and the dSYM upload.
  - Tests run those scripts with `sh` and fake environments.
- **App code:**
  - One fresh-database hook in bootstrap (`core/storage/fresh_database.dart`).
  - `defaultTargetPlatform` branches in `app_info.dart`.
  - An Android `locales_config.xml`.
  - No new strings and no new dependencies.
- **Store material:**
  - Markdown under `docs/release/`, with `{{TOKEN}}` placeholders whose values live in `docs/release/placeholders.json`. `app/tool/fill_release_docs.dart` renders filled copies into the git-ignored `build/release-docs/`.
  - Store images are rendered by our own widgets in `app/test/store_assets/` with real fonts. The feature graphic is a committed golden; screenshots go to the git-ignored `build/store-screenshots/`.
- **Protocol:** `packages/atv_remote` changes only in the CLI (`lib/src/cli/`, `bin/atv_cli.dart`). No wire behaviour changes.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2, go_router 18.1.1, drift 2.34.0, AGP 9.0.1, google-services 4.5.0, firebase-crashlytics Gradle plugin 3.0.8, CocoaPods (Mac only), Windows PowerShell 5.1 and bash for the wrappers, POSIX `sh` for Xcode build phases. No new packages, no version bumps.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md`.
- **Binding parts:**
  - the privacy promise (TV names, addresses and MACs stay on the phone);
  - the anti-goal "using 'Google' in the name or icon";
  - the monetisation rules (decision #6).
- **Relation to the master plan:** this plan expands Phase 9 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md`.
  - **9.1 (legal and listing assets)** → Tasks 9.8–9.11.
  - **9.2 / 9.3 (Android and iOS release)** → Tasks 9.1–9.3 and the runbook; signing, uploads, tracks and review are [owner].
  - **9.4 (launch ops)** → Task 9.12.
  - It adds the Phase 9 carry-overs from `status.md` (Tasks 9.4–9.7).
- **Before starting, read:**
  - the skills `store-release` (primary), `app-services`, `flutter-app-architecture`, `remote-design-system`, `atv-remote-protocol` (Task 9.7);
  - in `decisions.md`: #5, #6, #12, #18, #22, #28, #35, #38–#43, #46, #48–#50;
  - `learnings.md` (Windows tooling, Phase 6 Firebase/AdMob gotchas, Phase 8 privacy and backup);
  - `docs/knowledge/device-matrix.md` (row format and rules).

## Global Constraints

- **Toolchain:**
  - Flutter 3.44.1 / Dart 3.12.1. No dependency changes in this phase: `pubspec.yaml` and `pubspec.lock` are untouched.
  - Lints are `very_good_analysis` 10.3.0. Document every public member, including those in `app/tool/*.dart`.
  - `packages/atv_remote` is analysed with `--fatal-infos`.
- **Scripts:**
  - **`.ps1`:** runs under Windows PowerShell 5.1 (`powershell -File`). No `&&`, `??` or ternaries.
  - **`.sh`:** `#!/usr/bin/env bash` with `set -euo pipefail`.
  - **Xcode build phases:** `/bin/sh` POSIX, no bashisms.
  - **Line endings:** every `*.sh` is LF (already in `.gitattributes`).
  - **Dart helpers:** `app/tool/*.dart` import only `dart:` libraries.
  - **Formatting:** `tool/check.ps1` and `tool/check.sh` add `app/tool` to their format lists (Task 9.1).
- **Non-negotiables (CLAUDE.md):**
  - **No competitor material:** never copy code, assets, text or branding from competitor apps, including anything in `docs/competitor-analysis/`. All store copy, review replies and legal text are written fresh from our own facts. Task 9.9 bans the competitor's names and its store title phrase "Remote for Android TV" by test.
  - **No "Google" in the name or icon:** no "Google" in the app name, the store name fields, the subtitle, the keywords, the icon or the feature graphic. "for Android TV" appears in descriptive text and in the placeholder name `Remotely for Android TV` (decision #12) only.
  - **No secrets:** no keystore, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `env/*.json` (except `example.json`), `secrets.properties`, `Secrets.xcconfig`, RevenueCat key or real ad id is ever created in or committed to the repo. Test fixtures use obviously fake values in a temp directory (P9-R2). **Claude never creates the upload keystore** (P9-R1).
  - **All TV I/O lives in `packages/atv_remote`.**
- **Strings:**
  - No new or changed ARB strings in Phase 9. A task that finds it needs one stops and reports the key and copy to the controller.
  - Store copy is not ARB; it lives in `docs/release/store-listing/`.
- **Platform branches** use `defaultTargetPlatform`; tests use `testWidgetsOn(...)` from `test/helpers/platform_override.dart`. After Task 9.5, nothing in `app/lib` uses `dart:io`'s `Platform`, and a scan test enforces it.
- **Accessibility and layout:** the Phase 8 rules stand.
  - **Text size:** every changed screen is tested at 320 dp and 200 % text with the non-linear scaler, in light and dark.
  - **Layout:** use `EdgeInsetsDirectional` in touched layout code.
  - **Text is never cut** except where P9-R9 allows it.
- **Tests:**
  - **Time:** production code uses `clock`, and tests use fake time.
  - **Real processes:** tests that run a real process (`git`, `sh`, `powershell`, `dart`) skip with `markTestSkipped('<tool> is not on the PATH')` when the tool is missing, and give each process a 60 s timeout.
  - **Fixtures:** fixture trees live under `Directory.systemTemp.createTempSync('release_fixture_')` and are deleted in `addTearDown`.
- **Goldens:**
  - One `*_golden_test.dart` per subject, `@Tags(['golden'])`, generated on Windows with `flutter test --update-goldens --tags golden <path>`. Inspect every new PNG.
  - **A golden that changes outside its task's "Expected re-baselines" list is a defect.** The only new baseline in this phase is `docs/release/store-assets/feature_graphic.png` (Task 9.10).
- **Where commands run:** `flutter` and `dart` from `app/` (or `packages/atv_remote/`); `check.ps1`, the release wrappers and `git` from the repo root.
- **Before every commit:** `powershell -File tool/check.ps1` must print `All checks passed.`. Note: a full check is already running on this tree when Phase 9 starts, so wait for it rather than starting a second one (learnings: a stalled run can be stopped and rerun).
- **Commits** end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Knowledge files:**
  - Don't edit `docs/knowledge/{status,decisions,learnings}.md`, `CLAUDE.md` or `.claude/skills/*`. Put knowledge and skill updates in your task report; the controller applies them.
  - **Exception:** Task 9.12 owns the Phase 9 rows of `docs/knowledge/device-matrix.md`.
- **Owner, device and Mac work** is marked **[owner]**, **[device]** or **[Mac]**. An implementer who can't run it says so in the report and never claims it passed. Anything that only a Mac can prove is labelled **(unverified, Mac)** in code comments and docs.

## Rulings (conflicts and open questions resolved for this phase)

1. **P9-R1 — Scope: prepare everything, sign and submit nothing.**
   - **In scope:**
     - scripts that check and build;
     - native scaffolding that is inert without the owner's files;
     - code carry-overs;
     - documents and images;
     - fixture-based tests.
   - **Out of scope, all [owner]:**
     - **Accounts and records:** creating any account, project, app record, product or ad unit.
     - **Signing and real config:** generating the upload keystore or any signing key; writing real config or ids.
     - **Hosting:** hosting pages or `app-ads.txt`.
     - **Uploads:** uploading any build.
     - **Tracks and review:** the closed test (12 testers × 14 days), TestFlight and review submission.
     - **Device and Mac runs:** the real-device matrix and the Mac checks.
     - **Sign-offs:** the Malay sign-off, and choosing the final app name and bundle id.
   - **Throwaway key material:** no task creates a keystore, not even a throwaway one. The positive signing path is proven by the owner (DM-105).
2. **P9-R2 — One release checker in Dart; two thin wrappers.**
   - **The checker:** `app/tool/release_check.dart` (no package imports), run as `dart tool/release_check.dart --platform android|ios [--stage pre|manifest|post] [--root <repo>]` from `app/`.
     - `--stage` defaults to `pre`; `--root` defaults to the repo root, two directories above the script.
     - **Output:** each problem prints one line, `REFUSED [<code>] <message>`, then `<n> problem(s). Fix them before a store build.`. A pass prints `All <platform> <stage> release checks passed.`.
     - **Exit codes:** 0 pass, 1 refused, 64 usage error.
     - **One run reports every problem**, in the table's order.
   - **Checks** (all paths relative to `--root`):

     | Code | Platform | Stage | Refuses when |
     |---|---|---|---|
     | `env-missing` | both | pre | `app/env/prod.json` is missing or not a JSON object. The env-dependent checks below are then skipped. |
     | `firebase-disabled` | both | pre | `FIREBASE_ENABLED` is not the JSON boolean `true` |
     | `revenuecat-android` | both | pre | `REVENUECAT_ANDROID_KEY` doesn't match `^goog_[A-Za-z0-9]+$`, which also rules out empty and `test_` Test Store keys |
     | `revenuecat-ios` | both | pre | `REVENUECAT_IOS_KEY` doesn't match `^appl_[A-Za-z0-9]+$` |
     | `banner-android`, `banner-ios` | both | pre | `ADMOB_BANNER_*` doesn't match `^ca-app-pub-\d{16}/\d{10}$`, or uses Google's test publisher `3940256099942544` |
     | `interstitial-android`, `interstitial-ios` | both | pre | `ADMOB_INTERSTITIAL_*` is **non-empty** and fails the banner rule (interstitials are off by default, decision #41, so empty is allowed) |
     | `ump-debug` | both | pre | `UMP_DEBUG_GEOGRAPHY` or `UMP_TEST_DEVICE_ID` is non-empty |
     | `firebase-android-config` | android | pre | `app/android/app/src/prod/google-services.json` is missing, isn't JSON, or has no `client[].client_info.android_client_info.package_name` equal to the prod application id |
     | `firebase-ios-config` | ios | pre | `app/ios/config/prod/GoogleService-Info.plist` is missing or its `BUNDLE_ID` isn't the prod id |
     | `admob-app-android` | android | pre | `admobAppIdProd` in `app/android/secrets.properties` is missing, empty, the example's placeholder (contains `XXXXXXXX`), Google's test publisher, or doesn't match `^ca-app-pub-\d{16}~\d{10}$` |
     | `admob-app-ios` | ios | pre | the same rules for `ADMOB_APP_ID_PROD` in `app/ios/Flutter/Secrets.xcconfig` |
     | `signing` | android | pre | `app/android/key.properties` is missing, lacks any of `storeFile`, `storePassword`, `keyAlias`, `keyPassword`, or its `storeFile` doesn't exist. A leading `~/` means the home directory (P9-R3). |
     | `secrets-tracked` | both | pre | `git ls-files` lists any never-commit path (the `store-release` list). A path named in the message. If git can't list the files, the message says so. |
     | `placeholder-links` | both | pre | `app/lib/app/app_links.dart` still contains `example.com` (privacy, terms or support address; the message names which) |
     | `app-store-id` | ios | pre | `app_links.dart` still contains `id0000000000` |
     | `manifest-missing` | android | manifest, post | no `AndroidManifest.xml` under `app/build/app/intermediates/merged_manifest*/prodRelease/` (the newest one is used) |
     | `manifest-backup` | android | manifest, post | the merged `<application>` lacks `android:allowBackup="false"`, `android:fullBackupContent="false"` or `android:dataExtractionRules="@xml/data_extraction_rules"` (the message names which) |
     | `manifest-target-sdk` | android | manifest, post | the merged `<uses-sdk android:targetSdkVersion>` is below `35` (Global Constraints; the owner confirms Play's current floor) |
     | `manifest-admob-id` | android | post | the merged `com.google.android.gms.ads.APPLICATION_ID` value uses Google's test publisher |
     | `artifact-missing` | both | post | `app/build/app/outputs/bundle/prodRelease/app-prod-release.aab` (Android), or no `*.ipa` in `app/build/ios/ipa/` (iOS) |
     | `debug-signed` | android | post | the certificate printer's output for the AAB contains `CN=Android Debug`, or the printer returned `null` (signature unreadable, for example keytool not found) |

   - **The prod application id** is read from `app/lib/app/flavor.dart`: the `applicationId` of `prod`. `flavor_config_test` already keeps the native ids equal to it.
   - **Wrappers:**
     - **Invocation:** `tool/release.ps1 -Platform android|ios [-DryRun] [-Root <dir>]` and `tool/release.sh --platform android|ios [--dry-run] [--root <dir>]`.
     - **Steps:**
       1. Pre-checks. On refusal: `No build was made.`, exit 1.
       2. `-DryRun`: `Dry run: every pre-build check passed. No build was made.`, exit 0.
       3. iOS off a Mac: `iOS store builds need a Mac (flutter build ipa).`, exit 1.
       4. Delete the previous artifact, so the post-check can't pass on a stale file.
       5. From `<root>/app`, build:
          - Android: `flutter build appbundle --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json`
          - iOS: `flutter build ipa --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json`
          - Then the post-checks. On refusal: `Do not upload <path>.`, exit 1.
       6. Print `Built <path>`, the size, the SHA-256 (`Get-FileHash` / `shasum -a 256`), the pubspec `version:`, and `Next: upload it to the internal test track (docs/release/runbook.md).`
     - **The certificate printer** runs `keytool -printcert -jarfile <aab>`, with keytool found from `JAVA_HOME/bin`, then `PATH`.
   - **No obfuscation** (`--obfuscate`) in v1: Crashlytics stack traces stay readable without uploading Dart symbols.
   - **Fixtures** use fake values that fit each format:
     - `goog_fixtureAndroidKey` and `appl_fixtureIosKey`;
     - `ca-app-pub-1234567890123456/1234567890` and `ca-app-pub-1234567890123456~1234567890`;
     - a 4-byte dummy store file.

     These are not secrets and never leave the temp directory.
3. **P9-R3 — Android release signing.** In `build.gradle.kts`, reading `rootProject.file("key.properties")`, which is `app/android/key.properties`:
   - **Present and complete, with an existing `storeFile`:**
     - A `release` signing config with `storeFile`, `storePassword`, `keyAlias` and `keyPassword` is used by the `release` build type of both flavors.
     - `storeFile` may be absolute or start with `~/` (replaced by `System.getProperty("user.home")`). Anything else is relative to `app/android/`.
   - **Present but incomplete, or `storeFile` missing:** any requested release task fails with a `GradleException` that names the file and the problem:
     - `android/key.properties is incomplete: <keys> missing. See android/key.properties.example.`
     - `android/key.properties points at <path>, which doesn't exist. Restore the upload keystore from your backup, or fix storeFile.`
   - **Absent:**
     - A requested task matching `(?i)bundle\w*prod\w*release` fails with: `A prod app bundle is the file you upload to Google Play, so it must be signed with the upload key: copy android/key.properties.example to android/key.properties and fill it in (store-release skill). Release APKs and dev bundles still build, signed with the debug key.`
     - Every other release task falls back to debug signing and logs `release build signed with the debug key (no android/key.properties); don't upload it.` This keeps `flutter run --release` and the prodRelease APK for manifest checks.
   - **The example file:** `app/android/key.properties.example` (committed) holds the four keys with placeholder values and the `keytool` command from the runbook as a comment. It isn't git-ignored (the `key.properties` pattern matches only the exact name).
   - **Misplaced `google-services.json`:** the scan for files in unsupported locations runs **whatever the flavors have**, not only when none has a file. The locations are the module root, `src/{debug,release,profile}/` and `src/{dev,prod}{Debug,Release,Profile}/`. Each match logs the existing warning.
4. **P9-R4 — The AdMob app id at upload time.**
   - **Upload artifacts refuse Google's test app id:** the Android prod bundle and the iOS archive. Other prod builds keep the test-id fallback with a warning, so a clean clone still builds and runs.
   - **Android:** a requested `bundle…Prod…Release` task with no valid `admobAppIdProd` (so the fallback would apply) fails with `A prod app bundle needs the real AdMob app id: set admobAppIdProd in android/secrets.properties.` The existing malformed-id `GradleException` stays.
   - **iOS:** `app/ios/scripts/check_admob_app_id.sh` is the **first** Runner build phase, "Check AdMob app id". It does nothing unless `$CONFIGURATION` ends in `-prod`. For prod configurations:
     - an empty `ADMOB_APP_ID`, a placeholder (`XXXXXXXX` or `YYYYYYYYYY` in it), or an id not matching `^ca-app-pub-[0-9]{16}~[0-9]{10}$` prints `error: …` and exits 1, because the SDK would stop the app at launch;
     - with `ACTION = install` (an Xcode archive, which `flutter build ipa` runs), Google's test publisher prints `error: …` and exits 1;
     - otherwise the test id prints `warning: prod uses Google's test AdMob app id; set ADMOB_APP_ID_PROD in ios/Flutter/Secrets.xcconfig` and exits 0.
   - **(unverified, Mac)** that `flutter build ipa` sets `ACTION=install`. DM-106 checks it.
5. **P9-R5 — iOS build plumbing and crash symbols.**
   - **Podfile:** `app/ios/Podfile` from Flutter 3.44.1's template (`packages/flutter_tools/templates/cocoapods/Podfile-ios` in the SDK), with three changes:
     - `platform :ios, '15.0'`;
     - `$FirebaseAnalyticsWithoutAdIdSupport = true` above the target, so Analytics never links the ad id, matching Android's `google_analytics_adid_collection_enabled=false` and decision #39 (`ad_*` always denied);
     - a `project 'Runner', {…}` map that lists all nine configurations: `Debug`, `Profile`, `Release` and the six `{Debug,Profile,Release}-{dev,prod}`, with Debug ones `:debug` and the rest `:release`.
   - **Per-flavor xcconfigs:** six files `app/ios/Flutter/{Debug,Profile,Release}-{dev,prod}.xcconfig`. Each holds `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.<config lower-case>.xcconfig"` then `#include "<Debug|Release>.xcconfig"` (Profile uses Release). Each of the six Runner build configurations takes its file as `baseConfigurationReference`. The plain `Debug`/`Release`/`Profile` keep theirs.
     - **(unverified, Mac):** that `pod install` then prints no "did not set the base configuration" warning (DM-106).
   - **dSYMs:** `app/ios/scripts/upload_crashlytics_symbols.sh` is the **last** Runner build phase, "Upload Crashlytics symbols", after "Copy Firebase config". It does nothing in these cases:
     - `$CONFIGURATION` doesn't start with `Release-`: `note: …`, exit 0;
     - `$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/GoogleService-Info.plist` is absent: `note: no Firebase config; no symbols uploaded`, exit 0;
     - `$PODS_ROOT/FirebaseCrashlytics/run` isn't executable: `warning: …`, exit 0.

     Otherwise it runs `"$PODS_ROOT/FirebaseCrashlytics/run" -gsp "<that plist>"`. The phase's input paths are Firebase's documented five:
     - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}`
     - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}`
     - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist`
     - `$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist`
     - `$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)`

     **(unverified, Mac):** the `-gsp` flag, and that user-script sandboxing lets the phase read them (DM-107).
   - **Android mapping files:** the Crashlytics Gradle plugin already uploads them for release builds of a flavor with its `google-services.json`, and `build.gradle.kts` already skips the upload for a flavor without one. No change; the owner sees it on the first real bundle (DM-107).
6. **P9-R6 — A fresh database forgets what described the old phone** (closes the restored-iPhone carry-over and the Try-again edge case).
   - **When:** bootstrap opens the database first. If this run created it (`AppDatabase.createdThisRun()`), it resets three preferences **before** the initial route is resolved:
     - `settings.onboarding_complete` → false. The new phone has no TVs; onboarding, the demo offer and the iOS Local Network explainer give iOS's prompt its context.
     - `privacy.att_preprompt_shown` → false. The ATT decision belongs to the device; our pre-prompt must come before iOS asks (decision #41).
     - `apps.shortcuts_seeded` → false. The flag describes the database. Clearing it at creation means a first start that fails after creating the database still seeds on Try again.
   - **Kept on purpose:** everything else, notably:
     - `review.launch_count`, `review.key_presses` and `review.prompt_shown`: they describe the user's experience with the app, not this phone. Resetting them would re-arm the review prompt on every new phone. Interstitials are off by default.
     - the privacy choices, the consent region and the theme and remote preferences: the user's own choices.
     - the cached Premium state: RevenueCat re-checks it.
   - **Errors:**
     - A database that can't open is reported (`safeRecordError`, reason `fresh database`) and changes nothing; the route resolver then handles the same error as today.
     - A failing preference write is reported and the start continues. Accepted residual: a crash between creating the database and the reset write leaves the Try-again edge case open for that one launch.
   - `shortcutsSeed`'s own `isNewStore()` check stays as a second guard.
7. **P9-R7 — Android 13+ per-app language.**
   - **Files:** `res/xml/locales_config.xml` lists exactly the locales of `lib/app/l10n/app_*.arb` (today `en`, `ms`), and the manifest's `<application>` gains `android:localeConfig="@xml/locales_config"`.
   - **Scope:** declaration only. The in-app picker stays the primary control. With the in-app language on "System default", the system's per-app choice reaches Flutter through the platform locales **(unverified, device)** (DM-103).
   - No `AppCompatDelegate` sync.
8. **P9-R8 — No `dart:io Platform` in `app/lib`.**
   - **The OS reader:** `app_info.dart` branches on `defaultTargetPlatform`. The OS-version fallback becomes `(os: osNameOf(platform), version: '?')`, never the kernel string.
   - **Feedback:** `feedback.dart`'s fallback `AppInfo` uses the same function.
   - **The scan:** `app/test/platform/no_dart_io_platform_test.dart` fails on any `app/lib` file matching `\bPlatform\.(is[A-Z]\w*|operatingSystem\w*|environment|localeName|numberOfProcessors|resolvedExecutable|pathSeparator)\b` or `import 'dart:io' show[^;]*\bPlatform\b`.
9. **P9-R9 — Text is never cut, on every page and in every error state** (closes P8-C15 and the 8.13 concern).
   - **Scope:** the Malay sweep (`l10n_overflow_test.dart`) checks **every** `RenderParagraph` on every screen it opens, not only titles and buttons: field labels, hints, helpers, errors and body text.
   - **Settings:** 320 dp at 200 % linear and with `NonlinearTwoXScaler`, in Malay and in the pseudo-locale.
   - **Allowed to ellipsize,** each only with the full text in semantics:
     - (a) app-bar titles (Phase 7 rule);
     - (b) user-entered TV names (P8-C14, the fixture names);
     - (c) text inside the Remote layout preview (decision #50).
   - **Error states:** the sweep also opens every error, failure and unavailable state. A coverage test fails when an ARB key whose name contains `Failed`, `Error`, `Unavailable`, `Offline` or `NotFound` is never rendered by the sweep, unless it is on an explicit allow-list with a reason per key (for example "snackbar only, covered by `<test>`").
   - **The fix rule** (Phase 8 practice): raise `maxLines`, `helperMaxLines` or `errorMaxLines` (6–10), or let the text wrap. Never shorten copy.
10. **P9-R10 — CLI hardening** (`packages/atv_remote`).
    - **Identity file:** `loadOrCreateIdentity` writes `<file>.tmp`, flushes, then renames it onto `identity.json`. A leftover `.tmp` is overwritten, and an existing `identity.json` is never touched.
    - **`hold`:** moves into `lib/src/cli/hold.dart` as `holdKey`.
      - **Ctrl+C** (SIGINT) during the hold releases the key (`endLong`), prints `Interrupted; released <key>.` and returns 130.
      - **A connection lost** mid-hold, which is a `StateError` from `sendKey`, prints `The connection to the TV closed during the hold.` and returns 1. It never surfaces as an uncaught error.
      - **Connect errors** print the existing messages, moved to `describeConnectError`.
    - **`pair`:** blocks in `stdin.readLineSync`, where a signal handler can't run. Ctrl+C there ends the process, and the TV cancels the pairing by itself. Accepted.
    - **`cliKeyCodes` coverage** was closed in Phase 8 by `cli_key_names_cover_named_exactly` (`test/key_codes_test.dart`); there is no further work.
    - **Gen scripts:** `tool/gen_proto.{ps1,sh}` record the protoc release (`36.2`), its download URL and the `protoc_plugin` version (`25.1.0`) in their header comments. They warn (not fail) when `protoc --version` isn't `libprotoc 36.2`.
11. **P9-R11 — Placeholders: one values file** (decision #35).
    - **The values file:** `docs/release/placeholders.json` maps each `TOKEN` to `{ "value": <string or null>, "about": "<what it is>", "code": "<AppLinks member or null>" }`. `null` means "not chosen yet".
    - **Docs:** use `{{TOKEN}}` only.
    - **Code:** `AppLinks` stays the one code location. A test keeps each `code`-linked token's value, or its placeholder, equal to `AppLinks`. The release check refuses the placeholders (P9-R2).
    - **The fill script:** `dart tool/fill_release_docs.dart` (from `app/`) renders every `docs/release/**/*.md` with values substituted into `build/release-docs/` (git-ignored by `build/`). It lists every unfilled token and exits 1 unless `--allow-missing`.
    - **Tokens:** `APP_NAME`, `DEVELOPER_NAME`, `DEVELOPER_ADDRESS`, `SUPPORT_EMAIL`, `SUPPORT_URL`, `PRIVACY_POLICY_URL`, `TERMS_URL`, `EFFECTIVE_DATE`, `ANALYTICS_RETENTION`, `GOVERNING_LAW`, `DEMO_VIDEO_URL`, `ADMOB_PUBLISHER_ID`, `APP_STORE_ID`, `PLAY_PACKAGE`.
    - **Today's code values** go into `value` where they exist:
      - `APP_NAME`: `Remotely for Android TV`;
      - `PLAY_PACKAGE`: `com.digitallinked.atvremote`;
      - `PRIVACY_POLICY_URL`, `TERMS_URL`, `SUPPORT_EMAIL` and `APP_STORE_ID`: the current `example.com` and `0000000000` placeholders.

      All other tokens start as `null`.
12. **P9-R12 — Legal pages are drafts written from our own facts.**
    - **Status:** both files start with `> DRAFT — not legal advice. The owner (and, if they choose, a lawyer) reviews this before it is hosted.`. Claude never hosts anything.
    - **The privacy policy states exactly these facts:**
      - **Stays on the phone:** TV names, network addresses, MAC addresses, the pairing certificate and TV key pins, shortcuts, the TV-app usage counts and settings. None is sent anywhere. Android backup and device transfer are off; on iOS the database is excluded from backups and the keychain item is this-device-only (decision #49).
      - **Local network:** direct TLS to the TV (ports 6466/6467), mDNS discovery, Wake-on-LAN on Android.
      - **Firebase Analytics:** the event catalogue in plain words (screens, onboarding, pairing and connection outcomes, sampled key names, app launches by catalogue package or "custom", layout, paywall and purchase events, the review prompt), the app instance id, and the approximate location Google derives from the IP. No ad id; the Privacy choices control; the tri-state default (decision #39).
      - **Firebase Crashlytics:** crash data, scrubbed (decision #39); the control; debug builds never send.
      - **Firebase Remote Config and Installations:** always fetched, for switches and the minimum version, with the Installation ID.
      - **AdMob:** the free version only, on the Apps and Settings screens; the advertising id (iOS only with ATT allowed); IP-derived location; personalised ads only with UMP consent where required; Ad privacy choices; Premium means no ads.
      - **UMP:** stores the consent choice on the phone.
      - **RevenueCat:** an anonymous app user id and store transactions to confirm Premium; payments are handled by Google Play / the App Store.
      - **Feedback email:** sent by your mail app, with the app and OS version.
      - **General:** no accounts; nothing sold; not directed at children under 13; retention (`{{ANALYTICS_RETENTION}}`, Crashlytics 90 days); rights and contact; the effective date.
    - **The terms cover:**
      - the licence to use;
      - compatibility (Android TV / Google TV with the Remote Service; no guarantee for every TV);
      - Premium (prices shown in the store, auto-renewal, cancel in the store, refunds per store policy, lifetime is one payment);
      - Apple's standard EULA for App Store users;
      - the trademark notice (`aboutTrademark`, verbatim);
      - no warranty and limited liability;
      - governing law `{{GOVERNING_LAW}}`;
      - contact.
13. **P9-R13 — Store copy.**
    - **Files:** `docs/release/store-listing/en.md` and `ms.md`. Each field is a heading `## <id> (max <n>)` followed by one fenced `text` block.
    - **Fields:**

      | Id | Max |
      |---|---|
      | `play.title` | 30 |
      | `play.short_description` | 80 |
      | `play.full_description` | 4000 |
      | `appstore.name` | 30 |
      | `appstore.subtitle` | 30 |
      | `appstore.promotional_text` | 170 |
      | `appstore.description` | 4000 |
      | `appstore.keywords` | 100 |
      | `release_notes` | 500 |
      | `shot.phone.01`–`08` | 40 each |
      | `shot.tablet.01`–`02` | 40 each |
      | `feature_graphic.title` | 20 |
      | `feature_graphic.tagline` | 40 |

    - **Length** is counted after filling tokens from `placeholders.json`, with `null` values counted as their `{{TOKEN}}` text.
    - **Names:** `play.title` and `appstore.name` are `{{APP_NAME}}`.
    - **No third-party trademarks** in the names, the subtitle, the keywords, the captions or the feature-graphic text. That includes Google, Android, Netflix, YouTube and other app or brand names. The descriptions may say the app works with Android TV and Google TV, and end with the trademark notice.
    - **Claims:** every claim is something the app does today (spec goals); nothing about voice, widgets or watches (v1.1).
    - **Malay:** `ms.md` starts with `Status: UNREVIEWED — needs the owner's sign-off (DM-068) before use.`
14. **P9-R14 — Store images.**
    - **The feature graphic:** 1024×500, opaque, rendered by `BrandMarkPainter` plus `feature_graphic.title`/`.tagline` in Roboto. It is a golden whose baseline is `docs/release/store-assets/feature_graphic.png` (the brand accent background `#3D5AFE`, white text).
    - **Screenshots:** a two-pass generator.
      1. Pump the real screen through `pumpRouterApp` at the logical size and device pixel ratio, and capture it with `RenderRepaintBoundary.toImage` inside `runAsync`.
      2. Pump a `StoreFrame` (store canvas; caption band in the top 18 %; the screen image centred at 78 % of the width with corners of 6 % of the width; accent background, white Roboto Medium caption) and write the PNG.
    - **Sizes:**

      | Set | Canvas | App size (dp) @ ratio |
      |---|---|---|
      | Play phone | 1080×1920 | 412×732 @ 2.625 |
      | Play tablet | 2560×1600 | 1280×800 @ 2 |
      | iPhone 6.9″ | 1320×2868 | 440×956 @ 3 |
      | iPad 13″ (landscape) | 2752×2064 | 1376×1032 @ 2 |

      App Store sets render with `TargetPlatform.iOS`. Each set comes in `en` and `ms` (Malay captions UNREVIEWED).
    - **Data:**
      - a connected `FakeRemoteSession` on "Living Room TV";
      - custom shortcuts named Movies, Music, News, Sports, Kids and Photos;
      - **no third-party app names or logos**;
      - no demo badge and no ads (the banner slot stays empty);
      - real fonts (Roboto and MaterialIcons from the SDK's `material_fonts`).
    - **Output:** `build/store-screenshots/<set>/<locale>/<nn>_<id>.png`, written only when `STORE_SCREENSHOTS_OUT` is set. `tool/store_screenshots.ps1`/`.sh` set it and run the generator. The PNGs are never committed.
15. **P9-R15 — Store form defaults** (drafts in `docs/release/forms/`; the owner pastes and confirms).
    - **Play:**
      - **Ads:** contains ads = **Yes**.
      - **Target audience:** **18+ only** (keeps the app out of the Families policy).
      - **App access:** every feature needs an Android TV; the demo is reached from onboarding → "Try demo".
      - **Content rating:** an IARC utility app with no objectionable content; digital purchases **Yes**; users interact **No**; shares location with other users **No**. Expected rating: Everyone / PEGI 3.
    - **Data safety:**
      - **Collected:** advertising ID, Firebase Installation ID, app set ID; approximate location; crash logs and diagnostics; app interactions; purchase history.
      - **Encrypted in transit:** Yes.
      - **Sold:** none.
      - **Account deletion:** N/A, no accounts.
      - **Deletion requests:** by email to `{{SUPPORT_EMAIL}}`.
    - **Apple App Privacy:**
      - **Data types:** Identifiers (Device ID), Usage Data (Product Interaction, Advertising Data), Diagnostics (Crash Data, Performance Data), Purchases (Purchase History), Location (Coarse Location).
      - **Linked to the user:** No.
      - **Tracking:** Yes (the IDFA after ATT allows).
      - Each row says which SDK collects it and links the vendor's disclosure page for the owner to confirm.
    - **Age rating:** 4+.
    - **SKAdNetwork:** v1 ships Google's own id `cstr6suwn9.skadnetwork` only, because there is no mediation (decision #5). `forms/skadnetwork.md` records the source page and how to add Google's third-party buyer list if the owner chooses.
    - **AdServices permissions** (`ACCESS_ADSERVICES_*`, merged from play-services-ads): **kept** by default. The draft gives the `tools:node="remove"` lines if the owner removes them.
    - **Export compliance:** the draft recommends "uses only exempt, standard encryption (TLS)" and `ITSAppUsesNonExemptEncryption = NO`, but **Info.plist isn't changed**: it is a legal declaration for the owner.
16. **P9-R16 — Deferred, with reasons** (also in the exit table):
    - **Device and Mac work:** every device-matrix row and Mac check, the battery threshold, TalkBack/VoiceOver, Switch/Voice Access and the DM-006/010 captures.
    - **`ExcludeSemantics` while theater-dimmed:** only if DM-069 says so.
    - **Collapsing the Apps banner with the keyboard up:** only if AdMob flags it.
    - **The predictive-back private class name:** at the next Flutter bump.
    - **D-pad wedge depth below 160 dp:** only if the device run shows mis-taps.
    - **Real app icons:** owner default "no".
    - **The real Malaysian app ids:** need the TV (device run).
    - **iOS Wake-on-LAN:** needs Apple's multicast entitlement.
    - **CI and fastlane uploads:** v1.1, per the `store-release` skill.

## Review Focus

1. **A prod store artifact built from a tree that is missing any config, key or real id.** Expected: no upload artifact is produced, and the user is told every missing item at once, each in plain words. Tests: Task 9.1 `reports_every_problem_at_once`, `refuses_each_missing_service_key_with_its_own_reason`; Task 9.2 `a_prod_bundle_without_key_properties_or_the_admob_id_is_refused`; Task 9.3 `admob_check_script_behaviour`.
2. **A `key.properties` with a typo'd store path or a missing key.** Expected: the build stops and names the file and the problem; it never silently debug-signs. Test: Task 9.2 `a_broken_key_properties_fails_with_a_clear_message`, plus the Step 4 Gradle runs.
3. **`env/prod.json` left with Google's test ad units, a Test Store RevenueCat key, or `UMP_DEBUG_GEOGRAPHY=eea` from testing.** Expected: refused, because prod would ship test ads, no Premium or a forced EEA form. Tests: Task 9.1 `refuses_google_test_ad_units`, `refuses_revenuecat_keys_of_the_wrong_store_or_the_test_store`, `refuses_ump_debug_settings_in_prod`.
4. **A restored or Quick-Start iPhone whose first start fails after the database is created, then Try again.** Expected: it behaves as a fresh install: onboarding, our pre-prompt before iOS's, the region's default shortcuts. The theme and privacy choices are kept. Tests: Task 9.4 `try_again_after_a_failed_first_start_still_seeds_the_apps_row`, `a_restored_iphone_starts_on_onboarding_with_its_choices_kept`.
5. **Ctrl+C or a dropped Wi-Fi during `atv_cli hold`, and a crash while the CLI writes its identity.** Expected: the key is released on the TV, the tool exits with a message (not a stack trace), and the identity file is never left half-written. Tests: Task 9.7 `hold_releases_the_key_when_interrupted`, `hold_reports_a_dropped_connection_instead_of_throwing`, `a_failed_write_never_leaves_a_partial_identity`.

---

## File Structure

```
tool/
  release.ps1, release.sh                     wrappers: pre-checks → build → post-checks       (9.1)
  check.ps1, check.sh                         format app/tool                                   (9.1)
  gen_proto.ps1, gen_proto.sh                 protoc 36.2 URL + version warning                 (9.7)
  store_screenshots.ps1, store_screenshots.sh run the screenshot generator                      (9.10)
app/
  tool/release_check.dart                     the checker (P9-R2)                               (9.1)
  tool/fill_release_docs.dart                 fills {{TOKEN}}s into build/release-docs/         (9.8)
  android/key.properties.example                                                                (9.2)
  android/app/build.gradle.kts                signing, bundle-time AdMob refusal, warning scan  (9.2)
  android/app/src/main/AndroidManifest.xml, res/xml/locales_config.xml                          (9.5)
  ios/Podfile; ios/Flutter/{Debug,Profile,Release}-{dev,prod}.xcconfig                          (9.3)
  ios/scripts/check_admob_app_id.sh, upload_crashlytics_symbols.sh                              (9.3)
  ios/Runner.xcodeproj/project.pbxproj        two phases, six xcconfig references               (9.3)
  lib/
    bootstrap.dart                            calls the fresh-database hook                     (9.4)
    core/storage/fresh_database.dart, settings_store.dart (resetForFreshDatabase)                (9.4)
    features/apps/application/shortcuts.dart  doc comment only                                  (9.4)
    core/app_info/app_info.dart, features/settings/application/feedback.dart                    (9.5)
    app/app_links.dart                        doc comments point at placeholders.json           (9.8)
    any page whose text the sweep finds cut   maxLines only                                     (9.6)
  test/
    tool/release_check_test.dart, tool/release_fixture.dart, tool/release_wrappers_test.dart    (9.1)
    platform/release_signing_test.dart, platform/ads_config_test.dart, platform/secrets_ignored_test.dart (9.2)
    platform/ios_release_test.dart                                                               (9.3)
    core/storage/fresh_database_test.dart, bootstrap_test.dart                                   (9.4)
    core/app_info/app_info_test.dart, platform/no_dart_io_platform_test.dart, platform/locale_config_test.dart (9.5)
    app/l10n_overflow_test.dart                                                                  (9.6)
    release/placeholders_test.dart, release/legal_docs_test.dart                                 (9.8)
    release/store_copy.dart, release/store_copy_test.dart                                        (9.9)
    helpers/real_fonts.dart; store_assets/{store_frame.dart, store_frame_test.dart,
      feature_graphic_golden_test.dart, store_screenshots_test.dart}                             (9.10)
    release/store_forms_test.dart                                                                (9.11)
    release/launch_ops_test.dart                                                                 (9.12)
    app/phase9_flow_test.dart                                                                    (9.13)
packages/atv_remote/
  lib/src/cli/identity_store.dart, lib/src/cli/hold.dart, lib/src/cli/messages.dart, bin/atv_cli.dart (9.7)
  test/cli_helpers_test.dart, test/cli_hold_test.dart, test/gen_scripts_test.dart               (9.7)
docs/release/
  placeholders.json                                                                              (9.8)
  legal/privacy-policy.md, legal/terms.md                                                        (9.8)
  store-listing/en.md, store-listing/ms.md                                                       (9.9)
  store-assets/feature_graphic.png, store-assets/screenshot-plan.md                              (9.10)
  forms/{play-data-safety, apple-app-privacy, content-rating, play-declarations, permissions,
         export-compliance, skadnetwork, adservices-permissions, app-ads-txt}.md                 (9.11)
  review/apple-review-notes.md, review/demo-video-script.md, rename-checklist.md                 (9.11)
  runbook.md; launch-ops/{crashlytics-alerts, kill-switch-checklist, review-response-plan, v1.1-backlog}.md (9.12)
docs/knowledge/device-matrix.md               section 11 (DM-103…DM-111), DM-060/061 expectations (9.12)
```

| Task | Master task | Deliverable | Needs |
|---|---|---|---|
| 9.1 | 9.2/9.3 + carry-over | Release checker, wrappers, fixture tests | — |
| 9.2 | 9.2 | Android signing scaffolding, bundle-time AdMob refusal, warning scan | owner proves the keystore path [owner] |
| 9.3 | 9.3 | iOS AdMob check, dSYM upload, Podfile, flavor xcconfigs | Mac [owner][Mac] |
| 9.4 | carry-over | Fresh-database preference rule; Try-again fix | — |
| 9.5 | carry-over | `defaultTargetPlatform` in app info; Android `localeConfig` | Android 13+ check [device] |
| 9.6 | carry-over | Full-page and error-state text sweep, and fixes | — |
| 9.7 | carry-over | CLI hardening; protoc release in the gen scripts | — |
| 9.8 | 9.1 | Placeholders file and fill script; privacy policy and terms (drafts) | owner hosts, legal review [owner] |
| 9.9 | 9.1 | Store copy EN + MS | Malay sign-off [owner] |
| 9.10 | 9.1 | Feature graphic; screenshot generator and plan | owner reviews images [owner] |
| 9.11 | 9.2/9.3 | Store-form drafts, review notes, demo-video script, rename checklist | owner pastes [owner] |
| 9.12 | 9.4 | Runbook, launch-ops docs, v1.1 backlog, device-matrix rows | — |
| 9.13 | exit | Seams, full check, no-config builds, the dry run | — |

**Order** (one implementer at a time in the shared tree):
- **9.1 → 9.2 → 9.3:** the checker defines the rules that the native guards mirror.
- **9.4–9.7** in order; they share no files.
- **9.8 before 9.9–9.12:** they use its tokens and the placeholder test.
- **9.9 before 9.10:** captions and graphic text come from the store copy.
- **9.6 before 9.10:** screenshots show the final layouts.
- **9.13 last.**

---

### Task 9.1: The release checker and the release wrappers

**Files:**
- Create: `app/tool/release_check.dart`, `tool/release.ps1`, `tool/release.sh`, `app/test/tool/release_fixture.dart`, `app/test/tool/release_check_test.dart`, `app/test/tool/release_wrappers_test.dart`
- Modify: `tool/check.ps1`, `tool/check.sh` (add `app/tool` to the format list)

**Interfaces:**
- Consumes: the P9-R2 table; `app/lib/app/flavor.dart` (read as text); `AdUnitIds` test values (`app/lib/core/ads/ad_unit_ids.dart`) for the fixtures.
- Produces (all in `app/tool/release_check.dart`):
  - `enum ReleasePlatform { android, ios }`, `enum ReleaseStage { pre, manifest, post }`
  - `final class Refusal { const Refusal(this.code, this.message); final String code; final String message; }` with value equality and `toString() => 'REFUSED [$code] $message'`
  - `typedef CertificatePrinter = Future<String?> Function(File artifact);`, `Future<String?> keytoolPrintCertificate(File artifact)`
  - `typedef TrackedFileLister = Future<List<String>?> Function(Directory root);`, `Future<List<String>?> gitTrackedFiles(Directory root)` (`null` when git is missing or `root` isn't a work tree)
  - `Future<List<Refusal>> checkRelease({required Directory root, required ReleasePlatform platform, ReleaseStage stage = ReleaseStage.pre, CertificatePrinter printCertificate = keytoolPrintCertificate, TrackedFileLister listTrackedFiles = gitTrackedFiles})`: refusals in the table's order. `manifest` runs only the `manifest`-stage rows; `post` runs the `manifest` and `post` rows.
  - `Future<void> main(List<String> args)`
  - In `release_fixture.dart`: `Directory writeReleaseFixture({Set<String> omit = const {}, Map<String, Object?> env = const {}, Map<String, String> files = const {}, bool gitInit = true})`. It writes a **complete** tree:
    - `app/env/prod.json`;
    - both Firebase files with the prod id;
    - `secrets.properties` and `Secrets.xcconfig`;
    - `key.properties` with an existing dummy `upload.jks`;
    - a mini `flavor.dart` and an `app_links.dart` with non-placeholder links (`https://legal.remotely.test/privacy`, `/terms`, `help@remotely.test`, `id1234567890`);
    - merged manifests and artifacts are written only via `files`.

    `omit` drops a path; `env` overrides keys; `files` adds or replaces files. `gitInit` runs `git init -q` and `git add -A`.

- [ ] **Step 1: Write the failing tests**

```dart
// release_check_test.dart: each test builds a fixture, calls checkRelease, and compares codes
test('a_complete_android_tree_passes_the_pre_checks', ...)          // [] for android pre
test('a_complete_ios_tree_passes_the_pre_checks', ...)              // [] for ios pre
test('refuses_a_missing_env_file', ...)                            // omit prod.json → exactly ['env-missing'] (env rows skipped)
test('refuses_firebase_disabled_or_not_a_boolean', ...)            // false, "true" → ['firebase-disabled'] each
test('refuses_each_missing_service_key_with_its_own_reason', ...)
    // for each of REVENUECAT_ANDROID_KEY, REVENUECAT_IOS_KEY, ADMOB_BANNER_ANDROID, ADMOB_BANNER_IOS set to '':
    // exactly its own code (both platforms check all four)
test('refuses_revenuecat_keys_of_the_wrong_store_or_the_test_store', ...)
    // ANDROID 'appl_x', 'test_x' → revenuecat-android; IOS 'goog_x' → revenuecat-ios
test('refuses_google_test_ad_units', ...)
    // banner = AdUnitIds.androidBanner → banner-android; interstitial = AdUnitIds.iosInterstitial → interstitial-ios
test('allows_empty_interstitial_ids', ...)                         // '' for both → []
test('refuses_ump_debug_settings_in_prod', ...)                    // UMP_DEBUG_GEOGRAPHY 'eea' / UMP_TEST_DEVICE_ID 'abc' → ['ump-debug']
test('refuses_missing_or_mismatched_firebase_config', ...)
    // android: omit → firebase-android-config; package_name 'com.other' → same; ios: omit / BUNDLE_ID other → firebase-ios-config
test('refuses_admob_app_ids_that_are_empty_placeholder_test_or_malformed', ...)
    // for '', 'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY', AdUnitIds.androidAppId, 'ca-app-pub-1234567890123456/1234567890':
    // android → admob-app-android; same values in Secrets.xcconfig, ios → admob-app-ios
test('refuses_android_signing_without_a_complete_key_properties', ...)
    // omit key.properties; drop keyAlias; storeFile → missing path; each → ['signing'], message names the problem
test('a_tilde_store_path_resolves_to_the_home_directory', ...)     // storeFile '~/x.jks' with HOME/USERPROFILE pointed at the fixture → []
test('refuses_tracked_secrets', ...)                               // files: app/env/prod.json committed via git add -f → secrets-tracked naming it
test('refuses_when_git_cannot_list_files', ...)                    // listTrackedFiles returns null → secrets-tracked, message says git couldn't list
test('refuses_placeholder_links', ...)                             // app_links.dart with example.com → placeholder-links (message names privacy/terms/support)
test('refuses_the_placeholder_app_store_id_on_ios_only', ...)      // id0000000000 → ios: app-store-id; android: []
test('reports_every_problem_at_once', ...)
    // gitInit true, every file omitted except flavor.dart and a placeholder app_links.dart →
    // android: ['env-missing','firebase-android-config','admob-app-android','signing','placeholder-links']
    // ios:     ['env-missing','firebase-ios-config','admob-app-ios','placeholder-links','app-store-id']
test('manifest_stage_refuses_a_missing_merged_manifest', ...)      // ['manifest-missing']
test('manifest_stage_refuses_each_missing_backup_attribute', ...)  // each of the three removed → manifest-backup naming it
test('manifest_stage_refuses_a_target_sdk_below_35', ...)          // 34 → manifest-target-sdk; 35 and 36 → []
test('post_stage_refuses_a_missing_bundle', ...)                   // ['artifact-missing']
test('post_stage_refuses_a_debug_signed_bundle', ...)              // printer → 'Owner: CN=Android Debug, O=Android, C=US' → debug-signed
test('post_stage_refuses_an_unreadable_signature', ...)            // printer → null → debug-signed, message says the signature couldn't be read
test('post_stage_refuses_the_test_admob_id_in_the_merged_manifest', ...) // APPLICATION_ID test value → manifest-admob-id
test('ios_post_stage_refuses_a_missing_ipa', ...)                  // ['artifact-missing']
test('cli_prints_one_line_per_refusal_and_exits_1', ...)
    // Process.run('dart', ['tool/release_check.dart','--platform','android','--root',fixture]) on the reports_every… tree:
    // 5 'REFUSED [' lines, last line '5 problem(s). Fix them before a store build.', exitCode 1
test('cli_passes_with_exit_0', ...)                                // complete tree → 'All android pre release checks passed.', 0
test('cli_exits_64_on_bad_arguments', ...)                         // '--platform windows' and no args → 64

// release_wrappers_test.dart (skip per tool when missing; ps1 only on Windows)
test('ps1_dry_run_refuses_an_empty_tree_and_builds_nothing', ...)
    // powershell -NoProfile -File ../tool/release.ps1 -Platform android -DryRun -Root <empty fixture>
    // → exit 1, stdout has the 5 REFUSED lines and 'No build was made.'; fixture has no app/build
test('ps1_dry_run_on_a_complete_tree_says_no_build_was_made', ...) // exit 0, 'Dry run: every pre-build check passed. No build was made.'
test('sh_dry_run_refuses_an_empty_tree_and_builds_nothing', ...)   // bash ../tool/release.sh --platform ios --dry-run --root <fixture>
test('sh_dry_run_on_a_complete_tree_says_no_build_was_made', ...)
test('ps1_refuses_an_ios_build_off_a_mac', ...)                    // complete tree, no -DryRun, -Platform ios on Windows → 1, 'iOS store builds need a Mac'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/tool`
Expected: FAIL (the checker and the wrappers don't exist).

- [ ] **Step 3: Implement**
  1. **The checker**, rule by rule in table order, with the message wording from P9-R2. Use plain `RegExp` and `jsonDecode`; read `.properties` and `.xcconfig` lines as `key = value`, ignoring comments and whitespace. For plists, use a regex for `<key>BUNDLE_ID</key>\s*<string>([^<]+)</string>`.
  2. **The fixture helper and the wrappers.** The wrappers find the checker as `<script dir>/../app/tool/release_check.dart` and pass `--root`. The real build runs only when not `-DryRun`.
  3. **`app/tool`** in both check scripts' format lists.
  4. `dart format tool test` from `app/`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/tool`
Expected: all PASS (wrapper tests skipped only where their shell is missing; say which in the report).

- [ ] **Step 5: Dry-run the real tree**

Run (repo root): `powershell -File tool/release.ps1 -Platform android -DryRun`, then the same with `-Platform ios`.
Expected: exit 1. Android lists `env-missing`, `firebase-android-config`, `admob-app-android`, `signing`, `placeholder-links`; iOS lists `env-missing`, `firebase-ios-config`, `admob-app-ios`, `placeholder-links`, `app-store-id`; both end with `No build was made.`. If this machine has local config files, the list is shorter: report the actual output.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/tool app/test/tool tool/release.ps1 tool/release.sh tool/check.ps1 tool/check.sh
git commit -m "feat(tool): release checker and wrappers that refuse an incomplete prod build" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- rulings P9-R1 and P9-R2;
- the real-tree dry-run output;
- which wrapper tests ran or were skipped;
- skill edits for `store-release`: the release-script checkbox becomes "done: `tool/release.ps1`/`.sh`, checks in `app/tool/release_check.dart`", plus the refusal code table.

---

### Task 9.2: Android release signing, the bundle-time AdMob refusal and the warning scan

**Files:**
- Create: `app/android/key.properties.example`, `app/test/platform/release_signing_test.dart`
- Modify: `app/android/app/build.gradle.kts`, `app/test/platform/ads_config_test.dart`, `app/test/platform/firebase_config_test.dart`, `app/test/platform/secrets_ignored_test.dart`

**Interfaces:**
- Consumes: P9-R3, P9-R4 (Android); the existing `admobAppIdProd`, `prodRequested` and `firebaseFlavors` values.
- Produces:
  - In `build.gradle.kts`:
    - `val keyPropertiesFile = rootProject.file("key.properties")`
    - `val releaseSigningProblem: String?` (null = usable or absent)
    - `val uploadBundleRequested = gradle.startParameter.taskNames.any { Regex("(?i)bundle\\w*prod\\w*release").containsMatchIn(it) }`
    - `signingConfigs { create("release") { … } }` only when usable
    - `buildTypes.release.signingConfig` = release when usable, else debug
    - the four P9-R3/P9-R4 messages verbatim
  - `key.properties.example`: `storeFile=~/keys/atvremote-upload.jks`, `storePassword=CHANGE_ME`, `keyAlias=upload`, `keyPassword=CHANGE_ME`, plus a comment with the owner's `keytool -genkeypair -v -keystore ~/keys/atvremote-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload` line and "back it up offline; losing it means a Play upload-key reset".

- [ ] **Step 1: Write the failing tests**

```dart
// release_signing_test.dart (string checks on the build script, like ads_config_test.dart)
test('release_signing_reads_key_properties_and_falls_back_to_debug_only_without_it', ...)
    // contains rootProject.file("key.properties"); the four keys; signingConfigs.getByName("debug") appears only in the
    // fallback expression; create("release") is guarded by the usable check
test('a_broken_key_properties_fails_with_a_clear_message', ...)
    // contains both P9-R3 messages ('is incomplete:', 'which doesn't exist') inside a GradleException that is thrown
    // when a release task is requested
test('a_prod_bundle_without_key_properties_or_the_admob_id_is_refused', ...)
    // contains the bundle regex and both bundle messages; the debug-key warning text for other release builds
test('a_tilde_store_path_means_the_home_directory', ...)            // 'removePrefix("~/")' or equivalent with user.home
test('the_example_lists_the_four_keys_with_placeholders', ...)      // key.properties.example parses to exactly the four keys, values CHANGE_ME / ~/keys/…

// firebase_config_test.dart
test('a_misplaced_google_services_file_is_reported_whatever_the_flavors_have', ...)
    // the unsupported-locations scan is not inside the else-branch of `if (firebaseFlavors.isNotEmpty())`
    // (it appears before that if, or after it, at top level)

// secrets_ignored_test.dart (extend secret_paths_are_ignored_by_git_and_the_example_is_not)
//   android/key.properties is ignored; android/key.properties.example is not
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/platform`
Expected: FAIL (no signing block, no example, the scan is still in the else-branch).

- [ ] **Step 3: Implement** P9-R3 and P9-R4 in `build.gradle.kts`; move the unsupported-location scan to top level; write `key.properties.example`; `dart format test`.
- [ ] **Step 4: Prove the Gradle behaviour** (from `app/`, no `key.properties`, no `secrets.properties`; each build may take minutes)

| Command | Expected |
|---|---|
| `flutter build appbundle --flavor prod -t lib/main_prod.dart` | fails; output contains `A prod app bundle is the file you upload to Google Play` |
| `flutter build apk --release --flavor prod -t lib/main_prod.dart` | succeeds; output contains `release build signed with the debug key` |
| `flutter build appbundle --flavor dev -t lib/main_dev.dart` | succeeds (dev bundles are never uploaded) |
| create `android/key.properties` with all four keys and `storeFile=does-not-exist.jks`, run the APK line | fails with `points at … does-not-exist.jks, which doesn't exist`; **then delete that `key.properties`** |
| the same file without `keyAlias` | fails with `is incomplete: keyAlias missing`; **delete it** |

Then confirm `git status` shows no `key.properties`. The bundle-time AdMob refusal can't be reached without `key.properties`, and Claude creates no keystore (P9-R1), so it is proven by the string test and by the owner (DM-105).

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test test/platform`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/android/app/build.gradle.kts app/android/key.properties.example app/test/platform
git commit -m "feat(android): upload-key signing from key.properties; prod bundles refuse the debug key and the test AdMob id" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- rulings P9-R3 and P9-R4 (Android);
- the Step 4 outputs (one line each);
- skill edit for `store-release` → "Versioning & signing": `key.properties` support is in, with a pointer to the example;
- the learnings line on how Flutter passes Gradle task names (what `taskNames` held).

---

### Task 9.3: iOS release scaffolding — AdMob check, dSYM upload, Podfile, flavor xcconfigs (unverified, Mac)

**Files:**
- Create: `app/ios/scripts/check_admob_app_id.sh`, `app/ios/scripts/upload_crashlytics_symbols.sh`, `app/ios/Podfile`, `app/ios/Flutter/{Debug-dev,Debug-prod,Profile-dev,Profile-prod,Release-dev,Release-prod}.xcconfig`, `app/test/platform/ios_release_test.dart`
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj`:
  - two `PBXShellScriptBuildPhase`s, in Runner's `buildPhases` first and last;
  - six `PBXFileReference`s, in the Flutter group;
  - six `baseConfigurationReference`s on the Runner flavor configurations.

  Use new 24-hex-digit ids that don't collide.

**Interfaces:**
- Consumes: P9-R4 (iOS) and P9-R5; the existing `Copy Firebase config` phase and `copy_firebase_config.sh` style.
- Produces: the two scripts (POSIX `sh`, `set -e` where safe, messages prefixed `error:`, `warning:` or `note:` so Xcode shows them), the Podfile and the six xcconfigs, all per P9-R4 and P9-R5.

- [ ] **Step 1: Write the failing tests**

```dart
// ios_release_test.dart
test('admob_check_runs_first_in_the_runner_build', ...)
    // Runner's buildPhases list starts with the "Check AdMob app id" phase; its shellScript runs scripts/check_admob_app_id.sh
test('crashlytics_symbols_upload_runs_last_after_the_firebase_config_copy', ...)
    // "Upload Crashlytics symbols" is the last Runner phase, after "Copy Firebase config"; inputPaths are P9-R5's five
test('admob_check_script_behaviour', ...)   // runs `sh scripts/check_admob_app_id.sh` with env; skip without sh
    // (CONFIGURATION, ACTION, ADMOB_APP_ID) → exit:
    // ('Debug-dev', 'build', '')                                    → 0
    // ('Release-prod', 'build', test id)                             → 0, stdout has 'warning:'
    // ('Release-prod', 'install', test id)                           → 1, 'error:'
    // ('Debug-prod', 'build', '')                                    → 1
    // ('Release-prod', 'build', 'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY') → 1
    // ('Release-prod', 'install', 'ca-app-pub-1234567890123456/1234567890') → 1
    // ('Release-prod', 'install', 'ca-app-pub-1234567890123456~1234567890') → 0
test('crashlytics_script_skips_without_config_and_runs_the_pods_tool_with_it', ...)
    // temp BUILT_PRODUCTS_DIR/PRODUCT_NAME.app and PODS_ROOT/FirebaseCrashlytics/run (a stub that writes "$@" to a file):
    // Debug-prod → 0, stub not run; Release-prod without the plist → 0, 'note: no Firebase config'; with it → 0,
    // stub got '-gsp <plist path>'; Release-prod with the plist but no stub → 0, 'warning:'
test('podfile_targets_ios_15_maps_every_configuration_and_drops_the_ad_id_from_analytics', ...)
    // platform :ios, '15.0'; $FirebaseAnalyticsWithoutAdIdSupport = true before `target 'Runner'`; all nine configuration
    // names mapped (Debug* → :debug, others → :release); flutter_install_all_ios_pods and flutter_additional_ios_build_settings kept
test('every_runner_flavor_configuration_includes_its_pods_xcconfig_then_the_shared_one', ...)
    // each of the six Runner configurations' baseConfigurationReference names its <Config>-<flavor>.xcconfig; each file's
    // first include is `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.<lower>.xcconfig"`, the second
    // `#include "Debug.xcconfig"` (Debug-*) or `#include "Release.xcconfig"` (Profile-*, Release-*)
test('the_scripts_have_lf_line_endings', ...)                       // no '\r' in either .sh (bytes)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/platform/ios_release_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
  1. The two scripts.
  2. The Podfile: copy the SDK template, then make the three P9-R5 changes.
  3. The six xcconfigs.
  4. The pbxproj edits by hand, keeping its tab indentation and sorted sections. Then check that `flavor_config_test`, `firebase_config_test` and `ios_malay_test` still pass (they parse the same file).
  5. `dart format test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/platform`
Expected: all PASS (script tests skipped only without `sh`).

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/ios/scripts app/ios/Podfile app/ios/Flutter/*-dev.xcconfig app/ios/Flutter/*-prod.xcconfig app/ios/Runner.xcodeproj/project.pbxproj app/test/platform/ios_release_test.dart
git commit -m "feat(ios): AdMob app id check, Crashlytics dSYM upload, Podfile at 15.0 and per-flavor Pods xcconfigs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

**[owner][Mac]:** DM-106 (pod install with no base-configuration warning; the two builds and the archive refusal) and DM-107 (dSYMs reach Crashlytics).

Report:
- ruling P9-R5;
- the new pbxproj ids;
- every (unverified, Mac) point;
- skill edits for `store-release` → iOS checklist ("Podfile at 15.0, the AdMob Run Script and the dSYM upload are in; verify on the Mac: DM-106/107") and for `app-services` ("Analytics without the ad id on iOS: `$FirebaseAnalyticsWithoutAdIdSupport`").

---

### Task 9.4: A fresh database forgets what described the old phone

**Files:**
- Create: `app/lib/core/storage/fresh_database.dart`, `app/test/core/storage/fresh_database_test.dart`
- Modify: `app/lib/core/storage/settings_store.dart`, `app/lib/bootstrap.dart`, `app/lib/features/apps/application/shortcuts.dart` (doc comment), `app/test/bootstrap_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.createdThisRun()`, `SettingsStore` setters, `safeRecordError`, bootstrap's `openDatabase` seam.
- Produces:
  - `Future<void> SettingsStore.resetForFreshDatabase()`: sets `onboardingComplete`, `attPrepromptShown` and `shortcutsSeeded` to false and touches no other key.
  - `const Set<String> SettingsStore.freshDatabaseKeys` = those three key strings.
  - `Future<bool> forgetPhoneStateIfDatabaseIsNew({required SettingsStore settings, required Future<bool> Function() databaseIsNew, void Function(Object error, StackTrace stack)? onError})`: returns true when it reset. It never throws: errors go to `onError` and it returns false.
  - Bootstrap calls it right before `resolveInitialLocation`, with `databaseIsNew: () => container.read(appDatabaseProvider).createdThisRun()` and `onError` → `safeRecordError(…, reason: 'fresh database')`.

- [ ] **Step 1: Write the failing tests**

```dart
// fresh_database_test.dart
test('a_fresh_database_resets_onboarding_the_att_preprompt_and_the_seeded_flag', ...)
    // prefs: the three true; databaseIsNew → true → returns true; the three read false
test('an_existing_database_keeps_every_preference', ...)            // databaseIsNew → false → false; nothing written
test('launch_count_review_and_privacy_choices_survive_a_fresh_database', ...)
    // every key in SettingsStore.keys minus freshDatabaseKeys set to a non-default value; after the reset each is unchanged
test('fresh_database_keys_are_the_three_of_the_ruling', ...)        // == {'settings.onboarding_complete', 'privacy.att_preprompt_shown', 'apps.shortcuts_seeded'}
test('a_database_that_cannot_open_is_reported_and_changes_nothing', ...)
    // databaseIsNew throws SqliteException → onError called once; returns false; prefs unchanged
test('a_failing_preference_write_is_reported_and_the_start_continues', ...)
    // failing_preferences helper (install before the store opens) → onError once; returns false
test('try_again_after_a_failed_first_start_still_seeds_the_apps_row', ...)
    // temp file DB: run 1 = AppDatabase(NativeDatabase(file)), restored prefs (three true), hook → reset; close (the start "fails")
    // run 2 = new AppDatabase on the same file: createdThisRun() false; a ProviderContainer with the real shortcutsSeedProvider,
    // the drift ShortcutRepository, test catalogue, region MY → shortcuts == the MY default row

// bootstrap_test.dart
testWidgets('a_restored_iphone_starts_on_onboarding_with_its_choices_kept', ...)
    // iOS; prefs: onboarding_complete, att_preprompt_shown, shortcuts_seeded true, theme dark, launch_count 7,
    // privacy.share_usage false; openDatabase → in-memory (fresh) → initial location == AppRoutes.onboarding; theme still dark;
    // share_usage still false; launch_count 8 after the start; att_preprompt_shown false
testWidgets('a_phone_with_its_database_keeps_skipping_onboarding', ...)
    // the same prefs, a database that already existed (createdThisRun false) → AppRoutes.discover; att_preprompt_shown true
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/storage/fresh_database_test.dart test/bootstrap_test.dart`
Expected: FAIL (no hook, no reset).

- [ ] **Step 3: Implement** the store method, the hook and the bootstrap call (P9-R6). Update `shortcutsSeed`'s doc comment: the flag is now cleared at creation; `isNewStore()` stays as a second guard. `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS. In particular, `settings_keys_hold_no_tv_data` and the Phase 7 onboarding tests are unchanged.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): a fresh database resets onboarding, the ATT pre-prompt and the seeded flag; Try again still seeds" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- ruling P9-R6 (amends #49's "a fresh DB re-seeds" to "a fresh DB resets three preferences");
- the new DM-060/061 expectations for Task 9.12;
- the learnings line: preferences that describe the device or the database are reset at database creation.

---

### Task 9.5: `defaultTargetPlatform` for the OS reader, and Android per-app languages

**Files:**
- Create: `app/android/app/src/main/res/xml/locales_config.xml`, `app/test/platform/no_dart_io_platform_test.dart`, `app/test/platform/locale_config_test.dart`
- Modify: `app/lib/core/app_info/app_info.dart`, `app/lib/features/settings/application/feedback.dart`, `app/android/app/src/main/AndroidManifest.xml`, `app/test/core/app_info/app_info_test.dart`, the feedback test that covers the fallback (`app/test/features/settings/` — extend the existing file)

**Interfaces:**
- Consumes: `DeviceInfoPlugin` (inside the provider only), `defaultTargetPlatform`.
- Produces (in `app_info.dart`):
  - `String osNameOf(TargetPlatform platform)`: `Android`, `iOS`, `macOS`, `Windows`, `Linux`, `Fuchsia`.
  - `({String os, String version}) fallbackOsVersion(TargetPlatform platform)` → `(os: osNameOf(platform), version: '?')`.
  - `Future<({String os, String version})> readOsVersionFor(TargetPlatform platform, {required Future<String> Function() androidRelease, required Future<String> Function() iosSystemVersion})`: Android → `(os: 'Android', version: await androidRelease())`, iOS → `('iOS', …)`, others → `fallbackOsVersion(platform)`.

  `osVersionReaderProvider`'s default calls it with `defaultTargetPlatform` and the plugin reads. `_osVersionOrFallback` uses `fallbackOsVersion(defaultTargetPlatform)`. `feedback.dart`'s fallback `AppInfo` takes `os`/`osVersion` from it. No `dart:io` import remains in either file.
- `locales_config.xml`: `<locale-config xmlns:android=…>` with `<locale android:name="en"/>` and `<locale android:name="ms"/>`; the manifest gets `android:localeConfig="@xml/locales_config"` on `<application>` (P9-R7).

- [ ] **Step 1: Write the failing tests**

```dart
// app_info_test.dart
test('reads_the_android_release_on_android', ...)   // readOsVersionFor(android, androidRelease: () async => '12', …) == ('Android','12')
test('reads_the_ios_system_version_on_ios', ...)    // ('iOS','17.5')
test('other_platforms_use_the_fallback', ...)        // windows → ('Windows','?'); neither reader is called
test('a_failing_or_slow_reader_falls_back_to_the_target_platform', ...)
    // testWidgetsOn android: reader throws / exceeds osVersionTimeout (fake time) → appInfo.os 'Android', osVersion '?'
// feedback test
testWidgets('feedback_falls_back_to_the_target_platform_when_app_info_fails', ...)
    // iOS, appInfoProvider throws → the mail body footer says 'System: iOS ?'
// no_dart_io_platform_test.dart
test('app_lib_never_uses_dart_io_platform', ...)     // P9-R8 regexes over every app/lib/**.dart except *.g.dart → no match (list offenders)
// locale_config_test.dart
test('android_declares_its_app_languages', ...)      // manifest has android:localeConfig="@xml/locales_config"
test('the_locale_config_lists_exactly_the_arb_locales', ...)
    // locale names in locales_config.xml == the suffixes of lib/app/l10n/app_*.arb ({'en','ms'})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/app_info test/platform test/features/settings`
Expected: FAIL.

- [ ] **Step 3: Implement**; `dart format lib test`. Then `flutter build apk --debug --flavor dev -t lib/main_dev.dart` and confirm that the merged devDebug manifest keeps `localeConfig` and the three backup attributes. Report the path.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test app/android/app/src/main
git commit -m "fix(app): branch on defaultTargetPlatform for the OS name; declare the app's languages for Android 13" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- rulings P9-R7 and P9-R8;
- the merged-manifest path;
- the DM-103 row for Task 9.12;
- skill edit for `flutter-app-architecture`: the no-`dart:io Platform` scan test.

---

### Task 9.6: Full-page and error-state text sweep

**Files:**
- Modify: `app/test/app/l10n_overflow_test.dart`; only if the sweep finds cut text, the `maxLines`/`helperMaxLines`/`errorMaxLines` of the owning widgets under `app/lib/features/**` or `app/lib/app/widgets/**`
- Test: the same file

**Interfaces:**
- Consumes: `forEachScreen`, `_truncated(RenderParagraph)`, `_expectTitlesAndButtonsReadable`, `NonlinearTwoXScaler`, `PseudoLocalizations`, the in-memory repositories and the failing seams (`DiskException`, failing preferences, `FakePurchaseService` unavailable, `FakePairingClient` failures).
- Produces:
  - `void _expectAllTextReadable(WidgetTester t, String why)`: every `RenderParagraph` on screen that `_truncated` reports fails, unless one of P9-R9's three exceptions holds **and** an ancestor `Semantics` label contains the full text. The failure message names the screen, the text and the widget path.
  - Error-state openers added to `forEachScreen`:
    - Apps (shortcuts read fails);
    - Edit apps (fails);
    - Your TVs (saved devices fail);
    - Edit TV (the device is gone or fails);
    - discovery (empty after 10 s, NSD start fails);
    - pairing (each `PairingFailure`, identity load fails, the code timeout);
    - the paywall (unavailable, purchase fails, restore fails);
    - the update gate (blocking);
    - Privacy (services off);
    - the remote (not connected, identity changed).

    Use the existing seams; add a seam only in `test/helpers/`.
  - `const Map<String, String> _errorKeysNotInSweep` (key → reason).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('every_screen_shows_all_its_text_whole_in_malay_at_200_percent', ...)   // forEachScreen(ms, linear 2.0) → _expectAllTextReadable
testWidgets('every_screen_shows_all_its_text_whole_with_a_non_linear_scaler', ...)  // ms, NonlinearTwoXScaler
testWidgets('every_screen_shows_all_its_text_whole_in_the_pseudo_locale', ...)      // pseudo, linear 2.0
testWidgets('every_error_state_fits_320dp_in_malay_at_200_percent_text', ...)       // the new openers, light and dark
test('every_error_string_is_opened_by_the_sweep', ...)
    // ARB keys matching /(Failed|Error|Unavailable|Offline|NotFound)/ minus _errorKeysNotInSweep ⊆ the keys the sweep
    // rendered (record the rendered Malay strings and map back through app_ms.arb); every allow-list reason is non-empty
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/l10n_overflow_test.dart`
Expected: FAIL. List every cut text it reports; Phase 8 expected some on full pages (the shortcut editor helper was one).

- [ ] **Step 3: Fix each cut text** in the owning widget by P9-R9's rule. No copy changes. `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** none. A `maxLines` change shows in a golden only when the text overflowed at 100 % with Ahem; if one changes, list it with its fix.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): every page and error state shows its text whole in Malay at 200 percent" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- ruling P9-R9 (closes P8-C15 and the 8.13 concern);
- each fix (file, widget, old → new limit);
- the allow-list with reasons;
- skill edit for `remote-design-system`: "help and error text: `maxLines` 6–10; the sweep checks every paragraph".

---

### Task 9.7: CLI hardening and the protoc release in the gen scripts

**Files:**
- Create: `packages/atv_remote/lib/src/cli/hold.dart`, `packages/atv_remote/lib/src/cli/messages.dart`, `packages/atv_remote/test/cli_hold_test.dart`, `packages/atv_remote/test/gen_scripts_test.dart`
- Modify: `packages/atv_remote/lib/src/cli/identity_store.dart`, `packages/atv_remote/bin/atv_cli.dart`, `packages/atv_remote/test/cli_helpers_test.dart`, `tool/gen_proto.ps1`, `tool/gen_proto.sh`

**Interfaces:**
- Consumes: `RemoteClient`, `RemoteConnectException`, `KeyDirection`; `FakeTvServer` (`package:atv_remote/testing.dart`) with `trustClient`, `receivedKeyCodes`, `receivedKeyDirections`, `dropConnections`.
- Produces:
  - `String describeConnectError(RemoteConnectException e, String host)`: `Not paired - run: pair <host>` for `certificateRejected`, otherwise `Could not connect: <reason>[ (<message>)]`. Same text as today.
  - `Future<int> holdKey({required RemoteClient client, required int keyCode, required String keyName, required Duration hold, required Future<void> interrupted, required StringSink out, required StringSink err})`:
    - **Steps:** connect, `startLong`, then wait for whichever comes first of `hold` and `interrupted`. Then `endLong` if `client.isReady`, a 300 ms settle, and `client.close()`.
    - **Returns:**
      - 0 with `Held <keyName> for <ms> ms.`;
      - 130 with `Interrupted; released <keyName>.`;
      - 1 with `describeConnectError` on a connect error;
      - 1 with `The connection to the TV closed during the hold.` on a `StateError`.
    - Never throws either of those.
  - `Future<ClientIdentity> loadOrCreateIdentity(File file, {Future<void> Function(File file, String contents) writeFile = writeFlushed})`, with `Future<void> writeFlushed(File file, String contents)` (`writeAsString(flush: true)`). It writes `File('${file.path}.tmp')`, then renames it onto `file` (P9-R10).
  - `bin/atv_cli.dart`: `_hold` calls `holdKey(…, interrupted: ProcessSignal.sigint.watch().first.then((_) {}))`; `_printConnectError` uses `describeConnectError`.
  - The gen-script header lines:
    - `# protoc 36.2: https://github.com/protocolbuffers/protobuf/releases/tag/v36.2`, naming the asset (`protoc-36.2-win64.zip` in `.ps1`; `protoc-36.2-linux-x86_64.zip` / `protoc-36.2-osx-universal_binary.zip` in `.sh`), unzipped into `tool/bin/`;
    - `# protoc_plugin 25.1.0: dart pub global activate protoc_plugin 25.1.0`;
    - a check that warns `protoc is <x>; the generated code was made with libprotoc 36.2` when `protoc --version` differs.

- [ ] **Step 1: Write the failing tests**

```dart
// cli_hold_test.dart (a paired FakeTvServer per test; timeouts on conditions, P8 rule)
test('hold_sends_start_long_then_end_long_after_the_hold', ...)    // hold 200 ms → 0; receivedKeyDirections for the code == [startLong, endLong]
test('hold_releases_the_key_when_interrupted', ...)
    // hold 30 s; complete `interrupted` once startLong is seen → returns 130 within 2 s; directions end with endLong;
    // out contains 'Interrupted; released home.'
test('hold_reports_a_dropped_connection_instead_of_throwing', ...)
    // after startLong, server.dropConnections(); `interrupted` completes 100 ms later → returns 1; err contains
    // 'closed during the hold'; no uncaught error (runZonedGuarded collects none)
test('hold_reports_an_unpaired_identity', ...)                      // fresh identity → 1; err 'Not paired - run: pair 127.0.0.1'

// cli_helpers_test.dart
test('a_failed_write_never_leaves_a_partial_identity', ...)
    // writeFile writes half the contents to the .tmp then throws → the call throws; identity.json does not exist
test('a_leftover_temp_file_is_replaced', ...)                       // stale identity.json.tmp present → creates; .tmp gone; identity.json parses
test('an_existing_identity_is_never_rewritten', ...)                // second call: writeFile never called; same modulus

// gen_scripts_test.dart (reads ../../tool/gen_proto.{ps1,sh})
test('gen_scripts_record_the_protoc_release_and_plugin_version', ...)
    // both contain '36.2', 'releases/tag/v36.2' and 'protoc_plugin 25.1.0'; ps1 names win64, sh names linux-x86_64 and osx
test('gen_scripts_warn_on_another_protoc_version', ...)             // both contain '--version' and 'libprotoc 36.2'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run (from `packages/atv_remote/`): `flutter test test/cli_hold_test.dart test/cli_helpers_test.dart test/gen_scripts_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**; `dart format lib test bin`; `dart analyze --fatal-infos`. If `tool/bin/bin/protoc.exe` exists, run `tool/bin/bin/protoc.exe --version` and report what it prints. If it isn't 36.2, report it and **don't** change the pin.
- [ ] **Step 4: Run the package tests and confirm they pass**

Run: `flutter test` (from `packages/atv_remote/`)
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add packages/atv_remote tool/gen_proto.ps1 tool/gen_proto.sh
git commit -m "fix(atv_remote): CLI hold releases the key on Ctrl+C and reports a lost connection; atomic identity file; protoc release in the gen scripts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- ruling P9-R10;
- the protoc version found;
- skill edit for `atv-remote-protocol` → CLI: hold/SIGINT behaviour, and that the identity file is written atomically;
- the learnings line on `ProcessSignal.sigint` on Windows.

---

### Task 9.8: Placeholders file, fill script, privacy policy and terms (drafts)

**Files:**
- Create: `docs/release/placeholders.json`, `docs/release/legal/privacy-policy.md`, `docs/release/legal/terms.md`, `app/tool/fill_release_docs.dart`, `app/test/release/placeholders_test.dart`, `app/test/release/legal_docs_test.dart`
- Modify: `app/lib/app/app_links.dart` (doc comments only: "value from `docs/release/placeholders.json` → `<TOKEN>`; the release check refuses the placeholder")

**Interfaces:**
- Consumes: P9-R11, P9-R12; `AppLinks`; `app_en.arb` (`privacyUsageTitle`, `privacyCrashTitle`, `privacyAdChoices`, `aboutTrademark`, the `settingsPrivacy` page title key).
- Produces:
  - `placeholders.json` (P9-R11). The `code` field is `AppLinks.privacyPolicy`, `AppLinks.terms`, `AppLinks.supportEmail` or `AppLinks.appStoreListing` for those four tokens.
  - In `fill_release_docs.dart`:
    - `final class FillResult { final List<File> written; final Set<String> missing; }`
    - `Future<FillResult> fillReleaseDocs({required Directory root, required Directory out})`
    - `main(['--allow-missing'?])`, which writes to `<root>/build/release-docs/` and exits 1 when `missing` is non-empty unless the flag is given.
  - The two legal drafts (P9-R12), using only registered tokens.

- [ ] **Step 1: Write the failing tests**

```dart
// placeholders_test.dart
test('every_token_in_docs_release_is_registered', ...)       // every {{X}} in docs/release/**/*.md is a key of placeholders.json
test('every_registered_token_is_used_or_marked_code_only', ...) // each key appears in some doc, or has a non-null `code`
test('app_links_match_the_placeholder_values', ...)
    // AppLinks.privacyPolicy.toString() == PRIVACY_POLICY_URL.value; terms; supportEmail; appStoreListing ends with 'id' + APP_STORE_ID.value
test('no_other_lib_file_holds_a_link_or_support_address', ...)
    // no app/lib file but app_links.dart contains 'https://', 'http://' or an e-mail address (list offenders);
    // generated l10n files are excluded
test('fill_replaces_every_token_and_lists_the_missing_ones', ...)
    // temp root with a doc '{{A}} {{B}}' and values {A: 'x', B: null} → written file 'x {{B}}', missing == {'B'}
test('fill_never_writes_inside_docs', ...)                    // every written path is under out

// legal_docs_test.dart
test('legal_docs_are_marked_draft_until_the_owner_reviews_them', ...) // both start with the P9-R12 DRAFT line
test('privacy_policy_names_every_service_the_app_uses', ...)
    // contains 'Firebase Analytics', 'Firebase Crashlytics', 'Firebase Remote Config', 'Firebase Installation',
    // 'AdMob', 'User Messaging Platform', 'App Tracking Transparency', 'RevenueCat', 'Google Play', 'App Store'
test('privacy_policy_says_what_never_leaves_the_phone', ...)
    // mentions TV name, network address, MAC address, backup, device transfer (case-insensitive)
test('privacy_policy_matches_the_in_app_controls', ...)       // contains the English ARB values of the privacy titles verbatim
test('terms_cover_premium_renewal_and_the_trademark_notice', ...)
    // 'renew', 'cancel', 'refund', 'Lifetime', Apple's EULA link text, and aboutTrademark verbatim
test('legal_docs_never_name_the_competitor', ...)             // no 'Remote ATV', 'Simha' (case-insensitive)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/release`
Expected: FAIL.

- [ ] **Step 3: Write** the JSON, the script and the two drafts from P9-R12's facts. Every fact must match the code and decisions, so read `analytics_events.dart`, `crash_scrubber.dart` and decision #39 before writing. Then `dart format tool test`.
- [ ] **Step 4: Run the tests and the fill script**

Run: `flutter test test/release` → all PASS. Then `dart tool/fill_release_docs.dart` → exit 1 listing the `null` tokens; then `dart tool/fill_release_docs.dart --allow-missing` → exit 0, files under `build/release-docs/`.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add docs/release app/tool/fill_release_docs.dart app/test/release app/lib/app/app_links.dart
git commit -m "docs(release): placeholder values in one file, privacy policy and terms drafts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- rulings P9-R11 and P9-R12;
- any fact you couldn't confirm from the code (marked `[owner to confirm]` in the draft);
- skill edit for `store-release`: "placeholders: `docs/release/placeholders.json` + `AppLinks`; fill with `app/tool/fill_release_docs.dart`".

---

### Task 9.9: Store copy in English and Malay

**Files:**
- Create: `docs/release/store-listing/en.md`, `docs/release/store-listing/ms.md`, `app/test/release/store_copy.dart`, `app/test/release/store_copy_test.dart`

**Interfaces:**
- Consumes: P9-R13; `placeholders.json`; `aboutTrademark` (en and ms ARB); the spec's goals (what the app does).
- Produces (in `store_copy.dart`, a test helper Task 9.10 reuses):
  - `final class StoreField { final String id; final int max; final String text; }`
  - `Map<String, StoreField> parseStoreCopy(String markdown)`: it throws `FormatException` on a heading without exactly one following `text` block, or on a duplicate id.
  - `String fillTokens(String text, Map<String, String?> values)`
  - `Map<String, StoreField> loadStoreCopy(String locale)` (reads `../docs/release/store-listing/<locale>.md`)

- [ ] **Step 1: Write the failing tests**

```dart
test('both_languages_have_exactly_the_p9_r13_fields', ...)     // the id set of en and ms == P9-R13's list (with 01–08, 01–02)
test('every_field_is_within_its_store_limit', ...)             // fillTokens(text).length <= max, en and ms, reason names the id
test('names_are_the_app_name_token', ...)                      // play.title and appstore.name text == '{{APP_NAME}}'
test('name_fields_keywords_captions_and_graphic_text_carry_no_trademarks', ...)
    // after filling (APP_NAME's 'for Android TV' is the only allowed hit, in the two name fields):
    // no /google|android|netflix|youtube|disney|prime video|spotify|apple tv|hbo|viu|iqiyi|chromecast|roku|fire tv|samsung/i
test('descriptions_end_with_the_trademark_notice', ...)        // play.full_description and appstore.description end with that locale's aboutTrademark
test('copy_never_borrows_from_the_competitor', ...)            // no 'Remote ATV', 'Simha', 'Remote for Android TV' (any case)
test('copy_promises_nothing_v1_lacks', ...)                    // no /voice|widget|watch|siri|alexa/i
test('malay_copy_is_marked_unreviewed', ...)                   // ms.md's first line is the P9-R13 status line
test('the_parser_rejects_a_heading_without_a_block', ...)      // parseStoreCopy('## x (max 5)\n') throws FormatException
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/release/store_copy_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write the copy** in our own words.
  - **English:** plain, the same voice as the app (decision #12 tone), naming real features:
    - discovery and pairing;
    - touchpad, D-pad and numbers;
    - volume, the keyboard, the app shortcuts row;
    - Wake-on-LAN (Android);
    - several TVs; demo mode;
    - light/dark and colour styles (Premium); no ads with Premium;
    - privacy (TV details stay on the phone).
  - **Malay:** follows the Phase 8 glossary (P8-R8).
  - **Captions:** match P9-R14's shot list.

  Then `dart format test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/release`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add docs/release/store-listing app/test/release/store_copy.dart app/test/release/store_copy_test.dart
git commit -m "docs(release): store listing copy in English and Malay (Malay unreviewed)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- ruling P9-R13;
- the Malay terms you weren't sure of, for DM-068.

---

### Task 9.10: Feature graphic and the screenshot generator

**Files:**
- Create:
  - `app/test/helpers/real_fonts.dart`
  - `app/test/store_assets/store_frame.dart`, `store_frame_test.dart`, `feature_graphic_golden_test.dart`, `store_screenshots_test.dart`
  - `docs/release/store-assets/feature_graphic.png` (golden baseline), `docs/release/store-assets/screenshot-plan.md`
  - `tool/store_screenshots.ps1`, `tool/store_screenshots.sh`
- Modify: `app/test/app/l10n_short_labels_test.dart` (use `loadRealFonts`; behaviour unchanged)

**Interfaces:**
- Consumes: `BrandMarkPainter` (`test/branding/brand_mark.dart`); `loadStoreCopy` and `fillTokens` (Task 9.9); `pumpRouterApp`, `FakeRemoteSession`, `InMemoryShortcutRepository`, `testDevices`; P9-R14.
- Produces:
  - `Future<void> loadRealFonts()` (Roboto regular/medium/bold and MaterialIcons from the SDK's `material_fonts`, the `_materialFonts()` lookup moved here).
  - `enum StoreSet { playPhone, playTablet, iphone69, ipad13 }`, each with `Size canvas`, `Size appSize`, `double pixelRatio` and `TargetPlatform platform` per the P9-R14 table.
  - `final class StoreShot { final String id; final String captionField; final StoreSet set; final Future<void> Function(WidgetTester t) open; }`
  - `const List<StoreShot> storeShots`:
    - **phone** (each on `playPhone` and `iphone69`):
      1. `01_touchpad`: the remote, Touchpad;
      2. `02_dpad`: the remote, D-pad;
      3. `03_apps`: the Apps screen;
      4. `04_keyboard`: the keyboard sheet open, "Hello" typed;
      5. `05_discovery`: discovery with two TVs found;
      6. `06_pairing`: the pairing code page;
      7. `07_styles`: Appearance with a style chosen, dark;
      8. `08_tvs`: Your TVs with three TVs;
    - **tablet** (each on `playTablet` and `ipad13`):
      1. `01_split`: the remote, split layout;
      2. `02_apps`: Apps.
  - `class StoreFrame extends StatelessWidget { const StoreFrame({required StoreSet set, required ui.Image screen, required String caption}); }`
  - `Future<ui.Image> captureScreen(WidgetTester t, StoreShot shot, Locale locale)`, `Future<Uint8List> renderFramed(WidgetTester t, StoreShot shot, Locale locale)`.

- [ ] **Step 1: Write the failing tests**

```dart
// store_frame_test.dart (always runs; small and fast)
test('every_store_set_matches_its_store_rules', ...)
    // canvases == the P9-R14 table; every side within the store's 320–3840 (Play) or exact Apple sizes;
    // appSize * pixelRatio fits inside the frame's screen rect
testWidgets('a_framed_shot_has_the_store_size_and_its_caption', ...)
    // StoreFrame(playPhone, a 4×4 solid image, 'Caption') → captured image 1080×1920; the caption Text is present
test('every_shot_has_a_caption_in_both_languages', ...)       // each shot's captionField exists in en and ms store copy
test('shots_show_no_third_party_app_names', ...)
    // the shortcut names used by the shots ∩ the catalogue's app names == ∅; no shot uses the demo session

// feature_graphic_golden_test.dart  @Tags(['golden'])
testWidgets('feature_graphic_1024x500', ...)   // loadRealFonts; matchesGoldenFile('../../../docs/release/store-assets/feature_graphic.png')
testWidgets('feature_graphic_is_opaque', ...)  // render → every pixel's alpha == 255 (Play rejects transparency)

// store_screenshots_test.dart (skips unless STORE_SCREENSHOTS_OUT is set)
testWidgets('generator_writes_every_shot', ...)
    // for each shot × {en, ms}: write <out>/<set>/<locale>/<id>.png; afterwards 40 files, each PNG decodes to its canvas size
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/store_assets`
Expected: FAIL.

- [ ] **Step 3: Implement**:
  - the helpers, frame and shots;
  - `flutter test --update-goldens --tags golden test/store_assets/feature_graphic_golden_test.dart`, then **inspect** the PNG;
  - the two tool scripts (set `STORE_SCREENSHOTS_OUT` to `<repo>/build/store-screenshots`, run `flutter test test/store_assets/store_screenshots_test.dart` from `app/`);
  - `screenshot-plan.md` (the P9-R14 tables, the shot list with captions, how to regenerate, the owner's review step, and how to upload per store);
  - `dart format test`.
- [ ] **Step 4: Run the generator and the tests**

Run: `powershell -File tool/store_screenshots.ps1`
Expected: `generator_writes_every_shot` passes and 40 PNGs exist under `build/store-screenshots/`. Open at least one of each set and confirm:
- real fonts (no Ahem boxes) and real icons;
- no ad, no demo badge, no clipped caption.

Then `flutter test` → all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/test/helpers/real_fonts.dart app/test/store_assets app/test/app/l10n_short_labels_test.dart docs/release/store-assets tool/store_screenshots.ps1 tool/store_screenshots.sh
git commit -m "feat(release): feature graphic from our own painter and a framed screenshot generator" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** **new** `docs/release/store-assets/feature_graphic.png`. Nothing else changes; `l10n_short_labels_test` results are identical.

Report:
- ruling P9-R14;
- generator timing;
- anything that rendered differently from the app on a device (input for DM-111);
- skill edits for `store-release` (listing assets: where the graphic and screenshots come from) and `remote-design-system` (store frame spec pointer).

---

### Task 9.11: Store-form drafts, review notes, demo-video script and the rename checklist

**Files:**
- Create:
  - `docs/release/forms/{play-data-safety, apple-app-privacy, content-rating, play-declarations, permissions, export-compliance, skadnetwork, adservices-permissions, app-ads-txt}.md`
  - `docs/release/review/{apple-review-notes, demo-video-script}.md`
  - `docs/release/rename-checklist.md`
  - `app/test/release/store_forms_test.dart`

**Interfaces:**
- Consumes: P9-R15; the merged prodRelease manifest (built in Step 3); `Info.plist`; `AndroidManifest.xml`; `placeholders.json`; the `store-release` skill checklists.
- Produces the drafts. Each starts with `> DRAFT for the owner to paste. Confirm every answer against the console's current wording.`
  - **`permissions.md`:**
    - our own manifest's permissions with a one-line reason each;
    - a "Merged from SDKs" table (permission, SDK, reason), copied from the merged manifest;
    - the AdServices keep/remove choice, pointing to `adservices-permissions.md`.
  - **`apple-review-notes.md`:**
    - the app needs an Android TV or Google TV on the same Wi-Fi;
    - the demo path (onboarding → Try demo; or discovery → Try demo);
    - `{{DEMO_VIDEO_URL}}`;
    - ATT and Local Network explained;
    - the three IAP product ids;
    - "not affiliated with Google";
    - where Restore is.
  - **`demo-video-script.md`:** a 60–90 s shot list:
    - fresh install → onboarding;
    - the Local Network prompt; discovery; pairing with the code on the TV;
    - D-pad, volume and keyboard on the real TV;
    - Apps; Settings → Privacy choices; the paywall with Restore;
    - each shot gives what's on the phone and what's on the TV;
    - no third-party content on the TV screen beyond the home screen.
  - **`rename-checklist.md`:** every file holding `com.digitallinked.atvremote`, `Remotely for Android TV`, `Remotely Dev` or `Remotely` (purpose strings, `DeviceInfo` client name), each with what to change. It includes the warning that the Play package name is permanent after the first upload.

- [ ] **Step 1: Write the failing tests**

```dart
test('forms_are_marked_draft', ...)                              // every forms/ and review/ file starts with the DRAFT line
test('permissions_doc_explains_every_permission_we_declare', ...)
    // every <uses-permission android:name> in app/android/app/src/main/AndroidManifest.xml appears in permissions.md
test('skadnetwork_doc_matches_info_plist', ...)                  // SKAdNetworkIdentifier values in Info.plist == the ids table in skadnetwork.md
test('privacy_forms_cover_every_sdk', ...)
    // play-data-safety.md and apple-app-privacy.md each name Firebase Analytics, Crashlytics, Remote Config, AdMob, RevenueCat
test('data_safety_lists_the_skill_data_types', ...)
    // 'Advertising ID', 'Firebase Installation ID', 'App set ID', 'Approximate location', 'Crash logs', 'Diagnostics',
    // 'App interactions', 'Purchase history'
test('apple_privacy_lists_coarse_location_and_performance_data_and_tracking', ...) // 'Coarse Location', 'Performance Data', 'Tracking: Yes'
test('rename_checklist_names_every_file_that_holds_the_name_or_id', ...)
    // scan app/android (src, gradle files), app/ios (Runner, Flutter/*.xcconfig, project.pbxproj), app/lib (not *.g.dart,
    // not l10n output) for the four strings → each hit's path appears in rename-checklist.md
test('review_notes_give_the_demo_path_and_the_video_token', ...) // 'Try demo' and '{{DEMO_VIDEO_URL}}'
test('app_ads_txt_template_uses_the_publisher_token', ...)       // 'google.com, {{ADMOB_PUBLISHER_ID}}, DIRECT, f08c47fec0942fa0'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/release/store_forms_test.dart`
Expected: FAIL.

- [ ] **Step 3: Build and read the prod merged manifest**

Run (from `app/`): `flutter build apk --release --flavor prod -t lib/main_prod.dart` (no config; debug-signed per P9-R3).
Then: `dart tool/release_check.dart --platform android --stage manifest`
Expected: `All android manifest release checks passed.` (closes the prodRelease re-check carry-over). Copy every `<uses-permission>` of the merged manifest into `permissions.md`.

- [ ] **Step 4: Write the drafts** (P9-R15). Every answer cites its source: a decision, the skill, or the vendor disclosure page, given as the URL for the owner to open. `dart format test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test test/release`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add docs/release/forms docs/release/review docs/release/rename-checklist.md app/test/release/store_forms_test.dart
git commit -m "docs(release): store form drafts, review notes, demo video script and the rename checklist" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- ruling P9-R15;
- the merged-manifest path and its permission list;
- the manifest-stage output;
- skill edits for `store-release` (forms now drafted; links to `docs/release/forms/`; merged-manifest path under AGP 9).

---

### Task 9.12: Release runbook, launch-ops docs, v1.1 backlog and the Phase 9 device-matrix rows

**Files:**
- Create: `docs/release/runbook.md`, `docs/release/launch-ops/{crashlytics-alerts, kill-switch-checklist, review-response-plan, v1.1-backlog}.md`, `app/test/release/launch_ops_test.dart`
- Modify: `docs/knowledge/device-matrix.md`:
  - a new `## 11. Phase 9 (release)` before `## Coverage`;
  - DM-060/061 "Also check" items (1)–(4) rewritten to the P9-R6 behaviour;
  - a `### Phase 9 tasks` coverage table.

**Interfaces:**
- Consumes:
  - `AppConfig`'s defaults and keys (`app/lib/core/config/app_config.dart`) and the `app-services` Remote Config list;
  - every [owner] item in this plan;
  - the master plan's Phase 7 v1.1 list;
  - P9-R16.
- Produces:
  - **`runbook.md`:** the owner's ordered steps, each with what to do, which command or console page, and which DM row or form it needs.
    1. Final name and ids (`rename-checklist.md`; before the first upload).
    2. Accounts (Play Console, Apple Developer; the 12-tester closed test clock).
    3. Firebase dev and prod projects and files (`store-release` table).
    4. AdMob apps, ad units and the UMP GDPR message (before Firebase is enabled in prod), then host `app-ads.txt`.
    5. RevenueCat project, entitlement, products, offering and keys; store products and sandbox testers.
    6. Host the legal pages; fill `placeholders.json` and `AppLinks`; run the fill script.
    7. Create the upload keystore (`keytool` line, offline backup) and `key.properties`; turn on Play App Signing.
    8. The Malay sign-off (DM-068) before the Malay listing.
    9. The device matrix gates (DM-056/057/060/061/058/059/066 and the Phase 9 rows).
    10. `tool/release.ps1 -Platform android -DryRun`, then the real run.
    11. Internal track → closed test (12 × 14 days) → production staged 10 % → 50 % → 100 % with the gates in `crashlytics-alerts.md`.
    12. On the Mac: Secrets, plist, `pod install`, `tool/release.sh --platform ios`, TestFlight internal → external, App Review with the notes.
    13. Launch week (`review-response-plan.md`, `kill-switch-checklist.md`).
  - **`crashlytics-alerts.md`:**
    - **Alerts:** new fatal issue, regressed issue, velocity alert; who gets them.
    - **Rollout gates:** halt if crash-free users < 99.5 % or a new fatal in discover/pair/connect.
    - **Play vitals:** user-perceived crash rate 1.09 % and ANR rate 0.47 %, as the bad-behaviour thresholds the owner confirms in the console.
  - **`kill-switch-checklist.md`:** for each of `ads_banner_enabled` and `ads_interstitial_enabled` (and `min_supported_version`):
    - console path → change → launch once (fetch) → launch again (applied, decision #40) → expected result → restore;
    - plus the code's defaults verbatim.
  - **`review-response-plan.md`:**
    - first-week cadence (daily, reply within 48 h);
    - categories (can't find the TV, pairing code, disconnects, ads, Premium/restore, a TV app won't open, requests);
    - one original reply per category in English (Malay drafts marked UNREVIEWED);
    - rules: never ask for IPs or TV names in public, point to Help, log a bug per pattern.
  - **`v1.1-backlog.md`:** a groomed table (item, why, size S/M/L, depends on):
    - home-screen widget; notification remote; voice search (#7); iOS App Intents / Siri Shortcuts (Guideline 4.2);
    - watch apps; iOS Wake-on-LAN (entitlement); mediation and the SKAdNetwork list;
    - CI with fastlane uploads;
    - the conditional P9-R16 items; `kImeTextMode` and the idle timeout after the device run (#10, #23).
  - **New device-matrix rows** (same columns and rules as the file; Result cells empty):
    - **DM-103:** Android 13+ per-app language (P9-R7).
    - **DM-104 [owner]:** a dry run on the owner's machine with real config → `All android pre release checks passed.`
    - **DM-105 [owner]:** the real Android release run. The AAB signer is the owner's upload certificate (`keytool -printcert -jarfile`); the internal track accepts it; it covers both P9-R3 refusals and the bundle-time AdMob refusal.
    - **DM-106 [Mac]:** `pod install` with no base-configuration warning; `flutter build ios --flavor prod --no-codesign` with no `Secrets.xcconfig` builds (with the warning); `flutter build ipa --flavor prod` without it fails at "Check AdMob app id".
    - **DM-107 [Mac][owner]:** dSYMs and Android mapping reach Crashlytics; a forced test crash is symbolicated.
    - **DM-108 [owner]:** a restored iPhone behaves per P9-R6. This replaces nothing; DM-060/061 are rewritten.
    - **DM-109 [owner]:** the kill switches per `kill-switch-checklist.md`.
    - **DM-110 [owner]:** a Crashlytics alert arrives for a test crash.
    - **DM-111 [owner]:** the generated screenshots match the app on a phone; no clipped captions.

- [ ] **Step 1: Write the failing tests**

```dart
// launch_ops_test.dart
test('kill_switch_checklist_names_the_real_keys_and_defaults', ...)
    // for ads_banner_enabled, ads_interstitial_enabled, min_supported_version: the key and the code default (read from
    // AppConfig's defaults) appear in kill-switch-checklist.md
test('runbook_links_only_files_that_exist', ...)              // every relative Markdown link in docs/release/**/*.md resolves to a file
test('runbook_covers_every_owner_item', ...)
    // contains: keystore, key.properties, Play App Signing, 12 testers, 14 days, staged, 10 %, 50 %, 100 %, TestFlight,
    // UMP, app-ads.txt, DM-068, placeholders.json
test('device_matrix_phase_9_rows_are_new_and_empty', ...)
    // DM-103…DM-111 exist once each under '## 11. Phase 9'; their Result, Device and Date cells are empty; ids unique file-wide
test('review_replies_are_our_own', ...)                       // no 'Remote ATV', 'Simha'; no request for an IP or MAC address
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/release/launch_ops_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write** the docs and the device-matrix edits (the file's rules: stable ids, empty results; DM-060/061 keep their ids). `dart format test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/release`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add docs/release/runbook.md docs/release/launch-ops docs/knowledge/device-matrix.md app/test/release/launch_ops_test.dart
git commit -m "docs(release): release runbook, launch ops, v1.1 backlog and the phase 9 device rows" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report:
- the v1.1 backlog summary for `status.md` (master 9.4 asks for it there; the controller links the file);
- skill edit for `store-release`: link the runbook.

---

### Task 9.13: Seams, the full check and the phase exit

**Files:**
- Create: `app/test/app/phase9_flow_test.dart`
- Modify: only what the tests reveal

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the seam tests**

```dart
testWidgets('a_restored_iphone_gets_onboarding_the_explainer_and_the_default_row', ...)
    // iOS, restored prefs (P9-R6's three true), fresh in-memory DB, region MY → onboarding → Get started → the Local
    // Network explainer → discovery; then a saved fake TV → the remote's quick row shows the MY default row
testWidgets('the_banner_kill_switch_applies_from_the_next_launch', ...)
    // launch 1: fake config source fetches ads_banner_enabled=false, the activated value is still true → /apps shows the
    // banner slot loading; launch 2 (same source) → no banner request on /apps or /settings; ads_interstitial_enabled stays false
test('the_release_check_and_the_native_guards_agree_on_the_admob_rules', ...)
    // the Android test app id refused by release_check (admob-app-android) is the same value build.gradle.kts falls back
    // to and refuses for bundles; the iOS one is the value check_admob_app_id.sh refuses on install
test('no_app_lib_file_uses_dart_io_platform', ...)            // re-runs Task 9.5's scan (listed for the exit)
test('every_release_doc_token_is_registered', ...)            // re-runs Task 9.8's check (listed for the exit)
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/phase9_flow_test.dart`
Expected: they may fail. A failure is a real defect: fix it in the owning file and name the fix.

- [ ] **Step 3: Run every test and the goldens**

Run: `flutter test` (from `app/`) and `flutter test` (from `packages/atv_remote/`)
Expected: all PASS. `git status` shows no golden changes beyond `feature_graphic.png` (9.10).

- [ ] **Step 4: Build with no config**

On a tree with no `google-services.json`, `env/*.json` (except the example), `secrets.properties`, `Secrets.xcconfig` or `key.properties`:

| Command (from `app/`) | Expected |
|---|---|
| `flutter build apk --debug --flavor dev -t lib/main_dev.dart` | succeeds |
| `flutter build apk --release --flavor prod -t lib/main_prod.dart` | succeeds with the debug-key warning |
| `dart tool/release_check.dart --platform android --stage manifest` | `All android manifest release checks passed.` |
| `flutter build appbundle --flavor prod -t lib/main_prod.dart` | fails with the P9-R3 bundle message |

- [ ] **Step 5: The dry run without config**

Run (repo root): `powershell -File tool/release.ps1 -Platform android -DryRun` and `-Platform ios -DryRun`; on Linux CI or Git Bash also `bash tool/release.sh --platform android --dry-run`.
Expected: exit 1 with the Task 9.1 Step 5 lists, every line a plain reason, and `No build was made.`. Paste the output into the report.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): phase 9 seams: restored iPhone, kill switch, AdMob rules agree" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Linux CI.** The controller opens the PR when the owner asks. The `check` job (`tool/check.sh`, 40 min) and the `goldens` job must pass. This closes the "run `tool/check.sh` / the Linux CI job on the PR" carry-over.

Report:
- every defect the tests found, with its fix;
- the Step 4–5 outputs;
- the status.md handoff text: the "Current phase", "Next up" and "Blocked / needs the owner" paragraphs, written to replace the current ones, using this plan's "Needs the owner".

---

## Phase exit checklist

- [ ] **Checks:**
  - `powershell -File tool/check.ps1` → `All checks passed.`;
  - the PR's Linux `check` and Windows `goldens` jobs pass;
  - a clean clone with no config builds the dev APK and the prod release APK;
  - the prodRelease merged manifest passes the manifest stage;
  - the prod bundle and both dry runs refuse with plain reasons.
- [ ] **Golden PNGs:**
  - **new:** `docs/release/store-assets/feature_graphic.png` (9.10);
  - **re-baselined:** any listed by 9.6 with its fix;
  - **unchanged:** every other golden.
- [ ] **No secrets:** `git ls-files` shows no never-commit path. `secrets_are_git_ignored` and the checker's `secrets-tracked` pass on the real tree.
- [ ] **Carry-overs:** every item of `status.md` "Carry-over to Phase 9+" is closed by a task report or deferred here.

  | Carry-over | Task / deferral |
  |---|---|
  | P8 gate: DM-056/057 (Android backup and transfer) | deferred [owner][device]: needs the devices; runbook step 9 gates upload on it |
  | P8 gate: DM-060/061 (iOS restore, Quick Start; DM-061 a release issue if the DB travels) | expectations rewritten for P9-R6 (9.12); run deferred [owner][device], runbook step 9 |
  | P8 gate: Mac DM-058/059, DM-066 | deferred [owner][Mac]: needs the Mac; runbook step 12 |
  | P8 gate: Malay sign-off DM-068 ("diendors", "memaparkan iklan", `paywallFreeForever`) | deferred [owner]: the owner's review; `ms.md` marked UNREVIEWED (9.9); runbook step 8 |
  | P8 gate: re-check the prodRelease merged manifest | 9.1 (`manifest`/`post` stages), run in 9.11 Step 3 and 9.13 Step 4 |
  | P8-C15 full-page field-text sweep; error states the Malay sweep never opens | 9.6 |
  | Restored iPhone `launch_count`, `att_preprompt_shown`, `onboarding_complete` | 9.4 (P9-R6: reset the last two, keep `launch_count`) |
  | Startup trace and battery runs; battery threshold | deferred [owner][device]: needs the Note10+ (DM-098/099/101/102); threshold set after the first measurement (P8-R5) |
  | TalkBack/VoiceOver, Switch/Voice Access rows; DM-006/010 captures | deferred [owner][device]: device run |
  | Android 13 `localeConfig` | 9.5 (P9-R7) |
  | Try-again `createdThisRun` edge case | 9.4 (the seeded flag is cleared at creation) |
  | `app_info.dart` `dart:io Platform` | 9.5 (P9-R8, plus `feedback.dart` and a scan) |
  | `tool/check.sh` / Linux CI on the PR | 9.13 Step 7 |
  | Later: theater `ExcludeSemantics` | deferred: DM-069 decides (P9-R16) |
  | Later: Apps banner collapse with the keyboard up | deferred: only if AdMob flags it (P9-R16) |
  | Later: predictive-back private class name | deferred: next Flutter bump (P9-R16) |
  | Later: D-pad wedge depth below 160 dp | deferred: only if the device run shows mis-taps (P9-R16) |
  | P6: `tool/release.ps1` refuses an incomplete prod build | 9.1 |
  | P6: iOS `check_admob_app_id.sh` Run Script | 9.3 |
  | P6: misplaced `google-services.json` warning across flavors | 9.2 |
  | P6: Crashlytics dSYM and mapping upload | 9.3 (iOS); Android plugin default, no change (P9-R5); proven by DM-107 [owner] |
  | P6: Podfile at 15.0 + `$FirebaseAnalyticsWithoutAdIdSupport` | 9.3 (P9-R5: set to true) |
  | P6: keep or remove the AdServices permissions | 9.11 draft with default "keep"; final choice [owner] |
  | P6: Data safety and App Privacy forms (approximate location, performance data) | 9.11 |
  | P6: SKAdNetwork buyer list | 9.11 (P9-R15: Google's id only for v1; how to extend) |
  | P6: App Store id for `appStoreListing` | deferred [owner]: exists only after the App Store Connect record; `app-store-id` refusal (9.1) and `APP_STORE_ID` token (9.8) |
  | P6: privacy policy naming Firebase (Installation IDs), AdMob/UMP, RevenueCat | 9.8 (draft; hosting [owner]) |
  | Signing: release builds are debug-signed; add `key.properties` | 9.2 (the keystore itself [owner]) |
  | Placeholders: links and support address (decision #35) | 9.8 (one values file, `AppLinks` kept in sync, release check refuses); values [owner] |
  | CLI: atomic identity file, SIGINT, the `hold` `StateError` | 9.7 |
  | CLI: `cliKeyCodes` coverage | closed in Phase 8 (`cli_key_names_cover_named_exactly`); verified in 9.7, no work |
  | protoc download URL and version in the gen scripts | 9.7 |
  | "Drift opens lazily": callers handle errors | standing rule; 9.4's hook follows it |

- [ ] **Knowledge updates.** The task reports collectively carry:
  - **Decisions:**
    - P9-R1–R16, recorded as decisions #51 (release check and native guards: R2–R5), #52 (fresh database: R6, amending #49), #53 (platform and text rules: R7–R9), #54 (CLI: R10), #55 (store material and placeholders: R11–R15, extending #35) and #56 (scope and deferrals: R1, R16);
    - no obfuscation in v1.
  - **Skills (controller edits):**
    - `store-release`: release script done, refusal codes, signing, iOS checklist, forms, runbook, placeholders, store images;
    - `app-services`: Analytics without the ad id on iOS; the fresh-database rule for ATT;
    - `flutter-app-architecture`: no `dart:io Platform` scan; the fresh-database hook in bootstrap;
    - `remote-design-system`: help/error `maxLines`, every-paragraph sweep, store frame;
    - `atv-remote-protocol`: CLI hold and identity.
  - **Learnings:**
    - Gradle `taskNames` as passed by `flutter build`;
    - the merged-manifest path under AGP 9;
    - `ProcessSignal.sigint` on Windows;
    - the real-font loading for store images;
    - generator timing;
    - the protoc version found.
  - **Status:**
    - Phase 9 preparation done;
    - "Next up" = the owner's runbook (accounts → config → keystore → device matrix → closed test), then Phase 9 execution with the owner;
    - the v1.1 backlog linked.

## Needs the owner

1. **Accounts:** a Google Play Console developer account and an Apple Developer account.
   - A new personal Play account needs a **closed test with 12 testers opted in for 14 continuous days** before production. Start recruiting now.
   - Add the developer name and address (`DEVELOPER_NAME`, `DEVELOPER_ADDRESS`).
2. **Final app name and bundle id** before the first Play upload (the package name is permanent), using `docs/release/rename-checklist.md`. Defaults: `Remotely for Android TV`, `com.digitallinked.atvremote`.
3. **Firebase:** dev and prod projects, the four config files in the `store-release` paths, and the Analytics data-retention setting (`ANALYTICS_RETENTION`).
4. **AdMob:**
   - apps and ad units, with the app ids in `secrets.properties` and `Secrets.xcconfig` and the units in `env/prod.json`;
   - **publish the UMP GDPR message before enabling Firebase in prod**, and don't create the IDFA explainer (decision #41);
   - host `app-ads.txt` on the developer website (`forms/app-ads-txt.md`);
   - decide whether to keep the AdServices permissions [keep].
5. **RevenueCat and the stores:** project, the `premium` entitlement, the three products, the offering and the keys; store products and sandbox testers. Confirm the prices, the style names Ocean / Ember / Midnight, and that interstitials stay off.
6. **The upload keystore:**
   - create it with the runbook's `keytool` line, outside the repo, backed up offline;
   - write `app/android/key.properties` from the example;
   - turn on Play App Signing;
   - then run DM-105.
7. **Legal pages:**
   - review the drafts (or have a lawyer review them);
   - host the privacy policy and terms and choose the support email and URL;
   - fill `docs/release/placeholders.json` and update `AppLinks` to match (the test keeps them in step);
   - choose `GOVERNING_LAW`;
   - after the App Store Connect record exists, set `APP_STORE_ID`.
8. **Malay:**
   - sign off every string in `app_ms.arb`, `ms.lproj/InfoPlist.strings` and `store-listing/ms.md` (DM-068): "diendors", "memaparkan iklan", `paywallFreeForever`, and the 9.9 report's list;
   - until then, no Malay store listing.
9. **The device matrix** with Claude:
   - DM-001…DM-102 and the Phase 9 rows DM-103…DM-111;
   - the gates before any upload are DM-056/057/060/061;
   - ask before any Power or Wake-on-LAN step.
10. **The Mac:**
    - `pod install`;
    - DM-058/059/066/106/107;
    - the iOS builds and `tool/release.sh --platform ios`;
    - the Xcode version that App Store Connect currently requires;
    - the multicast entitlement request (for iOS Wake-on-LAN, later).
11. **Store submission:**
    - paste the form drafts;
    - upload the screenshots after reviewing them (DM-111) and the feature graphic;
    - record the demo video from the script (`DEMO_VIDEO_URL`);
    - internal → closed → production staged 10 % → 50 % → 100 %;
    - TestFlight → App Review with the review notes.
12. **Questions (defaults in brackets):**
    - Should a restored iPhone show onboarding and our ATT pre-prompt again? [yes, P9-R6]
    - Should it keep the launch count? [yes]
    - Ship only Google's SKAdNetwork id? [yes until mediation]
    - Declare `ITSAppUsesNonExemptEncryption = NO`? [yes, after your confirmation; Info.plist unchanged until then]
    - Play target audience 18+ only? [yes]
    - Store screenshots without third-party app names? [yes]
    - No code obfuscation in v1? [yes]
