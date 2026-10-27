# Phase 6 — Services and Monetisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app gets its managed services and its business model without losing what makes it trustworthy.
- **Services:** Firebase Crashlytics, Analytics and Remote Config, Google's consent tools (UMP), App Tracking Transparency (ATT) on iOS, an adaptive AdMob banner at the bottom of the Apps screen and the Settings hub, interstitials (off by default), RevenueCat Premium (no ads and three premium colour styles), a review prompt and a forced-update gate.
- **No accounts needed:** every service builds, analyzes, tests and runs with **no accounts and no real keys**. Google's published test ad IDs are the only IDs committed. Firebase and RevenueCat switch on only when git-ignored config files and `--dart-define-from-file` values are present. Without them the app runs on no-op services, and the remote works exactly as in Phase 5.
- **Privacy:** nothing that identifies a TV (name, address, MAC, pin, pairing code) or anything the user typed ever reaches Analytics or Crashlytics. Where consent is required, nothing is shared until the user agrees.
- **Free forever:** Premium never gates a remote feature, a TV or reconnecting.
- **Carry-overs:** the Phase 5 carry-overs to Phase 6 land: the banner, the Premium and Privacy-choices rows, the `AD_ID` manifest test, the FAQ privacy answer, the listener debug log, the scrubbing reporter, the startup timeout and the real OS version in feedback.

**Architecture:**
- Every vendor SDK sits behind a small interface in `app/lib/core/<service>/`. **Exactly one adapter file per SDK** imports the vendor package (a source-scan test enforces this).
- Features depend on Riverpod providers that pick the real adapter or a no-op one:
  - `serviceConfigProvider` holds the dart-define values.
  - `firebaseStatusProvider` holds the result of initialisation.
- Firebase starts in a bootstrap startup step, which has a timeout and must not throw. Everything else starts after the first frame and never blocks it.
- `CrashReporter` becomes a delegating reporter. It logs from the first line of `main`, and after Firebase is ready it forwards to a **scrubbing** Crashlytics reporter.
- `AppAnalytics` wraps the sink. It applies the event-catalogue guard (it throws in debug), the user's privacy choice and a small buffer for the time before the consent region is known.
- Consent, ATT, ads, purchases and the review prompt are keepAlive controllers over fakeable services.
- The UI never touches a socket. The library (`packages/atv_remote`) doesn't change in this phase.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2 (riverpod_generator 4.0.4), go_router 18.1.1, drift 2.34.0. New in this phase, all pinned exactly. They were resolved together against this workspace with `flutter pub add --dry-run` on 2026-10-27:
- firebase_core 5.1.0, firebase_crashlytics 6.0.1, firebase_analytics 13.0.1, firebase_remote_config 7.0.1. The Firebase Android SDK is BoM 35 (needs minSdk 24) and the Firebase iOS SDK is 13 (**needs iOS 15.0**).
- google_mobile_ads 9.2.0 (also pulls webview_flutter 4.14.1; Android minSdk 24, iOS 13).
- app_tracking_transparency 2.0.7.
- purchases_flutter 10.18.1 (Android minSdk 21, iOS 13).
- in_app_review 2.0.12, device_info_plus 13.3.0.
- Gradle plugins (newest on Google Maven, 2026-10-27): `com.google.gms.google-services` 4.5.0 and `com.google.firebase.crashlytics` 3.0.8. Whether they work with AGP 9.0.1 is (unverified). Task 6.2 proves it with a throw-away config.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md` (binding: goals 8, 9, 11; anti-goals "ads that can be hit by accident", "logging personal data", "remote unusable when Firebase, ads or RevenueCat are offline"). This plan expands Phase 6 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md`. It keeps that plan's interfaces and test names except where a **Ruling** below says otherwise. Before starting, read:
- the `app-services` skill (primary), plus `store-release`, `flutter-app-architecture` and `remote-design-system` (safe zones, paywall rules)
- `docs/knowledge/decisions.md` #5, #6, #12, #20, #27, #30, #35, #37 and `learnings.md` (especially "Phase 5 gotchas" and "Riverpod 3 and widget-test gotchas")
- `app/lib/bootstrap.dart`, `app/lib/core/crash/{crash_reporter,error_handlers}.dart`, `app/lib/core/ads/banner_slot.dart`, `app/lib/app/{app,app_shell,router,app_links}.dart`, `app/lib/core/storage/{settings_store,settings_controller}.dart`, `app/lib/features/remote/application/remote_actions.dart` (`remoteActionListenerProvider`), `app/lib/features/settings/presentation/{settings_screen,appearance_page,about_page}.dart`, `app/lib/features/apps/presentation/apps_screen.dart`, `app/test/helpers/pump_router_app.dart`, `app/test/platform/*`
- Google's AdMob test-ID page, UMP guide (Flutter), Firebase consent-mode docs, RevenueCat Flutter docs and Apple guideline 5.1.1(iv) / 3.1.2. Reference only; record surprises as learnings.

## Global Constraints

- Flutter 3.44.1 / Dart 3.12.1, `environment.sdk: ^3.12.1`. Lints: `very_good_analysis` 10.3.0 with `public_member_api_docs`, so every public `lib/` member gets a `///` doc. Keep pubspec dependencies sorted.
- **Dependencies:** only the versions in the Tech Stack line, pinned exactly (`flutter pub add name:version`), each added by the task that first needs it:
  - 6.2: firebase_core
  - 6.3: firebase_crashlytics
  - 6.4: firebase_analytics
  - 6.5: firebase_remote_config
  - 6.6: google_mobile_ads, app_tracking_transparency
  - 6.7: purchases_flutter
  - 6.10: in_app_review, device_info_plus

  `git add` includes the root `pubspec.lock` (pub workspace).
- **Vendor isolation:** each vendor package is imported by its adapter file only (the File Structure lists them). `test/platform/vendor_imports_test.dart` (Task 6.2) enforces this. Interfaces and domain types are our own. No RevenueCat, AdMob or Firebase type appears in a provider signature or a widget.
- **No secrets, no real IDs** (CLAUDE.md, `store-release`):
  - Never commit `google-services.json`, `GoogleService-Info.plist`, `app/env/*.json` (except `example.json`), `app/android/secrets.properties` or `app/ios/Flutter/Secrets.xcconfig`.
  - The only AdMob IDs in the repo are Google's test IDs (publisher `ca-app-pub-3940256099942544`; `no_real_admob_ids_committed` scans for others).
  - No RevenueCat key (`goog_`, `appl_`, `test_` prefixes) and no Firebase API key (`AIza`) in tracked files.
- **Works with no accounts:** `powershell -File tool/check.ps1` and `flutter build apk --debug --flavor dev -t lib/main_dev.dart` pass on a clean clone with no config files and no dart-defines. Tests never call a platform channel: every vendor-backed provider gets a fake or no-op default in `pumpRouterApp` (each task adds its own defaults there) and in the `buildRootWidget` overrides used by `test/bootstrap_test.dart`. Real adapters catch every error, `MissingPluginException` included, and degrade instead of throwing.
- **The remote first:** no service failure, timeout or missing config may block the first frame for more than the startup-step timeout (5 s each). None may stop a key press or show an error to the user, except the forced-update gate and the paywall's own errors.
- **Privacy (decision #6, anti-goals, P4-R17):**
  - No analytics parameter or crash payload may contain a TV name, nickname, mDNS service name, host, IP, MAC, key pin, pairing code, typed text or a custom package name.
  - `TextSent` is never logged. Screen names are route names, never paths.
  - Collection is off natively until the Dart side turns it on (Ruling P6-R2).
  - Usage counts (decision #30) stay on the phone.
- **Ads (decision #6, `remote-design-system` safe zones):**
  - Only `BannerSlot` shows a banner, and it exists only on `/apps` and the `/settings` hub.
  - No ad within 48 dp of any tappable control (Ruling P6-R9).
  - No ads before consent is resolved, none for Premium users, and none on the remote, discovery, pairing, onboarding, paywall, Settings sub-pages, sheets or dialogs.
  - Interstitials are off unless Remote Config turns them on.
- **Premium (decision #6):** removes ads and unlocks colour styles. Nothing else is gated, ever.
- **Strings:** every Phase 6 string is added to `app/lib/app/l10n/app_en.arb` in **Task 6.1** (Ruling P6-R1), each with an `@key` description. Later tasks use those keys and don't edit the ARB file. If a task finds it needs another string, it stops and reports the key and copy to the controller. No hard-coded UI text. Exceptions (not ARB):
  - iOS `Info.plist` purpose strings (English for now; `InfoPlist.strings` arrives with the Malay translation in Phase 8)
  - store prices and the period text the store returns (`priceString`)
  - the Phase 2 startup error screen
- **Navigation model:**
  - Pushed pages have a back arrow and a title that names the page. The paywall closes with ✕ (`closeAction`) and returns to its source (Ruling P6-R11).
  - Dialogs use `showAppDialog`, sheets `showAppSheet`; never a stock `AlertDialog`.
- Touch targets ≥ 48 dp, ≥ 8 dp apart. Every new screen, sheet and dialog is tested at **320 dp width and 200% text** (no exception thrown, nothing that carries meaning clipped), with a non-linear text scaler, and in light and dark. Colour is never the only signal (locked styles say "Included with Premium").
- Use `EdgeInsetsDirectional`/`AlignmentDirectional` in new layout code. Respect reduce motion.
- Platform branches use `defaultTargetPlatform` (tests set `debugDefaultTargetPlatformOverride` and reset it in `tearDown`), never `dart:io Platform`. The one exception is `AppInfo`.
- Riverpod 3:
  - `Override` and `ProviderException` come from `package:flutter_riverpod/misc.dart`.
  - Check `ref.mounted` after every `await` in a notifier, and watch every dependency before the first `await`.
  - A notifier can't `ref.invalidate` a provider that depends on it (use `ref.container.invalidate`).
  - Use `retry: noRetry` on providers whose errors the UI shows.
  - Hold a `container.listen` subscription across an await on an autoDispose `.future` (learnings).
- Time: production code uses `clock`. Tests use `fakeAsync` or `tester.pump(duration)`, with no real waits over 100 ms.
- drift: widget tests never subscribe to a drift `.watch()` stream. Use the in-memory repositories.
- Code generation: `flutter pub run build_runner build --delete-conflicting-outputs`, then `dart format lib test`, both from `app/`. On Windows, revert unrelated `.g.dart` files that changed only in line endings.
- Goldens: one `*_golden_test.dart` per subject, `@Tags(['golden'])`, baselines in `goldens/` next to the test, generated on Windows with `flutter test --update-goldens --tags golden <path>`. Inspect every new or changed PNG. Never commit `failures/` folders.
- `flutter`/`dart` commands run from `app/`; `check.ps1` and `git` from the repo root. Before every commit, `powershell -File tool/check.ps1` must print `All checks passed.`
- Commits end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Don't edit `docs/knowledge/*`, `CLAUDE.md` or `.claude/skills/*`. Put knowledge and skill updates in your task report; the controller applies them.

## Rulings (conflicts and open questions resolved for this phase)

1. **P6-R1 — Strings, routes, stubs and storage keys land first.**
   - Task 6.1 adds:
     - every Phase 6 ARB key (the table in Task 6.1)
     - the routes `/settings/privacy` and a real `/paywall` (`PaywallScreen` stub), a `name:` on every `GoRoute`
     - the Premium and Privacy-choices hub rows
     - every new `SettingsStore` key
     - the `PrivacyChoices` model and a `premiumProvider` stub (always free)
     - `app/env/example.json` and the `.gitignore` additions
   - Later tasks replace stub bodies and never touch `app_en.arb` or the route table. 6.4 adds an observer to `router.dart`; that's the only later router edit.
   - `AppRoutes.paywall` takes a `PaywallSource` (`settings`, `themes`, `privacy`, `unknown`), not a string. An unknown or missing `source` query is `unknown`.
2. **P6-R2 — Config without accounts** (amends the `store-release` config table and the master Task 6.1 "flutterfire config" note).
   - **Dart values** come only from `--dart-define-from-file=env/<flavor>.json`. Keys (`ServiceConfigKeys`):
     - `FIREBASE_ENABLED`
     - `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`
     - `ADMOB_BANNER_ANDROID`, `ADMOB_BANNER_IOS`, `ADMOB_INTERSTITIAL_ANDROID`, `ADMOB_INTERSTITIAL_IOS`
     - `UMP_DEBUG_GEOGRAPHY` (`''`, `eea` or `other`; dev only)
     - `UMP_TEST_DEVICE_ID` (dev only)

     All default to empty/false. `app/env/example.json` holds every key with an empty value, plus a `_README` string explaining the copy step.
   - **Firebase native config:**
     - Android `app/android/app/src/<flavor>/google-services.json`, iOS `app/ios/config/<flavor>/GoogleService-Info.plist`; all git-ignored.
     - Android applies the google-services and Crashlytics Gradle plugins **only when a flavor's file exists**.
     - iOS copies the plist with a committed script that does nothing when the file is missing.
   - **Firebase starts only when `FIREBASE_ENABLED` is true** (`Firebase.initializeApp()` reads the native files). Otherwise `FirebaseStatus.notConfigured`. A throw or a 5 s timeout gives `FirebaseStatus.unavailable`. Both give no-op services.
   - **Collection is off natively until the Dart side turns it on:** Android `<meta-data>` and iOS `Info.plist` keys disable Analytics and Crashlytics collection, Analytics ad-ID/IDFV collection and every consent-mode default (Task 6.2).
   - **iOS deployment target becomes 15.0** (Firebase iOS SDK 13). This supersedes "iOS deployment target 13.0" in the master Global Constraints.
   - The flutterfire-generated `firebase_options.dart` is **not** used. Whether `Firebase.initializeApp()` without options throws cleanly on iOS when the plist is missing is (unverified, Mac). Don't set `FIREBASE_ENABLED` without the plist.
3. **P6-R3 — Startup order** (amends the `app-services` skill's order: RevenueCat moves before ads):
   1. `main`: a `DelegatingCrashReporter` (logging) is installed before anything else.
   2. Startup step 1 (≤ 5 s): Firebase init. If ready, the delegate becomes the scrubbing Crashlytics reporter (6.3).
   3. Startup step 2 (≤ 5 s): Remote Config `ensureInitialized` + `activate` (values fetched last launch); `fetch` runs unawaited for next launch (Ruling P6-R7).
   4. First frame.
   5. Without waiting, in parallel: the silent UMP update (`requestConsentInfoUpdate`, writes the consent region) and the RevenueCat `configure` (Premium is then known before any banner).
   6. When `/remote` first becomes the top route: the UMP consent form, if UMP requires one.
   7. Before the first banner load on iOS: the ATT pre-prompt, then the system prompt.
   8. Ads SDK init (after consent and only if `canRequestAds`), then the banner.

   `StartupGate` gets an overall 20 s timeout. On timeout it shows the existing error screen and reports `startup timeout` as fatal (Phase 5 carry-over).
4. **P6-R4 — Privacy choices and the consent region.**
   - Two user choices in `AppSettings`, tri-state (`bool?`, `null` = never chosen): `shareUsageStats`, `shareCrashReports`.
   - `ConsentRegion { unknown, required, notRequired }` is app state. It is written from UMP's consent status after every silent update:
     - `notRequired` → `notRequired`
     - `required` or `obtained` → `required`
     - `unknown` or an error → keep the stored value
   - **Effective share** = `choice ?? (region == ConsentRegion.notRequired)`. Where consent is required, or before the region is known, nothing is shared until the user turns it on in Settings → Privacy choices. Elsewhere, sharing is on until the user turns it off.
   - UMP's ad consent never counts as consent for our analytics (TCF covers Google's ad purposes, not `analytics_storage`; (unverified) whether Firebase infers `analytics_storage` from TCF).
   - While a choice is `null` **and** the region is `unknown`, analytics events wait in a buffer (the latest 50). They are sent when sharing turns out allowed and dropped when it turns out denied. Crash reports aren't buffered: Crashlytics keeps them on the device while collection is off.
   - **Debug builds never send crash reports** (logging only). Profile and release builds of either flavor do, when configured and allowed. Analytics sends from every build mode when configured and allowed (DebugView).
5. **P6-R5 — Crash scrubbing.** `CrashScrubber.scrub(text)` replaces, in this order:
   - PEM blocks → `<pem>`
   - base64 runs of ≥ 40 characters that contain a digit, an upper-case and a lower-case letter → `<b64>`
   - mDNS service names (`*._androidtvremote2._tcp*`, `*._androidtvremote._tcp*`) and `*.local` host names → `<host>`
   - the saved TVs' display names, nicknames and service names (≥ 3 characters, case-insensitive, not inside a longer word) → `<tv>`
   - MAC addresses in `:`, `-`, dotted and bare forms → `<mac>`
   - IPv6 (≥ 2 colons between hex groups, optional `%zone`) and IPv4 → `<ip>`
   - hex runs of ≥ 12 characters → `<hex>`
   - 6-character hex tokens containing a digit (pairing codes) → `<code>`

   The scrubbing reporter:
   - Sends `ScrubbedError('<runtimeType>: <scrubbed message>')` with the original stack trace (Dart frames carry no data) and a scrubbed `reason`.
   - For `FlutterErrorDetails`: only the scrubbed `exceptionAsString()` and `context`. `informationCollector` (which can hold widget values such as typed text) is dropped.
   - Never sets a user ID or custom keys.
   - Over-scrubbing ordinary text such as times (`12:30:45`) is accepted.
6. **P6-R6 — Analytics catalogue and guard** (the `app-services` list, made exact):

   | Event | Params (all required) | Logged when |
   |---|---|---|
   | `onboarding_complete` | none | either onboarding button |
   | `tv_discovered` | `count` int ≥ 1 | the first time a `DiscoveryController`'s list becomes non-empty |
   | `pair_start` | none | a pairing controller starts |
   | `pair_success` | none | pairing saved the TV |
   | `pair_fail` | `reason`: snake_case `PairingErrorKind` name, or `code_expired` | the pairing ends without success |
   | `connect_success` | none | a non-demo session's status becomes `connected` from any other status |
   | `connect_lost` | `reason`: snake_case `RemoteCloseReason` name or `unknown` | `connected` → anything but `connected`, unless the reason is `closedByClient` |
   | `key_press` | `key`: a name from `analyticsKeyName` | 10% of `KeySent` (sampled) |
   | `app_launch` | `package`: a catalogue package, else `custom` | `AppLaunched` |
   | `layout_change` | `layout`: `touchpad`, `dpad`, `apps`, `colour_keys`, `media_keys` or `none` | `navigationStyle` or `quickAccessRow` changed (Settings or a pad swipe) |
   | `paywall_view` | `source`: `PaywallSource` name; `variant`: the Remote Config value | the paywall opens |
   | `purchase_success` | `product`: `premium_monthly`, `premium_yearly` or `premium_lifetime` | a purchase unlocked Premium |
   | `restore_success` | none | a restore unlocked Premium |
   | `review_prompt_shown` | none | the review API was asked |

   - Screen views use `logScreenView(screenName: <GoRoute name>)` for page routes whose name is in `AppRouteNames.all`. Sheets, dialogs and unknown names are ignored. Paths are never used.
   - Demo sessions log no `connect_*`, `key_press` or `app_launch`.
   - **Guard:** event names and param keys must match the table exactly. Enumerated params must hold one of their values. Every string must match `^[A-Za-z0-9_.]{1,100}$`. It must also not contain an IPv4, IPv6, MAC or ≥ 12-hex run, `manual:`, `.local` or `_tcp`.
   - A violation throws `AnalyticsPolicyError` in debug builds and drops the event (with a debug-only log of the event name) in release.
   - The guard runs for every sink, the no-op one included, so every widget test checks the params of everything it triggers.
7. **P6-R7 — Remote Config.**
   - Keys and in-code defaults exactly as the skill: `ads_banner_enabled=true`, `ads_interstitial_enabled=false`, `ads_interstitial_min_interval_s=600`, `review_prompt_min_key_presses=150`, `paywall_variant="a"`, `min_supported_version="1.0.0"`, `catalogue_version=1`.
   - **Values fetched in one launch apply from the next launch** (activate at start, fetch in the background). A kill switch then takes effect on the next start, and nothing flips mid-session. Fetch interval 1 h (prod) or 5 min (dev); fetch timeout 10 s.
   - A value of the wrong type falls back to its default. Without Firebase: defaults only.
   - **Forced update:**
     - When the app's version is below `min_supported_version` (numeric `major.minor.patch`; build suffix ignored), a blocking "Update required" screen replaces every route, the demo included.
     - Its only action opens the store listing (Android: the Play page for the flavor's application id; iOS: the `AppLinks.appStoreListing` **placeholder** until the App Store record exists, Phase 9).
     - A malformed value, or app info that can't be read, never blocks.
8. **P6-R8 — Consent and ATT UX.**
   - **UMP form:** shown once per launch at most, the first time `/remote` becomes the top route (the demo included). Never over onboarding, discovery or pairing. `BannerSlot` also waits for it, so no ad can load first.
   - **Privacy choices page** (`/settings/privacy`, from the Settings hub):
     - the two switches (showing the effective value; a change stores an explicit choice and applies at once)
     - "Ad privacy choices" (UMP privacy-options form), only when UMP says it's required
     - "Remove ads with Premium" (free users)
     - on iOS, an "Ad tracking" status row that opens the phone's Settings (`app-settings:`)
     - a note when Firebase is off in this build
   - **ATT pre-prompt:**
     - Shown on iOS only, and only when the ATT status is `notDetermined` and it was never shown before. It appears right before the first banner load.
     - A themed dialog with **one** action, "Continue", which always leads to the system prompt. It has no "Not now" and can't be dismissed by the barrier or Back: Apple 5.1.1(iv) reviewers reject pre-prompts with a way out ((unverified) current practice).
     - Ads load either way; the SDK reads the ATT status.
     - The file is `app/lib/core/ads/tracking_preprompt.dart`, not `features/onboarding/` (master 6.2): it isn't part of onboarding.
   - Android `com.google.android.gms.permission.AD_ID` is declared explicitly. Analytics never uses it (`google_analytics_adid_collection_enabled=false`).
9. **P6-R9 — Ads.**
   - **Unit IDs:**
     - **dev always uses Google's test units** (it ignores the defines). Test IDs: banner Android `ca-app-pub-3940256099942544/9214589741`, iOS `ca-app-pub-3940256099942544/2435281174`; interstitial Android `ca-app-pub-3940256099942544/1033173712`, iOS `ca-app-pub-3940256099942544/4411468910`.
     - **prod uses the `ADMOB_*` defines**, and an empty define means no ad of that kind.
   - **App IDs (native, required or the SDK crashes at launch):**
     - Android `${admobAppId}` manifest placeholder:
       - dev: the test ID `ca-app-pub-3940256099942544~3347511713`
       - prod: `admobAppIdProd` from git-ignored `app/android/secrets.properties`, else the test ID with a Gradle warning
     - iOS `GADApplicationIdentifier = $(ADMOB_APP_ID)`:
       - dev configs: the test ID `ca-app-pub-3940256099942544~1458002511`
       - prod configs: `$(ADMOB_APP_ID_PROD)`, defined as the test ID in `Debug/Release.xcconfig` and overridable from git-ignored `Secrets.xcconfig`
     - `DELAY_APP_MEASUREMENT_INIT` / `GADDelayAppMeasurementInit` = true.
   - **Banner eligibility:** all of these must hold:
     - a unit ID for this flavor and platform
     - `ads_banner_enabled`
     - Premium known and false
     - consent gathered and `canRequestAds`
     - on iOS, the ATT decision made
     - the screen tall enough: screen height − vertical padding − 64 (app bar) − 48 (label band) − banner height ≥ 200
   - **Layout:**
     - Until an ad has loaded, the slot is zero-size, exactly as in Phase 5.
     - A loaded ad shows as a top `Divider` (outline), then a **label band at least 48 dp tall** with the centred caption "Advertisement" (`textSecondary`), then the large anchored adaptive banner (`getLargeAnchoredAdaptiveBannerAdSizeWithOrientation` for the safe-area width).
     - The band keeps the ad creative ≥ 48 dp away from any control in the scroll view above it, wherever it's scrolled.
     - The whole slot is one semantics container labelled "Advertisement".
   - **Lifecycle:**
     - Each `BannerSlot` loads its own ad and disposes it on leave.
     - It reloads when the width or orientation changes.
     - A failed load takes no space and isn't retried in that visit.
   - **Interstitial** (`InterstitialTrigger.leftSettings` only: popping the Settings hub). Shown only if all of these hold:
     - `ads_interstitial_enabled`
     - not Premium, not demo
     - `canRequestAds`
     - launch count ≥ 2
     - ≥ `ads_interstitial_min_interval_s` since the last one (persisted)
     - no connection loss or not-connected notice in the last 60 s
     - an ad already loaded (it never waits; it preloads after consent while enabled)
10. **P6-R10 — Premium and RevenueCat.**
    - **Store setup:**
      - Entitlement `premium`; products `premium_monthly`, `premium_yearly`, `premium_lifetime` (non-consumable).
      - The current offering's `PackageType.monthly`/`annual`/`lifetime` packages map to `PremiumPlanKind.monthly`/`yearly`/`lifetime`. Missing packages are skipped; none at all means "unavailable".
      - Users are anonymous: never `logIn`, never device identifiers or attributes. Debug logs only in dev.
      - **No introductory offers or trials in v1.** The owner must not configure them (the paywall has no copy for them).
    - **`premiumProvider` state:** `PremiumState { isPremium, known, expiresAt, lifetime }`. It starts from the cached last entitlement (`premium.active`, `premium.expires_at`; still valid while not expired, lifetime never expires).
      - With a configured service, `known` becomes true on the first live entitlement or after 5 s (then the cache stands).
      - With no key (`UnavailablePurchaseService`), the cache is `known` at once, so dev without RevenueCat still shows test ads.
      - Every live answer rewrites the cache.
11. **P6-R11 — Paywall** (`remote-design-system` paywall rules, Apple 3.1.2):
    - **Layout, in order:**
      - the value first: No ads, Colour styles
      - the honest note that everything else stays free
      - the plans as a radio group, with the price from the store and the renewal terms under each
      - Continue, Restore purchases
      - the platform's billing terms
      - Terms of use and Privacy policy links
    - All of it is in one scroll view, with no bottom-anchored buttons.
    - **Pre-selected plan:**
      - Yearly, when its price is below 12× the monthly price, shows "Best value" and "Save N%" (N = floor of (1 − yearly / (12 × monthly)) × 100).
      - Otherwise monthly is pre-selected, with no badge.
      - Lifetime is never pre-selected.
    - **Navigation:** ✕ (leading, `closeAction`) pops when possible, else `go('/remote')`. No banner, ever.
    - **Already Premium:** "You have Premium", plus Manage subscription (store subscription page; not for lifetime) and Restore.
    - **Outcomes:**
      - Purchased: "Welcome to Premium. Thank you!" snackbar, then close.
      - Cancelled: nothing.
      - Pending: a message.
      - Already owned: suggests Restore.
      - Other failures: a message.
12. **P6-R12 — Colour styles** ("premium themes"):
    - `ColourStyle { standard, ocean, ember, midnight }`; `standard` is the Phase 2 palette and is free.
    - Each premium style overrides `bg`, `surface`, `surfaceRaised`, `outline`, `textPrimary`, `textSecondary`, `accent` and `onAccent` for light and dark. Status, danger and TV-key colours are unchanged. Theater mode ignores styles.
    - **Effective style:**
      - Colours from wallpaper on → dynamic colour wins, and the style group shows a note.
      - Else Premium → the stored style.
      - Else `standard`.
    - Losing Premium keeps the stored choice, so it returns with Premium.
    - Free users see the three styles with "Included with Premium". Tapping one opens `/paywall?source=themes` and changes nothing.
13. **P6-R13 — Review prompt.**
    - **When:** `in_app_review` is asked at most once per install, when all of these hold:
      - cumulative key presses ≥ `review_prompt_min_key_presses`
      - launch count ≥ 2
      - the session isn't the demo
      - a non-demo session has just become `connected` at the start of a session, with no connection loss or not-connected notice in the previous 60 s
    - The press count is kept in memory, written every 10 presses and on pause.
    - An unavailable review API marks nothing (it tries again next time).
14. **P6-R14 — Carry-overs** (all items under "Carry-over to Phase 6" in `status.md`):
    - **Banner:** the banner fills `BannerSlot` (6.8). The Premium and Privacy-choices rows are added (6.1), with the page (6.6) and the Premium subtitle (6.7).
    - **Permission test:** `android_queries_test` asserts exactly the five permissions: the four network permissions + `AD_ID` (6.6).
    - **FAQ:** `faqPrivacyA` changes copy (6.1) and a seam test keeps it true (6.11). Auto Backup stays in Phase 8.
    - **Error handling:**
      - `RemoteActions._report` logs listener failures in debug builds (event type only, 6.4).
      - Crashlytics only ever sees scrubbed text (6.3).
      - `StartupGate` times out (6.2).
    - **OS version:** feedback's OS version comes from `device_info_plus` (`Android 12`, `iOS 17.5`), not the kernel string (6.10).
15. **P6-R15 — Out of scope:**
    - Phase 7: onboarding cards (they'll call the same `onboarding_complete`), a Settings entry before pairing, so Privacy choices are reachable from discovery.
    - Phase 8: the `allowBackup` decision, `InfoPlist.strings`, the sandbox purchase integration checklist, the device matrix.
    - Phase 9:
      - real Firebase/AdMob/RevenueCat config, store products, Data safety and App Privacy forms
      - the privacy policy text covering these SDKs
      - the App Store id for `appStoreListing`
      - Crashlytics dSYM/mapping upload in release scripts
    - Not in v1: mediation, rewarded or native ads, real-time Remote Config, A/B paywall variants beyond `a`, accounts, server receipts of our own.

## Review Focus

1. **The remote works with every service failing, offline or unconfigured.** No startup step can hang the first frame, and no failing SDK can throw into the UI (Task 6.2 `app_starts_when_firebase_init_fails`, `startup_that_never_finishes_shows_the_error_screen`; Task 6.11 `the_remote_works_with_every_service_failing`).
2. **No ad before consent, nowhere but the two screens, never near a control.** Task 6.8 tests: `ads_not_initialised_before_consent_resolved`, `no_banner_on_remote_screen`, `banner_has_48dp_clearance_from_nav_controls`, `ios_waits_for_the_tracking_decision_before_the_first_ad`. Task 6.11: `banner_only_on_apps_and_the_settings_hub`.
3. **Nothing that identifies a TV, or anything the user typed, leaves the phone.** The guard, the scrubber, route names instead of paths, and `custom` instead of custom packages. Tests: Task 6.3 `scrubs_saved_tv_names_service_names_and_hosts`; Task 6.4 `analytics_rejects_params_with_ip_or_mac_pattern`, `screen_names_never_contain_route_parameters`; Task 6.11 `no_analytics_event_or_crash_report_carries_tv_data`.
4. **Choices are honoured live, and defaults are conservative where consent is required** (Task 6.4 `nothing_is_sent_when_usage_sharing_is_off`, `waiting_events_are_dropped_when_sharing_is_denied`; Task 6.3 `nothing_is_sent_when_crash_reports_are_off`; Task 6.6 `privacy_switches_show_the_effective_choice`).
5. **Premium is honest.**
   - Premium users never see an ad, even offline or before RevenueCat answers.
   - Nothing core is gated.
   - The paywall shows terms, Restore and the links, and closes back to its source.
   - Tests: Task 6.7 `offline_uses_cached_entitlement`, `paywall_shows_terms_restore_privacy`, `close_returns_to_source_route`; Task 6.8 `banner_hidden_for_premium`, `banner_waits_for_premium_to_be_known`.
6. **No secret or real ID is committed, and a clean clone builds** (Task 6.1 `secrets_are_git_ignored`; Task 6.6 `no_real_admob_ids_committed`; Task 6.2 `vendor_sdks_are_imported_only_by_their_adapters` and the no-config APK build).

---

## File Structure

```
.gitignore                                             secrets.properties, Secrets.xcconfig, ios/config/  (6.1)
app/
  pubspec.yaml                                         one dependency group per task (see Global Constraints)
  env/example.json                                     every ServiceConfig key, empty                    (6.1)
  android/settings.gradle.kts                          google-services 4.5.0 + crashlytics 3.0.8, apply false (6.2)
  android/app/build.gradle.kts                         conditional Firebase plugins (6.2); admobAppId placeholders (6.6)
  android/secrets.example.properties                                                                     (6.6)
  android/app/src/main/AndroidManifest.xml             Firebase collection-off meta-data (6.2); AD_ID, APPLICATION_ID, DELAY_APP_MEASUREMENT_INIT (6.6)
  ios/Runner.xcodeproj/project.pbxproj                 deployment target 15.0 + "Copy Firebase config" phase (6.2); ADMOB_APP_ID (6.6)
  ios/scripts/copy_firebase_config.sh                                                                    (6.2)
  ios/Flutter/{Debug,Release}.xcconfig                 ADMOB_APP_ID_PROD + #include? "Secrets.xcconfig"  (6.6)
  ios/Flutter/Secrets.example.xcconfig                                                                   (6.6)
  ios/Runner/Info.plist                                Firebase collection-off keys (6.2); GAD*, SKAdNetworkItems, NSUserTrackingUsageDescription (6.6)
  lib/
    bootstrap.dart                                     Firebase + RC startup steps, delegating reporter, timeout (6.2, 6.3, 6.5); launch count (6.10)
    app/l10n/app_en.arb                                every Phase 6 string                               (6.1)
    app/router.dart                                    /settings/privacy, PaywallScreen, route names (6.1); analytics observer (6.4)
    app/app.dart                                       consent + premium warm-up (6.6, 6.7); colour style (6.9)
    app/app_shell.dart                                 UpdateGate                                         (6.5)
    app/app_links.dart                                 store listing (6.5); subscription management links (6.7)
    app/theme/colour_styles.dart, app_theme.dart       premium palettes                                   (6.9)
    core/config/service_config.dart (+ .g.dart)                                                          (6.2)
    core/firebase/firebase_bootstrap.dart (+ .g.dart)  ADAPTER: firebase_core                             (6.2)
    core/crash/crash_reporter.dart                     DelegatingCrashReporter, CompositeCrashReporter    (6.2)
    core/crash/crash_scrubber.dart, scrubbing_crash_reporter.dart, crash_collection.dart (+ .g.dart)      (6.3)
    core/crash/crashlytics_sink.dart                   ADAPTER: firebase_crashlytics                      (6.3)
    core/analytics/analytics_events.dart, analytics_guard.dart, app_analytics.dart (+ .g.dart),
      analytics_route_observer.dart, analytics_hooks.dart (+ .g.dart), key_names.dart                    (6.4)
    core/analytics/firebase_analytics_sink.dart        ADAPTER: firebase_analytics                        (6.4)
    core/config/app_config.dart (+ .g.dart), app_version.dart, update_gate.dart                          (6.5)
    core/config/firebase_remote_config_source.dart     ADAPTER: firebase_remote_config                    (6.5)
    core/privacy/privacy_choices.dart (+ .g.dart)                                                        (6.1)
    core/ads/consent_service.dart, consent_controller.dart (+ .g.dart), tracking_service.dart,
      tracking_preprompt.dart                                                                            (6.6)
    core/ads/ump_consent_service.dart                  ADAPTER: google_mobile_ads (UMP)                   (6.6)
    core/ads/att_tracking_service.dart                 ADAPTER: app_tracking_transparency                 (6.6)
    core/ads/ad_unit_ids.dart, ads_service.dart (+ .g.dart), interstitials.dart (+ .g.dart)              (6.8)
    core/ads/google_mobile_ads_sdk.dart                ADAPTER: google_mobile_ads (ads)                   (6.8)
    core/ads/banner_slot.dart                          real body                                          (6.8)
    core/purchases/premium.dart (+ .g.dart)            stub (6.1) → real (6.7)
    core/purchases/purchase_service.dart, unavailable_purchase_service.dart                              (6.7)
    core/purchases/revenuecat_purchase_service.dart    ADAPTER: purchases_flutter                         (6.7)
    core/review/review_prompter.dart (+ .g.dart)                                                         (6.10)
    core/review/in_app_review_requester.dart           ADAPTER: in_app_review                             (6.10)
    core/app_info/app_info.dart                        ADAPTER: device_info_plus (OS version)             (6.10)
    core/storage/settings_store.dart                   every Phase 6 key                                  (6.1)
    features/settings/presentation/settings_screen.dart   Premium + Privacy rows (6.1); Premium subtitle (6.7); interstitial trigger (6.8)
    features/settings/presentation/privacy_choices_page.dart   stub (6.1) → page (6.6)
    features/settings/presentation/appearance_page.dart        colour styles (6.9)
    features/settings/presentation/about_page.dart             dev-only test crash row (6.3)
    features/paywall/presentation/paywall_screen.dart          stub (6.1) → screen (6.7)
    features/paywall/presentation/widgets/plan_tile.dart, application/paywall_controller.dart (+ .g.dart) (6.7)
    features/remote/application/remote_actions.dart    listener fan-out + debug log                       (6.4)
    features/remote/presentation/remote_screen.dart    consent gather on first top-route                  (6.6)
    features/pairing/application/pairing_controller.dart, features/discovery/application/discovery_controller.dart,
      features/onboarding/presentation/onboarding_screen.dart   analytics calls                           (6.4)
  test/
    helpers/test_premium.dart (6.1); recording_crashlytics_sink.dart (6.3); recording_analytics_sink.dart (6.4);
      fake_config_source.dart (6.5); fake_consent_service.dart, fake_tracking_service.dart (6.6);
      fake_purchase_service.dart (6.7); fake_ads_sdk.dart, ad_clearance.dart (6.8); fake_review_requester.dart (6.10)
    helpers/pump_router_app.dart                       each task adds its defaults
    platform/vendor_imports_test.dart, firebase_config_test.dart (6.2); ads_config_test.dart (6.6); secrets_ignored_test.dart (6.1)
    app/services_flow_test.dart, app/phase6_accessibility_test.dart                                      (6.11)
```

| Task | Master task | Deliverable |
|---|---|---|
| 6.1 | prep | Every ARB key; `/settings/privacy` + `/paywall` stubs; route names; hub rows; every new storage key; `PrivacyChoices`; `premiumProvider` stub; env example and ignores |
| 6.2 | 6.1 (part) | `ServiceConfig`, Firebase bootstrap, Android/iOS config plumbing (no accounts), iOS 15, delegating reporter, startup timeout, vendor-import test |
| 6.3 | 6.1 (part) | Scrubber, scrubbing Crashlytics reporter, collection follows the choice, dev test-crash row |
| 6.4 | 6.1 (part) | `AppAnalytics` (guard, choice, buffer), event hooks, route-name screen views, listener debug log |
| 6.5 | 6.1 (part) + 6.5 (part) | Remote Config `AppConfig`, forced-update gate |
| 6.6 | 6.2 | UMP consent, Privacy choices page, ATT pre-prompt, native ad IDs, `AD_ID` + manifest test |
| 6.7 | 6.4 | RevenueCat service, Premium state with cache, paywall |
| 6.8 | 6.3 | Ads service, the real `BannerSlot`, interstitial pacing |
| 6.9 | 6.4 (themes) | Colour styles (premium palettes) in Appearance and the theme |
| 6.10 | 6.5 (part) | Review prompter, launch and press counters, real OS version |
| 6.11 | exit | Seam tests, privacy and banner sweeps, accessibility, dev APK |

**Order and parallelism** (the controller runs one implementer at a time in the shared tree; "parallel-safe" means disjoint files, so reviews don't overlap):
- **6.1 first, alone.** Every task depends on its strings, routes, storage keys and stubs.
- **6.2 next.** 6.3–6.5 need `firebaseStatusProvider` and the bootstrap seams.
- **Group A after 6.2: 6.3, 6.4, 6.5.** Their review overlap is limited to `pubspec.yaml`/`pubspec.lock`, `bootstrap.dart` (6.3 and 6.5 each add a few lines) and appended `pumpRouterApp` defaults.
- **6.6 and 6.7 after 6.1.** They're parallel-safe with group A for review (they don't touch bootstrap or the Firebase files). Run them after group A anyway (pubspec order).
- **6.8 after 6.5, 6.6 and 6.7** (config, consent and Premium). **6.9 after 6.7.** **6.10 after 6.4 and 6.5.** 6.9 and 6.10 are parallel-safe with each other.
- **6.11 last.** Suggested run order: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10, 6.11.

---

### Task 6.1: All strings, the privacy and paywall routes, hub rows and the Phase 6 storage keys

**Files:**
- Modify:
  - `app/lib/app/l10n/app_en.arb`
  - `app/lib/app/router.dart` (routes, names, `PaywallSource`)
  - `app/lib/core/storage/settings_store.dart` (keys, `AppSettings` fields)
  - `app/lib/features/settings/presentation/settings_screen.dart` (two rows)
  - `.gitignore`
- Create:
  - `app/lib/core/privacy/privacy_choices.dart` (+ `.g.dart`)
  - `app/lib/core/purchases/premium.dart` (+ `.g.dart`, stub)
  - `app/lib/features/settings/presentation/privacy_choices_page.dart` (stub `PrivacyChoicesPage()`)
  - `app/lib/features/paywall/presentation/paywall_screen.dart` (stub `PaywallScreen({required PaywallSource source})`)
  - `app/env/example.json`
  - `app/test/helpers/test_premium.dart`
- Modify (tests):
  - `app/test/app/router_test.dart` (the three paywall tests use `PaywallSource`)
  - `app/test/app/apps_devices_settings_flow_test.dart` (the `AppRoutes.paywall(source: 'test')` line)
  - `app/test/core/storage/settings_store_test.dart`, `app/test/app/l10n/app_localizations_test.dart`
  - re-baseline `app/test/features/settings/goldens/settings_hub_{light,dark}.png`
- Test: create `app/test/core/privacy/privacy_choices_test.dart`, `app/test/features/settings/settings_hub_phase6_test.dart`, `app/test/platform/secrets_ignored_test.dart`

**Interfaces:**
- Consumes: `PlaceholderScreen`, `SettingsNavTile`, `SettingsStore`, `settingsControllerProvider`.
- Produces:
  - `AppRoutes.settingsPrivacy = '/settings/privacy'`.
  - `enum PaywallSource { settings, themes, privacy, unknown; static PaywallSource parse(String? s) }` (in `paywall_screen.dart`). `AppRoutes.paywall({required PaywallSource source}) => '/paywall?source=${source.name}'`. The router builds `PaywallScreen(source: PaywallSource.parse(state.uri.queryParameters['source']))`. Both stubs are `PlaceholderScreen`s titled `pageTitlePaywall` / `pageTitlePrivacyChoices`.
  - `abstract final class AppRouteNames`:
    - `onboarding`, `discover`, `pair`, `remote`, `apps`, `manageApps = 'manage_apps'`, `devices`, `editDevice = 'edit_device'`
    - `settings`, `settingsAppearance = 'settings_appearance'`, `settingsRemoteLayout = 'settings_remote_layout'`, `settingsRemoteBehaviour = 'settings_remote_behaviour'`, `settingsHelp = 'settings_help'`, `settingsAbout = 'settings_about'`, `settingsPrivacy = 'settings_privacy'`
    - `paywall`
    - `static const Set<String> all`

    Every `GoRoute` gets `name:` from it. Nothing else in the router changes.
  - `SettingsStore` (keys added to `keys`; reads never throw, as now):
    - `AppSettings` gains `colourStyle` (`ColourStyle { standard, ocean, ember, midnight }`, default `standard`), `shareUsageStats` (`bool?`, default `null`) and `shareCrashReports` (`bool?`, default `null`). Equality, hash, `toString`, `defaults` and `snapshot` are updated.
    - Setters: `setColourStyle(ColourStyle)`, `setShareUsageStats(bool?)` and `setShareCrashReports(bool?)` (`null` removes the key). Keys: `settings.colour_style`, `privacy.share_usage`, `privacy.share_crashes`.
    - **App state** (not in `AppSettings`), each with a getter and setter:

      | Getter | Type, default | Key |
      |---|---|---|
      | `consentRegion` | `ConsentRegion`, default `unknown` | `privacy.consent_region` |
      | `trackingPrepromptShown` | `bool`, default `false` | `privacy.att_preprompt_shown` |
      | `cachedPremium` | `({bool active, DateTime? expiresAt})`, default `(active: false, expiresAt: null)` | `premium.active`; `premium.expires_at`, ms since the epoch, UTC |
      | `interstitialLastShownAt` | `DateTime?` | `ads.interstitial_last_shown_at` |
      | `reviewKeyPresses` | `int`, default 0 | `review.key_presses` |
      | `launchCount` | `int`, default 0 | `review.launch_count` |
      | `reviewPromptShown` | `bool`, default `false` | `review.prompt_shown` |
  - `privacy_choices.dart`:
    - `enum ConsentRegion { unknown, required, notRequired }`
    - `bool effectiveShare(bool? choice, ConsentRegion region) => choice ?? region == ConsentRegion.notRequired;`
    - `@immutable class PrivacyChoices { shareUsage, shareCrashReports, region, usageDecided /* choice != null || region != unknown */, crashDecided }`
    - `@Riverpod(keepAlive: true) class ConsentRegionState` (build reads the store; `Future<void> set(ConsentRegion)` writes, then publishes)
    - `@Riverpod(keepAlive: true) PrivacyChoices privacyChoices(Ref ref)` (watches `settingsControllerProvider` and `consentRegionStateProvider`)
  - `premium.dart`:
    - `@immutable class PremiumState { const PremiumState({required this.isPremium, required this.known, this.expiresAt, this.lifetime = false}); static const free = PremiumState(isPremium: false, known: true); }`
    - `@Riverpod(keepAlive: true) class Premium extends _$Premium { @override PremiumState build() => PremiumState.free; }`. The doc says Task 6.7 replaces the body and keeps the name and state type.
  - Test helper `TestPremium extends Premium` (`TestPremium(this.initial)`, `void set(PremiumState s) => state = s`). Use it as `premiumProvider.overrideWith(() => TestPremium(...))`.
  - Settings hub, section **App**, after Appearance:
    - `SettingsNavTile(icon: Icons.workspace_premium_outlined, title: pageTitlePaywall, subtitle: settingsPremiumSubtitle)` → `push(AppRoutes.paywall(source: PaywallSource.settings))`
    - `SettingsNavTile(icon: Icons.shield_outlined, title: pageTitlePrivacyChoices, subtitle: settingsPrivacyChoicesSubtitle)` → `push(AppRoutes.settingsPrivacy)`
  - `app/env/example.json`: `{"_README": "Copy to dev.json or prod.json (git-ignored) and fill in; run with --dart-define-from-file=env/<flavor>.json. Empty values keep a service off.", "FIREBASE_ENABLED": false, "REVENUECAT_ANDROID_KEY": "", "REVENUECAT_IOS_KEY": "", "ADMOB_BANNER_ANDROID": "", "ADMOB_BANNER_IOS": "", "ADMOB_INTERSTITIAL_ANDROID": "", "ADMOB_INTERSTITIAL_IOS": "", "UMP_DEBUG_GEOGRAPHY": "", "UMP_TEST_DEVICE_ID": ""}`.
  - `.gitignore` adds `app/android/secrets.properties`, `app/ios/Flutter/Secrets.xcconfig` and `app/ios/config/`.
- **ARB keys** (exact copy; placeholders are `String` unless noted). These are all of Phase 6's strings. Write each `@key` description from the "Used for" column.

  **Changed:**

  | Key | Copy | Used for |
  |---|---|---|
  | `faqPrivacyA` | `Your TV's name, network address and MAC address stay on this phone. The app never sends them to us. If you allow it in Settings → Privacy choices, the app sends anonymous usage statistics and crash reports, which never include them.` | FAQ answer (Phase 5 carry-over) |

  **Settings hub and About:**

  | Key | Copy | Used for |
  |---|---|---|
  | `settingsPremiumSubtitle` | `No ads and extra colour styles` | hub Premium row, free user |
  | `settingsPremiumActiveSubtitle` | `You have Premium. Thank you!` | hub Premium row, Premium user |
  | `pageTitlePrivacyChoices` | `Privacy choices` | page title and hub row |
  | `settingsPrivacyChoicesSubtitle` | `Usage statistics, crash reports and ads` | hub row subtitle |
  | `aboutTestCrash` | `Send a test crash report` | About row, dev flavor only |
  | `aboutTestCrashSent` | `Test crash report sent. It shows in Crashlytics within a few minutes.` | snackbar after the dev test crash |

  **Privacy choices:**

  | Key | Copy | Used for |
  |---|---|---|
  | `privacyIntro` | `Choose what the app may share. Your TV's name, network address and MAC address never leave this phone.` | page intro |
  | `privacySectionImprove` | `Help improve the app` | section header |
  | `privacyUsageTitle` | `Share usage statistics` | switch |
  | `privacyUsageSubtitle` | `Anonymous counts of the screens and features you use. Never what you type or anything about your TV.` | switch subtitle |
  | `privacyCrashTitle` | `Share crash reports` | switch |
  | `privacyCrashSubtitle` | `Sent when something goes wrong, so it can be fixed. Names, addresses and codes are removed first.` | switch subtitle |
  | `privacyServicesOff` | `This build of the app doesn't send usage statistics or crash reports.` | note when Firebase is off |
  | `privacySectionAds` | `Ads` | section header |
  | `privacyAdsInfo` | `The free app shows a banner ad at the bottom of the Apps and Settings screens only.` | Ads section text, free user |
  | `privacyAdsPremium` | `You have Premium, so the app shows no ads.` | Ads section text, Premium user |
  | `privacyAdChoices` | `Ad privacy choices` | row → consent options form |
  | `privacyAdChoicesSubtitle` | `Choose how ads are picked for you.` | row subtitle |
  | `privacyAdChoicesFailed` | `Couldn't open ad privacy choices. Check your internet connection and try again.` | snackbar |
  | `privacyRemoveAds` | `Remove ads with Premium` | row → paywall (source privacy) |
  | `privacyTrackingTitle` | `Ad tracking` | iOS status row |
  | `privacyTrackingAllowed` | `Allowed. You can change this in your iPhone's Settings.` | row subtitle |
  | `privacyTrackingDenied` | `Not allowed. You can change this in your iPhone's Settings.` | row subtitle |
  | `privacyTrackingNotDetermined` | `Not chosen yet. The app asks before it first shows an ad.` | row subtitle |
  | `privacyTrackingRestricted` | `Turned off on this iPhone.` | row subtitle |
  | `privacyOpensSettings` | `Opens your phone's Settings` | semantics hint of the tracking row |

  **Tracking pre-prompt:**

  | Key | Copy | Used for |
  |---|---|---|
  | `trackingPrepromptTitle` | `About ads in this app` | dialog title |
  | `trackingPrepromptBody` | `The free app shows a small ad at the bottom of this screen. Next, your iPhone asks whether the app may use your activity in other apps to choose ads. You see the same number of ads whatever you choose, and the remote works the same.` | dialog body |
  | `trackingPrepromptContinue` | `Continue` | the only action |

  **Ads:**

  | Key | Copy | Used for |
  |---|---|---|
  | `adLabel` | `Advertisement` | label band above the banner; its semantics label |

  **Paywall:**

  | Key | Copy | Used for |
  |---|---|---|
  | `paywallHeadline` | `Make the remote yours` | headline |
  | `paywallSubhead` | `Premium removes ads, adds colour styles and supports the app's development.` | text under the headline |
  | `paywallBenefitNoAds` | `No ads` | benefit title |
  | `paywallBenefitNoAdsBody` | `No banner on the Apps and Settings screens.` | benefit text |
  | `paywallBenefitStyles` | `Colour styles` | benefit title |
  | `paywallBenefitStylesBody` | `Ocean, Ember and Midnight, in light and dark.` | benefit text |
  | `paywallFreeForever` | `Everything else stays free: every TV, every remote control, app shortcuts, the keyboard and turning your TV on.` | honest note |
  | `paywallChoosePlan` | `Choose a plan` | radio group label |
  | `paywallPlanMonthly` | `Monthly` | plan title |
  | `paywallPlanYearly` | `Yearly` | plan title |
  | `paywallPlanLifetime` | `Lifetime` | plan title |
  | `paywallPricePerMonth` | `{price} per month` | plan price |
  | `paywallPricePerYear` | `{price} per year` | plan price |
  | `paywallPriceOnce` | `{price}, one payment` | lifetime price |
  | `paywallRenewsMonthly` | `Renews every month until you cancel.` | monthly terms |
  | `paywallRenewsYearly` | `Renews every year until you cancel.` | yearly terms |
  | `paywallLifetimeTerms` | `Pay once. No subscription.` | lifetime terms |
  | `paywallBestValue` | `Best value` | badge on yearly |
  | `paywallSavePercent` | `Save {percent}%` | badge text (`percent`: `int`) |
  | `paywallContinue` | `Continue` | purchase button |
  | `paywallRestore` | `Restore purchases` | restore button |
  | `paywallTermsAndroid` | `Payment is charged to your Google Play account. Subscriptions renew automatically until you cancel them in Google Play, and you keep Premium until the end of the period you paid for.` | billing terms, Android |
  | `paywallTermsIos` | `Payment is charged to your Apple ID. Subscriptions renew automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel them in your Apple ID settings.` | billing terms, iOS |
  | `paywallLoading` | `Loading plans…` | loading state |
  | `paywallUnavailableTitle` | `Premium isn't available right now` | no offering |
  | `paywallUnavailableBody` | `Check your internet connection and try again.` | no offering (button reuses `commonRetry`) |
  | `paywallPurchasing` | `Confirming your purchase…` | in progress |
  | `paywallWelcome` | `Welcome to Premium. Thank you!` | snackbar after a purchase |
  | `paywallPending` | `Your purchase is waiting for approval. Premium starts as soon as it's complete.` | pending purchase |
  | `paywallFailed` | `The purchase didn't go through. Try again.` | unknown or store failure |
  | `paywallNetworkError` | `Couldn't reach the store. Check your internet connection and try again.` | network failure |
  | `paywallNotAllowed` | `Purchases aren't allowed on this phone.` | purchases disabled |
  | `paywallAlreadyOwned` | `You already own Premium. Tap Restore purchases to get it back.` | already owned |
  | `paywallRestored` | `Purchases restored. You have Premium.` | restore success |
  | `paywallNothingToRestore` | `No purchases found for this account.` | restore found nothing |
  | `paywallRestoreFailed` | `Couldn't restore purchases. Try again.` | restore failed |
  | `paywallActiveTitle` | `You have Premium` | already-Premium state |
  | `paywallActiveBody` | `Thank you for supporting the app. There are no ads, and every colour style is yours.` | already-Premium state |
  | `paywallActiveLifetime` | `Lifetime Premium: it never expires.` | already Premium, lifetime |
  | `paywallManageSubscription` | `Manage subscription` | opens the store's subscription page |

  **Appearance:**

  | Key | Copy | Used for |
  |---|---|---|
  | `appearanceStyle` | `Colour style` | group label |
  | `appearanceStyleStandard` | `Standard` | style name |
  | `appearanceStyleOcean` | `Ocean` | style name |
  | `appearanceStyleEmber` | `Ember` | style name |
  | `appearanceStyleMidnight` | `Midnight` | style name |
  | `appearanceStyleLocked` | `Included with Premium` | subtitle of a locked style |
  | `appearanceStyleWallpaperOn` | `Colours from wallpaper are on, so colour styles don't show.` | note while dynamic colour is on |

  **Forced update:**

  | Key | Copy | Used for |
  |---|---|---|
  | `updateRequiredTitle` | `Update required` | blocking screen title |
  | `updateRequiredBody` | `This version of the app is too old to keep working reliably. Update to the latest version to continue.` | blocking screen text |
  | `updateRequiredAction` | `Update` | opens the store listing |
  | `updateRequiredFailed` | `Couldn't open the store. Update the app from your phone's app store.` | snackbar when the link fails |

- [ ] **Step 1: Write the failing tests**

```dart
// router_test.dart
testWidgets('every_route_renders_its_titled_screen', ...)
    // existing map + AppRoutes.settingsPrivacy: 'Privacy choices'; '/paywall': 'Premium' stays
testWidgets('paywall_route_parses_its_source', ...)
    // AppRoutes.paywall(source: PaywallSource.themes) → tester.widget<PaywallScreen>(…).source == PaywallSource.themes;
    // '/paywall?source=bogus' and '/paywall' → PaywallSource.unknown   (replaces paywall_route_passes_source / _without_source_)
test('route_helpers_encode_their_arguments', ...)  // + AppRoutes.paywall(source: PaywallSource.settings) == '/paywall?source=settings'
testWidgets('every_route_has_a_parameter_free_name', ...)
    // walk ref.read(appRouterProvider).configuration.routes recursively: every GoRoute.name != null,
    // in AppRouteNames.all, matches ^[a-z_]+$; AppRouteNames.all has 16 entries, no duplicates

// settings_store_test.dart
test('phase_6_values_default_and_round_trip', ...)
    // fresh store: colourStyle standard, shareUsageStats null, shareCrashReports null, consentRegion unknown,
    // trackingPrepromptShown false, cachedPremium (false, null), interstitialLastShownAt null, counters 0, reviewPromptShown false;
    // each setter round-trips (expiresAt compared in UTC ms); setShareUsageStats(null) removes the key
test('unknown_phase_6_enum_names_fall_back', ...)   // 'settings.colour_style' = 'neon' → standard; region 'mars' → unknown
test('every_phase_6_key_is_in_the_allow_list', ...)

// privacy_choices_test.dart
test('share_defaults_follow_the_consent_region', () {
  expect(effectiveShare(null, ConsentRegion.unknown), isFalse);
  expect(effectiveShare(null, ConsentRegion.required), isFalse);
  expect(effectiveShare(null, ConsentRegion.notRequired), isTrue);
  expect(effectiveShare(true, ConsentRegion.required), isTrue);
  expect(effectiveShare(false, ConsentRegion.notRequired), isFalse);
});
test('privacy_choices_follow_settings_and_region', ...)  // ProviderContainer.test; set region, then a choice → provider updates; decided flags

// settings_hub_phase6_test.dart (pumpRouterApp at /settings)
testWidgets('hub_has_premium_and_privacy_rows_after_appearance', ...)
    // order in the App section: Appearance, Premium, Privacy choices; tap Premium → PaywallScreen(source: settings);
    // back; tap Privacy choices → AppBar 'Privacy choices'
testWidgets('hub_fits_320dp_at_200_percent_text_with_the_new_rows', ...)

// app_localizations_test.dart
test('phase_6_strings_load', ...)
    // l.paywallPricePerMonth('RM 9.90') == 'RM 9.90 per month'; l.paywallSavePercent(40) == 'Save 40%';
    // l.faqPrivacyA contains 'Privacy choices'

// secrets_ignored_test.dart
test('secrets_are_git_ignored', ...)
    // ../.gitignore lines include google-services.json, GoogleService-Info.plist, app/env/*.json, !app/env/example.json,
    // app/android/secrets.properties, app/ios/Flutter/Secrets.xcconfig, app/ios/config/
test('env_example_lists_every_service_key_empty', ...)
    // jsonDecode(env/example.json): keys == {_README, FIREBASE_ENABLED, REVENUECAT_ANDROID_KEY, REVENUECAT_IOS_KEY,
    // ADMOB_BANNER_ANDROID, ADMOB_BANNER_IOS, ADMOB_INTERSTITIAL_ANDROID, ADMOB_INTERSTITIAL_IOS, UMP_DEBUG_GEOGRAPHY, UMP_TEST_DEVICE_ID};
    // FIREBASE_ENABLED == false; every other value except _README == ''
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app test/core/storage test/core/privacy test/features/settings test/platform`
Expected: FAIL (missing routes, keys and types).

- [ ] **Step 3: Implement** the ARB keys, then `flutter pub get` (regenerates l10n). Then the store keys, `privacy_choices.dart`, `premium.dart`, the stubs, routes and names, the hub rows, `example.json`, `.gitignore` and `TestPremium`. Run build_runner, then `dart format lib test`. Update the two tests that called `AppRoutes.paywall(source: '…')` and say so in the report.
- [ ] **Step 4: Re-baseline the hub goldens** (two new rows)

Run: `flutter test --update-goldens --tags golden test/features/settings/settings_hub_golden_test.dart` and inspect both.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add .gitignore app/env/example.json app/lib app/test
git commit -m "feat(app): phase 6 strings, privacy and paywall routes, hub rows and service settings keys" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decisions for Rulings P6-R1 and P6-R4 (model only), and the `faqPrivacyA` copy change.

---

### Task 6.2: Service config, Firebase bootstrap and native config plumbing

**Files:**
- Modify:
  - `app/pubspec.yaml` (`firebase_core: 5.1.0`)
  - `app/lib/bootstrap.dart`
  - `app/lib/core/crash/crash_reporter.dart`
  - `app/android/settings.gradle.kts`, `app/android/app/build.gradle.kts`
  - `app/android/app/src/main/AndroidManifest.xml`
  - `app/ios/Runner.xcodeproj/project.pbxproj`, `app/ios/Runner/Info.plist`
  - `app/test/helpers/pump_router_app.dart` (defaults), `app/test/bootstrap_test.dart`
- Create:
  - `app/lib/core/config/service_config.dart` (+ `.g.dart`)
  - `app/lib/core/firebase/firebase_bootstrap.dart` (+ `.g.dart`; the only `firebase_core` import)
  - `app/ios/scripts/copy_firebase_config.sh`
- Test: `app/test/core/config/service_config_test.dart`, `app/test/core/firebase/firebase_bootstrap_test.dart`, `app/test/platform/firebase_config_test.dart`, `app/test/platform/vendor_imports_test.dart`; additions to `app/test/bootstrap_test.dart`

**Interfaces:**
- Consumes: `buildRootWidget`, `runStartupSteps`, `StartupGate`, `installErrorHandlers`, `Flavor`.
- Produces:
  - `abstract final class ServiceConfigKeys` (the ten names from Ruling P6-R2, plus `static const all`; `_README` is not one).
  - `@immutable class ServiceConfig`:
    - `const` constructor; every field defaults to empty/false.
    - `static const ServiceConfig none = ServiceConfig();`
    - `static const ServiceConfig environment = ServiceConfig(firebaseEnabled: bool.fromEnvironment(ServiceConfigKeys.firebaseEnabled), revenueCatAndroidKey: String.fromEnvironment(...), ...);` (const evaluation is required for `fromEnvironment`)
    - `String? revenueCatKey(TargetPlatform p)` and `String? define(String key)` (non-empty or `null`)
    - `bool get umpDebugEea`, `String? get umpTestDeviceId`
  - `@Riverpod(keepAlive: true) ServiceConfig serviceConfig(Ref ref) => ServiceConfig.none;` (bootstrap overrides it).
  - `enum FirebaseStatus { notConfigured, unavailable, ready }`.
  - `Future<FirebaseStatus> initializeFirebase(ServiceConfig config, {Future<void> Function()? initializeApp, Duration timeout = const Duration(seconds: 5)})`:
    - `!config.firebaseEnabled` → `notConfigured`, without touching Firebase.
    - Otherwise it runs `initializeApp ?? () => Firebase.initializeApp()` with the timeout. A throw or timeout → `unavailable`; success → `ready`.
  - `@Riverpod(keepAlive: true) FirebaseStatus firebaseStatus(Ref ref) => FirebaseStatus.notConfigured;` (bootstrap overrides it).
  - `crash_reporter.dart` adds:
    - `class DelegatingCrashReporter implements CrashReporter { DelegatingCrashReporter(this.delegate); CrashReporter delegate; }`
    - `class CompositeCrashReporter implements CrashReporter { CompositeCrashReporter(List<CrashReporter> reporters); }`. It calls each reporter and swallows each one's failure.
  - `buildRootWidget(...)` gains `ServiceConfig serviceConfig = ServiceConfig.none` and `Future<FirebaseStatus> Function(ServiceConfig) initFirebase = initializeFirebase`:
    - Firebase is the first startup step. A throwing `initFirebase` counts as `unavailable` and is reported as `startup step 0`.
    - The container gets `serviceConfigProvider` and `firebaseStatusProvider` overrides.
    - The passed `startupSteps` run after it.
  - `bootstrap()`:
    - `final reporter = DelegatingCrashReporter(const LoggingCrashReporter());`, installed with `installErrorHandlers` before anything else.
    - `crashReporterProvider` is overridden with the same instance.
    - `serviceConfig: ServiceConfig.environment`.
  - `StartupGate({required build, required reporter, Duration timeout = const Duration(seconds: 20)})`. `build().timeout(timeout)`; a `TimeoutException` is reported as fatal with reason `startup timeout` and shows the error screen. Try again runs `build` afresh.
  - **Android:**
    - `settings.gradle.kts` plugins block adds `id("com.google.gms.google-services") version "4.5.0" apply false` and `id("com.google.firebase.crashlytics") version "3.0.8" apply false`.
    - `app/build.gradle.kts`, after the `plugins {}` block:

      ```kotlin
      // Firebase config is git-ignored: app/android/app/src/<flavor>/google-services.json.
      // Without it the plugins aren't applied and the app runs on no-op services (Ruling P6-R2).
      val firebaseFlavors = listOf("dev", "prod").filter { file("src/$it/google-services.json").exists() }
      if (firebaseFlavors.isNotEmpty()) {
          apply(plugin = "com.google.gms.google-services")
          apply(plugin = "com.google.firebase.crashlytics")
      }
      ```

      A flavor without its file must still build. If the google-services plugin 4.5.0 has `missingGoogleServicesStrategy`, set it to `WARN` through `extensions.configure<…>`. Otherwise apply only when **both** files exist. Report which.
  - **AndroidManifest** (inside `<application>`, with a comment citing Ruling P6-R2): `<meta-data>` `firebase_analytics_collection_enabled=false`, `firebase_crashlytics_collection_enabled=false`, `google_analytics_adid_collection_enabled=false`, `google_analytics_default_allow_analytics_storage=false`, `google_analytics_default_allow_ad_storage=false`, `google_analytics_default_allow_ad_user_data=false`, `google_analytics_default_allow_ad_personalization_signals=false`.
  - **iOS:**
    - Every `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` becomes `15.0;` (9 places).
    - A `PBXShellScriptBuildPhase` named `Copy Firebase config` is added to the Runner target's `buildPhases`, after Resources. It has a fresh unique 24-hex id, `alwaysOutOfDate = 1` and `shellScript = "/bin/sh \"$SRCROOT/scripts/copy_firebase_config.sh\"\n"`.
    - The script (`set -e`):
      - `flavor="${CONFIGURATION##*-}"`
      - copies `"$SRCROOT/config/$flavor/GoogleService-Info.plist"` to `"$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/"` when it exists
      - otherwise prints `note: no Firebase config for $flavor; Firebase stays off` and exits 0
    - `Info.plist` gets `FIREBASE_ANALYTICS_COLLECTION_ENABLED` `<false/>`, `FirebaseCrashlyticsCollectionEnabled` `<false/>`, `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED` `<false/>` and `GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE` / `_AD_STORAGE` / `_AD_USER_DATA` / `_AD_PERSONALIZATION_SIGNALS` `<false/>`.
  - `pumpRouterApp` defaults: `serviceConfigProvider.overrideWithValue(ServiceConfig.none)`, `firebaseStatusProvider.overrideWithValue(FirebaseStatus.notConfigured)`.
  - `vendor_imports_test.dart`:
    - Scans `lib/**/*.dart` for `package:firebase_core`, `firebase_crashlytics`, `firebase_analytics`, `firebase_remote_config`, `google_mobile_ads`, `app_tracking_transparency`, `purchases_flutter`, `in_app_review` and `device_info_plus` imports.
    - Each may appear only in its adapter file(s) from the File Structure. Write the allowlist for all of them now; files that don't exist yet simply have no imports.

- [ ] **Step 1: Write the failing tests**

```dart
// service_config_test.dart
test('none_has_every_service_off', ...)                // firebaseEnabled false; revenueCatKey(android/ios) null; define(any) null
test('empty_defines_count_as_missing', ...)           // ServiceConfig(revenueCatAndroidKey: '') → null
test('keys_match_the_env_example', ...)               // ServiceConfigKeys.all == example.json keys minus _README

// firebase_bootstrap_test.dart
test('not_enabled_never_touches_firebase', ...)       // initializeApp spy never called → notConfigured
test('a_throwing_init_is_unavailable', ...)           // throws PlatformException → unavailable
test('a_hanging_init_times_out', ...)                 // fakeAsync: never completes; 5 s → unavailable
test('a_good_init_is_ready', ...)

// bootstrap_test.dart (additions)
testWidgets('app_starts_when_firebase_init_fails', (t) async {   // master name
  final root = await buildRootWidget(flavor: Flavor.dev, crashReporter: rec,
      serviceConfig: const ServiceConfig(firebaseEnabled: true),
      initFirebase: (_) async => throw StateError('no config'),
      openSettings: memorySettings, openDatabase: memoryDb, overrides: serviceFakes);
  await t.pumpWidget(root); await t.pumpAndSettle();
  // the initial route renders (onboarding on a fresh store); container firebaseStatus == unavailable;
  // rec.errors.single.reason == 'startup step 0'
});
testWidgets('firebase_status_reaches_the_providers', ...)        // initFirebase returns ready → provider is ready
testWidgets('startup_that_never_finishes_shows_the_error_screen', ...)
    // StartupGate(timeout: 1 s, build: never-completing) → pump 1 s → 'The app could not start'; reporter fatal 'startup timeout';
    // 'Try again' with a working build → app shown
test('the_delegating_reporter_forwards_and_can_switch', ...)     // delegate swap; CompositeCrashReporter keeps going when one throws

// firebase_config_test.dart (text checks, like the Phase 2 platform tests)
test('android_applies_firebase_plugins_only_with_config', ...)
    // settings.gradle.kts declares both plugin ids with "apply false"; build.gradle.kts applies them inside an
    // `if (firebaseFlavors.isNotEmpty())` (or the both-files variant) block, never in plugins {}
test('firebase_collection_is_off_until_the_app_turns_it_on', ...) // the seven manifest meta-data and the seven plist keys
test('ios_deployment_target_is_15', ...)                          // no '= 13.0;' left; 9 × 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;'
test('ios_copies_firebase_config_per_flavor', ...)                // pbxproj has the phase in Runner's buildPhases; the script
                                                                  // exists, uses ${CONFIGURATION##*-}, tests -f and exits 0 without it
// vendor_imports_test.dart
test('vendor_sdks_are_imported_only_by_their_adapters', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/config test/core/firebase test/bootstrap_test.dart test/platform`
Expected: FAIL.

- [ ] **Step 3: Add the dependency**

Run: `flutter pub add firebase_core:5.1.0`

- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Build with no config, then with a throw-away config**

Run, from `app/`:
1. `flutter build apk --debug --flavor dev -t lib/main_dev.dart`. Expected: succeeds with no `google-services.json`.
2. Prove the plugins work with AGP 9.0.1. Write a **dummy** `android/app/src/dev/google-services.json` (git-ignored; never commit it):

   ```json
   {"project_info":{"project_number":"000000000000","project_id":"dummy-project","storage_bucket":"dummy-project.appspot.com"},"client":[{"client_info":{"mobilesdk_app_id":"1:000000000000:android:0000000000000000","android_client_info":{"package_name":"com.digitallinked.atvremote.dev"}},"api_key":[{"current_key":"dummy"}]}],"configuration_version":"1"}
   ```

3. Build `--flavor dev` and `--flavor prod` (debug). Expected: both succeed; prod builds without its file.
4. Delete the dummy file and confirm `git status` shows nothing under `android/app/src/`.

If the plugin versions fail with AGP 9.0.1, try the newest compatible versions and record them, or report the blocker. Don't apply the plugins unconditionally.

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git status --short app/android app/ios   # no google-services.json, no plist
git add app/pubspec.yaml pubspec.lock app/android app/ios app/lib app/test
git commit -m "feat(app): service config, firebase bootstrap behind config, ios 15, startup timeout" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- decisions: Ruling P6-R2 (incl. the iOS 15 change superseding the master constraint) and P6-R3 (startup order; the `app-services` skill update), plus the pins firebase_core 5.1.0, google-services 4.5.0 and crashlytics plugin 3.0.8 (or what worked)
- learnings: what the dummy-config builds showed, and whether `missingGoogleServicesStrategy` exists
- owner notes: `pod install` / SwiftPM on a Mac with iOS 15, and a check of the copy phase

---

### Task 6.3: Crash scrubbing and the Crashlytics reporter

**Files:**
- Modify:
  - `app/pubspec.yaml` (`firebase_crashlytics: 6.0.1`)
  - `app/lib/bootstrap.dart` (install the service reporter when Firebase is ready)
  - `app/lib/features/settings/presentation/about_page.dart` (dev-only test crash row)
- Create:
  - `app/lib/core/crash/crash_scrubber.dart`, `scrubbing_crash_reporter.dart`
  - `crashlytics_sink.dart` (the only `firebase_crashlytics` import)
  - `crash_collection.dart` (+ `.g.dart`)
  - `app/test/helpers/recording_crashlytics_sink.dart`
- Test: `app/test/core/crash/crash_scrubber_test.dart`, `scrubbing_crash_reporter_test.dart`, `crash_collection_test.dart`; additions to `app/test/bootstrap_test.dart`, `app/test/features/settings/about_page_test.dart`

**Interfaces:**
- Consumes: `DelegatingCrashReporter`, `CompositeCrashReporter`, `firebaseStatusProvider`, `privacyChoicesProvider`, `savedDevicesProvider` (`deviceRepositoryProvider`), `flavorProvider`.
- Produces:
  - `class CrashScrubber { CrashScrubber({Iterable<String> Function()? knownTerms}); String scrub(String? text); }`, following Ruling P6-R5 exactly. `knownTerms` supplies the saved TVs' `displayName`, `nickname` and `serviceName`.
  - `final class ScrubbedError { const ScrubbedError(this.message); final String message; @override String toString() => message; }`.
  - `abstract interface class CrashlyticsSink { Future<void> recordError(Object error, StackTrace? stack, {String? reason, bool fatal}); Future<void> setCollectionEnabled(bool enabled); Future<void> deleteUnsentReports(); }`. `FirebaseCrashlyticsSink` calls `FirebaseCrashlytics.instance` and catches everything.
  - `class ScrubbingCrashReporter implements CrashReporter { ScrubbingCrashReporter({required CrashlyticsSink sink, required CrashScrubber scrubber, required bool Function() enabled, bool isDebugBuild = kDebugMode}); }`:
    - It sends nothing when `!enabled()` or `isDebugBuild`.
    - `recordError` → `sink.recordError(ScrubbedError('${error.runtimeType}: ${scrubber.scrub(error.toString())}'), stack, reason: scrubber.scrub(reason), fatal: fatal)`.
    - `recordFlutterError` → the same, with `details.exceptionAsString()` and `reason: scrubber.scrub(details.context?.toDescription())`. It never reads `informationCollector`.
    - Sink failures are swallowed.
  - `@Riverpod(keepAlive: true) class CrashCollection`:
    - It builds the scrubber from a cached `Set<String>` of terms, kept up to date by listening to `deviceRepositoryProvider.watchAll()`. Errors are ignored.
    - When `firebaseStatus == ready`, it calls `sink.setCollectionEnabled(privacy.shareCrashReports && !kDebugMode)` on every change of `privacyChoicesProvider`, and `deleteUnsentReports()` when sharing turns off.
    - It exposes `CrashReporter reporter` (the scrubbing one).
  - `@Riverpod(keepAlive: true) CrashlyticsSink crashlyticsSink(Ref ref) => FirebaseCrashlyticsSink();` (tests override it).
  - `@Riverpod(keepAlive: true) bool crashDebugBuild(Ref ref) => kDebugMode;` is the seam `CrashCollection` and the reporter's `isDebugBuild` read, so tests can act as a release build.
  - `buildRootWidget`: when the status is `ready`, after the container is built, `reporter.delegate = CompositeCrashReporter([const LoggingCrashReporter(), container.read(crashCollectionProvider.notifier).reporter])`. `crashReporter` must then be a `DelegatingCrashReporter`; any other reporter is left as is (old tests).
  - About page, `flavor == Flavor.dev` only: `SettingsNavTile(icon: Icons.bug_report_outlined, title: aboutTestCrash)` → reports `StateError('Test crash report from a dev build')` (non-fatal) through `crashReporterProvider`, then shows the `aboutTestCrashSent` snackbar. It's absent in prod.

- [ ] **Step 1: Write the failing tests**

```dart
// crash_scrubber_test.dart
test('scrubs_ipv4_and_ipv6', () {
  final s = CrashScrubber();
  expect(s.scrub('SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 192.168.0.20, port = 6466'),
      allOf(contains('<ip>'), isNot(contains('192.168.0.20')), contains('port = 6466')));
  expect(s.scrub('fe80::1c2b:3a4d:5e6f:7a8b%wlan0 unreachable'), isNot(contains('fe80')));
});
test('scrubs_mac_in_every_format', ...)        // AA:BB:CC:DD:EE:F0, aa-bb-cc-dd-ee-f0, aabb.ccdd.eef0, AABBCCDDEEF0 → '<mac>' or '<hex>', none survive
test('scrubs_pairing_codes_hex_pins_and_keys', ...) // 'code A1B2C3 rejected', a 64-hex pin, a PEM block, a 60-char base64 key → none survive
test('scrubs_saved_tv_names_service_names_and_hosts', ...)
    // knownTerms {'Living Room TV 3', 'Den', 'manual:192.168.0.20'}: 'Living Room TV 3._androidtvremote2._tcp.local',
    // 'bravia-4k.local', 'Den is offline' → no 'Living', 'bravia', 'Den'; 'hidden' and 'garden' unchanged
test('keeps_ordinary_text', ...)               // 'Bad state: Paired without seeing the TV key', 'decade', 'port 6466' unchanged
test('null_and_empty_are_safe', ...)

// scrubbing_crash_reporter_test.dart (RecordingCrashlyticsSink)
test('sends_only_scrubbed_text', ...)
    // StateError('TV Living Room TV 3 at 192.168.0.20') → sink error toString starts 'StateError: ', no name, no IP; stack kept
test('flutter_errors_drop_their_information', ...)
    // FlutterErrorDetails(exception: 'x', informationCollector: () sync* { yield DiagnosticsNode.message('typed: hunter2'); })
    // → nothing recorded contains 'hunter2'
test('nothing_is_sent_when_crash_reports_are_off', ...)
test('nothing_is_sent_from_debug_builds', ...)     // isDebugBuild: true
test('sink_failures_never_throw', ...)

// crash_collection_test.dart (ProviderContainer.test; firebaseStatus ready; sink override)
test('collection_follows_the_privacy_choice_and_region', ...)
    // crashDebugBuildProvider → false; region notRequired, choice null → setCollectionEnabled(true);
    // set shareCrashReports false → history [true, false] and one deleteUnsentReports
test('debug_builds_keep_native_collection_off', ...)     // crashDebugBuildProvider → true → setCollectionEnabled(false) only
test('saved_tv_names_reach_the_scrubber', ...)    // InMemoryDeviceRepository upsert → scrub('Den') == '<tv>'
test('firebase_not_ready_never_touches_the_sink', ...)

// bootstrap_test.dart
testWidgets('firebase_ready_installs_the_scrubbing_reporter', ...)  // delegate is CompositeCrashReporter containing ScrubbingCrashReporter
testWidgets('firebase_unavailable_keeps_logging_only', ...)

// about_page_test.dart
testWidgets('dev_build_offers_a_test_crash_report', ...)  // tap → RecordingCrashReporter got StateError; snackbar text
testWidgets('prod_build_has_no_test_crash_row', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/crash test/bootstrap_test.dart test/features/settings/about_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the dependency:** `flutter pub add firebase_crashlytics:6.0.1`
- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): crashlytics behind a scrubbing reporter that follows the privacy choice" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P6-R5 and the debug-builds-never-send rule (P6-R4), plus the pin firebase_crashlytics 6.0.1. Learning: errors before Firebase init reach only the log.

---

### Task 6.4: Analytics with the guard, the privacy gate and the event hooks

**Files:**
- Modify:
  - `app/pubspec.yaml` (`firebase_analytics: 13.0.1`)
  - `app/lib/app/router.dart` (observer only)
  - `app/lib/app/app.dart` (read `analyticsHooksProvider` once)
  - `app/lib/features/remote/application/remote_actions.dart` (`remoteActionListenerProvider` body, `_report` debug log)
  - `app/lib/features/pairing/application/pairing_controller.dart`
  - `app/lib/features/discovery/application/discovery_controller.dart`
  - `app/lib/features/onboarding/presentation/onboarding_screen.dart`
- Create:
  - `app/lib/core/analytics/analytics_events.dart`, `analytics_guard.dart`
  - `app_analytics.dart` (+ `.g.dart`)
  - `firebase_analytics_sink.dart` (the only `firebase_analytics` import)
  - `analytics_route_observer.dart`
  - `analytics_hooks.dart` (+ `.g.dart`), `key_names.dart`
  - `app/test/helpers/recording_analytics_sink.dart`
- Test: `app/test/core/analytics/{analytics_guard,app_analytics,analytics_hooks,analytics_route_observer,key_names}_test.dart`; additions to `pairing_controller_test.dart`, `discovery_controller_test.dart`, `onboarding_screen_test.dart` (create if missing), `remote_actions_test.dart`

**Interfaces:**
- Consumes: `privacyChoicesProvider`, `firebaseStatusProvider`, `remoteSessionProvider`, `connectionStateProvider`, `settingsControllerProvider`, `catalogueProvider`, `RemoteActionEvent`s, `AppRouteNames`.
- Produces:
  - `analytics_events.dart`:
    - `@immutable class AnalyticsEvent { const AnalyticsEvent._(this.name, this.params); final String name; final Map<String, Object> params; }`, with one named factory per catalogue row (Ruling P6-R6), e.g. `AnalyticsEvent.pairFail(PairingErrorKind)` and `AnalyticsEvent.keyPress(int keyCode)` (via `analyticsKeyName`).
    - `String snakeCase(String camel)`.
  - `key_names.dart`: `String analyticsKeyName(int keyCode)`. Values:
    - `dpad_up`, `dpad_down`, `dpad_left`, `dpad_right`, `dpad_center`
    - `back`, `home`, `menu`, `power`
    - `volume_up`, `volume_down`, `mute`, `channel_up`, `channel_down`
    - `play_pause`, `next`, `previous`, `rewind`, `fast_forward`, `stop`
    - `red`, `green`, `yellow`, `blue`
    - `tv_input`, `settings`, `guide`, `info`, `captions`, `search`, `enter`, `delete`
    - `digit` (every 0–9 key; which digit is never logged)
    - `other`
  - `analytics_guard.dart`: `final class AnalyticsPolicyError extends Error { final String message; }`. `List<String> analyticsViolations(String name, Map<String, Object> params, {Set<String> cataloguePackages = const {}})` returns the reasons, empty when the event is fine (Ruling P6-R6).
  - `abstract interface class AnalyticsSink { Future<void> logEvent(String name, Map<String, Object> params); Future<void> logScreenView(String screenName); Future<void> setCollectionEnabled(bool enabled); }`:
    - `FirebaseAnalyticsSink`: `setCollectionEnabled` also calls `setConsent(analyticsStorageConsentGranted: enabled, adStorageConsentGranted: false, adUserDataConsentGranted: false, adPersonalizationSignalsConsentGranted: false)`. Everything is caught.
    - `NoopAnalyticsSink`.
  - `@Riverpod(keepAlive: true) AnalyticsSink analyticsSink(Ref ref)` → Firebase when `firebaseStatus == ready`, else no-op.
  - `@Riverpod(keepAlive: true) class AppAnalytics`, exposing `void log(AnalyticsEvent e)` and `void screen(String routeName)`:
    - The guard runs first. Debug (`analyticsDebugBuildProvider`, default `kDebugMode`): throw `AnalyticsPolicyError`. Release: drop.
    - Then the privacy gate: allowed → sink. Undecided (`!usageDecided`) → buffer (the latest 50, events and screens in order). Denied → drop.
    - On every `privacyChoicesProvider` change: `sink.setCollectionEnabled(shareUsage)`. Allowed flushes the buffer in order; denied clears it.
    - Sink errors are swallowed.
  - `AnalyticsRouteObserver extends NavigatorObserver`. `didPush`/`didReplace` (the new route) and `didPop` (the route below), for `PageRoute`s only, call `screen(name)` when `route.settings.name` is in `AppRouteNames.all`. `appRouter` adds it to `observers` through `ref.watch(analyticsRouteObserverProvider)`. Check go_router puts `GoRoute.name` into `Page.name`. If it doesn't, map `state.topRoute?.name` instead, and say which in the report.
  - `analytics_hooks.dart`:
    - `@Riverpod(keepAlive: true) AnalyticsHooks analyticsHooks(Ref ref)`. It listens to:
      - `connectionStateProvider` → `connect_success` / `connect_lost`, never for a demo session (`remoteSessionProvider` value `isDemo`)
      - `settingsControllerProvider`, via `select` on `navigationStyle` and `quickAccessRow` → `layout_change`
    - `@Riverpod(keepAlive: true) double Function() analyticsSampler(Ref ref) => math.Random().nextDouble;`
    - `remoteActionListenerProvider` now returns a fan-out listener:
      - `KeySent` → `key_press` when `sampler() < 0.1`
      - `AppLaunched` → `app_launch` (catalogue package, else `custom`; the catalogue is read with `ref.read(catalogueProvider).value`, and not loaded means `custom`)
      - `TextSent` → nothing
      - a demo session → nothing

      Task 6.10 adds the review counter to the same fan-out.
  - `RemoteActions._report`: `on Object catch (error) { if (kDebugMode) debugPrint('RemoteActions listener failed on ${event.runtimeType}: ${error.runtimeType}'); }`. No event fields, no error message.
  - Calls:
    - `PairingController`: `pair_start` in `_start`, `pair_success` before `_end(PairingSucceeded)`, `pair_fail` on `_end(PairingFailed)` and on the code-expired state.
    - `DiscoveryController`: `tv_discovered(count)` once per controller lifetime.
    - Both onboarding buttons: `onboarding_complete` after the setting is stored.
    - All of these go through `ref.read(appAnalyticsProvider.notifier).log(...)`.
  - `pumpRouterApp` adds no default: with Firebase not configured, the sink is the no-op one and the guard still checks every event.

- [ ] **Step 1: Write the failing tests**

```dart
// analytics_guard_test.dart
test('analytics_rejects_params_with_ip_or_mac_pattern', () {   // master name
  expect(analyticsViolations('app_launch', {'package': '192.168.0.20'}), isNotEmpty);
  expect(analyticsViolations('app_launch', {'package': 'AA:BB:CC:DD:EE:F0'}), isNotEmpty);
  expect(analyticsViolations('pair_fail', {'reason': 'fe80::1'}), isNotEmpty);
  expect(analyticsViolations('key_press', {'key': 'a1b2c3d4e5f6a7b8'}), isNotEmpty);
});
test('rejects_unknown_events_params_and_free_text', ...)  // 'tv_connected'; extra 'tv_name'; layout 'Living Room'; missing 'reason'
test('accepts_every_catalogue_factory', ...)              // each AnalyticsEvent factory with sample input → no violations
test('custom_packages_are_rejected_catalogue_packages_pass', ...)

// app_analytics_test.dart (ProviderContainer.test; analyticsSinkProvider → RecordingAnalyticsSink)
test('guard_throws_in_debug_and_drops_in_release', ...)
test('nothing_is_sent_when_usage_sharing_is_off', ...)
test('events_wait_until_the_region_is_known', ...)        // region unknown, choice null → 3 logs → sink empty; region notRequired → 3 in order
test('waiting_events_are_dropped_when_sharing_is_denied', ...) // → region required → buffer cleared; later allowed → still empty
test('buffer_keeps_the_latest_50', ...)
test('collection_follows_the_choice', ...)                // sink.collectionEnabled history [false, true, false]
test('a_failing_sink_never_throws', ...)

// analytics_hooks_test.dart
test('key_press_is_sampled_at_10_percent', ...)           // sampler cycles 0.0, 0.1, …, 0.9 → 100 KeySent → exactly 10 key_press
test('digits_are_logged_as_digit', ...)                   // KeySent(KeyCodes.digit(5)) with sampler 0 → key 'digit'
test('text_is_never_logged', ...)                         // TextSent(12) → sink has no event at all
test('app_launch_uses_catalogue_packages_or_custom', ...) // com.netflix.ninja → itself; com.example.private → 'custom'
test('demo_sessions_log_no_tv_events', ...)
test('connect_success_and_lost_carry_only_a_reason', ...) // FakeRemoteSession states: connected → reconnecting(pingTimeout) → connected
                                                          // → [connect_success, connect_lost{reason: ping_timeout}, connect_success]
test('layout_change_logged_for_settings_and_pad_swipes', ...)

// analytics_route_observer_test.dart (pumpRouterApp, region notRequired, recording sink)
testWidgets('screen_names_never_contain_route_parameters', ...)
    // initialLocation AppRoutes.editDevice('Living Room TV 3'), then push pair('Bravia/4K') → screens ['edit_device', 'pair'];
    // nothing recorded contains 'Living' or 'Bravia'
testWidgets('sheets_and_dialogs_are_not_screens', ...)   // open the TV switcher sheet and the feedback dialog → no screen_view

// remote_actions_test.dart
test('listener_errors_are_logged_in_debug_without_event_data', ...)
    // debugPrint captured; throwing listener; tap(KeyCodes.volumeUp) → true; log contains 'RemoteActions listener failed on KeySent'
    // and not '24'

// pairing_controller_test.dart / discovery_controller_test.dart / onboarding_screen_test.dart
test('pairing_logs_start_success_and_fail_without_codes', ...) // bad secret → pair_fail{reason: code_rejected_by_tv}; no param holds the code
test('tv_discovered_logged_once_with_a_count', ...)
testWidgets('onboarding_complete_logged_by_both_buttons', ...)

// key_names_test.dart
test('every_named_key_has_an_analytics_name', ...)       // for each KeyCodes.named → not 'other'; digit(0..9) → 'digit'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/analytics test/features/remote test/features/pairing test/features/discovery test/features/onboarding`
Expected: FAIL.

- [ ] **Step 3: Add the dependency:** `flutter pub add firebase_analytics:13.0.1`
- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS. The guard now checks every event the existing tests trigger; fix any real violation it finds in the calling code.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): analytics with an event guard, privacy gate and route-name screen views" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P6-R6 (the exact catalogue; the `app-services` skill's event list update), plus the pin firebase_analytics 13.0.1. Carry-over closed: the `_report` debug log. Learning: how go_router names pages.

---

### Task 6.5: Remote Config and the forced-update gate

**Files:**
- Modify:
  - `app/pubspec.yaml` (`firebase_remote_config: 7.0.1`)
  - `app/lib/bootstrap.dart` (startup step 2)
  - `app/lib/app/app_shell.dart` (`UpdateGate`)
  - `app/lib/app/app_links.dart` (`storeListing`)
- Create:
  - `app/lib/core/config/app_config.dart` (+ `.g.dart`), `app_version.dart`, `update_gate.dart`
  - `firebase_remote_config_source.dart` (the only `firebase_remote_config` import)
  - `app/test/helpers/fake_config_source.dart`
- Test: `app/test/core/config/{app_config,app_version,update_gate}_test.dart`; additions to `app/test/bootstrap_test.dart`

**Interfaces:**
- Consumes: `firebaseStatusProvider`, `flavorProvider`, `appInfoProvider`, `linkOpenerProvider`, `buildAppShell`.
- Produces:
  - `@immutable class AppConfigValues { adsBannerEnabled, adsInterstitialEnabled, adsInterstitialMinInterval (Duration), reviewPromptMinKeyPresses, paywallVariant, minSupportedVersion, catalogueVersion; static const defaults = …; static const Map<String, Object> defaultsMap; factory AppConfigValues.read(Object? Function(String key) get); }`. A wrong type or a negative number falls back to the default for that key.
  - `abstract interface class RemoteConfigSource { Future<void> activateCached(); Future<void> fetchForNextLaunch(); Object? value(String key); }`:
    - `FirebaseRemoteConfigSource({required Duration minimumFetchInterval})`: `setConfigSettings(RemoteConfigSettings(fetchTimeout: 10 s, minimumFetchInterval: …))`, `setDefaults(defaultsMap)`, `activate()`, then `fetch()`. Everything is caught.
    - `DefaultsOnlyConfigSource`.
  - `@Riverpod(keepAlive: true) RemoteConfigSource remoteConfigSource(Ref ref)`: Firebase when ready (interval 1 h for prod, 5 min for dev), else defaults only.
  - `@Riverpod(keepAlive: true) class AppConfig`: `build()` → `AppConfigValues.defaults`. `Future<void> load()` runs `activateCached`, then sets state from the source, then `unawaited(fetchForNextLaunch())`.
  - Bootstrap startup step 2: `container.read(appConfigProvider.notifier).load()`. The step mechanism bounds it to 5 s; the step list is reordered so it runs after the container exists. Explain how in the report.
  - `({int major, int minor, int patch})? parseAppVersion(String s)` (`1.2` = `1.2.0`; `+build` is ignored; anything else gives `null`). `bool isBelowMinimum(String current, String minimum)` is `false` whenever either doesn't parse.
  - `@riverpod bool updateRequired(Ref ref)`: `appInfoProvider` ready and `isBelowMinimum(info.version, config.minSupportedVersion)`; loading or an error gives `false`.
  - `AppLinks.storeListing(Flavor flavor, TargetPlatform platform)`:
    - Android `https://play.google.com/store/apps/details?id=${flavor.applicationId}`
    - iOS `AppLinks.appStoreListing`: `Uri.parse('https://apps.apple.com/app/id0000000000')`, documented `/// PLACEHOLDER until the App Store record exists (Phase 9).`
  - `class UpdateGate extends ConsumerWidget { const UpdateGate({required this.child}); }`. While `updateRequired`, it shows `_UpdateRequiredScreen` (a themed `Scaffold`, `PopScope(canPop: false)`, title, body, `FilledButton(updateRequiredAction)` → `LinkOpener.open(storeListing)`; `false` → the `updateRequiredFailed` snackbar) **instead of** `child`. `buildAppShell` becomes `UpdateGate(child: DemoBadgeOverlay(child: …))`.
  - `pumpRouterApp`: no new default (no Firebase → defaults only). Tests override `remoteConfigSourceProvider` with `FakeConfigSource(values)`.

- [ ] **Step 1: Write the failing tests**

```dart
// app_config_test.dart
test('config_defaults_match_app_services_skill', () {   // master name
  expect(AppConfigValues.defaultsMap, {
    'ads_banner_enabled': true, 'ads_interstitial_enabled': false, 'ads_interstitial_min_interval_s': 600,
    'review_prompt_min_key_presses': 150, 'paywall_variant': 'a', 'min_supported_version': '1.0.0', 'catalogue_version': 1,
  });
});
test('bad_types_fall_back_per_key', ...)                // 'abc' for an int, -5 for the interval, 1 for a bool → defaults
test('load_activates_cached_values_then_fetches_for_next_launch', ...)
    // FakeConfigSource records calls: [activateCached, fetchForNextLaunch]; state shows the activated values;
    // values the fake changes during fetch are NOT applied this session
test('without_firebase_only_defaults', ...)
test('a_throwing_source_keeps_defaults', ...)

// bootstrap_test.dart
testWidgets('config_never_blocks_startup', ...)          // activateCached never completes → app still renders within the step timeout

// app_version_test.dart
test('version_compare', ...)
    // ('1.0.0','1.0.1') below; ('1.2','1.2.0') not; ('1.10.0','1.9.9') not; ('1.0.0+5','1.0.0') not; ('x','2.0.0') not; ('1.0.0','') not

// update_gate_test.dart (pumpRouterApp at /remote; remoteConfigSourceProvider → FakeConfigSource({'min_supported_version': '9.0.0'}),
// and appConfigProvider loaded in the test setup)
testWidgets('below_min_version_shows_blocking_update', ...)   // master name
    // 'Update required' shown, RemoteBody absent; t.pageBack/maybePop doesn't leave it; tap 'Update' →
    // RecordingLinkOpener.opened.single == Uri.parse('https://play.google.com/store/apps/details?id=com.digitallinked.atvremote.dev')
testWidgets('ios_opens_the_app_store_placeholder', ...)
testWidgets('malformed_or_missing_min_version_never_blocks', ...)
testWidgets('app_info_failure_never_blocks', ...)
testWidgets('a_failed_store_link_says_so', ...)
testWidgets('update_gate_fits_320dp_at_200_percent_text', ...)  // light + dark
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/config test/bootstrap_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the dependency:** `flutter pub add firebase_remote_config:7.0.1`
- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): remote config with next-launch activation and a forced-update gate" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P6-R7, the pin firebase_remote_config 7.0.1, and the App Store listing placeholder (owner, Phase 9).

---

### Task 6.6: Consent (UMP), the Privacy choices page, the ATT pre-prompt and native ad IDs

**Files:**
- Modify:
  - `app/pubspec.yaml` (`google_mobile_ads: 9.2.0`, `app_tracking_transparency: 2.0.7`)
  - `app/lib/app/app.dart` (read `consentControllerProvider` once)
  - `app/lib/features/remote/presentation/remote_screen.dart` (gather on the first top-route frame)
  - `privacy_choices_page.dart` (stub → page)
  - `app/android/app/build.gradle.kts` (admob placeholders), `AndroidManifest.xml`
  - `app/ios/Runner.xcodeproj/project.pbxproj` (`ADMOB_APP_ID` ×6), `app/ios/Flutter/{Debug,Release}.xcconfig`, `app/ios/Runner/Info.plist`
  - `app/test/platform/android_queries_test.dart`, `app/test/helpers/pump_router_app.dart`
- Create:
  - `app/lib/core/ads/consent_service.dart`
  - `ump_consent_service.dart` (`google_mobile_ads` import, UMP only)
  - `consent_controller.dart` (+ `.g.dart`), `tracking_service.dart`
  - `att_tracking_service.dart` (the only `app_tracking_transparency` import)
  - `tracking_preprompt.dart`
  - `app/android/secrets.example.properties`, `app/ios/Flutter/Secrets.example.xcconfig`
  - `app/test/helpers/fake_consent_service.dart`, `fake_tracking_service.dart`
- Test: `app/test/core/ads/{consent_controller,tracking_preprompt}_test.dart`, `app/test/features/settings/privacy_choices_page_test.dart`, `privacy_choices_golden_test.dart`, `app/test/platform/ads_config_test.dart`; additions to `remote_screen_test.dart`, `android_queries_test.dart`

**Interfaces:**
- Consumes: `serviceConfigProvider`, `flavorProvider`, `consentRegionStateProvider`, `privacyChoicesProvider`, `premiumProvider` (stub), `firebaseStatusProvider`, `linkOpenerProvider`, `settingsStoreProvider`, `showAppDialog`.
- Produces:
  - `consent_service.dart`:
    - `enum ConsentFormOutcome { notNeeded, shown, failed }`
    - `abstract interface class ConsentService { Future<ConsentRegion> requestUpdate(); Future<ConsentFormOutcome> showFormIfRequired(); Future<bool> canRequestAds(); Future<bool> privacyOptionsRequired(); Future<bool> showPrivacyOptions(); }`
  - `UmpConsentService(ServiceConfig config, Flavor flavor)`:
    - `requestUpdate`:
      - wraps `ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(consentDebugSettings: …), success, failure)` in a `Completer`
      - in dev with `UMP_DEBUG_GEOGRAPHY=eea` (or `other`), uses `ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea, testIdentifiers: [UMP_TEST_DEVICE_ID])`
      - then maps `getConsentStatus()` (Ruling P6-R4)
    - `showFormIfRequired` → `ConsentForm.loadAndShowConsentFormIfRequired`.
    - `showPrivacyOptions` → `ConsentForm.showPrivacyOptionsForm`.
    - Every error (`MissingPluginException` included) gives `unknown`, `failed` or `false`.
  - `@Riverpod(keepAlive: true) ConsentService consentService(Ref ref) => UmpConsentService(...)`.
  - `@immutable class ConsentResult { region, canRequestAds, privacyOptionsRequired, gathered }`.
  - `@Riverpod(keepAlive: true) class ConsentController`:
    - `build()` returns the not-gathered result and schedules `refresh()` in a microtask.
    - `Future<void> refresh()`: once per process; `requestUpdate`, then `consentRegionStateProvider.set(region)` unless `unknown`.
    - `Future<ConsentResult> ensureGathered()`: memoised per process. It awaits `refresh`, then `showFormIfRequired`, then reads `canRequestAds` and `privacyOptionsRequired`, and publishes `gathered: true`.
    - `Future<bool> showPrivacyOptions()`, then re-reads `canRequestAds`.
  - `RemoteScreen`: in the first frame where `ModalRoute.isCurrentOf(context)` is true, `unawaited(ref.read(consentControllerProvider.notifier).ensureGathered())`. Once per screen state; the controller memoises across states.
  - `tracking_service.dart`:
    - `enum TrackingStatus { notApplicable, notDetermined, restricted, denied, authorized }`
    - `abstract interface class TrackingService { Future<TrackingStatus> status(); Future<TrackingStatus> request(); }`
    - `NoTrackingService` (Android: always `notApplicable`)
    - `AttTrackingService` (`AppTrackingTransparency.trackingAuthorizationStatus` / `requestTrackingAuthorization()`; errors give `notApplicable`)
    - `@Riverpod(keepAlive: true) TrackingService trackingService(Ref ref)` (iOS → ATT, else none)
  - `tracking_preprompt.dart`: `Future<void> ensureTrackingDecided(BuildContext context, WidgetRef ref)`:
    - It returns at once unless the platform is iOS, the status is `notDetermined` and `!store.trackingPrepromptShown`.
    - Otherwise it shows `showAppDialog(title: trackingPrepromptTitle, body: trackingPrepromptBody, actions: [AppDialogAction(trackingPrepromptContinue, isPrimary: true)], barrierDismissible: false)`, wrapped in `PopScope(canPop: false)`. Add the `barrierDismissible` parameter to `showAppDialog` if it's missing, defaulting to the current behaviour.
    - Then `setTrackingPrepromptShown(true)`, then `request()`.
    - Concurrent calls share one future.
  - `PrivacyChoicesPage` (Ruling P6-R8), a `ListView` in this order:
    - `privacyIntro`
    - `SettingsSectionHeader(privacySectionImprove)`
    - two `SettingsSwitchTile`s (value = the effective share; a change calls `setShareUsageStats(v)` / `setShareCrashReports(v)`)
    - `privacyServicesOff` when `firebaseStatus != ready`
    - `SettingsSectionHeader(privacySectionAds)`, then either:
      - Premium → `privacyAdsPremium`
      - free → `privacyAdsInfo`, `SettingsNavTile(privacyRemoveAds)` → paywall (source `privacy`), and `SettingsNavTile(privacyAdChoices, subtitle: privacyAdChoicesSubtitle)` when `privacyOptionsRequired` (`false` → the `privacyAdChoicesFailed` snackbar)
    - on iOS, `SettingsNavTile(privacyTrackingTitle, subtitle: <status text>)` → `LinkOpener.open(Uri.parse('app-settings:'))`, with `privacyOpensSettings` as the semantics hint
    - `SettingsNavTile(settingsPrivacy, external: true)` → `AppLinks.privacyPolicy`
    - No banner slot.
  - **Android:**
    - Manifest:
      - `<uses-permission android:name="com.google.android.gms.permission.AD_ID" />`
      - `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="${admobAppId}"/>`
      - `<meta-data android:name="com.google.android.gms.ads.DELAY_APP_MEASUREMENT_INIT" android:value="true"/>`
    - `build.gradle.kts`:
      - Reads `rootProject.file("secrets.properties")` into `Properties` when it exists.
      - `val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"`.
      - dev: `manifestPlaceholders["admobAppId"] = admobTestAppId`.
      - prod: `= secrets.getProperty("admobAppIdProd") ?: admobTestAppId`, with `logger.warn("prod uses Google's test AdMob app id; set admobAppIdProd in android/secrets.properties")` when missing.
    - `secrets.example.properties`: comments + `admobAppIdProd=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`.
  - **iOS:**
    - Runner's dev configs: `ADMOB_APP_ID = "ca-app-pub-3940256099942544~1458002511";`. Prod configs: `ADMOB_APP_ID = "$(ADMOB_APP_ID_PROD)";`.
    - `Debug.xcconfig` and `Release.xcconfig` each end with a comment, `ADMOB_APP_ID_PROD = ca-app-pub-3940256099942544~1458002511` and `#include? "Secrets.xcconfig"`.
    - `Secrets.example.xcconfig`: `ADMOB_APP_ID_PROD = ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`.
    - `Info.plist`:
      - `GADApplicationIdentifier` `$(ADMOB_APP_ID)`
      - `GADDelayAppMeasurementInit` `<true/>`
      - `NSUserTrackingUsageDescription` `Remotely uses this to show ads that are more relevant to you. The app shows the same number of ads whatever you choose.`
      - `SKAdNetworkItems` containing `cstr6suwn9.skadnetwork` (Google). Other networks come with mediation, later.

    Resolving `$(ADMOB_APP_ID_PROD)` this way is (unverified, Mac).
  - `pumpRouterApp` defaults: `consentServiceProvider.overrideWithValue(FakeConsentService())` (region `notRequired`, `canRequestAds` true, no form, privacy options not required) and `trackingServiceProvider.overrideWithValue(FakeTrackingService())` (`notApplicable`). `FakeConsentService` takes a `Completer` to hold `requestUpdate` or `showFormIfRequired`, and counts calls; `FakeTrackingService` records `request()` calls.

- [ ] **Step 1: Write the failing tests**

```dart
// consent_controller_test.dart (ProviderContainer.test)
test('refresh_writes_the_region_and_keeps_it_on_unknown', ...) // notRequired → stored; then unknown → still notRequired
test('gathering_runs_the_form_once_per_launch', ...)           // ensureGathered ×3 → showFormIfRequired called once
test('consent_errors_never_throw', ...)                        // service throws everywhere → result region unknown, canRequestAds false

// remote_screen_test.dart (additions)
testWidgets('consent_form_waits_for_the_remote', ...)
    // pumpRouterApp at /onboarding → fake.showFormCalls 0; go discover, pair → 0; go /remote → 1
testWidgets('consent_form_never_shown_twice_in_a_launch', ...)   // remote → settings → back → still 1

// tracking_preprompt_test.dart (debugDefaultTargetPlatformOverride = TargetPlatform.iOS; tearDown resets)
testWidgets('att_prompt_only_after_preprompt_accept', ...)       // master name
    // status notDetermined → call ensureTrackingDecided → dialog 'About ads in this app' shown, tracking.requests == 0;
    // tapping outside and pageBack leave it open; tap 'Continue' → requests == 1, store.trackingPrepromptShown true
testWidgets('preprompt_shown_at_most_once', ...)                // second call → no dialog, no request
testWidgets('no_preprompt_on_android_or_when_decided', ...)     // android; iOS denied/authorized/restricted → no dialog
testWidgets('preprompt_fits_320dp_at_200_percent_text', ...)    // light + dark

// privacy_choices_page_test.dart (pumpRouterApp at /settings/privacy)
testWidgets('privacy_switches_show_the_effective_choice', ...)
    // region notRequired + nulls → both on; region required + nulls → both off
testWidgets('turning_usage_off_stores_an_explicit_choice', ...) // tap → store.shareUsageStats == false; privacyChoices.shareUsage false
testWidgets('ad_privacy_row_only_when_required', ...)           // required → row; tap → fake.privacyOptionsCalls 1; result false → snackbar
testWidgets('premium_users_see_no_ad_rows', ...)                // TestPremium(premium) → 'You have Premium, so…'; no 'Remove ads…'
testWidgets('remove_ads_opens_the_paywall_from_privacy', ...)   // → PaywallScreen(source: privacy)
testWidgets('ios_tracking_row_shows_the_status_and_opens_settings', ...) // iOS denied → 'Not allowed…'; tap → opened 'app-settings:'
testWidgets('services_off_note_when_firebase_is_off', ...)
testWidgets('privacy_page_has_no_banner_and_fits_320dp_at_200_percent_text', ...)
// privacy_choices_golden_test.dart: free user, Size(390, 844), light → goldens/privacy_choices_light.png

// android_queries_test.dart
test('android_manifest_declares_mailto_and_https_queries', ...)
    // unchanged queries; permissions are exactly {INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE,
    // CHANGE_WIFI_MULTICAST_STATE, com.google.android.gms.permission.AD_ID} (closes the Phase 5 carry-over)

// ads_config_test.dart
test('android_declares_the_admob_app_id_and_delays_measurement', ...)
test('android_dev_uses_the_test_app_id_and_prod_reads_secrets_with_a_fallback', ...)
test('ios_declares_tracking_and_admob_keys', ...)       // the four plist keys; SKAdNetworkItems has cstr6suwn9.skadnetwork
test('ios_dev_configs_use_the_test_app_id', ...)        // 3 dev configs → test id; 3 prod → $(ADMOB_APP_ID_PROD); xcconfigs include? Secrets
test('no_real_admob_ids_committed', ...)
    // `git ls-files` from the repo root (Process.runSync), read every tracked text file under app/ and docs/:
    // every match of ca-app-pub-\d{16} is ca-app-pub-3940256099942544; no 'goog_'/'appl_' RevenueCat key pattern
    // (^|[^a-z])(goog|appl)_[A-Za-z0-9]{20,}; no 'AIza[0-9A-Za-z_-]{35}'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/ads test/features/settings test/features/remote/remote_screen_test.dart test/platform`
Expected: FAIL.

- [ ] **Step 3: Add the dependencies:** `flutter pub add google_mobile_ads:9.2.0 app_tracking_transparency:2.0.7`
- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Generate the golden, run the tests, build the dev APK**

Run `flutter test --update-goldens --tags golden test/features/settings/privacy_choices_golden_test.dart` (inspect), then `flutter test`, then `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
Expected: all PASS, and the build succeeds with no secrets file. The merged manifest has the test app ID: check `build/app/intermediates/merged_manifests/devDebug/**/AndroidManifest.xml` and report the path you found.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/android app/ios app/lib app/test
git commit -m "feat(app): consent before ads, privacy choices page, tracking pre-prompt and test admob app ids" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- decisions for Rulings P6-R4 (region from UMP) and P6-R8, plus the pins google_mobile_ads 9.2.0 and app_tracking_transparency 2.0.7
- carry-over closed: the manifest permission test
- learning: whether UMP with the test app ID returns `notRequired` or an error
- owner: the AdMob app IDs, UMP message setup in the AdMob console, and Mac verification of `$(ADMOB_APP_ID_PROD)`

---

### Task 6.7: RevenueCat, the Premium state and the paywall

**Files:**
- Modify:
  - `app/pubspec.yaml` (`purchases_flutter: 10.18.1`)
  - `app/lib/core/purchases/premium.dart` (stub → real)
  - `app/lib/app/app.dart` (read `premiumProvider` once)
  - `app/lib/app/app_links.dart` (subscription management)
  - `paywall_screen.dart` (stub → screen)
  - `settings_screen.dart` (Premium row subtitle)
  - `app/test/helpers/pump_router_app.dart`
- Create:
  - `app/lib/core/purchases/purchase_service.dart`, `unavailable_purchase_service.dart`
  - `revenuecat_purchase_service.dart` (the only `purchases_flutter` import)
  - `app/lib/features/paywall/application/paywall_controller.dart` (+ `.g.dart`)
  - `features/paywall/presentation/widgets/plan_tile.dart`
  - `app/test/helpers/fake_purchase_service.dart`
- Test: `app/test/core/purchases/{premium,revenuecat_mapping}_test.dart`, `app/test/features/paywall/{paywall_screen,paywall_controller}_test.dart`, `paywall_golden_test.dart`; additions to `settings_hub_phase6_test.dart`

**Interfaces:**
- Consumes: `serviceConfigProvider`, `flavorProvider`, `settingsStoreProvider` (premium cache), `appAnalyticsProvider`, `appConfigProvider` (variant), `linkOpenerProvider`, `AppLinks`, `clock`.
- Produces:
  - `purchase_service.dart` (our types only):
    - `enum PremiumPlanKind { monthly, yearly, lifetime }`, with `String get productId`: `premium_monthly` / `premium_yearly` / `premium_lifetime`.
    - `@immutable class PremiumPlan { kind, priceString, price (double), currencyCode }`.
    - `@immutable class PremiumOffer { List<PremiumPlan> plans }`.
    - `@immutable class EntitlementSnapshot { bool active; DateTime? expiresAt /* null = lifetime when active */; bool willRenew }`.
    - `sealed class PurchaseOutcome`: `Purchased(EntitlementSnapshot)`, `PurchaseCancelled`, `PurchasePending`, `PurchaseFailed(PurchaseFailure)`.
    - `enum PurchaseFailure { network, notAllowed, alreadyOwned, storeProblem, unknown }`.
    - `enum RestoreOutcome { restoredPremium, nothingToRestore, failed }`.
    - `abstract interface class PurchaseService { bool get isConfigured; Future<void> configure(); Stream<EntitlementSnapshot> get entitlements; Future<PremiumOffer?> loadOffer(); Future<PurchaseOutcome> purchase(PremiumPlanKind kind); Future<RestoreOutcome> restore(); }`.
  - `RevenueCatPurchaseService({required String apiKey, required bool debugLogs})`:
    - `configure`: `Purchases.setLogLevel(debug)` in dev; `Purchases.configure(PurchasesConfiguration(apiKey))`; `addCustomerInfoUpdateListener` → `entitlements`; an initial `getCustomerInfo()`.
    - Entitlement `premium`; `expirationDate` parsed as UTC.
    - `loadOffer` → `getOfferings().current` packages by `PackageType`.
    - `purchase` → `Purchases.purchase(PurchaseParams.package(pkg))`. Check the constructor name in 10.18.1: `PurchaseParams` has a private `_` constructor plus factories.
    - `PlatformException` → `PurchasesErrorHelper.getErrorCode(e)` → `purchaseOutcomeFor(code)`.
    - Every other error → `PurchaseFailed(unknown)` or `RestoreOutcome.failed`.
    - The mapping functions are pure and public for tests:
      - `PurchaseOutcome purchaseOutcomeFor(PurchasesErrorCode code)`:
        - `purchaseCancelledError` → cancelled
        - `paymentPendingError` → pending
        - `networkError` / `offlineConnectionError` → network
        - `purchaseNotAllowedError` → notAllowed
        - `productAlreadyPurchasedError` → alreadyOwned
        - `storeProblemError` → storeProblem
        - anything else → unknown
      - `EntitlementSnapshot entitlementFrom({required bool active, String? expirationDate, bool willRenew = false})`
  - `UnavailablePurchaseService`: not configured, empty stream, `loadOffer` → `null`, `purchase` → `PurchaseFailed(storeProblem)`, `restore` → failed.
  - `@Riverpod(keepAlive: true) PurchaseService purchaseService(Ref ref)`: a key for this platform → RevenueCat (`debugLogs: flavor == dev`); else unavailable.
  - `premium.dart`, real body (Ruling P6-R10):
    - `build()` reads the cache and returns `PremiumState(isPremium: cached.active && (cached.expiresAt == null || cached.expiresAt!.isAfter(clock.now())), known: !service.isConfigured, expiresAt: …, lifetime: cached.active && cached.expiresAt == null)`.
    - It then starts `configure()` in a microtask, subscribes to `entitlements` (each one is written to the cache and published with `known: true`), and arms a 5 s `known` timer.
    - `Future<void> apply(EntitlementSnapshot s)` is used by the paywall after a purchase or restore.
    - `ref.onDispose` cancels both.
  - `@riverpod class PaywallController`, with `PaywallState` = `PaywallLoading | PaywallUnavailable | PaywallReady(offer, selected, busy, badgePercent?) | PaywallActive(PremiumState)`:
    - `build(PaywallSource source)`: Premium → active; otherwise `loadOffer()` → ready (pre-selection per Ruling P6-R11) or unavailable. It logs `paywall_view{source, variant}` once.
    - `select(kind)`, `retry()`.
    - `Future<PurchaseOutcome> purchase()`: busy while running; `Purchased` → `premium.apply` + `purchase_success{product}`.
    - `Future<RestoreOutcome> restore()`: `restoredPremium` → `restore_success`.
  - `int? savePercent({required double monthly, required double yearly})` → `null` unless `yearly < 12 * monthly`; else `((1 - yearly / (12 * monthly)) * 100).floor()`.
  - `PaywallScreen` (Ruling P6-R11):
    - `Scaffold(appBar: AppBar(leading: IconButton(icon: Icon(Icons.close), tooltip: closeAction, onPressed: close), title: Text(pageTitlePaywall)))`.
    - The body is one `ListView` with the copy in the 6.1 table: two benefit rows (`ListTile`s with icons, not tappable), `paywallFreeForever`, the plan `RadioGroup` (`PlanTile`: title, price text, terms text, badge chips), `FilledButton(paywallContinue)`, `TextButton(paywallRestore)`, `paywallTermsAndroid`/`paywallTermsIos` (`bodySmall`, `textSecondary`), then the Terms and Privacy `TextButton`s (`openExternal`).
    - Busy: the buttons are disabled and `paywallPurchasing` shows with a `CircularProgressIndicator`.
    - The active state: `paywallActiveTitle`, `paywallActiveBody` or `paywallActiveLifetime`, `OutlinedButton(paywallManageSubscription)` (not for lifetime) → `AppLinks.manageSubscriptions(flavor, platform)`, then Restore.
    - `close`: `context.canPop() ? context.pop() : context.go(AppRoutes.remote)`.
  - `AppLinks.manageSubscriptions(Flavor f, TargetPlatform p)`: Android `https://play.google.com/store/account/subscriptions?package=${f.applicationId}`; iOS `https://apps.apple.com/account/subscriptions`.
  - Hub Premium row subtitle: `premium.isPremium ? settingsPremiumActiveSubtitle : settingsPremiumSubtitle`.
  - `pumpRouterApp`: no default needed (no key → unavailable, known at once). Tests use `purchaseServiceProvider.overrideWithValue(FakePurchaseService(...))`:
    - a controllable entitlement stream, `offer`
    - `nextPurchase` / `nextRestore` outcomes
    - `configureCalls`
    - `isConfigured` (default true)

- [ ] **Step 1: Write the failing tests**

```dart
// premium_test.dart (ProviderContainer.test, FakePurchaseService, in-memory store, clock overridden with withClock)
test('entitlement_updates_drive_premium', ...)            // emit active → isPremium true, known true; emit inactive → false
test('offline_uses_cached_entitlement', ...)              // master name: cache active, expires tomorrow; service never emits →
                                                          // isPremium true at once; after 5 s known true, still premium
test('cached_entitlement_expires', ...)                   // cache expired yesterday → isPremium false
test('lifetime_cache_never_expires', ...)
test('unconfigured_service_trusts_the_cache_at_once', ...)// UnavailablePurchaseService → known true in build()
test('every_live_answer_updates_the_cache', ...)
test('a_failing_configure_keeps_the_cache', ...)

// revenuecat_mapping_test.dart
test('purchase_failure_codes_map_to_outcomes', ...)       // the table in Interfaces
test('entitlement_from_parses_utc_and_lifetime', ...)
test('save_percent_is_honest', () {
  expect(savePercent(monthly: 4.99, yearly: 29.99), 49);
  expect(savePercent(monthly: 2.0, yearly: 24.0), isNull);
  expect(savePercent(monthly: 2.0, yearly: 30.0), isNull);
});

// paywall_screen_test.dart (pumpRouterApp; FakePurchaseService offer monthly 4.99 'RM 4.99', yearly 29.99 'RM 29.99', lifetime 'RM 59.90')
testWidgets('paywall_shows_terms_restore_privacy', ...)   // master name: 'Restore purchases', 'Terms of use', 'Privacy policy',
    // paywallTermsAndroid text (Android) / paywallTermsIos (iOS override), 'RM 4.99 per month' + 'Renews every month until you cancel.',
    // 'RM 29.99 per year' + 'Renews every year…', 'RM 59.90, one payment' + 'Pay once. No subscription.'; 'Everything else stays free…'
testWidgets('close_returns_to_source_route', ...)          // master name: /settings → Premium row → ✕ → Settings hub;
    // initialLocation /paywall?source=themes (nothing below) → ✕ → RemoteScreen
testWidgets('yearly_preselected_with_an_honest_saving', ...) // yearly selected; 'Best value', 'Save 49%'
testWidgets('no_badge_when_yearly_is_no_cheaper', ...)       // yearly 59.88 → monthly selected, no 'Best value'
testWidgets('lifetime_is_never_preselected', ...)            // offer lifetime only + monthly → monthly
testWidgets('purchase_success_closes_and_unlocks', ...)
    // nextPurchase Purchased(active) → tap Continue → 'Welcome to Premium. Thank you!'; back on the source; premium true;
    // analytics (region notRequired, recording sink): purchase_success{product: premium_yearly}
testWidgets('cancelled_purchase_stays_quietly', ...)
testWidgets('pending_and_failed_purchases_say_so', ...)      // pending, network, notAllowed, alreadyOwned, unknown → their copy
testWidgets('restore_outcomes', ...)                         // restoredPremium → 'Purchases restored…' + restore_success; nothing; failed
testWidgets('offers_unavailable_shows_retry', ...)           // loadOffer null → title + 'Try again' → retried
testWidgets('already_premium_shows_thanks_and_manage', ...)  // monthly active → 'You have Premium'; Manage → Play subscriptions URL;
                                                             // lifetime → 'Lifetime Premium…' and no Manage
testWidgets('paywall_view_logged_with_source_and_variant', ...) // {source: settings, variant: a}
testWidgets('busy_purchase_disables_the_buttons', ...)
testWidgets('paywall_has_no_banner', ...)
testWidgets('paywall_fits_320dp_at_200_percent_text', ...)   // light + dark, ready and active states
// paywall_golden_test.dart (@Tags(['golden'])): ready state, Size(390, 844) → goldens/paywall_{light,dark}.png

// settings_hub_phase6_test.dart
testWidgets('hub_premium_row_reflects_premium', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/purchases test/features/paywall test/features/settings`
Expected: FAIL.

- [ ] **Step 3: Add the dependency:** `flutter pub add purchases_flutter:10.18.1`
- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Generate the goldens, run the tests, build the dev APK**

Run `flutter test --update-goldens --tags golden test/features/paywall/paywall_golden_test.dart` (inspect both), then `flutter test`, then `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
Expected: all PASS, and the build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): revenuecat premium with an offline cache and an honest paywall" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- decisions for Rulings P6-R10 and P6-R11, plus the pin purchases_flutter 10.18.1
- owner: RevenueCat project and keys; store products and the `default` offering; no trials or intro offers in v1; the iOS In-App Purchase capability
- learning: whether `MainActivity` needs `FlutterFragmentActivity` (only RevenueCatUI does; (unverified) for core purchases on the device run)

---

### Task 6.8: Ads, the real banner slot and interstitial pacing

**Files:**
- Modify:
  - `app/lib/core/ads/banner_slot.dart` (body; the constructor, `AdPlacement` and `clearance` are kept)
  - `app/lib/features/settings/presentation/settings_screen.dart` (`PopScope` trigger)
  - `app/test/core/ads/banner_slot_test.dart` (rewritten)
  - `app/test/helpers/pump_router_app.dart`
- Create:
  - `app/lib/core/ads/ad_unit_ids.dart`, `ads_service.dart` (+ `.g.dart`)
  - `google_mobile_ads_sdk.dart` (`google_mobile_ads` import, ads only)
  - `interstitials.dart` (+ `.g.dart`)
  - `app/test/helpers/fake_ads_sdk.dart`, `ad_clearance.dart`
- Test: `app/test/core/ads/{ad_unit_ids,ads_controller,banner_slot,interstitials}_test.dart`, `banner_clearance_test.dart`

**Interfaces:**
- Consumes: `serviceConfigProvider`, `flavorProvider`, `appConfigProvider`, `premiumProvider`, `consentControllerProvider`, `ensureTrackingDecided`, `remoteSessionProvider` (`isDemo`), `connectionStateProvider`, `notConnectedNoticesProvider`, `settingsStoreProvider` (`launchCount`, `interstitialLastShownAt`), `clock`.
- Produces:
  - `abstract final class AdMobTestIds { androidAppId, iosAppId, androidBanner, iosBanner, androidInterstitial, iosInterstitial }` (the values in Ruling P6-R9).
  - `@immutable class AdUnitIds { final String? banner; final String? interstitial; static AdUnitIds resolve({required Flavor flavor, required TargetPlatform platform, required ServiceConfig config}); }`. dev → test IDs; prod → defines (empty → `null`); other platforms → both `null`.
  - `abstract interface class AdsSdk`:
    - `Future<void> initialize();`
    - `Future<AdBannerSize?> bannerSize(Orientation o, int width);`
    - `Future<LoadedBanner?> loadBanner(String unitId, AdBannerSize size);`
    - `Future<LoadedInterstitial?> loadInterstitial(String unitId);`

    Supporting types:
    - `class AdBannerSize { final int width; final int height; }`
    - `abstract interface class LoadedBanner { Widget get widget; void dispose(); }`
    - `abstract interface class LoadedInterstitial { Future<void> show(); void dispose(); }`

    `GoogleMobileAdsSdk`: `MobileAds.instance.initialize()`, `AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation`, `BannerAd(...).load()` wrapped in a `Completer` (failure → `null`, ad disposed), `AdWidget`, and `InterstitialAd.load`. Everything is caught.
  - `@Riverpod(keepAlive: true) AdsSdk adsSdk(Ref ref) => GoogleMobileAdsSdk();`.
  - `@Riverpod(keepAlive: true) class AdsController`:
    - `Future<bool> ready()`: memoised. `ensureGathered()`; `canRequestAds` false → `false`; else `initialize()` once → `true`. Errors → `false`.
    - `bool bannerAllowedNow(AdPlacement p)`: unit ID, `adsBannerEnabled`, premium known and false.
  - `BannerSlot` (now a `ConsumerStatefulWidget`; Ruling P6-R9):
    - **Load path:**
      - Watch `premiumProvider`, `appConfigProvider` and the unit IDs.
      - If not allowed: dispose any ad and build `SizedBox.shrink(key: ValueKey('banner_slot_${placement.name}'))`.
      - If allowed, after the first frame: `await ready()`, then on iOS `await ensureTrackingDecided(context, ref)`, then `bannerSize(MediaQuery.orientationOf, safe-area width)`, the small-screen check, then `loadBanner`.
      - On success, `setState` with the loaded ad, checking `mounted` after each await.
    - **Loaded layout:** `Semantics(container: true, label: adLabel, child: Column[Divider(height: 1, color: outline), ConstrainedBox(minHeight: 48, child: Center(Text(adLabel, style: labelSmall/textSecondary))), SizedBox(width: size.width, height: size.height, child: banner.widget)])`, with `key: ValueKey('banner_slot_${placement.name}')`. The text is in an `ExcludeSemantics` (the container label says it).
    - **Changes and disposal:**
      - A width or orientation change disposes the ad and loads again.
      - `dispose` disposes the ad.
      - Premium arriving while loaded disposes it and shrinks.
  - `enum InterstitialTrigger { leftSettings }`. `@Riverpod(keepAlive: true) class Interstitials`:
    - It listens to `connectionStateProvider` (any non-connected status after connected) and `notConnectedNoticesProvider`, which set `_lastTroubleAt = clock.now()`.
    - It preloads one ad when enabled, ready, not Premium and launch count ≥ 2.
    - `Future<bool> maybeShow(InterstitialTrigger t)` checks every rule in Ruling P6-R9. When they hold it calls `show()`, persists `setInterstitialLastShownAt(clock.now())` and preloads the next. It never awaits a load.
  - `SettingsScreen`: `PopScope(onPopInvokedWithResult: (didPop, _) { if (didPop) unawaited(ref.read(interstitialsProvider.notifier).maybeShow(InterstitialTrigger.leftSettings)); })`. Nothing else in the hub changes.
  - `pumpRouterApp` default: `adsSdkProvider.overrideWithValue(FakeAdsSdk())`. By default it initialises but **never loads**, so every existing test and golden sees the zero-size slot as in Phase 5. The constructor takes `loads: true` (a `ColoredBox` of the requested size, key `fake_banner`), `failLoads`, `initializeCalls`, `bannerLoads` and `disposed`, plus a fake interstitial with `shows`.
  - `ad_clearance.dart` (test helper):
    - `List<Rect> tappableRects(WidgetTester t)` covers `IconButton`, `BackButton`, `CloseButton`, `ButtonStyleButton`, `ListTile` (with `onTap`), `InkWell` (with `onTap`) and `Switch`/`Radio`, all on screen and not offstage.
    - `void expectClearance(WidgetTester t, Rect ad, {double min = 48})` asserts each rect's vertical gap to the creative's rect is ≥ `min` when they overlap horizontally.

- [ ] **Step 1: Write the failing tests**

```dart
// ad_unit_ids_test.dart
test('dev_always_uses_google_test_ids', ...)          // even with defines set
test('prod_uses_the_defines_or_nothing', ...)          // empty → null banner and interstitial
test('test_ids_are_googles', ...)                      // every AdMobTestIds value starts with ca-app-pub-3940256099942544

// ads_controller_test.dart
test('ads_not_initialised_before_consent_resolved', ...)   // master name: FakeConsentService.holdGather → ready() pending,
    // sdk.initializeCalls 0; complete with canRequestAds true → 1; second ready() → still 1
test('no_ads_when_consent_denies_ad_requests', ...)       // canRequestAds false → ready false, never initialised
test('sdk_failures_mean_no_ads_not_crashes', ...)

// banner_slot_test.dart (pumpRouterApp with FakeAdsSdk(loads: true))
testWidgets('no_banner_on_remote_screen', ...)           // master name: /remote → no BannerSlot, no 'fake_banner';
    // also /discover, /onboarding, /paywall, /settings/appearance… (every route except /apps and /settings) → none
testWidgets('banner_shows_on_apps_and_settings_when_allowed', ...) // 'fake_banner' + 'Advertisement'; semantics label 'Advertisement'
testWidgets('banner_hidden_for_premium', ...)             // master name: TestPremium(premium, known) → zero-size, sdk.bannerLoads 0
testWidgets('premium_stream_drives_ads_off', ...)         // master name: loaded on /settings → TestPremium.set(premium) → gone, disposed 1
testWidgets('banner_waits_for_premium_to_be_known', ...)  // PremiumState(isPremium: false, known: false) → no load; known → load
testWidgets('banner_respects_the_kill_switch', ...)       // FakeConfigSource ads_banner_enabled false → none
testWidgets('ios_waits_for_the_tracking_decision_before_the_first_ad', ...)
    // iOS, tracking notDetermined → pre-prompt shown on opening /settings, bannerLoads 0; Continue → load → banner
testWidgets('prod_without_unit_ids_shows_no_banner', ...)
testWidgets('failed_load_takes_no_space', ...)
testWidgets('banner_disposed_when_leaving_and_reloaded_on_rotation', ...)
testWidgets('tiny_screens_skip_the_banner', ...)          // Size(640, 300) at 200% text → no load
testWidgets('loaded_banner_fits_320dp_at_200_percent_text', ...)

// banner_clearance_test.dart
testWidgets('banner_has_48dp_clearance_from_nav_controls', (t) async {   // master name
  for (final size in [const Size(320, 640), const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      for (final route in [AppRoutes.apps, AppRoutes.settings]) {
        // FakeAdsSdk(loads: true); /apps also with an empty shortcut list (the Add apps button)
        // scroll to the top, the middle and the end; at each: expectClearance(t, t.getRect(find.byKey(const ValueKey('fake_banner'))))
      }
    }
  }
});

// interstitials_test.dart (fakeAsync + withClock; FakeConfigSource ads_interstitial_enabled true; launchCount 2)
test('interstitial_respects_min_interval', ...)          // master name: show → true; +599 s → false; +600 s → true; persisted
test('interstitial_off_by_default', ...)
test('interstitial_never_for_premium_demo_or_first_launch', ...)
test('interstitial_never_within_60s_of_trouble', ...)    // a not-connected notice at t-30 s → false; t+61 s → true
test('interstitial_only_when_already_loaded', ...)       // load pending → false at once (never waits)
testWidgets('leaving_settings_is_the_only_trigger', ...) // pop the hub → maybeShow once; sub-page pops don't trigger
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/ads test/features/settings`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner, then `dart format lib test`. The Phase 5 test `banner_slot_takes_no_space_until_phase_6` becomes `banner_slot_takes_no_space_until_an_ad_loads`; say so in the report.
- [ ] **Step 4: Run every test and build the dev APK**

Run: `flutter test`, then `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
Expected: all PASS (the Phase 5 goldens are unchanged, because the fake never loads), and the build succeeds.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): adaptive banner after consent with a 48dp label band, interstitial pacing off by default" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P6-R9 (unit IDs, the label band as the clearance rule, eligibility, interstitial rules). Carry-over closed: `BannerSlot` filled. Learning: the real banner's height on the Note10+ (device run).

---

### Task 6.9: Premium colour styles

**Files:**
- Modify:
  - `app/lib/app/theme/app_theme.dart` (`colours` parameter)
  - `app/lib/app/app.dart` (effective style)
  - `app/lib/features/settings/presentation/appearance_page.dart` (style group)
- Create: `app/lib/app/theme/colour_styles.dart`
- Test: `app/test/app/theme/colour_styles_test.dart`, `app/test/features/settings/appearance_styles_test.dart`, `appearance_styles_golden_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `ColourStyle` (6.1), `premiumProvider`, `settingsControllerProvider`, `AppRoutes.paywall`.
- Produces:
  - `AppColors colourStyleColors(ColourStyle style, Brightness b)`:
    - `standard` gives `AppColors.light`/`dark` unchanged.
    - Premium styles give `base.copyWith(bg, surface, surfaceRaised, outline, textPrimary, textSecondary, accent, onAccent)`, starting from these values. Adjust only if the contrast test fails; keep the hue, and report the final values.

      | Style | Brightness | bg | surface | surfaceRaised | outline | textPrimary | textSecondary | accent | onAccent |
      |---|---|---|---|---|---|---|---|---|---|
      | ocean | dark | `#0B1418` | `#101D22` | `#18282E` | `#24383F` | `#EFF6F7` | `#9FB4B9` | `#3FC6C6` | `#06181A` |
      | ocean | light | `#F3F8F8` | `#FFFFFF` | `#E4EFEF` | `#C9DADB` | `#0E1A1C` | `#44575A` | `#00777A` | `#FFFFFF` |
      | ember | dark | `#16110D` | `#1F1813` | `#2B221B` | `#3B2F25` | `#F8F2EC` | `#BFAF9F` | `#FF9F43` | `#1A0F05` |
      | ember | light | `#FAF6F2` | `#FFFFFF` | `#F1E9E1` | `#E0D3C6` | `#1D1610` | `#5E4E40` | `#B34D00` | `#FFFFFF` |
      | midnight | dark | `#000000` | `#0A0A0F` | `#16161F` | `#262633` | `#F1F0F7` | `#A9A6BD` | `#A98BFF` | `#120A26` |
      | midnight | light | `#F5F4FA` | `#FFFFFF` | `#EAE8F3` | `#D4D1E3` | `#14121D` | `#4E4A63` | `#5B3FD1` | `#FFFFFF` |
  - `ColourStyle effectiveColourStyle({required AppSettings settings, required PremiumState premium})` (Ruling P6-R12; dynamic colour is handled by the caller).
  - `buildAppTheme({required Brightness brightness, ColorScheme? dynamicScheme, AppColors? colours})`: `colours` replaces the base palette. `buildTheaterTheme` is unchanged.
  - `App` passes `colours: colourStyleColors(effective, b)` when dynamic colour isn't in use.
  - Appearance page: after the theme group, `SettingsChoiceGroup<ColourStyle>(label: appearanceStyle, value: premium.isPremium ? settings.colourStyle : ColourStyle.standard, …)`:
    - Each premium choice has the subtitle `appearanceStyleLocked` for free users.
    - Each row shows a 24 dp swatch pair (the style's accent on its bg, inside `ExcludeSemantics`).
    - `onChanged`: a free user picking a premium style → `push(AppRoutes.paywall(source: PaywallSource.themes))`, nothing stored. Otherwise `setColourStyle`.
    - While dynamic colour is on, the `appearanceStyleWallpaperOn` note sits above the group.

- [ ] **Step 1: Write the failing tests**

```dart
// colour_styles_test.dart
test('every_colour_style_meets_contrast', () {
  for (final s in ColourStyle.values) for (final b in Brightness.values) {
    final c = colourStyleColors(s, b);
    for (final bg in [c.bg, c.surface, c.surfaceRaised]) {
      expect(contrast(c.textPrimary, bg), greaterThanOrEqualTo(4.5), reason: '$s $b primary');
      expect(contrast(c.textSecondary, bg), greaterThanOrEqualTo(4.5), reason: '$s $b secondary');
    }
    expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
    expect(contrast(c.accent, c.bg), greaterThanOrEqualTo(4.5));       // text buttons
    expect(contrast(c.accent, c.surface), greaterThanOrEqualTo(4.5));
  }
});   // reuse the Phase 2 contrast helper
test('styles_keep_status_and_tv_key_colours', ...)
test('effective_style_rules', ...)        // free → standard; premium → stored; premium lost → standard (stored choice kept)

// appearance_styles_test.dart (pumpRouterApp at /settings/appearance)
testWidgets('free_users_see_locked_styles_and_go_to_the_paywall', ...)
    // 3 × 'Included with Premium'; tap 'Ocean' → PaywallScreen(source: themes); store.colourStyle still standard
testWidgets('premium_users_apply_a_style_at_once', ...)       // TestPremium(premium) → tap 'Midnight' → Theme bg == #000000 (dark)
testWidgets('losing_premium_falls_back_to_standard_and_keeps_the_choice', ...)
testWidgets('wallpaper_colours_win_over_a_style', ...)        // dynamic on → note shown; theme uses the dynamic scheme
testWidgets('theater_mode_ignores_styles', ...)               // remote theater theme == buildTheaterTheme()
testWidgets('style_group_fits_320dp_at_200_percent_text', ...)// light + dark
// appearance_styles_golden_test.dart: Premium, Midnight selected, Size(390, 844), dark → goldens/appearance_styles_dark.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/theme test/features/settings`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner if a provider changed, then `dart format lib test`.
- [ ] **Step 4: Generate the golden and run the tests**

Run `flutter test --update-goldens --tags golden test/features/settings/appearance_styles_golden_test.dart` (inspect), then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): premium colour styles with contrast-checked palettes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P6-R12 with the final hex values.

---

### Task 6.10: Review prompt, launch and press counters, and the real OS version

**Files:**
- Modify:
  - `app/pubspec.yaml` (`in_app_review: 2.0.12`, `device_info_plus: 13.3.0`)
  - `app/lib/bootstrap.dart` (launch count)
  - `app/lib/core/analytics/analytics_hooks.dart` (fan-out adds the press counter)
  - `app/lib/core/app_info/app_info.dart` (OS version)
  - `app/lib/app/app.dart` (read `reviewPrompterProvider` once)
  - `app/test/helpers/pump_router_app.dart`
- Create:
  - `app/lib/core/review/review_prompter.dart` (+ `.g.dart`)
  - `in_app_review_requester.dart` (the only `in_app_review` import)
  - `app/test/helpers/fake_review_requester.dart`
- Test: `app/test/core/review/review_prompter_test.dart`, `app/test/core/app_info/app_info_test.dart`; additions to `app/test/bootstrap_test.dart`, `app/test/features/settings/feedback_test.dart`

**Interfaces:**
- Consumes: `settingsStoreProvider` (`reviewKeyPresses`, `launchCount`, `reviewPromptShown`), `appConfigProvider`, `connectionStateProvider`, `remoteSessionProvider`, `notConnectedNoticesProvider`, `appAnalyticsProvider`, `sessionSignalsProvider` (pause), `clock`.
- Produces:
  - `abstract interface class ReviewRequester { Future<bool> isAvailable(); Future<void> request(); }`. `InAppReviewRequester` uses `InAppReview.instance` and catches everything.
  - `@Riverpod(keepAlive: true) ReviewRequester reviewRequester(Ref ref)`.
  - `@Riverpod(keepAlive: true) class ReviewPrompter`:
    - `void countPress()` keeps the count in memory and writes it every 10 presses and on app pause.
    - It listens to `connectionStateProvider` and notes trouble (a loss or a notice) times.
    - On a transition to `connected` it calls `_maybePrompt()`, which checks Ruling P6-R13. If it holds: `isAvailable()` → `request()` → `setReviewPromptShown(true)` + `review_prompt_shown`.
  - The fan-out listener calls `countPress()` for every `KeySent` (not sampled, not demo).
  - `buildRootWidget`: after the settings open, `await settings.setLaunchCount(settings.launchCount + 1)` (errors swallowed).
  - `app_info.dart`:
    - `typedef OsVersionReader = Future<({String os, String version})> Function();`
    - `@Riverpod(keepAlive: true) OsVersionReader osVersionReader(Ref ref)`: `DeviceInfoPlugin`; Android `('Android', androidInfo.version.release)`, iOS `('iOS', iosInfo.systemVersion)`, else `(Platform.operatingSystem, Platform.operatingSystemVersion)`.
    - `appInfo` uses it; a reader failure falls back to the `Platform` strings.
    - The feedback footer reads `System: Android 12`.
  - `pumpRouterApp` default: `reviewRequesterProvider.overrideWithValue(FakeReviewRequester())` (available, records requests).

- [ ] **Step 1: Write the failing tests**

```dart
// review_prompter_test.dart (ProviderContainer.test, FakeRemoteSession states, FakeConfigSource, fakeAsync + withClock)
test('review_prompt_after_150_presses_and_2_sessions_never_after_error', () {   // master name, in parts:
  // launchCount 1, 150 presses, connect → no request
  // launchCount 2, 149 presses, connect → no request
  // launchCount 2, 150 presses, a connection loss at t-30 s, then connect → no request
  // launchCount 2, 150 presses, clean connect → exactly one request + one review_prompt_shown event
});
test('review_prompt_shown_at_most_once', ...)
test('threshold_comes_from_remote_config', ...)          // review_prompt_min_key_presses 5
test('demo_never_prompts', ...)
test('unavailable_review_api_marks_nothing', ...)
test('press_count_survives_restart', ...)                // 25 presses + pause → store 25; new container reads 25
// bootstrap_test.dart
testWidgets('launch_count_increments_once_per_start', ...)

// app_info_test.dart
test('os_version_is_the_release_not_the_kernel', ...)   // reader ('Android', '12') → os 'Android', osVersion '12'
test('device_info_failure_falls_back_to_platform_strings', ...)
// feedback_test.dart (update the default AppInfo override to os 'Android', osVersion '12')
testWidgets('feedback_footer_names_the_os_release', ...) // mail contains 'System: Android 12'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/review test/core/app_info test/bootstrap_test.dart test/features/settings/feedback_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the dependencies:** `flutter pub add in_app_review:2.0.12 device_info_plus:13.3.0`
- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): review prompt after real use, launch counter and the real os version in feedback" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P6-R13, plus the pins in_app_review 2.0.12 and device_info_plus 13.3.0. Carry-over closed: feedback's OS version.

---

### Task 6.11: Seam tests, privacy and banner sweeps, accessibility and the phase exit

**Files:**
- Create (tests): `app/test/app/services_flow_test.dart`, `app/test/app/phase6_accessibility_test.dart`
- Modify: `app/test/app/apps_devices_settings_flow_test.dart` (`banner_slot_only_on_apps_and_the_settings_hub` now runs with `FakeAdsSdk(loads: true)` and includes `/paywall` and `/settings/privacy`); production files only to fix defects these tests reveal (name each one in the report)

**Interfaces:**
- Consumes: everything above. The real `TvRemoteSession` path with `FakeRemoteClients` and `InMemoryDeviceRepository`; `RecordingAnalyticsSink`, `RecordingCrashlyticsSink`, `FakeConsentService`, `FakeTrackingService`, `FakePurchaseService`, `FakeAdsSdk`, `FakeConfigSource`, `FakeReviewRequester`.
- Produces: no new production API. This task proves that the services work together and fail safely.

- [ ] **Step 1: Write the tests**

```dart
// services_flow_test.dart
testWidgets('the_remote_works_with_every_service_failing', ...)
    // firebaseStatus unavailable; consent, tracking, ads, purchases, config and review fakes all throw on every call →
    // discover → pair (code) → remote connected → tap Volume up reaches the client; Apps and Settings open with no banner;
    // the paywall shows 'Premium isn't available right now'; no exception, nothing on screen about the failures
testWidgets('first_launch_in_the_eea_asks_on_the_remote_and_shares_nothing_by_default', ...)
    // region required + form; onboarding/pair events buffered, then dropped; form shown once on /remote;
    // canRequestAds true → banner on /settings; Privacy choices: both switches off
testWidgets('outside_the_eea_sharing_is_on_until_turned_off', ...)
    // region notRequired → buffered events flushed; turn usage off → later events not sent; collection disabled
testWidgets('buying_premium_removes_banners_and_unlocks_styles', ...)
    // Appearance → tap Ember → paywall(themes) → Continue (Purchased) → back on Appearance → tap Ember → applied;
    // /settings and /apps: no banner; Privacy choices: 'You have Premium, so the app shows no ads.'
testWidgets('premium_offline_never_flashes_an_ad', ...)   // cached premium, a purchase service that never answers → no load ever
testWidgets('no_analytics_event_or_crash_report_carries_tv_data', ...)
    // region notRequired; pair 'Living Room TV 3' at 192.168.0.20, nickname 'Den', MAC AA:BB:CC:DD:EE:F0 (code A1B2C3);
    // type 'hunter2' on the keyboard; launch a custom shortcut com.example.private; switch layout; open /devices/<tv>;
    // report a SocketException-like error whose message holds the IP and the name through crashReporterProvider
    // (scrubbing reporter with isDebugBuild false); then for every recorded analytics event/screen and crash payload:
    // none contains 'Living Room', 'Den', '192.168.0.20', 'AA:BB:CC', 'A1B2C3', 'hunter2', 'com.example.private', the pin;
    // no IPv4/MAC regex match
testWidgets('forced_update_blocks_every_route', ...)      // min 9.0.0 → onboarding, remote, settings, paywall, demo: 'Update required'
testWidgets('no_ad_within_48dp_of_navigation_controls_anywhere', ...) // ad_clearance over /apps and /settings incl. landscape + 200%
testWidgets('faq_privacy_answer_matches_the_behaviour', ...)
    // Help → open 'What does the app keep about my TV?' → answer mentions 'Privacy choices'; that page has both switches
test('vendor_sdks_are_imported_only_by_their_adapters', ...) // re-run (lives in test/platform; listed here for the exit)

// phase6_accessibility_test.dart: for /paywall (ready and active), /settings/privacy, /settings/appearance (styles),
// /settings with a loaded fake banner, the update gate and the tracking pre-prompt, in light and dark:
testWidgets('${screen}_meets_text_contrast_${b.name}', ...)       // meetsGuideline(textContrastGuideline)
testWidgets('${screen}_meets_tap_target_guidelines_${b.name}', ...) // android/iOS/labeled tap-target guidelines
testWidgets('every_phase6_screen_fits_320dp_at_200_percent_text', ...)
testWidgets('every_phase6_screen_fits_a_non_linear_text_scaler', ...)
testWidgets('the_banner_is_announced_once_as_an_advertisement', ...)  // one semantics node labelled 'Advertisement'
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/services_flow_test.dart test/app/phase6_accessibility_test.dart test/app/apps_devices_settings_flow_test.dart`
Expected: they may fail. A failure here is a real defect: fix it in the owning file, name the fix in the report, and don't weaken the test.

- [ ] **Step 3: Fix** what the tests revealed.
- [ ] **Step 4: Run every test and the goldens**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Build the dev APK with no config**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart` on a tree with no `google-services.json`, no `env/*.json` and no `secrets.properties`.
Expected: build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): services seams, privacy sweep, banner placement and accessibility" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: every defect the seam tests found, with its fix.

---

## Phase exit checklist

- [ ] `powershell -File tool/check.ps1` → `All checks passed.` (goldens included). `tool/check.sh` passes with goldens excluded. A clean clone with no config builds the dev APK.
- [ ] Golden PNGs:
  - new: `privacy_choices_light`, `paywall_{light,dark}`, `appearance_styles_dark`
  - re-baselined: `settings_hub_{light,dark}` (new rows)
  - every other Phase 5 golden unchanged (the fake ads SDK never loads by default).
- [ ] Every carry-over to Phase 6 in `status.md` is closed by a task report, or deferred (Ruling P6-R14):
  - banner (6.8), hub rows (6.1/6.6/6.7)
  - `AD_ID` test (6.6)
  - `faqPrivacyA` (6.1, 6.11); Auto Backup **deferred** to Phase 8
  - listener debug log (6.4), scrubbing reporter (6.3), `StartupGate` timeout (6.2)
  - `device_info_plus` (6.10)
- [ ] **Owner verification with real accounts.** These are the master exit criteria; they need the owner. Phone: Note10+; an iPhone for iOS.
  1. **Firebase (dev project):**
     - Put `google-services.json` / `GoogleService-Info.plist` in place.
     - Run `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` with `FIREBASE_ENABLED: true`.
     - Run `adb shell setprop debug.firebase.analytics.app com.digitallinked.atvremote.dev`.
     - Check: events and route-name screen views show in **DebugView**, with no TV data in any parameter.
     - Turn usage off in Privacy choices: events stop.
     - Profile build (`--profile`): About → "Send a test crash report", and it shows in Crashlytics, scrubbed.
     - In the Remote Config console, set `min_supported_version` to `9.0.0`, restart twice: the update screen appears. Set it back.
     - Set `ads_banner_enabled` to false, restart twice: no banner. Set it back.
  2. **Ads + consent:**
     - Dev shows **test** banners only on Apps and the Settings hub, under the "Advertisement" band.
     - With `UMP_DEBUG_GEOGRAPHY: "eea"` and the device's hashed ID, the consent form appears once, on the remote. "Ad privacy choices" opens the options form.
     - iOS: the pre-prompt, then the system ATT prompt, before the first banner.
  3. **RevenueCat sandbox** (Play licence tester / App Store sandbox):
     - Buy monthly, yearly and lifetime on each platform; Restore on a reinstall.
     - Banners vanish and styles unlock.
     - Airplane mode after buying: still Premium.
     - Cancel the subscription in the store: Premium ends at expiry.

  Record the answers in `learnings.md`. If no device or account is available, say so in the report; don't claim the check passed.
- [ ] The still-open real-device run from Phases 3–5 (status.md) is unaffected. Do it before or with the above, following the live-testing rules (verify the screen before each tap, never Power without the owner's agreement, restore settings).
- [ ] The task reports collectively carry these knowledge updates:
  - **decisions:** Rulings P6-R1 to P6-R14, grouped as:
    - config and startup (R2, R3), including iOS 15
    - privacy (R4, R5, R6)
    - Remote Config and updates (R7)
    - consent and ads (R8, R9)
    - Premium, paywall and styles (R10–R12)
    - review (R13)
    - plus every pin from the Tech Stack line and the Gradle plugin versions that worked.
  - **skills (controller edits):**
    - `app-services`: the startup order (RevenueCat before ads), the exact event catalogue, privacy choices and buffering, the label band.
    - `store-release`: the config table (env keys, `secrets.properties`, `Secrets.xcconfig`, `ios/config/<flavor>/`), and the iOS 15 floor.
  - **learnings:**
    - Firebase plugin behaviour with AGP 9
    - UMP with the test app ID
    - how go_router names pages
    - RevenueCat `PurchaseParams` API
    - the `informationCollector` privacy trap
    - the owner-verification answers.
  - **status:**
    - Phase 6 done; carry-overs closed.
    - Carry-overs to Phase 7: a Settings entry before pairing, so Privacy choices are reachable from discovery.
    - Carry-overs to Phase 8: `allowBackup`; `InfoPlist.strings` for the ATT text.
    - Carry-overs to Phase 9: the real config and IDs, the App Store id, Crashlytics symbol upload, Data safety / App Privacy forms.

## Needs the owner

**To switch from test to real config** (Phase 9 at the latest; nothing real is ever committed):
1. **Firebase:** two projects (or one project with two apps per platform), `dev` and `prod`.
   - Android apps `com.digitallinked.atvremote.dev` / `com.digitallinked.atvremote` → `google-services.json` into `app/android/app/src/dev/` and `src/prod/`.
   - iOS apps with the same bundle ids → `GoogleService-Info.plist` into `app/ios/config/dev/` and `config/prod/`.
   - Enable Analytics (Google Signals **off**, no AdMob linking), Crashlytics and Remote Config. Publish the seven Remote Config keys with the in-code defaults.
   - Set `"FIREBASE_ENABLED": true` in `app/env/<flavor>.json`.
2. **AdMob:**
   - One AdMob app per platform (prod) → app IDs into `app/android/secrets.properties` (`admobAppIdProd=`) and `app/ios/Flutter/Secrets.xcconfig` (`ADMOB_APP_ID_PROD =`).
   - Ad units: an **adaptive banner** and an interstitial per platform → `ADMOB_BANNER_ANDROID/IOS` and `ADMOB_INTERSTITIAL_ANDROID/IOS` in `app/env/prod.json`. Dev keeps Google's test units automatically.
   - **Privacy & messaging:** a GDPR (EEA/UK/CH) consent message and, for iOS, an IDFA explainer message; also a US state regulations message if wanted.
   - Add the app-ads.txt file on the developer website.
3. **RevenueCat:**
   - A project with the Play and App Store apps (service-account JSON for Play; App Store Connect API key / in-app purchase key for Apple).
   - Entitlement `premium`. Products `premium_monthly`, `premium_yearly` (auto-renewing subscriptions) and `premium_lifetime` (non-consumable), attached to `premium`. A `default` offering with the Monthly, Annual and Lifetime packages.
   - Public SDK keys → `REVENUECAT_ANDROID_KEY` (`goog_…`) and `REVENUECAT_IOS_KEY` (`appl_…`) in `app/env/<flavor>.json`.
   - **No trials or introductory offers in v1** (the paywall has no copy for them).
4. **Store products:**
   - Play Console: two subscriptions (each with one base plan) + one in-app product, with the ids above, plus licence testers.
   - App Store Connect: a subscription group with the two subscriptions + a non-consumable, prices, localised names, the review screenshot, sandbox testers, the **In-App Purchase capability**, and the Paid Apps agreement.
5. **Privacy declarations (Phase 9):**
   - **Play Data safety:**
     - collected: device or other IDs (advertising ID by AdMob), app interactions/diagnostics (Analytics, Crashlytics), purchase history (RevenueCat/Play)
     - not sold; encrypted in transit; no account
     - the ads declaration says yes
   - **App Privacy labels:** Identifiers (device ID; used for third-party advertising), Usage Data (product interaction, advertising data), Diagnostics (crash data), Purchases. Tracking = **yes** (AdMob with ATT).
   - The privacy policy names Firebase, AdMob/UMP and RevenueCat.
6. **On a Mac:**
   - `pod install` (or SwiftPM), with iOS **15.0** as the platform. (unverified) whether Flutter 3.44 resolves these plugins through CocoaPods or SwiftPM.
   - If CocoaPods: add `$FirebaseAnalyticsWithoutAdIdSupport = true` to the generated Podfile and commit it.
   - Check that the "Copy Firebase config" phase and `$(ADMOB_APP_ID_PROD)` resolve.
   - `flutter build ios --flavor dev|prod -t lib/main_<f>.dart --no-codesign`.
   - Later (Phase 9): add the Crashlytics dSYM upload run script.
7. **Placeholders to replace:** `AppLinks.appStoreListing` (the App Store id, once the record exists), plus the existing privacy/terms/support placeholders (decision #35). The privacy policy must cover the services above before any store upload.
8. **Questions (defaults in brackets):** confirm prices per market [set in the consoles; the paywall reads them]; confirm the three style names Ocean/Ember/Midnight [yes]; whether interstitials should ever be turned on [no; Remote Config off].
