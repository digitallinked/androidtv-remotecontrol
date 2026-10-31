# Project status

_Last updated: 2026-10-31 by Claude (controller, subagent-driven run, Phase 8 merged)._

## Current phase

**Phase 9: Release preparation** (next; plan to be written from the master plan). Phases 0–8 are merged into `main`. Phase 9 prepares assets and scripts and stops before signing and store submission, which need the owner's accounts.

The **real-device run is still open** and is now scripted in `docs/knowledge/device-matrix.md` (rows DM-001…DM-102, results empty). It is the exit for Phases 3–8 and gates Phase 9's store steps.

## Done

- **Phase 8 (quality and hardening):**
  - **Release blocker closed in code** (decision #49): Android backup and device transfer off (`allowBackup`, `fullBackupContent`, `data_extraction_rules.xml`; verified in the devDebug and prodRelease merged manifests). iOS DB in a backup-excluded `Application Support/Database` via a small Swift channel; keychain this-device-only; a fresh DB re-seeds the Apps row. New-phone FAQ.
  - **Tests:** the fake TV is a test library (`package:atv_remote/testing.dart`); discover → pair → key and demo flows run on the host and on a device; key-press latency (p95 < 30 ms, host) and a 50-cycle resume leak test; `tool/measure_android.{ps1,sh}` for cold start, trace and battery (device numbers not yet measured).
  - **Accessibility:** every screen, sheet and state meets the four guidelines in light and dark, at 320 dp / 200 % and the non-linear scaler; Phase 2–6 a11y carry-overs fixed (dialog names, live regions, spinner labels, reorder announce, D-pad order, FittedLabel floor, demo strip contrast); reduce motion closed for Radio, Switch and the decorator.
  - **Hardening:** `noRetry` storage errors, MAC cleared with a distrusted pin, usage pruning, merge follow-ups, NSD stop/cancel, narrowed catches, D-pad hold region, RTL split layout, one `connectionTroubleProvider`, crash reports held until saved TV names are known.
  - **Malay:** complete `app_ms.arb` (454 keys, strict parity), Malay iOS purpose strings, pseudo-locale and Malay overflow sweeps.
  - Decisions #49–#50. App tests +2084, atv_remote +199.

- **Phase 7 (polish):**
  - **Onboarding:** 3 cards (Skip, Get started, Try demo), shown once, never trapped by a failing store. An iOS-only Local Network explainer before discovery.
  - **Motion:** real page transitions on all 16 routes through `appPage` (iOS swipe-back, Android predictive back). A full reduce-motion mode: no visible animation anywhere, including ink, menus and the iOS caret (decision #47).
  - **Branding:** an original icon (adaptive, themed/monochrome, iOS set, Play 512) and splash, all rendered from our own painter by `tool/brand.ps1` (decision #48).
  - **Reachability:** Settings (Help, privacy, feedback) from discovery and the no-TV remote before pairing. The update gate shows on the first frame. Premium users skip the UMP form.
  - **Apps:** name-prefix-first search, a ringed now-on-TV dot, a non-scrolling empty/loading/failed state, the keyboard closes on drag.
  - **Large text:** two-line quick tiles, stacked Edit apps rows, About polish; every Phase 7 screen fits 320 dp at 200% text and a non-linear scaler, with contrast, tap-target and screen-reader-order tests.
  - Haptic and touchpad-reach fixes. Decisions #46–#48. All Phase 7 carry-overs are closed.

- **Phase 6 (services & monetisation):**
  - **Firebase:**
    - Analytics, Crashlytics and Remote Config run behind config-present checks, with the startup order in decision #38.
    - Crashlytics goes through a scrubbing reporter. An analytics guard allows only the exact event catalogue, with a privacy gate and a 50-event buffer.
    - Remote Config uses next-launch activation and `seal()`. The update gate is driven by `min_supported_version`.
  - **Consent and ads:**
    - UMP consent, Privacy choices and Ad privacy choices.
    - The iOS ATT pre-prompt, re-asked when iOS never showed its question.
    - AdMob test IDs. An adaptive banner shows only on `/apps` and the `/settings` hub (48 dp clearance, "Advertisement" label). Paced interstitials are off by default.
  - **Premium:** RevenueCat Premium with an offline cache, the paywall (purchase and restore), and four colour styles, three of them Premium.
  - **Review prompt** (decision #43). The real OS version now appears in the feedback footer.
  - **Seam tests** prove three things: the remote works with every service failing; no TV data reaches analytics or crash reports; and banner placement and accessibility hold on every Phase 6 screen.
  - The no-config dev APK builds, and no secrets are tracked.
  - Decisions #38–#45. All Phase 6 carry-overs are closed.
- **Phase 5 (apps, devices, settings, help):**
  - All Phase 5 strings, routes and stub screens landed in one task. `BannerSlot` (empty) appears only on `/apps` and the `/settings` hub. There is a Settings button on the remote.
  - **App catalogue:**
    - A bundled app catalogue (`apps_v1.json`): our own data, a closed schema, 8 region default rows.
    - Shortcut and usage storage, with one-time region seeding, Reset and recommendations.
    - A phone-only usage tracker (never for the demo).
  - **Apps screens:**
    - The Apps screen: grid, search including the catalogue, launch → back to the remote. The All apps tile is pinned in the quick row.
    - Edit apps: reorder, Undo, reset, an add sheet with TV recommendations, and custom shortcuts.
  - **Your TVs and Edit TV:** rename live, a shared MAC field, remove without touching the client identity, and pair again. "Manage TVs" is in the switcher.
  - **Settings and Help:**
    - The Settings hub, Appearance (theme, wallpaper colours, language), Remote layout (live preview) and Remote behaviour (the Phase 4 toggles).
    - Help (FAQ and troubleshooting) and About (version, licences including androidtvremote2).
    - Legal links and the feedback email, both placeholders.
  - **Carry-overs closed:**
    - lastHost refresh, announced name kept, re-resolve before Pair again;
    - manual→mDNS merge with pin, append-only hardening;
    - upper-case monograms, the MAC paste error.
  - Seam, banner and accessibility tests (`app/test/app/apps_devices_settings_flow_test.dart`, `phase5_accessibility_test.dart`). Decisions #27–#37.
- **Phase 4 (remote experience):**
  - The input path (`RemoteActions`: refusals, Smooth Press, repeat, stuck-key guard, haptics).
  - Touchpad, D-pad and numbers pager; the quick-access row; the bottom cluster; the keyboard sheet.
  - Power, Wake-on-LAN and the MAC sheet; Keep Screen Awake; Theater Mode.
  - Layouts down to 320 dp at 200% text. Decisions #20–#26.
- **Phase 3 (connect flow):**
  - Discovery (NSD and manual IP), and the pairing wizard with a TOFU pin.
  - `RemoteSession`/`TvRemoteSession`, the session providers and `SessionSupervisor`.
  - The remote screen shell, demo mode and `WakeOnLanService`. Decisions #13–#19.
- **Phase 2 (app shell):**
  - Design tokens and theme, base components with goldens, ARB l10n.
  - Drift DB and `DeviceRepository`, secure `IdentityStore`, `SettingsStore`.
  - go_router, `bootstrap`, and the dev/prod flavors.
- **Phase 1 (protocol library):**
  - Protobufs, framing, client identity and pairing secret.
  - `FakeTvServer`, `PairingClient`, `RemoteClient`, `TvConnection`.
  - Wake-on-LAN, the discovery model and the CLI.
- **Phase 0:** monorepo scaffold, lints, `tool/check.ps1`/`.sh`, CI.

## In progress

_Nothing._

## Next up

1. **Real-device run (owner + Claude):** work through `docs/knowledge/device-matrix.md` (it folds in every item below and the Phase 7–8 checks). This is the exit for Phases 3–8.
   - **Setup:**
     - Install the dev flavor on the Note10+ with `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json`. Copy `env/example.json` to `env/dev.json` first; empty values keep services off.
     - Discover the TV, pair, then use every control and screen.
     - Record the answers in `learnings.md` → "Unverified protocol behaviour".
   - **Protocol and connection:**
     - Same key on 6467/6466 (decision #11)?
     - Ping interval (decision #10).
     - Does `_pickHost` get IPv4?
     - Reconnect time after an IP change.
   - **Remote controls:**
     - Hold feel and volume ramp; long OK.
     - IME replace-field (`atv_cli text`).
     - The Search key on Google TV.
     - Theater dim/wake, keep-awake, landscape.
   - **Apps and TVs:**
     - The MY default row after clearing data.
     - Which shortcut and catalogue packages open; raw MediaTek current-app packages.
     - Remove a TV, then re-pair; IP→mDNS merge without re-pairing.
   - **Settings and accessibility:**
     - Wallpaper colours on Android 12.
     - Mail and browser links; the licences page.
     - TalkBack Move up/down; maximum font size.
   - **Phase 6 checks:**
     - The test banner on Apps and Settings, and the Apps-screen banner with the keyboard up.
     - The UMP form with `UMP_DEBUG_GEOGRAPHY=eea`.
     - Firebase DebugView once a dev Firebase project exists. Check that the first screen views of a fresh install arrive.
     - A RevenueCat sandbox purchase and restore. Check that the paywall doesn't flash "You have Premium" while closing.
     - The review prompt (Play internal track only).
     - The feedback footer shows "System: Android 12".
   - **Phase 7 checks (not run yet):**
     - Onboarding on a fresh install; Try demo; Settings from discovery.
     - The launcher icon and splash on the Note10+; the themed (monochrome) icon on an Android 13+ device.
     - System "Remove animations" on: pages, sheets, presses and menus don't animate; iOS swipe-back still works.
     - TalkBack through onboarding; maximum font size on Apps, Edit apps and the quick row.
     - On a Mac/iPhone: the iOS icon set, splash, Local Network explainer, reduce motion.
   - **Ask before any Power or Wake-on-LAN test**, because it turns the TV off or on.
2. Write and execute the Phase 9 (release preparation) plan from the master plan, including the Phase 9 carry-overs below. Stop before signing and store submission.

## Carry-over to Phase 9+
- **Phase 9:**
  - **From Phase 8 (gates before store copy or upload):**
    - Device rows DM-056/057 (Android backup and transfer), DM-060/061 (iOS restore and Quick Start; **DM-061 is a release issue if the DB travels**).
    - Mac rows DM-058/059 (Swift storage channel compiles, DB location) and DM-066 (Malay `ms.lproj` in the Xcode build).
    - The owner's Malay sign-off (DM-068), including "diendors" in `aboutTrademark`, "memaparkan iklan" in the iOS tracking string and `paywallFreeForever`.
    - Re-check the prodRelease merged manifest for the three backup attributes before upload.
  - **From Phase 8 (work):**
    - A full-page field-text sweep (helpers and errors on pages, not only dialogs and sheets) (P8-C15).
    - A restored iPhone carries `launch_count`, `att_preprompt_shown` and `onboarding_complete` (DM-060): decide whether any should reset with a fresh DB.
    - The startup trace and battery runs, then set a battery threshold; TalkBack/VoiceOver and Switch/Voice Access rows; DM-006/DM-010 captures.
    - Android 13 `localeConfig`.
    - Edge case: if the first start on a restored iPhone creates the DB and then fails, Try again sees `createdThisRun` false → empty Apps row until Reset. Clear the seeded flag when the DB is created.
    - `app_info.dart` uses `dart:io Platform`; switch to `defaultTargetPlatform`.
    - Run `tool/check.sh` / the Linux CI job (40 min timeout) on the PR.
  - **Later (conditional):** theater `ExcludeSemantics` (only if the device check calls for it); Apps banner collapse with the keyboard up (only if AdMob flags it); the predictive-back test's private class name (next Flutter bump); D-pad wedge depth below 160 dp (only if the device run shows mis-taps).
  - **From Phase 6, release script and build checks:**
    - `tool/release.ps1` must refuse a prod build unless all of these are present: `FIREBASE_ENABLED: true`, both RevenueCat keys, both banner ids, the prod Firebase config files and the AdMob app ids.
    - The iOS `check_admob_app_id.sh` Run Script.
    - The misplaced-`google-services.json` warning across flavors.
    - Crashlytics dSYM and mapping upload.
    - Podfile at 15.0, plus `$FirebaseAnalyticsWithoutAdIdSupport`.
  - **From Phase 6, store forms and policy:**
    - The owner decides whether to keep or remove the AdServices permissions.
    - The Data safety and App Privacy forms, including approximate location and performance data (see `store-release`).
    - The SKAdNetwork buyer list.
    - The App Store id for `appStoreListing`.
    - A privacy policy that names Firebase (including Installation IDs), AdMob/UMP and RevenueCat.
  - **Signing and placeholders:**
    - Release builds are debug-signed. Add `key.properties` signing before any store upload.
    - Replace the placeholder links and support address (decision #35).
  - **CLI hardening:** an atomic identity file, SIGINT handling, `cliKeyCodes` coverage, and the uncaught `StateError` in `hold`.
  - Record the protoc download URL and version in the gen scripts.
- **Drift opens lazily:** a real DB open failure surfaces in the first query, so repository callers must handle errors. Apps and Your TVs now show a retry state.

## Blocked / needs the owner

- **Real-device run:** the TV on, on the same Wi-Fi as the phone; read the pairing code to Claude.
- **Phase 6 real config** (the plan's "Needs the owner"):
  - **Firebase:** dev and prod projects, and their config files.
  - **AdMob:**
    - Apps, ad units and app ids.
    - In the UMP console, publish the **GDPR message before enabling Firebase in prod**.
    - **Don't** create the IDFA explainer message. Decision #41 corrects the plan on this.
    - Host `app-ads.txt`.
  - **RevenueCat:** project, entitlement, products, offering and keys.
  - **Stores:** Play and App Store products, and sandbox testers.
  - **To confirm:** prices; the style names Ocean, Ember and Midnight; that interstitials stay off.
- **Store listing details:**
  - Support email address, privacy-policy URL and terms URL. These are placeholders now and are needed before any store upload.
  - Should app tiles ever show real app icons? Default: no. Monograms stay, because third-party logos need permission.
  - The real ids of Malaysian apps (Astro GO, sooka, Tonton): run `adb shell pm list packages` on the TV during the device run.
- **Mac:**
  - Run `pod install` at iOS 15.0, then the iOS flavor builds (`flutter build ios --flavor dev|prod -t lib/main_<f>.dart --no-codesign`).
  - New pods since Phase 4:
    - wakelock_plus, screen_brightness_ios, package_info_plus, url_launcher_ios;
    - the Phase 6 Firebase, AdMob, ATT, RevenueCat, in_app_review and device_info_plus pods.
  - Check that:
    - iOS restores system brightness after Theater mode;
    - the empty `ADMOB_APP_ID_PROD` guard works;
    - `ensureInitialized` runs;
    - UMP works with test IDs.
- **Phase 8 owner items:** review every Malay string (`app/lib/app/l10n/app_ms.arb`, DM-068) before Malay store copy; on the Mac, build iOS and check the Swift storage channel and `ms.lproj` (DM-058/059/066); run the device matrix with Claude.
- **Apple entitlement:** the multicast entitlement (`com.apple.developer.networking.multicast`), for Wake-on-LAN on iOS.
- **Accounts:** an Apple Developer account and a Google Play Console account. A new personal Play account must run a closed test with **12 testers for 14 days** before production.
- **App name and bundle ID:** the placeholders are `Remotely for Android TV` and `com.digitallinked.atvremote`.
  - They **must be final before the first Play closed-test upload**, because a Play package name can never change.
  - That upload needs an upload keystore, earlier than Phase 9.
- **Optional:** delete the stale git-ignored golden `failures/` folders under `app/test/`.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).

## How to run things

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`.
- App: `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` from `app/`. Without the define file, every service stays off.
- Package tests: from `packages/atv_remote`, run `flutter test`, not `dart test` (see learnings).
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch|text|hold> <host> ...`.
