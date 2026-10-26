# Learnings

Facts we discovered the hard way: protocol quirks, device bugs, tooling gotchas. Newest first. Format: **title**, then what happened, the fix or rule, and the source (test, device, link).

---

### Phase 3 platform behaviour (connect flow)
- iOS suspends Dart timers in the background: compare wall-clock time on resume (session grace, pairing countdown). iOS also drops connectivity_plus events while backgrounded: re-read the baseline on foreground.
- A Wi-Fi→Wi-Fi network switch can look like a duplicate event to connectivity_plus; the 15 s idle timeout catches the dead socket.
- `RawDatagramSocket.send` can return 0 instead of throwing (e.g. IPv6 target on an IPv4 socket on Windows): treat 0 bytes as a failure.
- NSD on Android may resolve an IPv6 address; `_pickHost` prefers IPv4 and falls back to `service.host` (unverified on the Note10+ — real-device run).
- Source: Tasks 3.2, 3.5, 3.9, 3.10.

### Riverpod 3 and widget-test gotchas (Phase 3)
- A notifier can't `ref.invalidate` a provider that depends on it; use `ref.container.invalidate`.
- `riverpod_generator` can't name drift data classes in a provider signature; hand-write that provider (`savedDevicesProvider`).
- Notifier instances survive `invalidateSelf`: keep per-build state in `build()` locals.
- The default provider retry hides errors for ~13 s; use `retry: noRetry` where the UI must show an error.
- A modal barrier's `BlockSemantics` hides widgets placed above the Navigator (in `MaterialApp.builder`) unless they are in their own semantics container; show dialogs from there with the router's `navigatorKey` context.
- go_router in tests: a pushed route doesn't appear in `currentConfiguration`; read `GoRouterState.of` from the top `Scaffold`. Don't await `push()`.
- Screens with a running spinner or countdown never settle: use `pumpRouterApp(settle: false)` and explicit pumps. Demo connect needs `pump()`, `pump(700ms)`, `pumpAndSettle()`.
- drift's watch stream leaves a pending timer: `pumpRouterApp` overrides `savedDevicesProvider` with an empty list by default; caller overrides replace defaults by `origin`.
- Fakes must not mark themselves closed on error/success, or "the controller closes the client" tests become vacuous; count `close()` calls instead.
- drift stores DateTime in whole seconds: compare saved devices field by field.
- Source: Tasks 3.4–3.9.

### Windows tooling gotchas (Phase 3)
- build_runner on Windows can rewrite unrelated `.g.dart` files with line-ending-only changes; revert them.
- A killed `flutter test` can leave `flutter_tester` holding `sqlite3.dll`; stop only that process before re-running.
- Write source files with the Write tool, not long Bash heredocs (heredocs mangle `@` and quotes).
- Dart 3.12 private named initialising formals (`this._x`) satisfy `prefer_initializing_formals`.

### Flutter app tooling in this workspace (Phase 2)
- Run code generation with `flutter pub run build_runner build --delete-conflicting-outputs` from `app/`; `dart run build_runner` fails in this pub workspace. Then `dart format` the generated files.
- Android builds need `kotlin.incremental=false` (set in `app/android/gradle.properties`): the pub cache is on C: and the project on D:, and incremental Kotlin fails with "different roots".
- `tool/check.*` formats only `app/lib`, `app/test` and `packages/atv_remote/{lib,test,bin}`. A new Dart directory (e.g. `app/integration_test`) must be added to that list.
- Golden tests are tagged `golden`, generated on Windows; Linux CI skips them and a Windows CI job runs them. Failed golden runs write `app/test/**/failures/` (git-ignored); never commit them.
- Riverpod 3: `Override` and `ProviderException` come from `package:flutter_riverpod/misc.dart`.
- freezed can't resolve alongside drift_dev ≥ 2.32 with this toolchain's `test`/analyzer pin; models are drift data classes or hand-written. drift is pinned to 2.34.0.
- drift: `insertOnConflictUpdate(data)` skips null fields — use `data.toCompanion(false)` so an upsert can clear a nullable column. drift reads `DateTime` back as local time; `DeviceRepository` returns UTC.
- `dynamic_color` 2.1.0 hands out `material_ui`'s `ColorScheme` (a different type from Flutter's); `app/lib/app/theme/dynamic_scheme.dart` converts it.
- iOS flavors (6 build configurations, `dev`/`prod` schemes) are only structurally tested on Windows; the owner must run `flutter build ios --flavor dev|prod -t lib/main_<f>.dart --no-codesign` on a Mac.

### Unverified protocol behaviour — checklist for the real-TV smoke test
All of these are (unverified) until the smoke test records an answer here:
- How a TV rejects an **unpaired client cert** on 6466: TLS alert, clean close, or TCP reset? We map an alert or close before the first `RemoteConfigure` to `certificateRejected`, and a reset to `networkError` (rulings R4/R12).
- The TV's **ping interval**. `RemoteClient.idleTimeout` is 15 s; target ≤ 10 s detection (decision #10).
- **Message order:** does the TV send `RemoteConfigure` before `RemoteSetActive`, and does it push `RemoteStart`/volume/current app before `SetActive`? (The client now handles any order.)
- **IME counters** for `sendText` (`RemoteImeBatchEdit` `ime_counter`/`field_counter` from the latest TV IME message), and whether text with emoji positions the cursor correctly (we count UTF-16 code units; androidtvremote2 counts code points).
- Does the TV present the **same key** on 6467 (pairing) and 6466 (control)? TOFU pinning assumes yes.
- Does `watch` run 5 minutes with no drop (pings answered)?

### `dart test` cannot resolve this workspace; use `flutter test`
- The root pub workspace contains a Flutter member, so `dart test` fails to find the Flutter SDK. `flutter test` runs pure-Dart tests (including `dart:io` sockets) on the host VM. `dart run bin/...` works, because it reuses the existing package config.
- Source: Task 0.1 / decision #8.

### dart:io TLS limits that shape the protocol code
- `SecureServerSocket` has no server-side bad-certificate callback, so a self-signed client cert fails the handshake unless it's in the server's trusted certs. The fake TV uses `FakeTvServer.trustClient(identity)`.
- A TLS handshake already in flight can't be aborted (`destroy`/`close`/`ConnectionTask.cancel` on the raw socket don't stop it). We bound waits with timeouts and destroy late sockets instead.
- `SecureSocket.connect(timeout:)` bounds only the TCP connect, not the handshake. `Socket.startConnect` resolves DNS before its timeout starts. Always wrap the whole connect in an outer timeout.
- `SecurityContext()` has no trusted roots by default; passing `withTrustedRoots: false` triggers a lint.
- Source: Tasks 1.4–1.6.

### Toolchain pins and gotchas
- protoc 36.2 (downloaded into git-ignored `tool/bin/`) + `protoc_plugin` 25.1.0. `protobuf` runtime is `^6.1.0`. Generated code is formatted by the gen scripts and excluded from the analyzer.
- `very_good_analysis` 10.3.0 is the newest version for Dart 3.12 (11.x needs 3.13).
- X.509 `UTCTime` can't encode dates in 2050+, so client certs use 20-year validity.
- On Windows a refused loopback connect takes ~2 s to fail; tests that need fast failures inject a fail-fast connector.
- Source: Tasks 1.1–1.7.

### Competitor connection silently drops; "Connected" badge lies
- Remote ATV lost the TV connection after a few minutes with no indicator, and its picker kept showing "Connected". Users had to tap the TV again to reconnect.
- **Rule for us:** answer every `RemotePingRequest`, show real-time connection state, and auto-reconnect with backoff. The UI badge must reflect socket state, not "paired" state.
- Source: live test, 2026-10-25 (teardown §4.1).

### TV-reported "current app" packages are raw and noisy
- The TV reports packages like `android` and `com.mediatek.wwtv.tvcenter`. Remote ATV showed them unfiltered as "recommendations".
- **Rule:** filter system packages, and map known packages to names and icons from our catalogue.
- Source: live test, 2026-10-25.

### Ads next to close buttons cause accidental clicks
- In Remote ATV the banner sits under the ✕ of Settings and the paywall; one double-tap produced an ad click.
- **Rule:** no ad within 48 dp of any navigation control; never place an ad on the remote screen's top bar.
- Source: live test, 2026-10-25.

### ADB screenshots from PowerShell
- `adb exec-out screencap -p > file.png` corrupts the PNG in PowerShell (text encoding). Use `adb shell screencap -p /sdcard/x.png` + `adb pull`, or REA `capture_adb_screen`.
