# Project status

_Last updated: 2026-10-29 by Claude (controller, subagent-driven run, Phase 6 merged)._

## Current phase

**Phase 7: Polish** (next; plan to be written from the master plan). Phases 0–6 are merged into `main`.

The **real-device run on the owner's phone and TV is still open**. It is the exit criterion for Phases 3–6. Phase 6 adds Firebase DebugView, ads with consent, and the RevenueCat sandbox (needs the owner and real test config).

## Done

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

1. **Real-device run (owner + Claude).** This is the exit for Phases 3–6.
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
   - **Ask before any Power or Wake-on-LAN test**, because it turns the TV off or on.
2. Write and execute the Phase 7 (polish) plan from the master plan, including the Phase 7 carry-overs below.

## Carry-over to Phase 7+
- **Phase 7 (polish):**
  - **From Phase 6:**
    - UpdateGate may flash the remote while `appInfo` loads.
    - A ruling, against P6-R8, on skipping the UMP form for a user who is already Premium (cached). "Ad privacy choices" stays reachable either way.
  - **Navigation and reachability:**
    - A Settings entry on the no-TV screen and in discovery. Today Help, privacy and feedback can't be reached before pairing (P6-R15).
  - **Apps and catalogue:**
    - Name-prefix-first catalogue search.
    - The now-on-TV dot ring on custom colours.
    - The Apps empty state needs extra scroll and `keyboardDismissBehavior`.
  - **Large text (200%):**
    - The Edit apps name column needs a stacked layout.
    - Quick-tile names ellipsize.
  - **About page:** a single watch, header semantics, no pop-in.
  - **Remote behaviour:**
    - The heavy haptic fires before `needsMac`/`cannotWake`.
    - Touchpad reach isn't updated from the up position.
  - **Onboarding:** a storage write error leaves "Get started" dead.
- Phase 8 (test/accessibility hardening):
  - **RELEASE BLOCKER: decide the Android `allowBackup` / data-extraction rules.**
    - Auto Backup copies the DB (TV names, IPs, MACs, pins, usage) off the phone, and restoring the secure-storage identity is a risk.
    - The Privacy page's "never leave this phone" (`privacyIntro`) and `faqPrivacyA` are true only once the DB and prefs are excluded.
    - Must land before Phase 9.
  - **From Phase 6:**
    - **Localisation and accessibility:**
      - `InfoPlist.strings` (Malay) for the ATT and local-network purpose strings.
      - A live-region announce on the update gate.
      - Pre-prompt dialog insets at 320 dp / 200% text: the body is about 2000 dp tall in a 192 dp-wide dialog.
      - Fit checks bounded by the scroll viewport. Tests read the pre-prompt body from `AppLocalizations`. The privacy fit test also covers the switch rows.
      - P6-C10: audit any accent-coloured body text on `surfaceRaised`, across all styles.
    - **Crash scrubbing:**
      - Seed the scrub terms synchronously (a one-shot `DeviceRepository` read).
      - Feed discovered but unsaved TV names to the scrubber terms.
    - **Tests:**
      - Test the real App's dynamic-scheme branch.
      - Widen only the setup budgets around TLS in `pairing_client_test`.
    - **Refactor:** one shared "connection trouble in the last 60 s" provider, replacing the copies in `Interstitials`, `ReviewPrompter` and `analyticsHooks`.
    - **Pending the device run:** collapse the Apps banner while the keyboard is up, if AdMob flags covered impressions.
  - **From Phase 5:**
    - **Providers:**
      - `shortcutsProvider` / `savedDevicesProvider` keep Riverpod's default retry, so a drift `SqliteException` spins for about 38 s before the new error states show. Use `retry: noRetry`, or show the error while retrying.
      - A merge that finishes after leaving discovery with a **null** active target leaves the default session on the deleted `manual:` row until the next rebuild. Follow it when `ref.exists(remoteSessionProvider)` and its target is the manual name.
      - A throwing HostResolver should fall back to the saved host.
    - **Storage:**
      - Clear a stale `wolMac` after an IP-only merge or an identity change.
      - A merge-transaction rollback test.
      - `watchMostUsed` applies its limit before the system filter; add usage pruning.
    - **Layout and duplication:**
      - The 320 dp app-bar 8 dp gap assertion.
      - Terse ARB descriptions.
      - Duplicated status-strip and snackbar logic (Apps vs Remote).
    - **Accessibility:**
      - Spinner semantics labels; the drag handle's extra focus stop; the PopupMenuButton tooltip.
      - Focus and announce after a move.
    - **Tests:** the Edit TV removal-guard test (needs an observable page transition).
  - **Phase 4 tests:**
    - **Key codes and session:**
      - A `KeyCodes.named` source scan, and `cliKeyCodes`↔`named`.
      - `serverPublicKeySha256` at `RemoteReady`.
      - The second TV's first volume is null.
      - Provider-level background-seeded grace.
    - **Input feel:** platform haptics; the transparent-key ripple; edge glow and same-touch stale glow.
    - **D-pad and Power:**
      - D-pad clamp at 100×100, wedge drag and hold-stays, the `dpad_pressed_up_light` golden.
      - Power drag-off cancel.
    - **Accessibility and text scaling:**
      - A11y guidelines for the disconnected state, the colour/media rows and the theater palette.
      - Non-linear `TextScaler` across the layout matrix.
  - **Phase 4 code:**
    - The D-pad's `_holdStart` should use `_downRegion`; give the D-pad an explicit `OrdinalSortKey`.
    - The split layout should use `EdgeInsetsDirectional` instead of `EdgeInsets.only` (RTL).
    - Narrow the screen-service catches.
    - `ExcludeSemantics` while theater-dimmed, after a Voice/Switch Access check.
  - **From Phase 3:**
    - **NSD and async:**
      - NSD `stop()` hangs if never listened, and has no `onCancel`.
      - Real-time negative waits.
      - Unawaited cancel/stop errors.
    - **Coverage gaps from Tasks 3.2–3.6:**
      - 200% TV name ellipsis.
      - 48/56 dp and dark-state tests.
      - Pairing failure tests at 320 dp and in dark mode.
    - **Accessibility:**
      - The demo strip is tappable under a modal.
      - Live regions.
      - Phase 2 a11y items.
- **Phase 9:**
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
