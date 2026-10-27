# Project status

_Last updated: 2026-10-27 by Claude (controller, subagent-driven run, Phase 5 merged)._

## Current phase

**Phase 6: Services & monetisation** (next; plan to be written from the master plan). Phases 0–5 are merged into `main`. The **real-device run on the owner's phone + TV is still open** — it is the exit criterion for Phases 3, 4 and 5 (needs the owner).

## Done

- **Phase 5 (apps, devices, settings, help):**
  - All Phase 5 strings, routes and stub screens in one task; `BannerSlot` (empty) only on `/apps` and the `/settings` hub; Settings button on the remote.
  - Bundled app catalogue (`apps_v1.json`, our own data, closed schema, 8 region default rows); shortcut and usage storage with one-time region seeding, Reset, recommendations and a phone-only usage tracker (never for the demo).
  - Apps screen (grid, search incl. catalogue, launch → back to remote), All apps tile pinned in the quick row; Edit apps (reorder, Undo, reset, add sheet with TV recommendations, custom shortcuts).
  - Your TVs + Edit TV (rename live, shared MAC field, remove without touching the client identity, pair again), "Manage TVs" in the switcher.
  - Settings hub, Appearance (theme, wallpaper colours, language), Remote layout (live preview), Remote behaviour (Phase 4 toggles); Help (FAQ + troubleshooting), About (version, licences incl. androidtvremote2), legal links and feedback email (placeholders).
  - Carry-overs closed: lastHost refresh, announced name kept, re-resolve before Pair again, manual→mDNS merge with pin, append-only hardening, monograms upper-case, MAC paste error.
  - Seam + banner + accessibility tests (`app/test/app/apps_devices_settings_flow_test.dart`, `phase5_accessibility_test.dart`). Decisions #27–#37.
- **Phase 4 (remote experience):** input path (`RemoteActions`: refusals, Smooth Press, repeat, stuck-key guard, haptics), touchpad/D-pad/numbers pager, quick-access row, bottom cluster, keyboard sheet, Power + Wake-on-LAN + MAC sheet, Keep Screen Awake, Theater Mode, layouts to 320 dp at 200% text. Decisions #20–#26.
- **Phase 3 (connect flow):** discovery (NSD + manual IP), pairing wizard with TOFU pin, `RemoteSession`/`TvRemoteSession`, session providers and `SessionSupervisor`, remote screen shell, demo mode, `WakeOnLanService`. Decisions #13–#19.
- **Phase 2 (app shell):** design tokens + theme, base components with goldens, ARB l10n, drift DB + `DeviceRepository`, secure `IdentityStore`, `SettingsStore`, go_router, `bootstrap`, dev/prod flavors.
- **Phase 1 (protocol library):** protobufs, framing, client identity + pairing secret, `FakeTvServer`, `PairingClient`, `RemoteClient`, `TvConnection`, Wake-on-LAN, discovery model, CLI.
- **Phase 0:** monorepo scaffold, lints, `tool/check.ps1`/`.sh`, CI.

## In progress

_Nothing._

## Next up

1. **Real-device run (owner + Claude)** — exit for Phases 3–5. Install the dev flavor on the Note10+ (`flutter run --flavor dev -t lib/main_dev.dart`), discover the TV, pair, then use every control and screen. Record answers in `learnings.md` → "Unverified protocol behaviour". Specifically: same key on 6467/6466 (decision #11); ping interval (decision #10); `_pickHost` gets IPv4; reconnect time after an IP change; hold feel and volume ramp; long OK; IME replace-field (`atv_cli text`); Search key on Google TV; Theater dim/wake; keep-awake; landscape; MY default row after clearing data; which shortcut/catalogue packages open; raw MediaTek current-app packages; remove a TV then re-pair; IP→mDNS merge without re-pairing; wallpaper colours on Android 12; mail/browser links; licences page; TalkBack Move up/down; maximum font size. **Ask before any Power / Wake-on-LAN test** (it turns the TV off/on).
2. Execute the Phase 6 plan `docs/superpowers/plans/2026-10-27-phase-6-services-monetisation.md` (11 tasks, rulings P6-R1..R15; order 6.1 → 6.11): Firebase Analytics/Crashlytics/Remote Config behind config-present checks, UMP consent + Privacy choices + ATT pre-prompt, RevenueCat Premium + paywall, AdMob banner filling `BannerSlot`, premium colour styles, review prompt, device_info_plus. Test IDs only — no real keys committed. **iOS deployment target rises to 15.0** (Firebase iOS SDK 13); startup order changes so Premium is known before ads (amends the app-services skill). The plan's "Needs the owner" lists the switch from test to real config.

## Carry-over to Phase 6
- Fill `BannerSlot` (only `/apps` and `/settings`; keep the 48 dp clearance and nothing within 48 dp of nav controls); add the Premium and Privacy-choices rows to the Settings hub.
- `app/test/platform/android_queries_test.dart` asserts exactly 4 `<uses-permission>` — AdMob's `AD_ID` will break it; assert the queries only or a superset.
- Keep the FAQ privacy answer (`faqPrivacyA`, "stays on this phone") true once analytics and Crashlytics land (and see the Auto Backup item in Phase 8).
- `RemoteActions._report` swallows listener errors silently — add a debug-only log (no text/TV data) when analytics attaches to `remoteActionListenerProvider`. `LoggingCrashReporter` logs raw errors — the Crashlytics reporter must scrub pairing codes/keys. `StartupGate` build has no timeout.
- Feedback footer's `osVersion` is the kernel string on Android — consider device_info_plus (pin decision).

## Carry-over to Phase 7+
- Phase 7 (polish): Settings entry on the no-TV screen and discovery (Help/privacy/feedback unreachable before pairing); name-prefix-first catalogue search; now-on-TV dot ring on custom colours; Apps empty-state extra scroll + `keyboardDismissBehavior`; Edit apps name column at 200% text (stacked layout); About single watch / header semantics / no pop-in; heavy haptic fires before `needsMac`/`cannotWake`; quick-tile names ellipsize at 200%; touchpad reach not updated from the up position; onboarding storage write error leaves "Get started" dead.
- Phase 8 (test/accessibility hardening):
  - **Decide Android `allowBackup` / data-extraction rules** (Auto Backup copies the DB — TV names, IPs, MACs, pins, usage — off the phone; secure-storage identity restore risk). Must land before Phase 9.
  - Phase 5: `shortcutsProvider` / `savedDevicesProvider` keep Riverpod's default retry, so a drift `SqliteException` spins ~38 s before the new error states show — `retry: noRetry` or show the error while retrying; a merge that finishes after leaving discovery with a **null** active target leaves the default session on the deleted `manual:` row until the next rebuild (follow it when `ref.exists(remoteSessionProvider)` and its target is the manual name); 320 dp app-bar 8 dp gap assertion; terse ARB descriptions; clear a stale `wolMac` after an IP-only merge or identity change; merge transaction rollback test; a throwing HostResolver should fall back to the saved host; `watchMostUsed` limit before system filter + usage pruning; duplicated status-strip/snackbar logic (Apps vs Remote); spinner semantics labels; drag-handle extra focus stop; PopupMenuButton tooltip; focus/announce after a move; Edit TV removal-guard test (needs an observable page transition).
  - Phase 4 tests: `KeyCodes.named` source-scan + `cliKeyCodes`↔`named`; `serverPublicKeySha256` at `RemoteReady`; second TV's first volume is null; provider-level background-seeded grace; platform haptics; transparent-key ripple; edge-glow + same-touch stale glow; D-pad clamp at 100×100, wedge-drag/hold-stays, `dpad_pressed_up_light` golden; Power drag-off cancel; a11y guidelines for the disconnected state, colour/media rows and theater palette; non-linear `TextScaler` across the layout matrix.
  - Phase 4 code: D-pad `_holdStart` should use `_downRegion`; D-pad explicit `OrdinalSortKey`; split layout `EdgeInsets.only` → `EdgeInsetsDirectional` (RTL); narrow screen-service catches; `ExcludeSemantics` while theater-dimmed (after a Voice/Switch Access check).
  - From Phase 3: NSD `stop()` hang if never listened + no `onCancel`; real-time negative waits; coverage gaps from Tasks 3.2–3.6; 200% TV name ellipsis; 48/56 dp + dark state tests; demo strip tappable under a modal; live regions; unawaited cancel/stop errors; pairing 320 dp / dark failure tests; Phase 2 a11y items.
- Phase 9: release is debug-signed — add `key.properties` signing before any store upload. Replace placeholder links/support address (decision #35). CLI hardening (atomic identity file, SIGINT, `cliKeyCodes` coverage, `hold` uncaught `StateError`). Record the protoc download URL/version in the gen scripts.
- drift opens lazily: a real DB open failure surfaces in the first query; repository callers must handle errors (Apps and Your TVs now show a retry state).

## Blocked / needs the owner

- Real-device run (TV on, same Wi-Fi; read the pairing code to Claude).
- Support email address, privacy-policy URL and terms URL (placeholders now; needed before any store upload).
- Should app tiles ever show real app icons? Default: no (monograms; third-party logos need permission).
- Real ids of Malaysian apps (Astro GO, sooka, Tonton): `adb shell pm list packages` on the TV during the device run.
- Mac: `pod install` and iOS flavor builds (`flutter build ios --flavor dev|prod -t lib/main_<f>.dart --no-codesign`) — new pods since Phase 4: wakelock_plus, screen_brightness_ios, package_info_plus, url_launcher_ios; check iOS restores system brightness after Theater mode.
- Apple's multicast entitlement (`com.apple.developer.networking.multicast`) for Wake-on-LAN on iOS.
- Apple Developer account and Google Play Console account. A new personal Play account must run a closed test with **12 testers for 14 days** before production.
- App name and bundle ID (placeholder: `Remotely for Android TV`, `com.digitallinked.atvremote`). **Must be final before the first Play closed-test upload** (a Play package name can never change), and that upload needs an upload keystore earlier than Phase 9.
- Optional: delete stale git-ignored golden `failures/` folders under `app/test/`.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).

## How to run things

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`.
- App: `flutter run --flavor dev -t lib/main_dev.dart` from `app/`.
- Package tests: from `packages/atv_remote`, `flutter test` (not `dart test`; see learnings).
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch|text|hold> <host> ...`.
