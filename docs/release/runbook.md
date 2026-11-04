# Release runbook (for the owner)

The ordered path from accounts to a staged production rollout on Google Play and the App Store. Phase 9 prepared every file and check this page uses; **every step below is the owner's**, because it needs the owner's accounts, keys, devices, Mac or legal judgement (Ruling P9-R1). Claude never creates a key, signs, uploads, hosts a page or changes a console setting. When you ask, Claude can run the checks and tests, explain a refusal, or update the docs with values you give it.

**How to read a step.** Each step says what to do, the exact command or console page, and **Verify:** the tool, test or device-matrix row that proves it worked. Device-matrix rows (`DM-nnn`) live in [the device matrix](../knowledge/device-matrix.md); write each result there.

**Conventions.**

- Commands run from the repo root unless the step says "from `app/`". Windows commands are for Windows PowerShell 5.1; Mac commands are for Terminal.
- Console menus move. Where a menu name below doesn't match, search the console for the page's title.
- **Never commit a secret.** The never-commit list is in the [store-release skill](../../.claude/skills/store-release/SKILL.md): keystores, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `app/env/*.json` (except `example.json`), `secrets.properties`, `Secrets.xcconfig`, RevenueCat keys. All of them are git-ignored; the release check refuses a tree that tracks one (`secrets-tracked`).
- After any change to code, docs or config examples, `powershell -File tool/check.ps1` must end with `All checks passed.` (run it from Git Bash until Task 9.13's wrapper-test fix lands; see "Known issues" at the end).

## Lead times: start these first

| What | How long | Start |
|---|---|---|
| Play closed test: **12 testers** opted in for **14 days** in a row (new personal developer accounts) | 14 days at least, plus recruiting | As soon as the Play account exists (step 2). Recruit the testers now. |
| Play and Apple developer account verification | Days | Step 2, first. |
| `app-ads.txt` verification by AdMob | Up to a day or more | Right after step 4. |
| Apple multicast entitlement (iOS Wake-on-LAN, v1.1) | Weeks, sometimes no answer | Any time; not needed for v1 ([backlog](launch-ops/v1.1-backlog.md) V11-06). |

## Step 1. Final app name and ids (before the first upload)

1. Choose the store name and the ids. Today's placeholders are `Remotely for Android TV` and `com.digitallinked.atvremote` (decision #12). **The Play package name is permanent after the first upload to any track**, and the iOS bundle id is effectively permanent once an App Store Connect record uses it.
2. Mind the App Store name risk: "Android" in App Store metadata invites a Guideline 2.3.10 question. A name without it is safer; "for Android TV" can stay in the descriptions. No "Google" in any name, subtitle, keyword or icon (CLAUDE.md).
3. If anything changes, follow [the rename checklist](rename-checklist.md) file by file: code, native files, store copy, `placeholders.json` (`APP_NAME`, `PLAY_PACKAGE`), the feature graphic title and its re-render.

**Verify:** `powershell -File tool/check.ps1` ends with `All checks passed.` (`rename_checklist_names_every_file_that_holds_the_name_or_id` keeps the checklist complete), and `cd app; flutter test test/release` passes.

## Step 2. Accounts and store records

1. **Google Play Console** developer account ([play.google.com/console](https://play.google.com/console)). Complete identity verification. Note the developer name and address you register: they fill `DEVELOPER_NAME` and `DEVELOPER_ADDRESS` in [placeholders.json](placeholders.json).
2. **Apple Developer Program** membership ([developer.apple.com](https://developer.apple.com/programs/)). In App Store Connect, sign the **Paid Applications** agreement and complete tax and banking: in-app purchases don't work until it is active.
3. **Create the app records** with the final ids from step 1:
   - Play Console → **Create app** (app, free, the declarations). Then **Test and release → Testing**: set up **Internal testing** and **Closed testing** tracks, and add the tester e-mail list. **The 14-day clock starts when 12 testers have opted in to a closed test with a published build**, so publish to closed testing as early as step 11 allows.
   - App Store Connect → **Apps → +** → New App, with the bundle id registered under Certificates, Identifiers & Profiles. Copy the numeric **Apple ID** of the record: it is `APP_STORE_ID` (step 6).

**Verify:** both consoles show the app record; the Play closed-test tester list holds at least 12 addresses.

## Step 3. Firebase: dev and prod projects

1. In the [Firebase console](https://console.firebase.google.com/), create two projects, dev and prod. In each, add an Android app and an iOS app:

   | Project | Android package / iOS bundle id | File | Put it at |
   |---|---|---|---|
   | dev | `com.digitallinked.atvremote.dev` | `google-services.json` | `app/android/app/src/dev/google-services.json` |
   | dev | `com.digitallinked.atvremote.dev` | `GoogleService-Info.plist` | `app/ios/config/dev/GoogleService-Info.plist` |
   | prod | `com.digitallinked.atvremote` | `google-services.json` | `app/android/app/src/prod/google-services.json` |
   | prod | `com.digitallinked.atvremote` | `GoogleService-Info.plist` | `app/ios/config/prod/GoogleService-Info.plist` |

   (Use the final ids from step 1 if they changed.) No other location: the build warns about a `google-services.json` anywhere else.
2. In each project, open **Crashlytics** once so it is enabled, and set **Analytics → Admin → Data retention**. Write the prod value into `ANALYTICS_RETENTION` (step 6).
3. In the prod project's **Remote Config**, create the seven parameters with the code defaults and publish ([kill-switch checklist](launch-ops/kill-switch-checklist.md), "The code's defaults").
4. Make the define files (git-ignored) from the example:

   ```powershell
   Copy-Item app/env/example.json app/env/dev.json
   Copy-Item app/env/example.json app/env/prod.json
   ```

   Set `"FIREBASE_ENABLED": true` in `dev.json` now. **Leave it `false` in `prod.json` until step 4's UMP message is published.** The other keys are filled in steps 4 and 5; the example is [app/env/example.json](../../app/env/example.json).
5. Set up the Crashlytics alerts in both projects ([crash alerts](launch-ops/crashlytics-alerts.md)).

**Verify:** with the dev files in place, run the dev build (`flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` from `app/`) and do **DM-042** (DebugView) and **DM-110** (a test crash raises an alert). The prod files are checked by the release check in step 10 (`firebase-android-config`, `firebase-ios-config`).

## Step 4. AdMob, the UMP consent message and app-ads.txt

1. In [AdMob](https://admob.google.com/), add the prod Android app and the prod iOS app (linked to the store listings once they exist). For each, create a **banner** ad unit. Interstitials stay off in v1 (decision #41): leave `ADMOB_INTERSTITIAL_ANDROID`/`_IOS` empty unless you decide otherwise (then they must be real units, and the privacy policy and forms keep disclosing them).
2. Put the ids where the builds read them (all git-ignored):
   - Android app id → `admobAppIdProd` in `app/android/secrets.properties` (copy [secrets.example.properties](../../app/android/secrets.example.properties));
   - iOS app id → `ADMOB_APP_ID_PROD` in `app/ios/Flutter/Secrets.xcconfig` (copy [Secrets.example.xcconfig](../../app/ios/Flutter/Secrets.example.xcconfig)); never leave it empty or as the placeholder;
   - banner units → `ADMOB_BANNER_ANDROID`, `ADMOB_BANNER_IOS` in `app/env/prod.json`.
3. **UMP:** AdMob → **Privacy & messaging** → create and **publish the GDPR message** (EEA, UK, Switzerland) for both apps **before** you set `FIREBASE_ENABLED` to `true` in `prod.json`. Without it, UMP reports consent as not required and analytics would default on in the EEA. **Don't** create the IDFA explainer message: the app's own pre-prompt owns the iOS tracking question (decision #41). Then set `"FIREBASE_ENABLED": true` in `prod.json`.
4. **app-ads.txt:** your AdMob publisher id (`pub-…`, AdMob → Settings → Account) is `ADMOB_PUBLISHER_ID`. Host the file at the root of the developer website named in both store listings, exactly as [the app-ads.txt draft](forms/app-ads-txt.md) shows.
5. **Cap ad content at G:** AdMob → **Blocking controls** → All apps (or each app) → **Maximum ad content rating = G** ("General audiences"), before the first release that shows ads. The app's content rating is Everyone / 4+, and both stores require ads to suit it ([content-rating.md](forms/content-rating.md), Ruling P9-C12). Task 9.13 also sets the same cap in code, so the console setting is a second guard, not the only one.
6. Decide whether to keep the AdServices permissions ([the AdServices draft](forms/adservices-permissions.md); the default is keep).

**Verify:** **DM-040** (the UMP form with `UMP_DEBUG_GEOGRAPHY=eea` in `dev.json`), **DM-038** (test banners only on Apps and the Settings hub), **DM-046** (iOS, on the Mac); AdMob → Apps → app-ads.txt shows the file as found; AdMob → Blocking controls shows **Maximum ad content rating: G** for both apps (take a screenshot for your records). The release check in step 10 refuses a test, placeholder or malformed id (`admob-app-android`, `admob-app-ios`, `banner-android`, `banner-ios`) and any UMP debug value left in `prod.json` (`ump-debug`).

## Step 5. RevenueCat, store products and sandbox testers

1. In [RevenueCat](https://app.revenuecat.com/): a project with the Play app and the App Store app; the entitlement **`premium`**; the products **`premium_monthly`**, **`premium_yearly`** (subscriptions) and **`premium_lifetime`** (one-time, non-consumable), each attached to `premium`; a **current offering** with the three packages. Copy the public SDK keys (`goog_…`, `appl_…`) into `REVENUECAT_ANDROID_KEY` and `REVENUECAT_IOS_KEY` in `app/env/prod.json` (and dev keys into `dev.json`).
2. In the stores, create the same three products with the same ids. **Play only lets you create in-app products after a build with the billing permission is uploaded**, so do the Play half after the first internal-testing upload (step 10), then come back. In App Store Connect, create a subscription group for the two subscriptions and the non-consumable, with prices and review screenshots.
3. Add Play **license testers** (Play Console → Settings → License testing) and App Store **sandbox testers** (App Store Connect → Users and Access → Sandbox).
4. Confirm the prices, the colour style names Ocean, Ember and Midnight, and that interstitials stay off.

**Verify:** **DM-044**, which runs every row of [the sandbox purchase checklist](../../app/integration_test/purchase_flow_sandbox.md) on Android and iOS. The release check refuses a missing or test key (`revenuecat-android`, `revenuecat-ios`).

## Step 6. Legal pages, placeholders and the fill script

1. Review [the privacy policy draft](legal/privacy-policy.md) and [the terms draft](legal/terms.md), yourself or with a lawyer. Work through each draft's "Owner to confirm" list (privacy policy items 1–16), then **delete that section and the `DRAFT` line** from the copy you host.
2. Choose the values and write them into [placeholders.json](placeholders.json): `DEVELOPER_NAME`, `DEVELOPER_ADDRESS`, `SUPPORT_EMAIL`, `SUPPORT_URL`, `PRIVACY_POLICY_URL`, `TERMS_URL`, `EFFECTIVE_DATE`, `ANALYTICS_RETENTION`, `GOVERNING_LAW`, `DEMO_VIDEO_URL` (step 12), `ADMOB_PUBLISHER_ID`, `APP_STORE_ID` (step 2).
3. Put the same privacy, terms, support e-mail and App Store values into [app_links.dart](../../app/lib/app/app_links.dart) (`AppLinks`). A test keeps the two files equal, and the release check refuses today's placeholder links and the placeholder App Store id (`placeholder-links`, `app-store-id`).
4. Render the filled copies, from `app/`:

   ```powershell
   dart tool/fill_release_docs.dart
   ```

   It writes every `docs/release/**/*.md` with the values filled in to the git-ignored `build/release-docs/`. If a value is still missing, it lists the tokens and exits 1; fix them and run it again. Use the filled copies for everything you paste or host.
5. **Host** the filled privacy policy and terms at the two URLs (and the support page). **Only after Task 9.13's certificate change has shipped** (privacy-policy owner item 11: the iPhone keychain wording depends on it).

**Verify:** `cd app; flutter test test/release` passes (`app_links_match_the_placeholder_values`); `dart tool/fill_release_docs.dart` exits 0; both URLs open on a phone (**DM-035**); the release check no longer lists `placeholder-links` or `app-store-id` (step 10).

## Step 7. The upload keystore, key.properties and Play App Signing

1. Create the upload keystore **once, outside the repository**, with the JDK's `keytool` (Android Studio ships one in its `jbr\bin` folder). On Windows PowerShell (PowerShell doesn't expand `~` for other programs, so use `$HOME`):

   ```powershell
   New-Item -ItemType Directory -Force "$HOME\keys"
   keytool -genkeypair -v -keystore "$HOME\keys\atvremote-upload.jks" -keyalg RSA -keysize 4096 -validity 10000 -alias upload
   ```

   On a Mac or in Git Bash the line from [key.properties.example](../../app/android/key.properties.example) works as written: `keytool -genkeypair -v -keystore ~/keys/atvremote-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload`.
2. **Back it up offline** right away: the `.jks` file in two places that aren't this PC (for example an encrypted USB drive and a password manager's file attachment), and both passwords in a password manager. Losing it means asking Google for an upload-key reset.
3. Copy `app/android/key.properties.example` to `app/android/key.properties` and fill in the four keys. `storeFile` may stay `~/keys/atvremote-upload.jks` (Gradle reads `~/` as your home folder); use forward slashes even on Windows.
4. **Play App Signing:** on the first upload (step 10), accept Google's app signing key (the default for new apps). Your keystore is then the **upload key**; Google signs what users install. After that upload, Play Console → **Setup → App signing** shows both certificates.

**Verify:** the release check's `signing` refusal is gone (**DM-104**), and **DM-105**: the bundle is signed with this key (`keytool -printcert -jarfile`), Play accepts it, and the four refusals behave as expected. `git status` never lists `key.properties` or the keystore.

## Step 8. The Malay sign-off (before any Malay listing)

1. **DM-068:** you (or a native reviewer) sign off every string in `app/lib/app/l10n/app_ms.arb` and `app/ios/Runner/ms.lproj/InfoPlist.strings`, including "diendors" in `aboutTrademark`, "memaparkan iklan" in the iOS tracking string and `paywallFreeForever`.
2. **DM-113:** then the Malay store listing ([ms.md](store-listing/ms.md)), the Malay screenshot captions, the Malay reply drafts and the Phase 9 terms listed in that row ("Tahan semula jadi", "tidak sekali-kali", the keywords and the rest).
3. Until both are done: publish the store listings in English only (no Malay listing on Play, no Malay localization in App Store Connect), and reply to reviews in English. Tell Claude when they are done, so it can change the `UNREVIEWED` status line of `ms.md` and its test.

**Verify:** both rows signed off in `status.md`.

## Step 9. The device-matrix gates

Run the matrix with Claude ([the device matrix](../knowledge/device-matrix.md), its live-testing rules first: **verify the screen before each tap, never press Power or Wake-on-LAN without the owner's yes, restore every setting afterwards, and connect via the TV switcher dropdown, then tap the TV**). A Fail stops the upload it gates until it is fixed or the owner accepts it in `status.md`. "Not run" is acceptable only where a row allows it (for example "no second phone").

| Before | These rows pass |
|---|---|
| The first Play upload (internal testing) | **DM-104** (dry run), **DM-056** and **DM-057** (Android backup and device transfer bring no TV data), **DM-103** (per-app language) |
| The first Play upload itself | **DM-105** (real build, signing, Play accepts it) |
| Promoting to closed testing | **DM-109** (kill switches), **DM-110** (crash alert), **DM-107** (Android half: mapping and a readable test crash), **DM-111** (screenshots), and the real-device run DM-001…DM-102 as far as the owner's devices allow (`status.md` "Next up" item 1) |
| The first TestFlight upload | **DM-058** and **DM-059** (Swift storage channel, database location), **DM-066** (Malay `ms.lproj`), **DM-106** (iOS build plumbing), **DM-112** (Swift packages: no ad-id Analytics, the dSYM tool) |
| TestFlight external (a public beta) | **DM-060** and **DM-061** (iOS restore and Quick Start: **if the TVs travel with Quick Start, that's a release issue: stop**). The plan gates these before "any upload"; they gate the first build outside your own team instead, because a Play upload can't reveal an iOS backup problem and TestFlight internal reaches only you. |
| App Store submission | **DM-107** (iOS half: the dSYM UUIDs in Crashlytics), **DM-108** (upgrade, reinstall and restore on a TestFlight build) |
| Any Malay listing | **DM-068** and **DM-113** (step 8) |

## Step 10. The Android release build

1. Dry run first, with all the real config in place (steps 3–7):

   ```powershell
   powershell -File tool/release.ps1 -Platform android -DryRun
   ```

   A pass prints `All android pre release checks passed.` and `Dry run: every pre-build check passed. No build was made.` (**DM-104**). A refusal prints one `REFUSED [<code>] <reason>` line per problem and `No build was made.`; fix each with the table below and run it again.
2. The real run:

   ```powershell
   powershell -File tool/release.ps1 -Platform android
   ```

   It builds `app/build/app/outputs/bundle/prodRelease/app-prod-release.aab`, checks the merged manifest and the signature, and prints `Built …`, the size, the SHA-256, the version and `Next: upload it to the internal test track (docs/release/runbook.md).` If a post-check refuses, it prints `Do not upload <path>.`: don't.
3. Check the signer: `keytool -printcert -jarfile app/build/app/outputs/bundle/prodRelease/app-prod-release.aab` shows your upload certificate, never `CN=Android Debug` (**DM-105**).
4. Play Console → **Test and release → Testing → Internal testing → Create new release** → upload the AAB → release notes from [en.md](store-listing/en.md) (`release_notes`) → **Save → Review release → Start rollout to Internal testing**.
5. **Every later upload needs a higher build number:** raise the `+N` in `app/pubspec.yaml` (`version: 1.0.0+1` → `1.0.0+2`). A new version name (`1.0.1`) also changes `kAppVersion` in `app/lib/core/config/app_version.dart`; a test keeps the two equal.

The script is [tool/release.ps1](../../tool/release.ps1) ([tool/release.sh](../../tool/release.sh) on a Mac or Linux). Its refusals (Ruling P9-R2):

| Code | Fix |
|---|---|
| `env-missing` | Create `app/env/prod.json` from the example (step 3). |
| `firebase-disabled` | `"FIREBASE_ENABLED": true` in `prod.json`, after the UMP message (step 4). |
| `revenuecat-android`, `revenuecat-ios` | The `goog_…` / `appl_…` public keys (step 5). Both platforms' keys are checked on either platform. |
| `banner-android`, `banner-ios` | Real banner unit ids, not Google's test ones (step 4). Both are checked on either platform. |
| `interstitial-android`, `interstitial-ios` | Empty, or a real unit id (step 4). |
| `ump-debug` | Empty `UMP_DEBUG_GEOGRAPHY` and `UMP_TEST_DEVICE_ID` in `prod.json`. |
| `firebase-android-config`, `firebase-ios-config` | The prod Firebase file at its path, for the prod id (step 3). |
| `admob-app-android`, `admob-app-ios` | The real AdMob app id in `secrets.properties` / `Secrets.xcconfig` (step 4). |
| `signing` | `app/android/key.properties` complete, and the keystore it names exists (step 7). |
| `secrets-tracked` | A never-commit file is tracked by git: `git rm --cached <path>`, commit, and if it held a real secret, rotate that secret. |
| `placeholder-links`, `app-store-id` | Real links and the App Store id in `AppLinks` (step 6). |
| `manifest-missing`, `manifest-backup`, `manifest-target-sdk`, `manifest-admob-id` | Post-checks of the merged manifest: don't upload; tell Claude the line. |
| `artifact-missing`, `debug-signed` | The build didn't produce a store-signed bundle: don't upload; check step 7. |

## Step 11. Play tracks: internal → closed test → staged production

1. **Store listing and App content** (Play Console → **Grow users → Store presence → Main store listing**, and **Policy and programs → App content**), from the filled copies (step 6):
   - texts from [en.md](store-listing/en.md); the icon (512 px, from `tool/brand.ps1`), [the feature graphic](store-assets/feature_graphic.png) and the screenshots (`powershell -File tool/store_screenshots.ps1`, reviewed in **DM-111**, per [the screenshot plan](store-assets/screenshot-plan.md));
   - **Data safety** from [play-data-safety.md](forms/play-data-safety.md); **ads** = yes, **target audience 18+ only**, **app access**, **advertising ID** and the rest from [play-declarations.md](forms/play-declarations.md); **content rating** from [content-rating.md](forms/content-rating.md); permissions as explained in [permissions.md](forms/permissions.md);
   - the privacy policy URL; countries.
2. **Internal testing:** install from the Play link on your own phone; play with it for a day; check Crashlytics (**DM-107**, Android half).
3. **Closed testing:** promote the release (or upload it) to the closed track, publish it, and get **12 testers** to opt in. The **14 days** count only while at least 12 stay opted in. Watch [the crash alerts](launch-ops/crashlytics-alerts.md) and the testers' feedback.
4. **Apply for production access** (Play Console → Dashboard) when the 14 days are done; answer Google's questions about the test honestly.
5. **Production, staged:** Production → Create new release → the same AAB (or a newer one) → rollout percentage **10 %**. Advance to **50 %**, then **100 %**, only when every gate in [crashlytics-alerts.md](launch-ops/crashlytics-alerts.md) is green for the stage's minimum time (48 hours each). **Halt rollout** the moment a halt condition appears, and contain with [the kill-switch checklist](launch-ops/kill-switch-checklist.md) if ads are involved.

**Verify:** each stage's gates in `crashlytics-alerts.md`; Android vitals stay under the bad-behaviour thresholds.

## Step 12. iOS, on the Mac: TestFlight and App Review

1. **Tools:** the Xcode version App Store Connect currently requires, CocoaPods, Flutter 3.44.1. Clone the repo, then `cd app && flutter pub get`.
2. **Config** (git-ignored; copy them from your PC by a private channel, never through git): `app/ios/Flutter/Secrets.xcconfig` (`ADMOB_APP_ID_PROD`), `app/ios/config/prod/GoogleService-Info.plist` (and the dev one), `app/env/prod.json`.
3. **Pods:** `cd app/ios && pod install`. If it changes the Xcode project, `Podfile.lock` or `Debug.xcconfig`/`Release.xcconfig`, commit those changes (they hold no secrets) and check that `flutter test test/platform` still passes (**DM-106**).
4. **Signing:** `open app/ios/Runner.xcworkspace` → Runner target → **Signing & Capabilities** → automatic signing with your team, for the `Release-prod` configuration (and the others you build).
5. **Build:** from the repo root,

   ```bash
   bash tool/release.sh --platform ios
   ```

   It runs the iOS pre-checks, exports `FIREBASE_ANALYTICS_WITHOUT_ADID=true` so Analytics resolves without the advertising id, builds the archive with `flutter build ipa --flavor prod`, and prints the `.ipa` path and its SHA-256. The archive's first build phase refuses a missing, placeholder or test AdMob app id. **If you ever archive from Xcode instead** (Product → Archive), first run `launchctl setenv FIREBASE_ANALYTICS_WITHOUT_ADID true`, quit and reopen Xcode, and reset the package caches (store-release skill).
6. **Upload:** drag the `.ipa` from `app/build/ios/ipa/` into Apple's **Transporter** app, or open `app/build/ios/archive/Runner.xcarchive` in Xcode's Organizer and **Distribute App**.
7. **TestFlight internal** (your own team) → test on an iPhone: **DM-107** (iOS half), **DM-108**. Then, once **DM-060** and **DM-061** have passed, **TestFlight external** (needs Beta App Review): a small group for a few days, with the gates in `crashlytics-alerts.md`.
8. **App Store submission**, from the filled copies:
   - the listing from [en.md](store-listing/en.md) (`appstore.*` fields) and the iPhone 6.9″ and iPad 13″ screenshots;
   - **App Privacy** from [apple-app-privacy.md](forms/apple-app-privacy.md); the **age rating** from [content-rating.md](forms/content-rating.md); **export compliance** from [export-compliance.md](forms/export-compliance.md);
   - **App Review information:** the notes from [apple-review-notes.md](review/apple-review-notes.md) and the demo video (`DEMO_VIDEO_URL`), recorded from [the demo-video script](review/demo-video-script.md) and uploaded as an unlisted video;
   - attach the three in-app purchases to the version; then **Submit for Review**.
9. The first App Store version goes to everyone when you release it (choose a manual release so you can pick the moment). For later versions use **Phased Release for automatic updates** (`crashlytics-alerts.md`).

**Verify:** **DM-058**, **DM-059**, **DM-066**, **DM-106**, **DM-112** before the first upload; **DM-060**, **DM-061** before TestFlight external; **DM-107**, **DM-108** before submission; App Store Connect shows the build as processed with no missing-compliance warning.

## Step 13. Launch week

- Daily: [the review response plan](launch-ops/review-response-plan.md) (read every review, reply within 48 hours, one bug per pattern), [the crash alerts and gates](launch-ops/crashlytics-alerts.md), Android vitals, the AdMob policy centre.
- Keep [the kill-switch checklist](launch-ops/kill-switch-checklist.md) at hand: `ads_banner_enabled` is the first lever for any ad problem.
- Record every halt, fix and new bug pattern in `docs/knowledge/status.md`. What comes next is in [the v1.1 backlog](launch-ops/v1.1-backlog.md).

## Owner decisions and open points

Collected from the Phase 9 task reviews and controller rulings (P9-C1…C12). Each has a default; the bracket says where it lives. **Each form draft's own "Owner to confirm" checklist is part of this list:** [play-data-safety.md](forms/play-data-safety.md), [apple-app-privacy.md](forms/apple-app-privacy.md), [content-rating.md](forms/content-rating.md), [play-declarations.md](forms/play-declarations.md), [permissions.md](forms/permissions.md), [export-compliance.md](forms/export-compliance.md), [skadnetwork.md](forms/skadnetwork.md), [adservices-permissions.md](forms/adservices-permissions.md), [app-ads-txt.md](forms/app-ads-txt.md), [apple-review-notes.md](review/apple-review-notes.md), and the privacy policy's items 1–16 ([privacy-policy.md](legal/privacy-policy.md)).

**Questions with a default (the Phase 9 plan's list):**

1. A restored iPhone shows onboarding and our ATT pre-prompt again (P9-R6). [yes; DM-060/061/108]
2. A restored iPhone keeps the launch count. [yes]
3. Ship only Google's SKAdNetwork id until there is mediation. [yes; [skadnetwork.md](forms/skadnetwork.md), backlog V11-15]
4. Declare `ITSAppUsesNonExemptEncryption = NO`. [yes after your confirmation; Info.plist is unchanged until then; [export-compliance.md](forms/export-compliance.md)] The algorithm answer is **"standard encryption algorithms instead of, or in addition to, the operating system's"**: the app bundles BoringSSL (Flutter's TLS) and `pointycastle`, so it doesn't rely on Apple's crypto alone (P9-C12). That answer makes App Store Connect ask about **France**: file the declaration Apple's current guidance asks for, or exclude France from availability until it is filed. [owner decision]
5. Play target audience 18+ only. [yes]
6. Store screenshots without third-party app names. [yes]
7. No code obfuscation in v1. [yes]
8. Keep the AdServices permissions. [keep; [adservices-permissions.md](forms/adservices-permissions.md)]
9. Interstitials stay off. [off; if you switch them on, the prod build needs interstitial unit ids and the disclosures stay; [kill-switch-checklist.md](launch-ops/kill-switch-checklist.md)]
10. Real app icons on the tiles. [no; backlog V11-16]

**Names and store copy:**

11. **App Store name risk:** "Remotely for Android TV" puts "Android" in App Store metadata (Guideline 2.3.10). Consider a name without it (step 1).
12. **Play short description** names Android TV and Google TV as a compatibility statement. Allowed (P9-R13); trademark-free is the cautious choice.
13. **Content rating versus target audience: not a conflict** (P9-C12). The content rating (Everyone / PEGI 3 on Play, 4+ on the App Store) describes the app's content, a TV remote; Play's **18+ target audience** says whom the app is for and keeps it out of the Families policy. Keep both, as [content-rating.md](forms/content-rating.md) and the privacy policy's owner item 9 say. What the 4+ rating does require is the **AdMob maximum ad content rating of G** (step 4, item 22).
14. **Malay keywords** include the English "tv remote"; keep or drop (DM-113).

**Malay review points** (DM-068, DM-113): "diendors" (`aboutTrademark`), "memaparkan iklan" (iOS tracking string), `paywallFreeForever`; "Tahan semula jadi" for Natural hold (or "Tekan lama semula jadi", "Tahanan semula jadi"); `privacyAdsInfo` "tetapi tidak semasa" versus "tidak sekali-kali"; and the Task 9.9 list in DM-113. Decide also whether the app's Malay UI ships in the first production build if DM-068 isn't finished by then.

**Store art** (DM-111): the "Photos" tile uses the all-apps glyph; the Malay sets show English shortcut names; discovery shows both TVs as Paired; the pairing shot and the tablet Apps shot are sparse; the phone quick row cuts the "Sports" tile. Accept, or list fixes (backlog V11-18).

**Privacy and legal** (the privacy policy's "Owner to confirm" items 1–16 are the full list):

15. **EEA storage consent:** even non-personalised ads use device storage, which ePrivacy may tie to consent. UMP's "limited ads" handles that case; ask your lawyer whether the policy's section 3 wording is enough.
16. **"Anonymous" in the app:** the Privacy choices page says "Anonymous counts…", but the app instance id makes the data pseudonymous. The strings are frozen for v1; fix after v1 (backlog V11-17) or accept the wording.
17. **California (CCPA/CPRA):** whether personalised AdMob ads count as "sharing" and need a "Do not sell or share" statement.
18. **Malaysia (PDPA):** if it applies, the notice must be in Malay and English.
19. **The iPhone pairing certificate:** host the policy only once Task 9.13's change (a reinstall gets a new certificate) has shipped.
20. **Store forms** (P9-C12; confirm each in the console's current wording, and the vendor disclosure links, which weren't checked online):
    - **Apple App Privacy, "Linked to the user":** answer **per [apple-app-privacy.md](forms/apple-app-privacy.md)**. Today that is **Yes** for every type AdMob collects (Device ID, Product Interaction, Advertising Data, Crash Data, Performance Data, Other Diagnostic Data, Coarse Location), because a type used for tracking can't honestly be "not linked" and AdMob collects crash data too, and **No** only for Purchase History, the one purely first-party row. **Performance Data** and **Other Diagnostic Data** are Linked: Yes (AdMob). The tracking marks per type are our reading of AdMob's page.
    - **Play Data safety, Crash logs:** collected by Crashlytics **and AdMob**, **Required** (AdMob collects it in the free version) and **Shared** (AdMob); copy AdMob's exact purposes from its page ([play-data-safety.md](forms/play-data-safety.md)). The "Shared" marks for the other AdMob types are our reading of Google's page too.
    - **Play App access:** the reviewer instructions are kept at 500 characters or fewer by a test; confirm the field's current limit in the console and shorten if needed ([play-declarations.md](forms/play-declarations.md)).
21. **Review notes length:** about 3,700 of App Store Connect's 4,000 characters before filling; the filled URLs make it longer. Trim if the console refuses it.
22. **AdMob maximum ad content rating = G** in the AdMob console before the first release with ads (step 4; [content-rating.md](forms/content-rating.md)). [do it]
23. **Staged rollout on the first production release:** confirm in the Play Console that a brand-new app's first production release can use a rollout percentage. If it can't, the closed test is the last gate before 100 %: extend it (more testers, more days) rather than skip a gate (step 11). [owner to confirm]

**Android 13+ per-app language** (DM-103): the in-app language wins over Android's per-app setting, and the two screens can disagree (the accepted P9-R7 residual). A one-way sync is backlog V11-14.

## Known issues (tooling)

- **The wrapper test from a PowerShell parent:** `sh_ios_build_resolves_analytics_without_the_ad_id` (in `app/test/tool/release_wrappers_test.dart`) fails when the test run is started from a plain PowerShell window and passes from Git Bash. Task 9.13 fixes it. Until then, run `powershell -File tool/check.ps1` from Git Bash. The release scripts themselves are not affected.
- **Don't run `flutter build` while `flutter test` runs** on Windows (learnings): one of them fails with "Unable to determine engine version" or a broken plugin registrant. A cold `flutter build apk --release` can take over 12 minutes.
