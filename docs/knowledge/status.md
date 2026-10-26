# Project status

_Last updated: 2026-10-26 by Claude (controller, subagent-driven run, Phase 3 merged)._

## Current phase

**Phase 4: Full remote** (next; plan to be written from the master plan). Phases 0–3 are merged into `main`. The **Phase 3 exit criterion — a real-device run on the owner's phone + TV — is still open** (needs the owner); the library smoke test is part of it.

## Done

- **Phase 3 (connect flow):**
  - Library: `TvConnection.disconnect()`, public `host`, generation re-check after `verifyServerKey`, stale re-resolve can't overwrite `host`; Wake-on-LAN tries every target.
  - NSD discovery (`NsdTvDiscovery`), host resolver, manual IP (`manual:<ip>`), iOS Bonjour + local-network keys.
  - `RemoteSession` / `TvRemoteSession` (TOFU pin check, conditional pin clear), session providers (`ActiveTarget`, `remoteSessionProvider`, state providers with `noRetry`), `SessionSupervisor` (60 s grace, 500 ms debounce, iOS resync).
  - Remote screen (status pill with Pair again / Reconnect, device switcher, basic controls fitting 320 dp, identity-changed dialog).
  - Demo mode (simulated TV, badge, TV preview) from onboarding and discovery.
  - Discovery screen (live list, manual IP sheet, legacy-service help, troubleshooting sheet, Try demo).
  - Pairing wizard (code field, paste, deadline countdown, failure states, pin saved before activation).
  - `WakeOnLanService` (limited + subnet + /24 broadcast); UI in Phase 4.
  - End-to-end seam tests in `app/test/app/connect_flow_test.dart`. Decisions #13–#19.
- **Phase 2 (app shell):** design tokens + theme (light/dark/dynamic, contrast-tested); `AppKeyButton`, `Rocker`, `StatusPill`, `AppDialog`, `AppSheet` with golden tests; English ARB l10n; drift DB (`devices`, `shortcuts`, `app_usage`) + `DeviceRepository`; secure `IdentityStore`; `SettingsStore`; Riverpod providers + `SettingsController`; go_router with start-route logic; `bootstrap` with error handlers, startup steps and a fallback screen; dev/prod flavors; release network permissions.
- **Phase 1 (protocol library):** protobufs, varint framing, client identity + pairing secret, `FakeTvServer`, `PairingClient`, `RemoteClient` (ping echo, 15 s idle timeout), `TvConnection` state machine, Wake-on-LAN, discovery model, public API barrel, CLI. Final review fixes incl. TOFU hooks.
- **Phase 0:** monorepo scaffold, lints, `tool/check.ps1`/`.sh`, CI.

## In progress

_Nothing._

## Next up

1. **Real-device run (owner + Claude)** — Phase 3 exit. Install the dev flavor on the Note10+, discover the TV, pair, use the remote, background >60 s and return, toggle Wi-Fi. Also record in `learnings.md`: does the TV present the same key on 6467 and 6466 (decision #11); the TV's ping interval (decision #10 → set `RemoteClient.idleTimeout`); does `_pickHost` get an IPv4 on the Note10+; time to reconnect after a DHCP/IP change. Use the checklist in `learnings.md` → "Unverified protocol behaviour".
2. Execute the Phase 4 plan `docs/superpowers/plans/2026-10-26-phase-4-remote-experience.md` (12 tasks, rulings P4-R1..R20): 4.1 first alone; 4.2–4.8 parallel-safe (disjoint files); 4.9–4.12 sequential (all edit `remote_screen.dart`). Every carry-over below is mapped to a task (4.1 fakes, 4.2 supervisor/live values/WoL timing, 4.4 key button, 4.9 keep scaffold, 4.10 MAC source, 4.12 demo preview tests).

## Carry-over to Phase 4
- `SessionSupervisor` assumes foreground at construction; seed it from the current visibility (a session activated while backgrounded connects without a grace timer).
- Keep the previous remote scaffold while the session reloads on a TV switch (the spinner currently replaces it; dependents show stale values with `isLoading`).
- Volume / power / current-app values are never reset across reconnects; reset or replay them when the UI shows them.
- Align test fakes with the real classes before `RemoteActions` (serverPublicKeySha256 before ready, push before ready, connect-after-close error type, unknown keycode).
- Wake-on-LAN: send `255.255.255.255` immediately and the others after the 2 s lookup; test the OSError/sync-throw lookup and the provider; **nothing fills `SavedDevice.wolMac` yet** — the power button needs a MAC source.
- Demo TV preview states (holding/released/opened/typed/screenOff) need tests once those buttons exist.
- `AppKeyButton` (from Phase 2): dispose calls `onLongPressEnd`; semantic long-press fires start+end back to back (TalkBack hold keys); rocker keys and pill share `surfaceRaised`.

## Carry-over to Phase 5
- Tapping a paired TV in discovery connects to the stored `lastHost`, not the freshly discovered host (slow recovery after an IP change); update `lastHost`.
- `toDiscoveredTv()` passes the nickname as `displayName`, so re-pairing could overwrite the announced name once rename exists.
- Re-resolve the host before "Pair again" (an mDNS TV whose IP changed shows "Can't reach").
- Merge `manual:<ip>` entries with a later mDNS entry for the same TV.

## Carry-over to Phase 6+
- Phase 6: `LoggingCrashReporter` logs raw errors — the Crashlytics reporter must scrub pairing codes/keys. `StartupGate` build has no timeout.
- Phase 7: onboarding storage write error leaves "Get started" dead.
- Phase 8 (test/accessibility hardening): NSD `stop()` hang if never listened + no `onCancel`; real-time negative waits; coverage gaps from Tasks 3.2–3.6; 200% text TV name ellipsis; 48/56 dp + dark state tests; demo strip tappable under a modal; live regions (discovery results, demo preview); unawaited cancel/stop errors; pairing 320 dp / dark failure tests; Phase 2 a11y items (`AppDialog` route label, semantic headers, reduce-motion ripple, `FittedBox` shrinking labels).
- Phase 9: release is debug-signed — add `key.properties` signing before any store upload. CLI hardening (atomic identity file, SIGINT, `cliKeyCodes` coverage) before sharing the CLI. Record the protoc download URL/version in the gen scripts.
- drift opens lazily: a real DB open failure surfaces in the first query; repository callers must handle errors.
- An identity that can't be loaded surfaces as `networkError` in the library; the app shows "can't load identity" after one retry.

## Blocked / needs the owner

- Real-device run (TV on, same Wi-Fi; read the pairing code to Claude).
- Mac: build iOS flavors (`flutter build ios --flavor dev|prod -t lib/main_<f>.dart --no-codesign`); request Apple's multicast entitlement (`com.apple.developer.networking.multicast`) for Wake-on-LAN.
- Apple Developer account and Google Play Console account. A new personal Play account must run a closed test with **12 testers for 14 days** before production.
- App name and bundle ID (placeholder: `Remotely for Android TV`, `com.digitallinked.atvremote`). **Must be final before the first Play closed-test upload** (the master plan starts the 14-day test after Phase 4; a Play package name can never change), and that upload needs an upload keystore earlier than Phase 9.
- Privacy policy and terms URLs.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).

## How to run things

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`.
- App: `flutter run --flavor dev -t lib/main_dev.dart` from `app/`.
- Package tests: from `packages/atv_remote`, `flutter test` (not `dart test`; see learnings).
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch> <host> ...`.
