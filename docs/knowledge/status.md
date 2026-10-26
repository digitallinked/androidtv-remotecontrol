# Project status

_Last updated: 2026-10-27 by Claude (controller, subagent-driven run, Phase 4 merged)._

## Current phase

**Phase 5: Apps, devices, settings, help** (next; plan to be written from the master plan). Phases 0–4 are merged into `main`. The **real-device run on the owner's phone + TV is still open** — it is the exit criterion for Phases 3 and 4 (needs the owner).

## Done

- **Phase 4 (remote experience):**
  - Library: `KeyCodes.enter`/`delete`, `KeyCodes.named`, `isSupportedKeyCode`; CLI `text` and `hold` commands for checking IME and long-press behaviour on the real TV.
  - Input path: `KeyInput`/`RemoteInput` → `RemoteActions` (refusals, Smooth Press, 120 ms repeat, 15 s stuck-key guard, haptics, action listener); test fakes aligned with the real clients.
  - Pad pager with Touchpad (steps, tap, hold, two-finger back), D-pad (wedge hit regions, holds) and Numbers; quick-access row (starter apps as letter tiles, colour keys, media keys, none); bottom cluster (volume/channel rockers, Mute, Keyboard, Back, Home); portrait and split layouts that fit 320 dp at 200% text.
  - Keyboard sheet (debounced live typing, Enter, Clear, auto-open on the TV's IME request).
  - Power key: tap hint, 600 ms hold → power key or Wake-on-LAN + reconnect; MAC setup sheet; iOS Wake-on-LAN gated off.
  - Keep Screen Awake and Theater Mode.
  - Carry-overs closed: supervisor seeded from visibility, live values cleared on drop, WoL limited broadcast first, previous remote kept during a TV switch, screen-reader-friendly holds, demo preview tests.
  - End-to-end tests (`app/test/app/remote_flow_test.dart`) and accessibility guideline tests. Decisions #20–#26.
- **Phase 3 (connect flow):** discovery (NSD + manual IP), pairing wizard with TOFU pin, `RemoteSession`/`TvRemoteSession`, session providers and `SessionSupervisor`, remote screen shell, demo mode, `WakeOnLanService`, connect-flow seam tests. Decisions #13–#19.
- **Phase 2 (app shell):** design tokens + theme, base components with goldens, ARB l10n, drift DB + `DeviceRepository`, secure `IdentityStore`, `SettingsStore`, go_router, `bootstrap`, dev/prod flavors.
- **Phase 1 (protocol library):** protobufs, framing, client identity + pairing secret, `FakeTvServer`, `PairingClient`, `RemoteClient`, `TvConnection`, Wake-on-LAN, discovery model, CLI.
- **Phase 0:** monorepo scaffold, lints, `tool/check.ps1`/`.sh`, CI.

## In progress

_Nothing._

## Next up

1. **Real-device run (owner + Claude)** — exit for Phases 3 and 4. Install the dev flavor on the Note10+ (`flutter run --flavor dev -t lib/main_dev.dart`), discover the TV, pair, then use every control. Record answers in `learnings.md` → "Unverified protocol behaviour". Specifically: same key on 6467/6466 (decision #11); ping interval (decision #10); `_pickHost` gets IPv4; reconnect time after an IP change; hold feel and volume ramp; long OK; IME replace-field (`atv_cli text`); Search key on Google TV; which starter apps open; Theater dim/wake; keep-awake; landscape. **Ask before any Power test** (it turns the TV off); Wake-on-LAN needs the TV's Wi-Fi/Ethernet MAC.
2. Execute the Phase 5 plan `docs/superpowers/plans/2026-10-27-phase-5-apps-devices-settings.md` (10 tasks, rulings P5-R1..R14): 5.1 first alone (all strings, routes, stubs, `BannerSlot`); 5.2/5.3/5.8 parallel-safe; 5.4 → 5.5 → 5.6 → 5.7 sequential (each edits `remote_screen.dart`); 5.9 parallel-safe with that chain; 5.10 last. Owner questions in the plan: support email + privacy/terms URLs (placeholders until then); real app icons (default: monograms, no third-party logos).

## Carry-over to Phase 5
- Settings pages for the Phase 4 toggles (haptics, Smooth Press, keep awake, theater, keyboard auto-open, quick-access variant). Settings UI was deferred by P4-R18.
- Replace `quickAccessAppsProvider`'s body with the catalogue; upper-case monograms for custom entries.
- Edit-device screen: reuse `parseMac` and the MAC field; an over-long pasted MAC is currently dropped silently.
- If the device run shows `replaceField` doesn't work, flip `kImeTextMode` to `appendOnly` and add grapheme tests (ZWJ, combining marks); appendOnly over-deletes after a partial failure.
- From Phase 3: update `lastHost` when a paired TV is tapped in discovery; `toDiscoveredTv()` passes the nickname as `displayName`; re-resolve the host before "Pair again"; merge `manual:<ip>` entries with a later mDNS entry.

## Carry-over to Phase 6+
- Phase 6: `RemoteActions._report` swallows listener errors silently — add a debug-only log (no text/TV data) when analytics attaches to `remoteActionListenerProvider`. `LoggingCrashReporter` logs raw errors — the Crashlytics reporter must scrub pairing codes/keys. `StartupGate` build has no timeout.
- Phase 7 (polish): heavy haptic fires before `needsMac`/`cannotWake`; app names ellipsize at 200% text in quick tiles; touchpad reach not updated from the up position; onboarding storage write error leaves "Get started" dead.
- Phase 8 (test/accessibility hardening):
  - Phase 4 tests: `KeyCodes.named` source-scan + `cliKeyCodes`↔`named`; `serverPublicKeySha256` at `RemoteReady`; second TV's first volume is null; provider-level background-seeded grace; platform haptics; transparent-key ripple; edge-glow + same-touch stale glow; D-pad clamp at 100×100, wedge-drag/hold-stays, `dpad_pressed_up_light` golden; Power drag-off cancel; a11y guidelines for the disconnected state, colour/media rows and theater palette; non-linear `TextScaler` across the layout matrix.
  - Phase 4 code: D-pad `_holdStart` should use the pointer-down region (`_downRegion`) like taps do; D-pad explicit `OrdinalSortKey`; split layout uses `EdgeInsets.only` (wrong in RTL → `EdgeInsetsDirectional`); narrow screen-service catches to `PlatformException`/`MissingPluginException`; `ExcludeSemantics` while theater-dimmed (after a Voice Access / Switch Access device check).
  - From Phase 3: NSD `stop()` hang if never listened + no `onCancel`; real-time negative waits; coverage gaps from Tasks 3.2–3.6; 200% TV name ellipsis; 48/56 dp + dark state tests; demo strip tappable under a modal; live regions; unawaited cancel/stop errors; pairing 320 dp / dark failure tests; Phase 2 a11y items.
- Phase 9: release is debug-signed — add `key.properties` signing before any store upload. CLI hardening (atomic identity file, SIGINT, `cliKeyCodes` coverage, `hold` uncaught `StateError`). Record the protoc download URL/version in the gen scripts.
- drift opens lazily: a real DB open failure surfaces in the first query; repository callers must handle errors.

## Blocked / needs the owner

- Real-device run (TV on, same Wi-Fi; read the pairing code to Claude).
- Mac: `pod install` and iOS flavor builds (`flutter build ios --flavor dev|prod -t lib/main_<f>.dart --no-codesign`) — Phase 4 added wakelock_plus, screen_brightness_ios and package_info_plus pods; check that iOS restores system brightness after Theater mode.
- Apple's multicast entitlement (`com.apple.developer.networking.multicast`) for Wake-on-LAN on iOS.
- Apple Developer account and Google Play Console account. A new personal Play account must run a closed test with **12 testers for 14 days** before production.
- App name and bundle ID (placeholder: `Remotely for Android TV`, `com.digitallinked.atvremote`). **Must be final before the first Play closed-test upload** (a Play package name can never change), and that upload needs an upload keystore earlier than Phase 9.
- Privacy policy and terms URLs.
- Optional: delete stale git-ignored golden `failures/` folders under `app/test/`.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).

## How to run things

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`.
- App: `flutter run --flavor dev -t lib/main_dev.dart` from `app/`.
- Package tests: from `packages/atv_remote`, `flutter test` (not `dart test`; see learnings).
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch|text|hold> <host> ...`.
