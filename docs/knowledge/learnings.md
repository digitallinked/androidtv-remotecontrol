# Learnings

Facts we discovered the hard way: protocol quirks, device bugs, tooling gotchas. Newest first. Format: **title**, then what happened, the fix or rule, and the source (test, device, link).

---

### Website hosting (2026-11-12)
- **Vitest fails on Windows when the drive letter is lower-case.** From Git Bash (`d:\...`) every web suite failed with "Cannot read properties of undefined (reading 'config')" and "no tests": vitest resolved itself as `D:/` and `d:/`, so two copies loaded. Run `npm test` from PowerShell at `D:\...`. Source: `web/`, 2026-11-12; 27 of 27 pass from `D:`.
- **A prerendered Next route bakes in `NEXT_PUBLIC_SITE_URL` at build time.** The sitemap, robots.txt and canonical links are static, so a runtime env var in Coolify doesn't change them. The Dockerfile takes the address as a build argument with the production default. Source: `web/Dockerfile`, decision #62.
- **The DigitalOcean registry `cargolinked` is on the Basic plan: 5 repositories, all in use.** New images go into an existing repository under their own tag prefix, and each project's prune step must match only its own prefix. Source: `GET /v2/registry/subscription`, 2026-11-12.
- **An empty folder doesn't survive a git checkout.** `web/public/` is empty and untracked, so the Dockerfile runs `mkdir -p public` before copying it. Source: `web/Dockerfile`.

### App id change and device tooling (2026-11-11)
- **Changing the application id makes a new app on the phone.** The renamed dev build installed beside the old one with the same label and none of its data, so the TV had to be paired again (the owner reads the code). Uninstall the old package once the new one is paired, and say which is which, because both show "Remotely Dev".
- **The first Gradle build after a namespace change takes about 15 minutes** (923 s on this PC), so run it in the background. Tests that build with Gradle (`release_gradle_test.dart`) and the flow tests time out in a full run under that load, then pass alone. Rerun the failing files alone before calling a failure real.
- **Git Bash rewrites `/sdcard/...` arguments** into `C:/Program Files/Git/sdcard/...`. Set `MSYS_NO_PATHCONV=1` for `adb shell` commands.
- **`adb` isn't on the PATH here.** Use `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`.
- **Wireless ADB's mDNS name disappears after the phone sleeps,** and `adb mdns services` stays empty even after restarting the server. Ask the owner for the IP and port on the Wireless debugging screen and `adb connect` to it.
- **Auto mode blocks `vercel domains add`** as an outward-facing change. Ask the owner, or let them run it.
- **A test that pins a placeholder fails once the owner fills it in.** `fill_of_the_repo_keeps_every_placeholder_out` and the rename-checklist test both broke when the URLs became real. Point such tests at a value that is still a placeholder, and add every file holding the domain or the id to `docs/release/rename-checklist.md`.
- Source: the 2026-11-11 session (`86643e3`).

### Marketing site (2026-11-07)
- **The docs arrive with CRLF on Windows, and a JavaScript `.` doesn't match `\r`.** `^> DRAFT.*\n` missed every real file while the LF test fixture passed, so the draft line was published. Normalise line endings first, and test with CRLF (`web/tests/release.test.ts`).
- **A key that fires on `pointerdown` can't hand focus on straight away.** The browser's `mousedown` then focuses the key, and on touch that `mousedown` comes after the finger lifts. Calling `.focus()` on the key instead draws a keyboard focus ring on every click. Take focus on the following `click`, which also counts as the gesture iOS wants before it shows a keyboard (`web/components/demo/RemoteDemo.tsx`).
- **Automation aims at an element's centre.** The centre of a D-pad wedge (`clip-path`) lies under OK, so a locator click times out while a real thumb is fine. Press by coordinates.
- **Another session can be editing this checkout.** The privacy policy changed while the site was being built, and the drift test caught it. Before committing, stage named paths and read `git status`.

### Real TV, app links (2026-11-11)
- **A refused app link costs the connection.** The TV answers `remoteAppLinkLaunchRequest` it can't serve with `remoteError` and then closes the socket, so the app goes to Reconnecting. Never send a link the TV hasn't been seen to accept.
- **`market://launch?id=` is dead on this TV, `market://details?id=` works** (decision #60).
- **`https` links are ambiguous on a TV:** they reach Android's chooser (reported as package `android`) or the TV's browser (`com.internet.tvbrowser`), not the app. Prefer the app's own scheme: `netflix://`, `vnd.youtube://`, `disneyplus://`.
- **The TV pings every 5.2 s** (median of 102, 2026-11-11), so the 15 s idle timeout is about three pings (V11-07).
- **The TV reports its foreground app on every change,** including the home screen (`com.google.android.apps.tv.launcherx`), the chooser (`android`), the browser, the Play Store (`com.android.vending`) and this TV's Disney+ app (`in.startv.hotstar.dplus.tv`).
- **The phone can test the TV without its pairing code:** a temporary debug build that logs every message and takes links over `adb forward tcp:8765` uses the phone's existing pairing. Install it over the dev build (same key, data kept), test, then reinstall the real build. Never commit the patch.
- **A TV can change its address.** It moved to another IP between sessions, and the app found it again by itself.

### Production pass (2026-11-07)
- **A locale is a language, not a place.** `en-GB` on a phone in Malaysia is ordinary. Anything that depends on where the phone is needs the SIM, the network or the iOS Region setting (decision #57).
- **`uiautomator dump` reads Flutter's semantics tree, in release builds too.** It gives every control's label and bounds with no screenshot, so a tap can be refused unless exactly one control matches. It also shows state: a quick tile reads "<app>, now on TV".
- **A secure lock screen stops live testing.** ADB over Wi-Fi survives the lock, but the app can't be driven behind it, and the phone locks after its own timeout. Never try to get past it.
- **A 404 on Play's website doesn't prove an id wrong, and a 200 proves only that it exists.** `com.google.android.youtube.tvkids` is a real TV app with no web listing. Read the title for a 200, query a 404 from the app's own market, and settle what's left on a TV.
- **A catalogue goes stale by itself.** Disney+ Hotstar stopped existing eleven months before this check found it. Compare the ids and names with the stores before a release.
- **A platform channel awaited in `buildRootWidget` would hang every test that calls it.** Read it in `bootstrap()`, which no test runs, and pass the value in.
- **`sqlite3` 3.x ships through a build hook, so `sqlite3_flutter_libs` is `0.6.0+eol`** and does nothing. The hook's framework has no privacy manifest, and `nm -u` on it lists `stat`, `fstat`, `lstat`, `statfs` and `fstatfs`. The old pod had no manifest either, but it set `SQLITE_ENABLE_LOCKING_STYLE=0` on iOS, which compiles `statfs` out. So the app's own `PrivacyInfo.xcprivacy` declares file timestamps and disk space. `E174.1` is the closest approved reason for `statfs`, not an exact one: SQLite uses it to identify the file system.
- **A first iOS build can die fetching Swift packages.** Flutter gives `xcodebuild -showBuildSettings` one minute and retries over half-unpacked downloads, and Firebase and AdMob take longer than that on a cold machine: `Could not resolve package dependencies … already exists`. Clear `~/Library/Caches/org.swift.swiftpm`, then run `xcodebuild -resolvePackageDependencies`, which has no limit.
- **`GoogleAppMeasurementIdentitySupport` ships unless `FIREBASE_ANALYTICS_WITHOUT_ADID=true` is set while Swift packages resolve.** Measured both ways on 2026-11-07. A build outside `tool/release.sh` has the advertising-id library in it, and the privacy policy promises it doesn't.
- **An iPhone build needs no Mac of ours.** A GitHub macOS runner builds both flavors and runs the flows on a simulator (decision #58). It proves compiling, not signing or a real iPhone.
- **`cmd locale set-app-locales` gives one app a language with no restart,** from Android 13. The emulator's `-change-locale` restarts the system just after boot, so the emulator action's next `adb` call finds no device.
- **Below Android 9, Flutter puts a button's tooltip in its accessibility label, on a line of its own.** The Settings button reads `\nSettings`, so match whole lines, not the whole label.
- **Two `adb` transports to one phone refuse every command without `-s`** (`more than one device/emulator`). Another session had connected the phone by IP, and a watcher that threw away stderr went blind without a sound. Pin the serial, and let a watcher report that it can't see.
- **`uiautomator dump` waits for the screen to go idle,** which takes about 30 s under a running animation such as discovery's spinner. A screenshot doesn't wait.
- **A new file holding the app id needs a row in `rename-checklist.md`.** `rename_checklist_names_every_file_that_holds_the_name_or_id` caught `phone_country.dart`, whose channel name contains it.
- **A `| tail` hides a build's exit code.** A wrapper reported success for a failed build. Send the build to a log and keep `$?`.
- **Two sessions can share one checkout.** The marketing site's session wrote `web/` and `.gitignore` here during this work. Check `git diff --cached`, commit with `git commit -- <paths>`, and keep a temporary patch in the tree only as long as its build.
- **`git status` lists `.g.dart` files after `build_runner` on Windows when only line endings differ.** `git diff --stat` shows the real changes.
- **The TV can leave the network altogether.** Neither ping nor ARP reaches it then, and only someone at the TV can bring it back. The phone's `ip neigh` shows the address it was using when the PC can't tell.

### CI and shells (2026-11-06)
- **An unhandled `socket.done` error blames `SecureSocket.connect`.** Dart reports it with the stack of where the socket was created, so a broken pipe from a late write after the server dropped the client looked like a failed connect. Only Linux raises it here. Logging the server's accepts showed the connect had worked. Rule: every socket gets a `done` handler, as `remote_client.dart`, `pairing_client.dart` and the fake server already do; the test's `_Peer` didn't.
- **When there's no Linux here, a throwaway `diag/**` branch with its own workflow gets a real answer in minutes.** WSL can fail to start under load. Replace `ci.yml` on that branch with a job for just the failing file, add logging, and delete the branch after.
- **`gradlew` needs bash, not `sh`.** Flutter generates it with `#!/usr/bin/env bash` and arrays, and Ubuntu's `sh` is dash, so `sh gradlew` dies at once with `Syntax error: "(" unexpected`. The font failure stopped `check.sh` before this step, so one bug hid the other. When CI goes from red to a new red, the first bug may have been masking it.
- **A file listing on Windows says nothing about the name on Linux.** The SDK's `fonts.zip` holds `Roboto-Regular.ttf`. Flutter's Windows unzip runs paths through `path.canonicalize`, which lower-cases them, so Windows has `roboto-regular.ttf`. The helper hardcoded the lower-case name, so CI failed on three test files for months while a note here said it couldn't be a case problem. Read the archive itself, and match names without case. A Windows test can still catch this by asserting the returned name, because a plain lookup succeeds on NTFS.
- **In a Bash heredoc through this harness, `\\n` can arrive as `\n`,** so a Python edit script silently stops matching, or writes a real newline. Build the pattern with `chr(92)` or bytes, and look for `NOT FOUND` in the output.
- **The TV answering ping doesn't mean it can be controlled.** It replied to ping while 6466 and 6467 timed out, and an hour later the ports were open (standby is the likely reason, unverified). `RemoteClient.connect` then reports `networkError`, while an unpaired client reports `certificateRejected`. Check the ports before calling something a pairing problem.
- **When wireless debugging is off, nothing on the PC can bring it back.** `adb connect` is refused on the old port and no port in 30000-49999 listens. When it is back it may be on a new port, and `adb devices` can find it without a new pairing.
- **A cold Gradle fails `release_gradle_test`'s first two tests on the 2-minute limit** on a loaded machine straight after `flutter clean`. The later tests take about a minute. Run a build or the tests once to warm it; don't raise the limit.

### First release build on a phone (2026-11-06)
- **R8 full mode strips a constructor kept only by `-keep class X`.** Anything created by reflection needs `{ <init>(); }`. A host test can't see this; check `build/app/outputs/mapping/<variant>/usage.txt` (decision #55).
- **`flutter build apk` can ship stale Dart and still report success.** New font assets went in while `libapp.so` held code from days earlier, with no error, across two builds. `flutter clean` cured it; the cause is unknown (unverified: the AOT stamps stayed older than `app.dill`). After a release build, prove the snapshot before trusting it: read `lib/arm64-v8a/libapp.so` from the APK and look for a string only the new code has.
- **Searching a Dart snapshot:** one-byte strings are Latin-1, so `·` is `0xB7`, not UTF-8's `C2 B7`, and class names don't survive release. Search for a const string that exists nowhere else.
- **A screenshot is the only proof the app updated.** The install succeeded, the hashes matched and the process ran while the phone showed last week's UI.

### Design pass (2026-11-06)
- **`ThemeData.fontFamily` doesn't reach styles handed straight to a component theme.** `listTileTheme` was given styles from our own `TextTheme`, and every list row silently fell back to the default font; only a real-font render showed it. The family is set in `_style` itself.
- **Goldens can't judge type.** They draw in the test font, so every word is a block, and long-looking subtitles there are short in reality. Judge copy and hierarchy from `loadRealFonts` renders, never from a golden.
- **Atkinson Hyperlegible Next has no `→` (U+2192),** used in 28 strings ("Settings → Network"). Android and iOS fall back to a system font, but `flutter test` draws a box. Everything else in both ARB files is covered. DM-116 confirms it on a phone.
- **`flutter_native_splash:create` rewrites untouched files with LF on Windows,** `Info.plist` and the storyboard included. They show as modified with an empty `git diff --numstat`; `git checkout` them. Binary changes and the two `v31` colours are the only real output of a colour change.
- **`AnimatedContainer` turns a decoration's border into padding** (`Container` does, `DecoratedBox` doesn't). A pill that swapped one for the other grew 2 dp and overflowed the pseudo-locale sweep. Tween the decoration inside a `DecoratedBox`.
- **Rows inside one panel are built together, so `scrollUntilVisible` stops early:** the row is in the tree while it is still off-screen, and the next tap misses it. Follow it with `ensureVisible`. A panel past the cache extent, on the other hand, isn't built at all, so scroll before `find`.
- **A failed `Bash` heredoc can leave nothing applied or everything applied.** Write edit scripts to a file instead, and check `git status` after a shell error.

### Real-device run (2026-11-05)
- **A fake that replaces a plugin also replaces the plugin's Dart.** `nsd`'s Dart side refuses a service name over 15 characters, and `_androidtvremote2._tcp` has 16, so every search failed on every phone while every test passed. Call `disableServiceTypeValidation(true)`. Rule: one test per plugin goes through the plugin's real Dart with only the channel mocked. Source: `nsd_tv_discovery_test.dart`, `the_real_plugin_browses_both_android_tv_service_types`.
- **`developer.log` shows nothing in a release build.** A catch that only logs drops the error for real users.
- **sqlite's error text quotes values.** `SqliteException.toString()` ends with `Causing statement: ..., parameters: <values>`, and drift keeps that text through its isolate. A scrubber can't remove a value it doesn't know, so cut the tail. Source: sqlite3-3.5.2 `lib/src/exception.dart`.
- **`ref.read` in a catch after an await throws once the widget is gone,** and replaces the handled failure. Read the reporter before the await.
- **A stacked route keeps the screen beneath alive,** so two screens on one provider both see a failure. Report from a shared provider, not per screen.
- **`market://launch?id=` is reported broken on many devices** after a Google Play change: the command sends and nothing happens. The docs give no date. (Unverified on the owner's TV until DM-029 runs; [HA docs](https://www.home-assistant.io/integrations/androidtv_remote); decision #56.)
- **flutter_svg:**
  - `compute` runs synchronously under `kDebugMode`, so debug builds never exercise the release isolate path. Device rows that judge logos need a release build.
  - A logo appears one frame late, so a test that doesn't settle shows an empty tile.
  - `Cache` leaks an uncaught error on a failed load and never clears `_pending`. A guarded zone's failed future can't reach a listener in another error zone, which is why `_LogoLoader` keeps `_failed`.
- **`hasRunningAnimations` counts any pending `LayoutBuilder` rebuild,** not only tickers.
- **Overlapping `flutter test` runs crash with `PathAccessException` on `sqlite3.dll`.** Rerun once the other has finished.
- **Real file I/O in `testWidgets` needs `tester.runAsync`.**
- **`PRAGMA database_list` gives the database's real path** without `path_provider`. Proven on Windows only until DM-114 step 5 runs.
- **Simple Icons has no Prime Video, Disney+, Hulu or Peacock,** and its CC0 doesn't cover every icon or any trademark (`DISCLAIMER.md`). Check coverage against the catalogue before promising a logo.

### Phase 9 gotchas (release prep)
- **Gradle and Android:**
  - `flutter build` runs Gradle with `-q`, so `logger.warn` and `logger.lifecycle` are hidden. Use `logger.quiet` for build warnings the user must see.
  - `gradlew build` and `assemble` never run the `bundle*` tasks. Refusals that must cover aggregate tasks need a `taskGraph.whenReady` backstop.
  - `flutter build apk --config-only` writes `gradlew`, `gradlew.bat` and `local.properties` without building. CI needs it before any Gradle dry run (`-m`).
  - Java Properties treats `\` as an escape: use forward slashes in `key.properties` paths.
  - Don't run `flutter build` while `flutter test` runs ("Unable to determine engine version").
- **iOS (from docs; Mac checks pending):**
  - `FIREBASE_ANALYTICS_WITHOUT_ADID` is the SPM switch for Ad-ID-free Analytics; the Podfile global works for CocoaPods only.
  - With a Podfile present, Flutter still runs `pod install` under SPM, and podhelper skips plugins that have a `Package.swift`.
  - `flutter build ipa` keeps `BUILD_DIR`, while `flutter build ios` sets `build/ios`.
  - A script phase whose `inputPaths` no task produces fails the build.
- **Store facts:**
  - dart:io TLS is Flutter's bundled BoringSSL, not the OS crypto. This changes the App Store export answer.
  - App Review Guideline 1.3 is the Kids Category. Ads matching the age rating is **2.5.18**.
  - Apple's App Privacy asks "Linked" per data type, so any type AdMob collects is Linked: Yes.
- **Tests and tooling on Windows:**
  - Parallel `flutter test` runs collide on the `sqlite3.dll` native asset: run one at a time.
  - Git's `usr\bin\bash.exe` keeps PATH as given. Launched from PowerShell it lacks `dirname` and `rm`, so a test that spawns bash must build the child's PATH itself.
  - A fresh worktree with `core.autocrlf=true` checks the docs out with CRLF. Doc-parsing tests normalise CRLF to LF (`releaseDoc()`).
  - `flutter_secure_storage`'s method channel never answers in a test, and an awaited call outside a pump hangs `flutter_tester` for good. `test/flutter_test_config.dart` installs `FlutterSecureStorage.setMockInitialValues({})`. A hung tester holds `build/native_assets/windows/sqlite3.dll`, so every later run in that tree fails with `PathAccessException: Deletion failed`.
  - Stopping a backgrounded `flutter test` shell leaves `flutter_tester.exe` running: check for orphans before rerunning.
  - A git worktree has its own `build/` and so sidesteps a locked `sqlite3.dll`. Keep its path short: under the long scratchpad path, the SwiftPM plugin generation fails with `PathNotFoundException` (MAX_PATH).
  - Under heavy machine load, the atv_remote latency p95 can pass 30 ms, and `discover_pair_press_key_flow` (a 20 s wait) can time out. Both pass alone at 2–5 ms. Run the final full check on a quiet machine, and don't change the thresholds.
- **Flutter widgets:**
  - `ListTile` → `InkWell` drops `Semantics(button, enabled)`: add it back explicitly.
  - A `LayoutBuilder` that adds a scroll view only below a size threshold rebuilds the subtree and resets its state. Keep the child under a `GlobalKey` (`ScrollWhenShort`).
  - `testWidgets` makes one `WidgetTester` per declaration and shares it across `variant` runs. An `Expando` keyed on the tester registers once per declaration.
- **CLI signals:**
  - On Windows, `ProcessSignal.sigint.watch()` works but `ProcessSignal.sigterm.watch()` throws `SignalException`, so watch SIGTERM only off Windows.
  - Once SIGINT is watched, Ctrl+C no longer kills the process: the program must release the key and exit by itself (`holdKey` returns 130).
- **Merged manifest under AGP 9:**
  - The prodRelease manifest is at `app/build/app/intermediates/merged_manifests/prodRelease/processProdReleaseManifest/AndroidManifest.xml`. The same content is also under `merged_manifest/prodRelease/…`, which is why the checker uses the newest `merged_manifest*` match.
  - The blame report is `app/build/app/outputs/logs/manifest-merger-prod-release-report.txt`.
- **Real fonts in tests:**
  - Widget tests render the Ahem test font unless you load fonts yourself. `test/helpers/real_fonts.dart` `loadRealFonts()` loads Roboto and MaterialIcons from the SDK's `material_fonts`. It finds them via `FLUTTER_ROOT`, then the folders above the runner, so it also works on Linux CI.
  - Roboto is also registered under `CupertinoSystemText`/`CupertinoSystemDisplay` for iOS-platform renders. There is no SF Pro, so the iOS screenshots use Roboto.
- **Codegen:**
  - The riverpod_generator hash uses `toSource()`, which drops comments. Doc comments edited by hand in `*.g.dart` keep the hash valid, but must match the source text.
- Source: Phase 9 SDD (`.superpowers/sdd/2026-10-31-phase-9-release-prep/`).

### Phase 8 gotchas (quality and hardening)
- **Real sockets in widget tests:**
  - dart:io TLS uses zero-length timers: under the test binding, drive real I/O with `pump(Duration.zero)` inside a `runAsync` loop (`pumpUntil`), not a bare `pump()`.
  - A live `RemoteClient` leaves its 15 s idle timer pending: unmount the app and wait for 0 open connections before the test ends (`FakeTvHarness.cleanUpAfter`).
  - `Ticker.start` during a frame takes that frame's timestamp, so `tap → pump() → pump(16 ms)` is exactly one frame elapsed.
- **flutter_test and Riverpod:**
  - `addTearDown(handle.dispose)` is too late for a `SemanticsHandle` in `testWidgets` (handles are checked before tear-downs): dispose it in a `finally`.
  - A `ProviderContainer` rejects two overrides of one provider: combine with `mergeOverrides(testAppOverrides(...), [...])`.
  - Riverpod 3.3.2 **keeps** a Notifier instance across rebuilds (`classListenable.result ??=`); the 3.0 changelog line saying otherwise is stale.
  - The riverpod_generator hash is `sha1(node.toSource())`, so whitespace, line endings and comments never change it. A `.g.dart` diff of line endings only comes from `core.autocrlf`: revert it.
  - `_statusOf` treats any loading state as `connecting`, so stale `AsyncLoading` values (volume, current app) never reach the remote UI.
  - `Matrix4.getMaxScaleOnAxis()` includes z (always 1), so it can't detect a 2D down-scale: read `storage[0]`/`storage[1]`.
  - `expectNoClipping` catches only thrown overflow, not ellipsized text: check `didExceedMaxLines` too.
  - Drift's multiple-database warning is silenced once in `test/flutter_test_config.dart`.
- **Flutter 3.44.1 framework quirks:**
  - A Theme swap gives a Theme-dependent `Scrollable` a new `ScrollPosition`; for one frame its semantics lack `hasImplicitScrolling` (healed by the next, self-scheduled frame).
  - A `GestureDetector` inside `Semantics(onTap)` makes a second unlabelled node unless `excludeFromSemantics: true`.
  - `LongPressStartDetails.localPosition` is already the down origin.
  - `TextButton.styleFrom(foregroundColor:)`-style derived overlays: see Phase 7.
- **Privacy and backup:**
  - With P8-R1, iOS preferences survive a backup or Quick Start but the database doesn't: any preference that stands for database state (like `shortcuts_seeded`) must be ignored when the database is created fresh.
- **Localisation:**
  - gen-l10n falls back to English for keys missing from `app_ms.arb` (it only warns).
  - iOS in Malay calls the Settings app "Seting"; Android uses "Tetapan". Menu paths must follow each OS.
  - At 320 dp and 100 % (Roboto 14 sp) the pad tabs have about 72 dp and the colour keys about 50 dp: keep those labels short.
- **Tooling:**
  - adb isn't on PATH on the Windows dev PC: `%LOCALAPPDATA%\Android\Sdk\platform-tools` (the measure scripts find it).
  - Battery discharge only accumulates unplugged: plug back in only when the measure script's countdown ends.
- Source: Phase 8 SDD (`.superpowers/sdd/2026-10-30-phase-8-hardening/`).

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
