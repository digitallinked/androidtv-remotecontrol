---
name: store-release
description: Use when preparing builds for Google Play or the Apple App Store — signing, versioning, store listings, screenshots, privacy/data-safety forms, App Privacy labels, review notes, closed testing, TestFlight, release tracks, or handling a rejection.
---

# Store release

## Overview
Both stores reject remote-control apps for the same few reasons: misleading branding, missing privacy disclosures, reviewers unable to test without a TV, and ads/consent problems. Prepare for each before submitting.

## Versioning & signing
- `pubspec.yaml` `version: X.Y.Z+build`; the build number always increases.
- **Android:** upload keystore stored outside the repo (`~/keys/atvremote-upload.jks`), referenced by a git-ignored `android/key.properties`. Play App Signing on. Ship an AAB. targetSdk = latest required by Play (36 since 31 August 2026). Re-check the runbook's "Store rules checked" table after any Flutter or SDK upgrade: target API, Billing Library 8+ and 16 KB pages can each block an upload.
- **iOS:** automatic signing, team in Xcode, bundle id fixed once chosen. Archive via `flutter build ipa --flavor prod`.
- CI later (GitHub Actions + fastlane); for v1, scripted local builds in `tool/release.ps1`. The CI `check` job runs `flutter build apk --config-only` before `tool/check.sh`, so the Gradle dry-run tests have a `gradlew`.

## Release docs (`docs/release/`, Phase 9)
- **`runbook.md`:** the owner's step-by-step path from accounts to launch week, ending with the owner-decision list. Start there.
- **Placeholders:**
  - `placeholders.json` is the one values file (decision #35, P9-R11), and docs use `{{TOKEN}}` only.
  - `dart tool/fill_release_docs.dart` (from `app/`) writes the filled copies to `build/release-docs/`. It exits 1 while any token is unfilled, unless you pass `--allow-missing`.
  - `AppLinks` stays the code source, and a test keeps the two equal.
- **Drafts:**
  - `legal/` holds the privacy policy and terms (DRAFT, not legal advice).
  - `store-listing/en.md` and `ms.md` hold the store copy (Malay UNREVIEWED).
  - `forms/` holds the Data safety, App Privacy, content rating, export, SKAdNetwork and Play declaration drafts.
  - `review/` holds the Apple review notes and the demo-video script.
  - Also `rename-checklist.md` and `launch-ops/`.
- **Images:**
  - `store-assets/feature_graphic.png` is a golden.
  - The screenshots come from `tool/store_screenshots.ps1`/`.sh`, which writes to `build/store-screenshots/<set>/<locale>/`. They are never committed.

## Google Play checklist
- [ ] **New personal developer account:** closed test with ≥ 12 testers opted in for 14 continuous days before production access.
- [ ] **Backup rules (closed in code, decision #49):** `allowBackup="false"`, `fullBackupContent="false"` and `data_extraction_rules.xml` exclude everything. Before upload, grep the **prodRelease** merged manifest for all three; the Privacy page's "never leave this phone" and the FAQ answers depend on them. Run device-matrix rows DM-056/057 (Android) and DM-060/061 (iOS restore and Quick Start; DM-061 is a release issue if the DB travels).
- [ ] **Malay:** the owner (or a native reviewer) signs off every `app_ms.arb` string (DM-068) before Malay store copy; the iOS `ms.lproj` resources build on a Mac (DM-066).
- [ ] Data safety. Collected:
  - device or other IDs: advertising ID, Firebase Installation ID, app set ID;
  - **approximate location**, which AdMob and Analytics derive from the IP;
  - app info and performance: crash logs, diagnostics;
  - app interactions (analytics);
  - purchase history.

  Data is encrypted in transit and none is sold. Account deletion is N/A (no accounts). TV names, IPs and MACs stay on the phone.
- [ ] Ads declaration = yes. Content rating questionnaire. Target audience 18+ (avoids Families policy).
- [ ] Permissions explained:
  - our own: `INTERNET`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_NETWORK_STATE`, `RECORD_AUDIO` (only once voice ships);
  - merged from SDKs: `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_*` (AdMob; the owner decides keep or `tools:node="remove"`), `com.android.vending.BILLING` (RevenueCat), `WAKE_LOCK` and `FOREGROUND_SERVICE` (Firebase), and install referrer.

  Check the merged manifest (`processProdReleaseManifest`) before filling the form.
- [ ] AdMob/UMP console:
  - Publish the GDPR (EEA/UK/CH) message **before** enabling Firebase in prod. Without it, UMP may report `notRequired` and analytics would default on. Verify with `UMP_DEBUG_GEOGRAPHY=eea`.
  - **Don't** create the IDFA explainer message: our own pre-prompt owns the ATT flow (decision #41).
- [ ] Build only with `tool/release.ps1 -Platform android` (or `release.sh`). It runs `app/tool/release_check.dart` and refuses, listing every problem at once, unless:
  - `env/prod.json` has `FIREBASE_ENABLED: true`, real RevenueCat keys and banner ids, and no UMP debug values;
  - the prod Firebase config files exist;
  - the AdMob app ids are real;
  - `key.properties` is complete and no secrets are tracked;
  - the links are real.

  After the build, it checks the merged manifest and the signature. Otherwise prod would silently ship with no analytics, no Premium and test ads. `-DryRun` runs the checks only. The full step order is in `docs/release/runbook.md`.
- [ ] **AdMob content cap G** in the AdMob console, matching the code (decision #52). Apple 2.5.18 requires ads to fit the age rating (4+).
- [ ] Listing: name without "Google"; "for Android TV" in descriptive text only; 8 phone screenshots, 2 tablet, feature graphic 1024×500, icon 512.
- [ ] Privacy policy URL live; in-app link in Settings → Legal.

## Apple App Store checklist
- [ ] `Info.plist`: `NSLocalNetworkUsageDescription`, `NSBonjourServices`, `NSUserTrackingUsageDescription`, `NSMicrophoneUsageDescription` (only when voice ships), `GADApplicationIdentifier`, `SKAdNetworkItems`.
- [ ] App Privacy labels match the SDKs (Identifiers, Usage Data, Diagnostics, Purchases, **Coarse Location**, **Performance Data**; tracking = yes). Every type AdMob collects is **Linked: Yes**; Purchase History is the only "No" (decision #52; draft in `docs/release/forms/apple-app-privacy.md`).
- [ ] The purpose strings `NSUserTrackingUsageDescription` and `NSLocalNetworkUsageDescription` name "Remotely"; update them when the app name is final.
- [ ] iOS deployment target 15.0 (Firebase iOS SDK 13). Podfile at 15.0. The Crashlytics dSYM upload and the "Check AdMob app id" build phase are in place (Phase 9, decisions #51/#52); verify both on a Mac (DM-106, DM-107).
- [ ] **Analytics without the ad id under Swift Package Manager** (P9-C4): `firebase_analytics` drops the advertising id only when `FIREBASE_ANALYTICS_WITHOUT_ADID=true` is set while Swift packages resolve. The Podfile's `$FirebaseAnalyticsWithoutAdIdSupport` covers only CocoaPods.
  - `tool/release.sh --platform ios` exports the variable for you.
  - An archive from the Xcode GUI (Product → Archive) doesn't see your shell's variables. Run `launchctl setenv FIREBASE_ANALYTICS_WITHOUT_ADID true` first, then quit and restart Xcode.
  - SwiftPM caches the resolved manifest. After setting or changing the variable, use File → Packages → Reset Package Caches (or delete the DerivedData `SourcePackages`) before building.
  - Check: `GoogleAppMeasurementIdentitySupport` is absent from the archive's build log.
- [ ] Paywall: price, period, auto-renew terms, Restore button, Terms (EULA) + Privacy links (Guideline 3.1.2).
- [ ] **Review notes:** the reviewer has no Android TV. Attach a demo video link showing discovery → pairing → control on a real TV, explain that the app requires an Android TV / Google TV on the same Wi-Fi, and provide the in-app **demo mode** (simulated TV) path for testing.
- [ ] Guideline 4.2/4.3: enough native value (widgets, Siri Shortcuts / App Intents later) to avoid "minimum functionality".
- [ ] TestFlight internal → external beta before release.
- [ ] EU trader status (DSA) verified in App Store Connect before EU distribution; a trader's address, phone and e-mail are public on the EU listing (runbook step 2).
- [ ] The iOS storage channel (`AppDelegate.swift`, backup-excluded DB directory) compiles and the DB lands in `Application Support/Database` (DM-058/059). There is no fallback: if the channel fails, the database doesn't open.

## Common rejections → fix
| Rejection | Fix |
|---|---|
| Play 4.3 / impersonation ("Google" in name/icon) | rename; generic icon |
| Apple 2.1 "couldn't test" | demo video + demo mode |
| Apple 5.1.1 / 5.1.2 privacy | purpose strings + ATT pre-prompt + labels |
| Play policy: ads interfere with use | respect `remote-design-system` safe zones |
| Apple 3.1.2 subscription info missing | paywall terms + links |

## Config files and secrets (where they live)
| File | Path | Get it from |
|---|---|---|
| Firebase Android | `app/android/app/src/{dev,prod}/google-services.json` | Firebase console → project → Android app per flavor (`my.newy.remotely.dev` / `my.newy.remotely`), or `flutterfire configure` |
| Firebase iOS | `app/ios/config/{dev,prod}/GoogleService-Info.plist` (copied by a build phase per scheme) | Firebase console → iOS app per flavor |
| Dart defines | `app/env/dev.json`, `app/env/prod.json` (copy `app/env/example.json`) → `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` | 9 keys: `FIREBASE_ENABLED`, `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`, `ADMOB_BANNER_ANDROID`, `ADMOB_BANNER_IOS`, `ADMOB_INTERSTITIAL_ANDROID`, `ADMOB_INTERSTITIAL_IOS`, `UMP_DEBUG_GEOGRAPHY`, `UMP_TEST_DEVICE_ID`. Empty values keep a service off; dev uses Google test ad IDs |
| AdMob app id, Android | `app/android/secrets.properties` (`admobAppIdProd`; copy `secrets.example.properties`) | AdMob console. Non-prod builds fall back to Google's test app id; a malformed prod id fails the Gradle build |
| AdMob app id, iOS | `app/ios/Flutter/Secrets.xcconfig` (`ADMOB_APP_ID_PROD`; copy `Secrets.example.xcconfig`), pulled in by `#include?` | AdMob console |
| Android upload key | `~/keys/atvremote-upload.jks` + `app/android/key.properties` | generated once with `keytool`; back up offline |
| CI secrets | GitHub Actions secrets (base64 of the files above) | added by the owner |

## Never commit
`*.jks`, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `app/env/*.json`, `secrets.properties`, `Secrets.xcconfig`, `.env`, RevenueCat keys, App Store Connect API keys. Commit `app/env/example.json`, `secrets.example.properties` and `Secrets.example.xcconfig` with placeholder values. Check `.gitignore` before every release commit.
