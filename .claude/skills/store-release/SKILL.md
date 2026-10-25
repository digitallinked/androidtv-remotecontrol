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
- [ ] Data safety: collects device/app IDs (ads, analytics), crash logs, purchase history; data encrypted in transit; no data sold; account deletion N/A (no accounts).
- [ ] Ads declaration = yes. Content rating questionnaire. Target audience 18+ (avoids Families policy).
- [ ] Permissions explained: `INTERNET`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_NETWORK_STATE`, `RECORD_AUDIO` (only once voice ships), `com.google.android.gms.permission.AD_ID`.
- [ ] Listing: name without "Google"; "for Android TV" in descriptive text only; 8 phone screenshots, 2 tablet, feature graphic 1024×500, icon 512.
- [ ] Privacy policy URL live; in-app link in Settings → Legal.

## Apple App Store checklist
- [ ] `Info.plist`: `NSLocalNetworkUsageDescription`, `NSBonjourServices`, `NSUserTrackingUsageDescription`, `NSMicrophoneUsageDescription` (only when voice ships), `GADApplicationIdentifier`, `SKAdNetworkItems`.
- [ ] App Privacy labels match the SDKs (Identifiers, Usage Data, Diagnostics, Purchases; tracking = yes if ATT and ads personalised).
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
| Dart defines | `app/env/dev.json`, `app/env/prod.json` → `flutter run --dart-define-from-file=env/dev.json` | keys: `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`, `ADMOB_BANNER_ANDROID`, `ADMOB_BANNER_IOS`; dev uses Google test ad IDs |
| Android upload key | `~/keys/atvremote-upload.jks` + `app/android/key.properties` | generated once with `keytool`; back up offline |
| CI secrets | GitHub Actions secrets (base64 of the files above) | added by the owner |

## Never commit
`*.jks`, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `app/env/*.json`, `.env`, RevenueCat keys, App Store Connect API keys. Commit `app/env/example.json` with placeholder values. Check `.gitignore` before every release commit.
