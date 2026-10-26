# Decisions log

Newest first. Each entry: date, decision, why, and what would make us revisit it. Never delete an entry; mark it `SUPERSEDED by #N` instead.

---

### #19 — 2026-10-26 — Phase 3 package pins
- nsd 5.0.1 (nsd_android 2.2.0 owns the Android multicast lock, so no native code), connectivity_plus 7.3.2, network_info_plus 8.2.2, fake_async 1.3.3, clock 1.1.2.
- **Revisit:** with the Flutter upgrade in decision #8.

### #18 — 2026-10-26 — Pairing UX and client identity
- Client name/model `Remotely`, `DeviceInfo` vendor `digitallinked`; `kAppVersion` is kept equal to the pubspec version.
- The code is normalised (trim, strip spaces/dashes, upper-case) in both the field formatter and the controller. Paste accepts exactly 6 hex characters after stripping whitespace and dashes.
- The 60 s code countdown runs from a wall-clock deadline (`clock.now()`), capped at 60 s, so a suspended iOS timer can't show stale seconds.
- Only the code glyphs are clamped to 1.3× text scale (six large glyphs can't fit 320 dp at 200%); label and error text scale fully.
- The identity read is retried once after 200 ms before a "can't load identity" state.
- Leaving mid-save: the pin is always saved (the TV now trusts us), but the session is activated only if the user stayed or the active target is none/this TV.

### #17 — 2026-10-26 — Wake-on-LAN targets
- Send to `255.255.255.255`, the Wi-Fi subnet broadcast (`network_info_plus` `getWifiBroadcast`), and the /24 of the TV's last IPv4. Each target is tried independently; the first error is rethrown only if every target failed; a 0-byte send counts as a failure.
- UI (power button) is Phase 4. iOS needs Apple's multicast entitlement.

### #16 — 2026-10-26 — Discovery and manual IP
- Manual TVs are `manual:<ipv4>` on 6466 and are never re-resolved; merging with a later mDNS entry is Phase 5.
- Host re-resolution gives up after 4 s, inside the 5 s connect budget.
- Discovery keeps browsing under the pushed pairing route (short-lived, stops on `go('/remote')`; accepted).
- Troubleshooting is an in-app sheet shared by discovery and pairing.

### #15 — 2026-10-26 — Session lifecycle
- Background grace 60 s, then disconnect. On return, force `disconnect()` + `connect()` if the grace closed the socket or the wall clock shows ≥ 60 s.
- Resume/network nudges are debounced (trailing 500 ms) and forwarded only in the foreground.
- The first connectivity event is a baseline; duplicates and all-`none` are ignored; the baseline is re-read on foreground (iOS drops background events).
- Reconnect action: `connect()` from `disconnected`, otherwise `notifyNetworkChanged()` (re-resolves the host).

### #14 — 2026-10-26 — TOFU pin rules (extends #11)
- Pin = lower-case hex of `PairingClient.serverPublicKeySha256`. No pin → `needsPairing`, no socket opened.
- `serverKeyChanged` clears the pin **only if it still equals the distrusted pin** (a just-re-paired pin is never wiped by a late old session). `certificateRejected` keeps the pin; re-pairing overwrites it.
- Pairing upserts the device before activating it; activation always rebuilds the session (ruling P3-R3). Re-selecting the TV that is already active does not rebuild.

### #13 — 2026-10-26 — Phase 3 session architecture
- The UI talks only to `RemoteSession`. `TvRemoteSession` wraps the library's `TvConnection`; `DemoRemoteSession` implements the same interface and opens no sockets. Widgets check `isDemo` only for the demo badge, the TV preview card and the "Demo TV" name.
- `ActiveTarget` holds `DeviceTarget(serviceName)` or `DemoTarget` (never persisted). `remoteSessionProvider` builds the session and its `SessionSupervisor`; providers whose errors the UI must show use `retry: noRetry`.
- App tests use `implements`-fakes (`FakeRemoteClient`, `FakePairingClient`, `FakeTvDiscovery`); the library's `FakeTvServer` stays unexported.
- **Revisit:** if more session kinds appear (core/session currently imports features/demo).

### #12 — 2026-10-25 — Phase 2 app-shell choices
- **Models:** no freezed (toolchain conflict); drift data classes + hand-written `AppSettings`. `SavedDevice.serverKeyPin` is nullable (null = no trusted key → pair).
- **Start route:** first run → onboarding placeholder → `/discover`; a saved TV → `/remote`. The route is resolved before `runApp` through one `ProviderContainer` (single database).
- **Theme:** dynamic colour is a separate on/off setting (default off). Contrast fixes: `dangerText` token (light `#B83A3A`), dark text on the accent is `#0F1115`.
- **Startup failure:** a themed fallback screen with an accessible "Try again"; it is the only screen with hard-coded English (it must work when localisation fails).
- **Flavors:** dev `com.digitallinked.atvremote.dev` "Remotely Dev", prod `com.digitallinked.atvremote` "Remotely for Android TV"; run with `flutter run --flavor dev -t lib/main_dev.dart`. Release is still debug-signed until Phase 9.
- **Revisit:** if the toolchain moves to a Dart version that resolves freezed + newer drift.

### #11 — 2026-10-25 — TOFU: pin the TV key at pairing time
- `PairingClient.serverPublicKeySha256` (SHA-256 over the TV cert's RSA modulus ‖ exponent) is stored as `SavedDevice.serverKeyPin` right after pairing. `TvConnection.verifyServerKey` checks it before reporting `connected`; on a mismatch → `needsPairing` with `serverKeyChanged`.
- **Why:** the pairing code is a hash over the TV's modulus, so the key seen during pairing is the only authenticated one. Hashing the key (not the whole cert) survives cert re-issuance with the same key.
- **Revisit:** if a real TV presents different keys on 6467 and 6466.

### #10 — 2026-10-25 — Idle timeout 15 s until measured
- `RemoteClient.idleTimeout` = 15 s for now. After the real-TV smoke test measures the ping interval, set it to ~2 intervals + margin, aiming for ≤ 10 s detection of a TV that vanished.
- **Why:** shorter timeouts risk false disconnects if the TV pings rarely; longer ones lose key presses after a power loss.

### #9 — 2026-10-25 — `TvConnectionState`, not `ConnectionState`
- Renamed to avoid clashing with Flutter's `ConnectionState` (imported by every widget file).

### #8 — 2026-10-25 — Pin Flutter 3.44.1 stable / Dart 3.12.1
- **Why:** reproducible builds locally and in CI (`.github/workflows/ci.yml` pins `flutter-version: 3.44.1`). Lints are `very_good_analysis` 10.3.0, the newest release that supports Dart 3.12 (11.x needs Dart 3.13). Protocol-package tests run via `flutter test` because `dart test` cannot resolve a workspace that contains a Flutter member.
- **Revisit:** when a Flutter or plugin upgrade is needed; bump CI, `environment.sdk` in the three pubspecs and `very_good_analysis` together.

### #7 — 2026-10-25 — Voice search ships after v1.0
- **Why:** the voice part of the protocol is the least documented; v1 should ship on solid features. The mic button stays hidden until it works.
- **Revisit:** once a voice spike works on the test TV.

### #6 — 2026-10-25 — Monetisation: ads + premium that removes them
- **Model:** free with an adaptive banner **only at the bottom of the Apps and Settings screens**. No ads on the remote, pairing, discovery, onboarding or paywall screens, and nothing within 48 dp of navigation controls. Interstitials are off by default (Remote Config). Premium (RevenueCat) removes ads and unlocks premium themes. **Free users get unlimited TVs and every remote feature**: we don't paywall core function.
- **Why:** proven by the competitor. Users complained about intrusive placement, not ads as such.
- **Revisit:** if conversion is below 1% after 60 days.

### #5 — 2026-10-25 — Backend = managed services only
- Firebase (Analytics, Crashlytics, Remote Config), RevenueCat and AdMob. No custom server for v1.
- **Why:** the remote talks to the TV directly over the LAN; a server adds cost and privacy burden without adding user value.

### #4 — 2026-10-25 — State management: Riverpod 3 with code generation; routing: go_router
- **Why:** testable, explicit dependencies, good async support for connection state streams.

### #3 — 2026-10-25 — Protocol in a separate pure-Dart package `packages/atv_remote`
- **Why:** unit-testable without Flutter, can be fuzzed against a fake TV server, keeps UI free of socket code.

### #2 — 2026-10-25 — Flutter for Android + iOS
- **Why:** one codebase. The protocol is plain TLS + protobuf, so it works from iOS too. The competitor proves Flutter is good enough here.

### #1 — 2026-10-25 — Target only Android TV / Google TV (Android TV Remote Service v2)
- Samsung (Tizen), LG (webOS), Roku and Fire TV are out of scope for v1.
