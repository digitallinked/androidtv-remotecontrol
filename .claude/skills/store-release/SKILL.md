---
name: store-release
description: Use when preparing builds for Google Play or the Apple App Store — signing, versioning, store listings, screenshots, privacy/data-safety forms, App Privacy labels, review notes, closed testing, TestFlight, release tracks, or handling a rejection.
---

# Store release

## Overview
Both stores reject remote-control apps for the same few reasons: misleading branding, missing privacy disclosures, reviewers unable to test without a TV, and ads/consent problems. Prepare for each before submitting.

## Versioning & signing
- `pubspec.yaml` `version: X.Y.Z+build`; the build number always increases.
- **Android:** upload keystore stored outside the repo (`~/keys/atvremote-upload.jks`), referenced by a git-ignored `android/key.properties`. Play App Signing on. Ship an AAB. targetSdk = latest required by Play (35+ in 2026).
- **iOS:** automatic signing, team in Xcode, bundle id fixed once chosen. Archive via `flutter build ipa --flavor prod`.
- CI later (GitHub Actions + fastlane); for v1, scripted local builds in `tool/release.ps1`.

## Google Play checklist
- [ ] **New personal developer account:** closed test with ≥ 12 testers opted in for 14 continuous days before production access.
- [ ] **Release blocker:** Auto Backup must exclude the drift DB and prefs (`allowBackup` / data-extraction rules, Phase 8). The Privacy page's "never leave this phone" and the FAQ answer depend on it.
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
- [ ] Release script (`tool/release.ps1`, Phase 9) refuses a prod build unless:
  - `env/prod.json` has `FIREBASE_ENABLED: true`, both RevenueCat keys and both banner ids;
  - the prod `google-services.json` and `GoogleService-Info.plist` exist;
  - the AdMob app ids are set.

  Otherwise prod silently ships with no analytics, no Premium and test ads.
- [ ] Listing: name without "Google"; "for Android TV" in descriptive text only; 8 phone screenshots, 2 tablet, feature graphic 1024×500, icon 512.
- [ ] Privacy policy URL live; in-app link in Settings → Legal.

## Apple App Store checklist
- [ ] `Info.plist`: `NSLocalNetworkUsageDescription`, `NSBonjourServices`, `NSUserTrackingUsageDescription`, `NSMicrophoneUsageDescription` (only when voice ships), `GADApplicationIdentifier`, `SKAdNetworkItems`.
- [ ] App Privacy labels match the SDKs (Identifiers, Usage Data, Diagnostics, Purchases, **Coarse Location**, **Performance Data**; tracking = yes).
- [ ] The purpose strings `NSUserTrackingUsageDescription` and `NSLocalNetworkUsageDescription` name "Remotely"; update them when the app name is final.
- [ ] iOS deployment target 15.0 (Firebase iOS SDK 13). Podfile at 15.0. Upload Crashlytics dSYMs. On a Mac, add an `ADMOB_APP_ID` Run Script check (Phase 9).
- [ ] Paywall: price, period, auto-renew terms, Restore button, Terms (EULA) + Privacy links (Guideline 3.1.2).
- [ ] **Review notes:** the reviewer has no Android TV. Attach a demo video link showing discovery → pairing → control on a real TV, explain that the app requires an Android TV / Google TV on the same Wi-Fi, and provide the in-app **demo mode** (simulated TV) path for testing.
- [ ] Guideline 4.2/4.3: enough native value (widgets, Siri Shortcuts / App Intents later) to avoid "minimum functionality".
- [ ] TestFlight internal → external beta before release.

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
| Firebase Android | `app/android/app/src/{dev,prod}/google-services.json` | Firebase console → project → Android app per flavor (`com.digitallinked.atvremote.dev` / `com.digitallinked.atvremote`), or `flutterfire configure` |
| Firebase iOS | `app/ios/config/{dev,prod}/GoogleService-Info.plist` (copied by a build phase per scheme) | Firebase console → iOS app per flavor |
| Dart defines | `app/env/dev.json`, `app/env/prod.json` (copy `app/env/example.json`) → `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` | 9 keys: `FIREBASE_ENABLED`, `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`, `ADMOB_BANNER_ANDROID`, `ADMOB_BANNER_IOS`, `ADMOB_INTERSTITIAL_ANDROID`, `ADMOB_INTERSTITIAL_IOS`, `UMP_DEBUG_GEOGRAPHY`, `UMP_TEST_DEVICE_ID`. Empty values keep a service off; dev uses Google test ad IDs |
| AdMob app id, Android | `app/android/secrets.properties` (`admobAppIdProd`; copy `secrets.example.properties`) | AdMob console. Non-prod builds fall back to Google's test app id; a malformed prod id fails the Gradle build |
| AdMob app id, iOS | `app/ios/Flutter/Secrets.xcconfig` (`ADMOB_APP_ID_PROD`; copy `Secrets.example.xcconfig`), pulled in by `#include?` | AdMob console |
| Android upload key | `~/keys/atvremote-upload.jks` + `app/android/key.properties` | generated once with `keytool`; back up offline |
| CI secrets | GitHub Actions secrets (base64 of the files above) | added by the owner |

## Never commit
`*.jks`, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `app/env/*.json`, `secrets.properties`, `Secrets.xcconfig`, `.env`, RevenueCat keys, App Store Connect API keys. Commit `app/env/example.json`, `secrets.example.properties` and `Secrets.example.xcconfig` with placeholder values. Check `.gitignore` before every release commit.
