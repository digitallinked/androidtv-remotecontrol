# Learnings

Facts we discovered the hard way: protocol quirks, device bugs, tooling gotchas. Newest first. Format: **title**, then what happened, the fix or rule, and the source (test, device, link).

---

### Phase 7 gotchas (polish)
- **Navigation:**
  - go_router 18.1.1 checks for material_ui's `MaterialApp`, not Flutter 3.44.1's, so plain `builder:` routes become `NoTransitionPage`. Recheck on every go_router bump; we use `pageBuilder` via `appPage`.
  - Only the pushed page carries its query parameters; a later `go('/settings')` drops `from=setup`.
- **Ink and reduce motion (Flutter 3.44.1):**
  - `InkHighlight` fades for about 200 ms whatever `disableAnimations` says (MediaQuery or platform); `NoSplash` removes only the splash.
  - `TextButton.styleFrom(foregroundColor:)` and `IconButton(color:)` derive a 0.1× pressed overlay that beats a theme `overlayColor`. `SegmentedButton` has its own theme. Test every tappable kind, including widget-styled ones.
  - In a scrollable, `startGesture` plus one `pump()` starts no ink: the press waits `kPressTimeout` (100 ms).
  - The iOS caret fades in a loop unless `cursorOpacityAnimates` is false.
- **Tests:**
  - `shared_preferences` 2.5.6 captures the platform at open: a failing-prefs test must install the failing platform before the store opens.
  - Re-pumping `MaterialApp` with a new brightness leaves `AnimatedTheme` mid-transition; `pumpAndSettle()` before reading colours.
  - `Brightness.values` is `[dark, light]`.
  - After `go()` under reduce motion the replaced page stays offstage for one frame.
  - Lazy lists un-build items scrolled away: scroll back or `Scrollable.ensureVisible(alignment: 0/1)` for large-text checks; 200% text on 320×640 Edit apps builds only the first row.
  - App-bar titles use `softWrap: false`, so compare `getMaxIntrinsicWidth(∞)` with `size.width` to detect truncation.
  - A flick that crosses `firstStep` between the last move and lift-off sends no step, by design (P7-R12).
- **Branding tooling:**
  - flutter_launcher_icons rewrites `project.pbxproj` (an asset-symbol setting and LF endings) on every run: `git checkout` it after `tool/brand.ps1`.
  - The adaptive foreground inset must be 0; the 16% default shrinks the mark.
  - With `core.autocrlf=true`, any text file a test compares byte for byte needs an `eol=lf` rule.
- **check.ps1** can stall in the test runner with no failure; stop and rerun. A clean run took 7–70 minutes this phase.
- Source: Phase 7 SDD (`.superpowers/sdd/2026-10-30-phase-7-polish/`).

### Phase 6 gotchas (services & monetisation)
- **Firebase and Analytics:**
  - Native Crashlytics initialises from its config file whatever `FIREBASE_ENABLED` says, and its collection override persists across launches.
  - **(unverified)** Firebase Analytics doesn't keep events logged while collection is off. `setAnalyticsCollectionEnabled` persists natively and overrides the manifest default.
- **Riverpod:**
  - `ref.listen` inside a notifier that nothing listens to never fires; hold a `container.listen`.
  - App-wide hooks keep `connectionStateProvider` alive and build `remoteSessionProvider` at startup. App-level tests that read analytics must override `remoteSessionProvider`, or they open the real drift DB in Documents.
  - Auto-dispose "actions" objects must take their dependencies in the constructor. A held instance outlives its `Ref`, and a lazy `_ref.read` after an await throws (Edit TV dropped the MAC when the name and MAC were saved together).
- **Crash scrubber:** saved-term scrubbing must run before prefix-consuming rules. A `%XX` escape ends in a hex digit, which defeats `\p{L}\p{N}` lookarounds.
- **AdMob, UMP and ATT:**
  - In `google_mobile_ads` 9.2.0, consent forms await dismissal before they complete. `InterstitialAd.load` returns before `onAdLoaded`, so read the ad only after the gate.
  - **(unverified)** iOS ATT `requestTrackingAuthorization` shows nothing and returns `notDetermined` while the app isn't active.
  - **(unverified)** UMP reports `notRequired` in the EEA when no GDPR message is published, which would turn analytics on by default. Publish the message before enabling Firebase in prod, and check with `UMP_DEBUG_GEOGRAPHY=eea`.
  - Debug builds with real prod ad ids need registered test devices.
  - The `in_app_review` 2.0.12 Android `requestReview` can fail with "In-App Review API unavailable" after `isAvailable()` said yes. Treat that as not asked.
- **Navigation:**
  - Navigate from a stable ancestor (router/navigator) captured before an await, not from a context that may unmount.
  - go_router puts `GoRoute.name` in `route.settings.name`, and the route observer also sees parent pages.
- **Windows:** normalise line endings before scripted edits. A lone `\r` survives gen-l10n and check.ps1.
- **Widget tests:**
  - `addTearDown(handle.dispose)` for a `SemanticsHandle` runs after Flutter's handle check; dispose it in try/finally.
  - Socket tests on a loaded machine need setup budgets of about 20 s around TLS handshakes; keep the asserted timings tight. Drive the fake TV's pings by hand rather than polling a ~75 ms state window.
- Source: Tasks 6.1–6.11 and the Phase 6 final review.

### Phase 5 gotchas (apps, devices, settings)
- Reading `.future` of an autoDispose provider with no listener throws "disposed during loading state". Hold a `container.listen(...)` subscription across the await.
- A `ref.watch(x.future)` that is awaited only after another await needs `.ignore()`, or its failure surfaces as an unhandled error.
- Riverpod 3's default retry makes a failing bundled-asset provider hang `.future` in tests — use `retry: noRetry`; mocking the `flutter/assets` channel also hangs, so put the raw string behind its own provider seam.
- build_runner can skip a file whose committed `.g.dart` was reverted (its cache thinks it's fresh) — `flutter pub run build_runner clean` then build; a riverpod hash is `sha1` of the declaration source, so stale hashes are real drift (debug-only effect).
- go_router: pushing a nested child path puts only that child over the current page; `go('/remote')` keeps `RemoteScreen`'s State (same page key).
- `ReorderableListView` adds its own localised Move up/down/start/end actions on each item; nesting another `Semantics(container: true, customSemanticsActions)` duplicates them. Its reorder animation ignores reduce-motion.
- `Uri(queryParameters:)` encodes spaces as `+`; build `mailto:` queries with `Uri.encodeComponent`.
- `MaterialApp` cross-fades themes for 200 ms (`themeAnimationDuration`); a single `pump()` still sees the old theme.
- `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent:)` gives a text-scale-aware row height; lazy rows don't build off-screen tiles, so assert order from data, not finders.
- `rootBundle.loadString` hands strings > 50 KB to an isolate that never completes inside `testWidgets` — keep bundled JSON < 40 KB.
- A Play web 404 for a package id isn't proof it's wrong (geo-restricted or TV-only listings).
- Android Auto Backup is on by default and copies the drift DB and prefs to the user's Google Drive.
- Riverpod 3 retries a provider that throws an `Exception` (drift's `SqliteException` included) for ~38 s, but not an `Error` — an error state can hide behind a spinner; use `retry: noRetry` where the UI must show it.
- A tile placed next to a scrollable in a `Row` needs its own `Semantics(container: true)`, or its label merges into the row's node.
- Source: Tasks 5.1–5.10 and the Phase 5 final review.

### Phase 4 Flutter gotchas (remote experience)
- `ScaffoldMessenger.hideCurrentSnackBar()` + `showSnackBar()` **queues** — it does not replace. Bursts of refusals built a ~25 s backlog; keep one `ScaffoldFeatureController` and show only when it's null.
- `RouteObserver<PageRoute>` ignores sheets and dialogs (both routes must be `PageRoute`), and a page pushed while a sheet is on top isn't seen. The platform wake lock is one global flag, not ref-counted.
- `ModalRoute.popped` completes at pop time, before the exit animation; release "is open" flags there and identity-check them in `dispose`, or a closing sheet's dispose clears the flag of a new one.
- Riverpod skips equal consecutive values: a stream of identical events (e.g. IME requests) needs identity-typed signals. flutter_riverpod 3.3.2 pauses only `watch` subscriptions under `TickerMode` off — `ref.listen` keeps firing (an earlier review claim of "replay on resume" was wrong).
- `TextScaler` may be non-linear (Android 14+): compute a line's height as `scale(fontSize) * height`, not `scale(fontSize * height)`. Linear test scalers hide this — test with a non-linear scaler too.
- Ahem goldens can't prove text wrapping (every glyph is one em); assert `maxLines`/`didExceedMaxLines` instead.
- Theater tests: the first tap only wakes — `warnIfMissed: false` and `pump()` after it; keep the child tree identical across a dim so state survives.
- After `FakeRemoteClient.push` use `pumpAndSettle`; share one in-memory DB across re-pumps (drift warns about multiple databases).
- A `ScrollEndNotification` also fires when a pointer interrupts a `PageView` animation (hold), possibly at a fractional page.
- Source: Tasks 4.3–4.12 and the Phase 4 final review.

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
- **Phase 4 additions:** does `RemoteImeBatchEdit` with the whole field replace the TV's field (`kImeTextMode = replaceField`; check with CLI `text`)? How does the TV's backspace count (graphemes vs code units) if `appendOnly` is ever used? Does a `startLong` volume key auto-repeat on the TV, and what happens if `endLong` never arrives? Long-press OK behaviour. What `KEYCODE_SEARCH` (84) does on Google TV. Does the 6466 socket survive TV standby? Does Wake-on-LAN wake the MediaTek TV, and how soon does `reconnect()` find it? Which starter apps open via `market://launch?id=`? Does iOS restore system brightness after `resetApplicationScreenBrightness`?
- **Phase 5 additions:** what `market://launch?id=` does for an app that isn't installed; which packages a MediaTek TV reports as the current app (filtering); whether the TV still lists or trusts a phone after it was removed in the app; whether a TV found by mDNS presents the same key as when it was paired by IP (merge without re-pairing); which starter/catalogue package names open on the TV (incl. `in.startv.hotstar.dplus`, `uk.co.bbc.iplayer`, `deezer.android.tv`, `com.google.android.youtube.tvkids`); the real ids of Astro GO, sooka and Tonton (`adb shell pm list packages` on the TV).

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
