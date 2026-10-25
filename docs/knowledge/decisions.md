# Decisions log

Newest first. Each entry: date, decision, why, and what would make us revisit it. Never delete an entry; mark it `SUPERSEDED by #N` instead.

---

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
