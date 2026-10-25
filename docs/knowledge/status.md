# Project status

_Last updated: 2026-10-25 by Claude (controller, subagent-driven run of Phase 0–1)._

## Current phase

**Phase 1: Protocol library.** All tasks are implemented and reviewed on branch `feat/phase-0-1-protocol` (not merged yet). The **real-TV smoke test** is pending (needs the owner).

## Done

- Task 0.1: monorepo scaffold (Dart pub workspace: `app/` + `packages/atv_remote/`), lints, `tool/check.ps1`/`.sh`, CI.
- Task 1.1: protobufs from androidtvremote2, generated Dart committed (`tool/gen_proto.ps1`/`.sh`).
- Task 1.2: varint framing codec.
- Task 1.3: client identity (RSA-2048 self-signed cert) and pairing secret, cross-checked by `tool/pairing_vector.py`.
- Task 1.4: `FakeTvServer` test harness (`packages/atv_remote/test/fake_tv/`).
- Task 1.5: `PairingClient` (port 6467).
- Task 1.6: `RemoteClient` (port 6466): ping echo, 15 s idle timeout, events, IME text, app links.
- Task 1.7: `TvConnection` state machine: backoff, reconnect, resume/network-change, host re-resolution.
- Task 1.8: Wake-on-LAN, discovery model, public API barrel `package:atv_remote/atv_remote.dart`, CLI `bin/atv_cli.dart`.
- Final review fixes: no key material in errors; handshake answers Configure/SetActive in any order; TOFU hooks (`PairingClient.serverPublicKeySha256`, `TvConnection.verifyServerKey`); `ConnectionState` renamed `TvConnectionState`.

## In progress

- Merge of `feat/phase-0-1-protocol` into `main` (waiting on the owner).

## Next up

1. **Real-TV smoke test (owner + Claude):** from `packages/atv_remote` run `dart run bin/atv_cli.dart pair <tv-ip>`, enter the code shown on the TV, then `key <tv-ip> home` and a 5-minute `watch <tv-ip>`. Use the checklist in `learnings.md` → "Unverified protocol behaviour"; record results there.
2. Set `RemoteClient.idleTimeout` from the measured ping interval (decision #10).
3. Write the detailed plan for Phase 2 (`superpowers:writing-plans`), then execute it.

## Carry-over from the Phase 1 reviews (do these when the app wires the library)

- `TvConnection`: re-check the generation after the `verifyServerKey` callback returns (guards a re-entrant `dispose()`); fold the duplicated rejection path into `_handleFailure`.
- The app must **debounce/coalesce** resume and network-change notifications: each one abandons the attempt in flight.
- The Reconnect button should call `notifyNetworkChanged()` (re-resolves the host), not `connect()`.
- Wake-on-LAN: pass the subnet broadcast address as well as `255.255.255.255`.
- The pairing UI must trim and upper-case the code before `submitCode`.
- `PairingClient` puts BoringSSL text in `connectionFailed` messages when the identity can't load; reduce to the exception type like `RemoteClient` does. `ClientIdentity.fromPem` still echoes `$e` for the certificate branch (only risky if a caller swaps the cert/key arguments).
- An identity that can't be loaded currently surfaces as `networkError` and retries until offline; the app may want a distinct "identity corrupt" state.
- CLI hardening before sharing it: write the identity file atomically with `chmod 600` on POSIX; catch setup errors; handle SIGINT in `pair`/`key`; add a test that `cliKeyCodes` covers every `KeyCodes` member.
- Release manifest still lacks `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`; iOS lacks `NSLocalNetworkUsageDescription`/`NSBonjourServices` (Phase 2/3 tasks).
- Record the protoc download URL/version in the gen scripts.

## Blocked / needs the owner

- Real-TV smoke test (TV on, same Wi-Fi; read the pairing code to Claude).
- Apple Developer account and Google Play Console account. A new personal Play account must run a closed test with **12 testers for 14 days** before production.
- App name and bundle ID (placeholder: `Remotely for Android TV`, `com.digitallinked.atvremote`).
- Privacy policy and terms URLs.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).

## How to run things

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`.
- Package tests: from `packages/atv_remote`, `flutter test` (not `dart test`; see learnings).
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch> <host> ...`.
