# Phase 8 — Quality and Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The v1.0 app is a release candidate. That means:
- **The release blocker is closed:** nothing about the user's TVs leaves the phone through Android Auto Backup, Android device-to-device transfer or an iOS backup, so the Privacy page's "never leave this phone" (`privacyIntro`) and `faqPrivacyA` are true.
- **The critical flows are proven end to end:** discover → pair → press a key against the protocol library's fake TV over real TLS, and the demo, on the host and on an emulator or device.
- **Accessibility is audited:** every screen, sheet, dialog and state meets the four Flutter guidelines, and a scripted TalkBack/VoiceOver checklist exists for the device run.
- **Malay ships:** a complete `app_ms.arb`, Malay iOS purpose strings, and overflow checks in Malay and in a pseudo-locale.
- **Performance is measured, not guessed:** key-press-to-send latency and a 50-cycle resume leak test run against the fake TV; cold start and battery have a measurement script and a place to record real numbers.
- **The device matrix exists:** `docs/knowledge/device-matrix.md` is a scripted checklist that folds in every device-run item from `status.md`.
- **Every Phase 8 carry-over in `status.md` is closed or explicitly deferred** (the table in the Phase exit checklist).

**Architecture:**
- **Protocol:** `packages/atv_remote` gains one library, `package:atv_remote/testing.dart`, which exports the existing `FakeTvServer` (moved from `test/fake_tv/` to `lib/src/testing/`). The main barrel `atv_remote.dart` doesn't export it, and no file under `app/lib` may import it. No wire behaviour changes.
- **Backup:** Android turns Auto Backup and device transfer off in the manifest and in `data_extraction_rules.xml`. On iOS the drift database moves into an `Application Support/Database` directory that a small method channel in `AppDelegate.swift` creates and marks `isExcludedFromBackup`. The keychain item is already `first_unlock_this_device`; preferences hold no TV data. Android's database path doesn't change.
- **Integration tests:** each flow is one binding-agnostic script in `app/integration_test/flows/`. It runs twice: on the host inside `flutter test` (`app/test/integration/`, so `tool/check.ps1` runs it) and on an emulator or device through `IntegrationTestWidgetsFlutterBinding` (`app/integration_test/*_test.dart`). Real socket waits go through one `pumpUntil` helper that alternates `runAsync` and `pump`.
- **Localisation:** `app_ms.arb` next to `app_en.arb`; gen-l10n adds `ms` to `supportedLocales`, so the existing language picker offers "Bahasa Melayu". The pseudo-locale is test-only: a generated `PseudoLocalizations extends AppLocalizationsEn` that wraps and lengthens every message.
- **Hardening:** the carry-overs are fixed in the files that own them, grouped by area.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2 (riverpod_generator 4.0.4), go_router 18.1.1, drift 2.34.0 / drift_flutter 0.3.1, flutter_secure_storage 11.2.0, AGP 9.0.1. The only new package is the SDK's own `integration_test` (dev dependency, `sdk: flutter`, Task 8.2). No version bumps.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md`.
- **Binding parts:** goal 11 (accessibility, 200% text), goal 12 (layouts), the privacy promise (TV names, addresses and MACs stay on the phone), the anti-goal "using 'Google' in the name or icon".
- **Relation to the master plan:** this plan expands Phase 8 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md` (Tasks 8.1–8.5 there). It keeps that plan's test names (`discover_pair_press_key_flow`, `demo_mode_flow`, `purchase_flow_sandbox`, `no_leak_after_50_resume_cycles`) and the file `docs/knowledge/device-matrix.md`. The master's numbering is reordered: the release blocker comes first (status.md "Next up" #2).
- **Before starting, read:**
  - the skills `flutter-app-architecture` (primary), `remote-design-system` (8.4–8.6, 8.10), `atv-remote-protocol` (8.2, 8.3, 8.9), `app-services` (8.8), `store-release` (8.1, 8.12, 8.14);
  - in `docs/knowledge/decisions.md`: #11, #13, #14, #15, #20, #24, #28–#30, #33, #34, #39, #42, #43, #46, #47;
  - `learnings.md`, especially the Phase 3–7 widget-test gotchas and "Windows tooling gotchas".

## Global Constraints

- **Toolchain:**
  - Flutter 3.44.1 / Dart 3.12.1, `environment.sdk: ^3.12.1`. No dependency upgrades in this phase.
  - Lints are `very_good_analysis` 10.3.0 with `public_member_api_docs`, so every public `lib/` member gets a `///` doc. `packages/atv_remote` is analysed with `--fatal-infos`.
  - Keep pubspec dependencies sorted.
- **Dependencies:** the only new one is `integration_test` (`sdk: flutter`) under `app` `dev_dependencies`, added by Task 8.2. `git add` includes the root `pubspec.lock` (pub workspace).
- **Non-negotiables (CLAUDE.md):**
  - Never copy code, assets, text or branding from competitor apps, including `docs/competitor-analysis/`. The Malay copy is our own translation of our own English.
  - No "Google" in the app name or icon. "Remotely for Android TV" stays the placeholder name in both languages; "for Android TV" appears in descriptive text only.
  - No secrets: nothing in this phase adds config files or ids. `secrets_are_git_ignored` keeps passing.
  - **All TV I/O lives in `packages/atv_remote`.** The fake TV is part of that package; app code under `lib/` never imports `package:atv_remote/testing.dart` (Task 8.2's scan test).
- **Strings (Ruling P8-R2):** every new English string of Phase 8 is added to `app/lib/app/l10n/app_en.arb` in **Task 8.1**, each with an `@key` description. Later tasks reuse existing keys. A task that finds it needs a string stops and reports the key and copy to the controller. Only Task 8.11 edits `@key` descriptions (the terse-description carry-over); only Tasks 8.12–8.13 create or edit `app_ms.arb`.
- **Navigation model:** pushed pages have a back arrow and a title that names the page; dialogs use `showAppDialog`, sheets `showAppSheet`; no ad on onboarding, discovery, pairing or the remote (decision #6).
- **Accessibility:**
  - Touch targets ≥ 48 dp (≥ 56 dp for remote keys), ≥ 8 dp apart.
  - Every new or changed screen, sheet and dialog is tested at **320 dp width and 200% text**, with the **non-linear** scaler (`test/helpers/nonlinear_text_scaler.dart`), in light and in dark.
  - Colour is never the only signal. Headers carry `Semantics(header: true)`.
- **Layout:** `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional` in new or touched layout code.
- **Platform branches** use `defaultTargetPlatform`. Tests use `testWidgetsOn(...)` from `test/helpers/platform_override.dart`. Never `dart:io Platform` in `app/lib`.
- **Riverpod 3:** `Override` and `ProviderException` from `package:flutter_riverpod/misc.dart`; check `ref.mounted` after every `await` in a notifier; `retry: noRetry` (from `core/session/session_providers.dart`) on providers whose errors the UI shows; hold a `container.listen` across an await on an autoDispose `.future`; auto-dispose actions take their dependencies in the constructor.
- **Time:** production code uses `clock`. Unit and widget tests use `fakeAsync` or `tester.pump(duration)`, with no real waits over 100 ms. **The one exception:** tests that talk to `FakeTvServer` over real sockets (Tasks 8.2, 8.3) wait on conditions with a timeout, never on a fixed delay; the timeout is the failure, not the wait.
- **drift:** widget tests never subscribe to a drift `.watch()` stream; use the in-memory repositories. Tests that need SQL semantics (transactions, rollback) use `AppDatabase(NativeDatabase.memory())` in a plain `test()`.
- **Code generation:** `flutter pub run build_runner build --delete-conflicting-outputs`, then `dart format lib test`, from `app/`. On Windows, revert unrelated `.g.dart` files that changed only in line endings.
- **Goldens:** one `*_golden_test.dart` per subject, `@Tags(['golden'])`, baselines in `goldens/` next to the test, generated on Windows with `flutter test --update-goldens --tags golden <path>`. Inspect every new or changed PNG. **A golden that changes outside its task's "Expected re-baselines" list is a defect.** Never commit `failures/` folders.
- **Where commands run:** `flutter` and `dart` from `app/` (or `packages/atv_remote/`); `check.ps1` and `git` from the repo root.
- **Before every commit:** `powershell -File tool/check.ps1` must print `All checks passed.` (learnings: a run may stall in the test runner; stop it and rerun).
- **Commits** end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Knowledge files:** don't edit `docs/knowledge/{status,decisions,learnings}.md`, `CLAUDE.md` or `.claude/skills/*`. Put knowledge and skill updates in your task report; the controller applies them. **Exceptions:** Task 8.3 creates the performance section's script and Task 8.14 creates `docs/knowledge/device-matrix.md`; those tasks own those new files.
- **Device and owner work** is marked **[device]** or **[owner]**. An implementer without the device says so in the report and never claims the check passed.

## Rulings (conflicts and open questions resolved for this phase)

1. **P8-R1 — Backup and transfer: nothing leaves the phone.** (Release blocker; closes the decision #30 caveat.)
   - **Android:** in `AndroidManifest.xml` `<application>`:
     - `android:allowBackup="false"` (cloud backup and adb backup off on every API level, and device transfer off up to API 30);
     - `android:fullBackupContent="false"`;
     - `android:dataExtractionRules="@xml/data_extraction_rules"`, a new `res/xml/data_extraction_rules.xml` whose `<cloud-backup>` and `<device-transfer>` sections each exclude every domain with `path="."`: `root`, `file`, `database`, `sharedpref`, `external`, `device_root`, `device_file`, `device_database`, `device_sharedpref`. On API 31+ `allowBackup="false"` does **not** stop device-to-device transfer; these rules do.
     - If the manifest merge fails because an SDK declares a conflicting value, add `xmlns:tools` and `tools:replace="android:allowBackup,android:fullBackupContent,android:dataExtractionRules"` (only the attributes that conflict) and report it.
   - **Why off rather than a selective include list:** a restored database is useless without the client identity, and the identity's Android Keystore key never transfers, so `resetOnError` makes a new identity and every TV asks to pair again anyway (the `atv-remote-protocol` skill, "client cert lost"). Backing up settings alone would save a theme choice; it isn't worth a second rules file to keep in sync with the privacy copy. Firebase's local ids are excluded too, which is the private choice.
   - **iOS:**
     - **The database** moves from `Documents/remotely.sqlite` (included in iCloud and computer backups and in Quick Start transfer) to `Library/Application Support/Database/remotely.sqlite`. Swift creates that directory and sets `URLResourceValues.isExcludedFromBackup = true` on it; journal files live beside the database in the same excluded directory. Dart asks for the path over `MethodChannel('com.digitallinked.atvremote/storage')`, method `backupExcludedDatabaseDirectory`, and passes it as `DriftNativeOptions(databaseDirectory:)`. If the channel fails, opening the database fails (repositories already show their error states, status.md "Drift opens lazily"); there is **no fallback to Documents**, which would break the promise.
     - **No migration:** nothing has shipped on iOS, and Android's path is unchanged.
     - **The keychain** item stays `KeychainAccessibility.first_unlock_this_device` (already so). A `ThisDeviceOnly` item is never restored onto another device. It holds our client certificate, not TV data. Task 8.1 pins this with a test.
     - **Preferences** (`NSUserDefaults`) stay in backups. `SettingsStore.keys` holds no TV name, address, MAC, pin or service name; Task 8.1 pins that with a test so a future key can't quietly break the promise.
   - **Copy:** `privacyIntro` and `faqPrivacyA` stay as they are. A new FAQ entry tells users what happens on a new phone (P8-R2).
2. **P8-R2 — Phase 8 strings land in Task 8.1.** Exact copy:

   | Key | Copy | Used for |
   |---|---|---|
   | `faqNewPhoneQ` | `I moved to a new phone. Where are my TVs?` | FAQ question |
   | `faqNewPhoneA` | `Your TVs and their pairing stay on the phone you paired them with. They aren't copied by backups or when you move to a new phone, so pair each TV again on the new phone.` | FAQ answer |
   | `loadingLabel` | `Loading…` | spoken label of every unlabelled progress spinner |
   | `manageAppsMoreOptions` | `More options` | tooltip of the Edit apps overflow menu |
   | `manageAppsMoved` | `{app} moved to position {position} of {count}` (`app` String; `position`, `count` int) | announced after a reorder |

   The FAQ entry goes after `faqPrivacyQ/A` on the Help page.
3. **P8-R3 — The fake TV is a testing library** (amends decision #13's "FakeTvServer stays unexported").
   - `packages/atv_remote/lib/testing.dart` exports `FakeTvServer` only. The implementation moves to `lib/src/testing/fake_tv_server.dart` and `lib/src/testing/fake_tv_identity.dart`. `atv_remote.dart` doesn't export it (`public_api_test` keeps proving the main surface).
   - It is test-only by rule: `app/test/platform/testing_library_imports_test.dart` fails if any file under `app/lib` imports `package:atv_remote/testing.dart`. Release builds tree-shake it anyway, because nothing in `lib/` reaches it.
   - It gains three members for Tasks 8.2–8.3: `Stream<int> get keyCodes` (broadcast, emits each injected key code as it's read), `int get openRemoteConnections` (remote-port sockets not yet closed) and `int get acceptedRemoteConnections` (every remote-port socket ever accepted).
4. **P8-R4 — How integration tests run without CI devices.**
   - Each flow is a function `Future<void> <flow>(WidgetTester t)` in `app/integration_test/flows/<flow>.dart`, written against `pumpRouterApp` and the fake TV.
   - **Host (every `tool/check.ps1`, Windows and Linux):** `app/test/integration/flows_host_test.dart` runs every flow under the normal test binding, tagged `integration`. Real socket progress is driven by `pumpUntil` (Task 8.2), which alternates `tester.runAsync(() => Future<void>.delayed(16 ms))` and `tester.pump()`; fake time never advances, so the 15 s idle timeout and the backoff timers never fire by accident.
   - **Device [device]:** `app/integration_test/<flow>_test.dart` calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` and the same function. Run with `flutter test integration_test/<flow>_test.dart -d <device-id>` from `app/` (the pubspec's `default-flavor: dev` picks the flavor). On an Android emulator or the Note10+ the fake TV binds `127.0.0.1` inside the app process. iOS simulator runs need the Mac.
   - **(unverified)** whether `flutter test integration_test` on Windows can target the host `flutter-tester` device. We don't rely on it: the host runner lives in `app/test/`.
   - `purchase_flow_sandbox` is a manual checklist (`app/integration_test/purchase_flow_sandbox.md`): RevenueCat sandbox purchases need store accounts that tests can't have.
5. **P8-R5 — Performance budgets and how they're measured.**
   - **Key-press-to-send** (master: < 30 ms): measured from the call (`RemoteClient.sendKey` in the package; `RemoteActions.tap` in the app) to `FakeTvServer.keyCodes` emitting, over loopback TLS, 5 warm-up presses then 50 measured presses. The test **prints** the median and p95 and asserts **p95 < 30 ms**. It measures our code path (actions, session, framing, TLS write), not Wi-Fi; the real-network figure comes from the device run.
   - **`no_leak_after_50_resume_cycles`:** 50 cycles of background (grace elapses, socket closed) and resume (reconnected) through the real `SessionSupervisor`, `TvRemoteSession` and `RemoteClient`. Afterwards the fake TV has exactly 1 open remote connection, 51 accepted; the client factory created 51 clients and 50 of them were closed; the signals have exactly the supervisor's listeners. After disposing, 0 open connections and 0 listeners.
   - **Cold start [device]:** target < 1.5 s on the Note10+ (master plan). Measured by `tool/measure_android.ps1` (Task 8.3): the median of 10 `am start -W` `TotalTime`s of a **profile** build after `am force-stop`, plus `timeToFirstFrameMicros` from `flutter run --profile --trace-startup`. **Battery [device]:** 30 minutes connected and idle on the remote screen (keep-awake on, screen on), against a 30-minute baseline with the app force-stopped and the screen on, both read from `dumpsys batterystats`. No pass/fail threshold until the first measurement exists; the owner sets one then.
   - **No number is written anywhere until it was measured.** The results tables in `device-matrix.md` start empty.
6. **P8-R6 — Accessibility audit scope.**
   - **Automated (Task 8.4):** every route, state, sheet and dialog that `phase5_accessibility_test`, `phase6_accessibility_test`, `phase7_accessibility_test` and `remote_accessibility_test` don't already cover gets `textContrastGuideline`, `androidTapTargetGuideline`, `iOSTapTargetGuideline` and `labeledTapTargetGuideline` in light and dark, plus the 320 dp / 200% and non-linear fit checks. The list is in Task 8.4.
   - **Code fixes (Task 8.5):** the Phase 2–6 accessibility carry-overs.
   - **Manual [device]:** TalkBack on the Note10+ and VoiceOver on an iPhone, scripted per screen in `device-matrix.md` (Task 8.14).
7. **P8-R7 — Reduce motion for Radio, Switch and the InputDecorator** (closes decision #47's deferral).
   - In production, reduce motion comes from the platform flag. Flutter's `AnimationController` with the default `AnimationBehavior.normal` then scales durations by 0.05: the decorator's 167 ms becomes about 8 ms, under one 60 Hz frame (16.7 ms). Radio and Switch use controllers with the same default.
   - **Ruling:** under the platform flag, a transition that completes within one frame counts as "no visible animation". Task 8.6 proves it for `Switch`, `Radio` and a focused `TextField`'s decorator with `tester.platformDispatcher.accessibilityFeaturesTestValue`. The MediaQuery-only flag (which production never sets alone, because `MediaQuery` mirrors the platform) is accepted at 167 ms.
   - If any of the three takes longer than one frame under the platform flag, Task 8.6 wraps that widget so that under reduce motion it is re-keyed on its value (a fresh State starts at the final position) with a persistent `FocusNode`, and proves focus survives a toggle.
8. **P8-R8 — Malay.**
   - **Variety:** Malaysian Malay (Bahasa Melayu as used in Malaysia), locale `ms`, one file `app_ms.arb`. Address the user as "anda". Sentence case. Short, plain sentences like the English.
   - **Not translated:** Remotely, Android TV, Google TV, Wi-Fi, Bluetooth, Netflix and every other app name, D-pad, Premium, TV, OK, IP, MAC, mDNS. Placeholders (`{app}`, `{tvName}`, …) are kept verbatim.
   - **Glossary** (use these consistently):

     | English | Malay |
     |---|---|
     | remote (control) | alat kawalan jauh |
     | pair / pairing | gandingkan / penggandingan |
     | connected / reconnecting… / offline | disambungkan / menyambung semula… / luar talian |
     | settings | tetapan |
     | apps / app | apl |
     | volume / mute | kelantangan / senyap |
     | home / back | laman utama / kembali |
     | keyboard | papan kekunci |
     | touchpad | pad sentuh |
     | channel | saluran |
     | power | kuasa |
     | search | cari |
     | help / about | bantuan / perihal |
     | privacy choices | pilihan privasi |
     | advertisement | iklan |
     | restore purchases | pulihkan pembelian |
     | subscription | langganan |
     | try demo | cuba demo |
     | skip / next / get started / continue | langkau / seterusnya / mulakan / teruskan |

   - **Who translates:** the Task 8.12 and 8.13 implementers, as a translation pass. Every Malay string is **[owner] review required** before Phase 9 store copy: the plan records the flag; the owner (or a native reviewer they choose) signs it off in `status.md`.
   - **Language picker:** `kLanguageNames` already names `ms` "Bahasa Melayu". The feedback mail footer stays English (decision #35); the startup-failure screen stays hard-coded English (decision #12).
   - **iOS:** `ios/Runner/ms.lproj/InfoPlist.strings` holds the Malay `NSLocalNetworkUsageDescription` and `NSUserTrackingUsageDescription`, registered in `project.pbxproj` as a `PBXVariantGroup` in the Resources phase, with `ms` in `knownRegions`. `Info.plist` gets `CFBundleLocalizations` = `[en, ms]`. The Android app label isn't translated (it is the brand).
9. **P8-R9 — The pseudo-locale is test-only.**
   - `app/test/helpers/pseudo_localizations.dart` is **generated** by `app/test/app/l10n/pseudo_localizations_test.dart` from `app_en.arb`: under `--update-goldens` (`autoUpdateGoldenFiles`) it writes the file; otherwise it compares and fails when stale (the `brand_icon.svg` pattern, decision #48). The file starts with `// GENERATED by pseudo_localizations_test.dart. Do not edit.`, `// dart format off` and `// ignore_for_file: type=lint`.
   - `class PseudoLocalizations extends AppLocalizationsEn` overrides every getter and method to return `pseudo(super.<key>(...))`, and `PseudoLocalizations.delegate` loads it for any locale.
   - `String pseudo(String s)`: replace `a e i o u c n A E I O U C N` with `á é í ó ú ç ñ Á É Í Ó Ú Ç Ñ`, then append `·` × `(s.length * 0.4).ceil()`, then wrap in `⟦` `⟧`. Placeholder values are already substituted (it wraps the English output), so they survive.
   - No pseudo-locale ships: nothing is added to `supportedLocales`.
10. **P8-R10 — Providers and storage.**
    - `savedDevicesProvider`, `shortcutsProvider` and every other provider whose error the UI shows use `retry: noRetry`, so a `SqliteException` shows the error state at once instead of after ~38 s of retries.
    - A TV's `wolMac` is cleared **together with its pin** whenever the pin is cleared for `serverKeyChanged` (the TV was reset or replaced, so its MAC may be stale). An IP-only merge (`adoptManualDevice`) keeps the MAC: the pin moves with it, the first connection's TOFU check proves the same TV, and if it fails the identity-change rule clears both.
    - `watchMostUsed({int limit, bool Function(String package)? exclude})` filters **before** the limit. Usage is pruned to the 200 most recently seen packages inside `record`'s transaction.
    - After a manual→mDNS merge, a session still pointing at the deleted `manual:` row moves to the merged row, whether the active target names it or (null target) the default session uses it.
    - A throwing `HostResolver` counts as "not found": callers fall back to the saved host.
11. **P8-R11 — Crash scrubbing terms.**
    - Bootstrap reads the saved TVs once (`DeviceRepository.all()`) before `runApp` and seeds `CrashCollection` with them (`seedTerms`), so an error in the first frames is scrubbed of saved names before `watchAll` emits.
    - TVs seen by discovery but not saved are added as **transient** terms (`addDiscoveredTerms`): display name and service name, at most 64, oldest dropped first, kept in memory only, never cleared by a saved-list change.
12. **P8-R12 — One "connection trouble" provider.** `connectionTroubleProvider` (`core/session/connection_trouble.dart`, keepAlive) records the time of the last trouble: entering `reconnecting`, `offline` or `needsPairing` from another status, a failed connect, or a not-connected notice. `Interstitials`, `ReviewPrompter` and `analyticsHooks` read `troubleWithin(Duration)` instead of keeping their own copies. Behaviour is unchanged: their existing tests stay green unmodified.
13. **P8-R13 — Deferred, with reasons** (also in the Phase exit table):
    - `ExcludeSemantics` while theater-dimmed: needs the Voice Access / Switch Access check on a device first (theater never dims with a screen reader on, decision #24). The check is in `device-matrix.md`; the code follows in Phase 9 if the check says so.
    - Collapsing the Apps banner while the keyboard is up: only if AdMob flags covered impressions on the device run.
    - The predictive-back test's private Flutter class name: recheck at the next Flutter bump; Phase 8 doesn't bump Flutter.
    - Android 13 per-app language (`localeConfig`): the in-app picker covers it; Phase 9 with the store listing.
    - Everything already filed under "Phase 9" in `status.md`.

## Review Focus

1. **A phone restored from a backup, or a new phone set up by transfer, must start with no saved TVs, pins, MACs or usage.** The app opens on onboarding or discovery and pairing works as on a fresh install. Tests: Task 8.1 `backup_and_transfer_exclude_every_domain`, `allow_backup_is_off`, `ios_database_opens_in_the_backup_excluded_directory`, `settings_keys_hold_no_tv_data`.
2. **A slow or loaded machine must not turn a correct flow into a flaky one.** The flows wait on conditions with a timeout and a reason, never on fixed delays. Tests: Task 8.2 `pump_until_reports_what_it_waited_for`, the two flows on the host.
3. **Fifty quick background/resume cycles leave exactly one socket and no extra listeners.** Test: Task 8.3 `no_leak_after_50_resume_cycles`.
4. **Malay copy, about a quarter longer than English, never clips a button or a title at 320 dp and 200% text, on any route or sheet.** Tests: Task 8.12 `every_screen_fits_the_pseudo_locale_at_320dp`; Task 8.13 `every_screen_fits_320dp_in_malay_at_200_percent_text`.
5. **A storage failure shows its error state at once, not after ~38 s of silent retries.** Tests: Task 8.7 `shortcuts_error_shows_without_retrying`, `saved_devices_error_shows_without_retrying`.

---

## File Structure

```
packages/atv_remote/
  lib/testing.dart                                     exports FakeTvServer                                (8.2)
  lib/src/testing/fake_tv_server.dart, fake_tv_identity.dart   moved from test/fake_tv/; + keyCodes, connection counts (8.2)
  test/latency_test.dart, test/connection_cycles_test.dart                                                  (8.3)
  lib/src/tv_connection.dart, remote_client.dart       only if 8.9's tests reveal defects
tool/check.ps1, tool/check.sh                          format app/integration_test                         (8.2)
tool/measure_android.ps1, tool/measure_android.sh      cold start, trace, battery                          (8.3)
docs/knowledge/device-matrix.md                        scripted device checklist                           (8.14)
app/
  pubspec.yaml                                         dev: integration_test                               (8.2)
  dart_test.yaml                                       tag integration                                     (8.2)
  android/app/src/main/AndroidManifest.xml, res/xml/data_extraction_rules.xml                               (8.1)
  ios/Runner/AppDelegate.swift                         storage channel                                     (8.1)
  ios/Runner/Info.plist, ms.lproj/InfoPlist.strings, Runner.xcodeproj/project.pbxproj                       (8.12)
  lib/
    app/l10n/app_en.arb                                Phase 8 strings (8.1); descriptions (8.11)
    app/l10n/app_ms.arb                                Malay (8.12 first half, 8.13 second half)
    app/widgets/app_dialog.dart                        route semantics, narrow insets                      (8.5)
    app/widgets/settings_button.dart                   extracted Settings IconButton                       (8.11)
    app/app_shell.dart                                 demo strip inert under a modal                      (8.5)
    core/storage/app_database.dart, database_location.dart   iOS excluded directory                       (8.1)
    core/storage/device_repository.dart                all(), wolMac with pin                              (8.7, 8.8)
    core/storage/storage_providers.dart                noRetry                                             (8.7)
    core/session/connection_trouble.dart               connectionTroubleProvider                           (8.8)
    core/crash/crash_collection.dart                   seedTerms, addDiscoveredTerms                       (8.8)
    core/config/update_gate.dart                       live region                                         (8.5)
    core/device/screen_services.dart                   narrowed catches                                    (8.10)
    features/apps/...                                  noRetry, usage pruning, move announce, menu tooltip (8.5, 8.7)
    features/discovery/...                             merge follow-up, discovered terms, NSD stop         (8.7, 8.8, 8.9)
    features/remote/presentation/widgets/{dpad,remote_body}.dart   D-pad fixes, directional insets         (8.10)
    features/settings/presentation/help_page.dart      FAQ entry                                           (8.1)
  integration_test/
    flows/discover_pair_press_key_flow.dart, flows/demo_mode_flow.dart                                      (8.2)
    discover_pair_press_key_flow_test.dart, demo_mode_flow_test.dart, purchase_flow_sandbox.md              (8.2)
  test/
    helpers/pump_until.dart, helpers/fake_tv_harness.dart                                                   (8.2)
    helpers/pump_router_app.dart                       testAppOverrides (8.3); locale + delegates (8.12)
    helpers/a11y.dart, helpers/fit_checks.dart                                                              (8.4, 8.5)
    helpers/pseudo_localizations.dart                  generated                                           (8.12)
    flutter_test_config.dart                           drift multiple-database warning off                 (8.11)
    integration/flows_host_test.dart, integration/latency_test.dart, integration/resume_cycles_test.dart  (8.2, 8.3)
    platform/backup_rules_test.dart, platform/testing_library_imports_test.dart, platform/ios_malay_test.dart (8.1, 8.2, 8.12)
    app/phase8_accessibility_test.dart, app/reduce_motion_controls_test.dart                                (8.4, 8.6)
    app/l10n/arb_parity_test.dart, app/l10n/pseudo_localizations_test.dart, app/l10n_overflow_test.dart     (8.12, 8.13)
    app/phase8_flow_test.dart                                                                               (8.15)
```

| Task | Master task | Deliverable | Needs |
|---|---|---|---|
| 8.1 | carry-over (blocker) | Backup and transfer off; iOS excluded DB directory; Phase 8 strings; new-phone FAQ | Mac to verify Swift [owner] |
| 8.2 | 8.1 | Fake TV testing library; two flows on host and device; purchase checklist | emulator optional [device] |
| 8.3 | 8.4 | Latency and leak tests; measurement scripts | measuring [device] |
| 8.4 | 8.2 | Accessibility sweep of every uncovered screen, sheet and state | — |
| 8.5 | carry-overs | Accessibility fixes (Phases 2–6) | — |
| 8.6 | carry-over (#47) | Reduce motion for Radio, Switch, InputDecorator; popup and reorder checks | — |
| 8.7 | carry-overs | Providers and storage hardening | — |
| 8.8 | carry-overs | Crash scrubbing terms; one connection-trouble provider | — |
| 8.9 | carry-overs | Protocol, NSD and session tests and fixes | — |
| 8.10 | carry-overs | Remote screen: Phase 4 code and tests | — |
| 8.11 | carry-overs | Test debt and duplication | — |
| 8.12 | 8.5 | Malay part 1: infrastructure, pseudo-locale, iOS strings, first half | owner review [owner] |
| 8.13 | 8.5 | Malay part 2: second half, strict parity, Malay overflow sweep | owner review [owner] |
| 8.14 | 8.3 | `device-matrix.md` with TalkBack/VoiceOver and performance scripts | executed later [owner][device] |
| 8.15 | exit | Seams, full check, dev APK and merged-manifest check | — |

**Order** (one implementer at a time in the shared tree):
- **8.1 first:** the blocker, and it adds every Phase 8 string.
- **8.2 before 8.3:** 8.3 uses the testing library and the harness.
- **8.4 before 8.5:** the sweep finds what 8.5 fixes; 8.5 turns the sweep's documented skips into passes.
- **8.6–8.11** in order; they share few files (`pump_router_app.dart`: 8.3 and 8.12 add parameters; `device_repository.dart`: 8.7 then 8.8).
- **8.12–8.13 after every layout task**, so the overflow sweeps see the final layouts.
- **8.14, then 8.15 last.**

---

### Task 8.1: RELEASE BLOCKER — backup and transfer rules, the iOS database location, Phase 8 strings

**Files:**
- Modify:
  - `app/android/app/src/main/AndroidManifest.xml`
  - `app/ios/Runner/AppDelegate.swift`
  - `app/lib/core/storage/app_database.dart` (`AppDatabase.open`)
  - `app/lib/core/storage/storage_providers.dart` (`appDatabaseProvider` uses the location)
  - `app/lib/app/l10n/app_en.arb` (the five P8-R2 keys)
  - `app/lib/features/settings/presentation/help_page.dart` (the FAQ entry)
- Create:
  - `app/android/app/src/main/res/xml/data_extraction_rules.xml`
  - `app/lib/core/storage/database_location.dart`
  - `app/test/platform/backup_rules_test.dart`
  - `app/test/core/storage/database_location_test.dart`
- Test: `app/test/core/storage/identity_store_test.dart`, `app/test/core/storage/settings_store_test.dart`, `app/test/features/settings/help_page_test.dart`, `app/test/app/l10n/app_localizations_test.dart`

**Interfaces:**
- Consumes: `DriftNativeOptions(databaseDirectory: Future<Object> Function()?)` (drift_flutter 0.3.1), `FlutterSecureKeyValueStore.defaultStorage`, `SettingsStore.keys`.
- Produces:
  - `const MethodChannel storageChannel = MethodChannel('com.digitallinked.atvremote/storage');`
  - `Future<Object> Function()? databaseDirectoryFor(TargetPlatform platform, {MethodChannel channel = storageChannel})`: `null` on every platform except iOS (drift's default, Documents/`app_flutter` on Android). On iOS a function that calls `backupExcludedDatabaseDirectory` and returns the path; a `null` result or a `PlatformException` throws `StateError('no backup-excluded database directory')`.
  - `AppDatabase.open({Future<Object> Function()? databaseDirectory})` → `driftDatabase(name: 'remotely', native: DriftNativeOptions(databaseDirectory: databaseDirectory))`. `appDatabaseProvider` passes `databaseDirectoryFor(defaultTargetPlatform)`.
  - Swift, in `didInitializeImplicitFlutterEngine` after plugin registration (the messenger comes from the engine bridge; **(unverified)** the exact accessor name on `FlutterImplicitEngineBridge` in 3.44.1, check on the Mac):

    ```swift
    let storage = FlutterMethodChannel(name: "com.digitallinked.atvremote/storage", binaryMessenger: messenger)
    storage.setMethodCallHandler { call, result in
      guard call.method == "backupExcludedDatabaseDirectory" else { return result(FlutterMethodNotImplemented) }
      do {
        var dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
          .appendingPathComponent("Database", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try dir.setResourceValues(values)
        result(dir.path)
      } catch { result(FlutterError(code: "storage", message: "unavailable", details: nil)) }
    }
    ```
  - The P8-R2 ARB keys, and a Help FAQ item `faqNewPhoneQ` / `faqNewPhoneA` after the privacy item.

- [ ] **Step 1: Write the failing tests**

```dart
// backup_rules_test.dart (reads files relative to app/ with string/RegExp checks, like android_queries_test.dart;
// no new XML package)
test('allow_backup_is_off', ...)
    // <application> has android:allowBackup="false" and android:fullBackupContent="false"
test('data_extraction_rules_are_referenced', ...)
    // android:dataExtractionRules="@xml/data_extraction_rules" and res/xml/data_extraction_rules.xml exists
test('backup_and_transfer_exclude_every_domain', ...)
    // <cloud-backup> and <device-transfer> each contain exactly the 9 P8-R1 domains as <exclude domain="…" path="."/>,
    // and no <include
test('the_privacy_promise_is_backed_by_the_rules', ...)
    // app_en.arb privacyIntro contains 'never leave this phone' AND allow_backup_is_off's facts hold
    // (fails if someone edits one without the other; the reason string says which file to read)

// database_location_test.dart
test('android_uses_drifts_default_directory', ...)  // databaseDirectoryFor(TargetPlatform.android) == null
test('ios_database_opens_in_the_backup_excluded_directory', ...)
    // TestDefaultBinaryMessengerBinding mock handler on storageChannel returns '/x/Application Support/Database'
    // → await databaseDirectoryFor(TargetPlatform.iOS)!() == '/x/Application Support/Database'; exactly one call,
    //   method 'backupExcludedDatabaseDirectory'
test('ios_without_an_excluded_directory_never_falls_back_to_documents', ...)
    // handler throws PlatformException / returns null → throwsStateError

// identity_store_test.dart
test('ios_keychain_item_never_leaves_this_device', ...)
    // FlutterSecureKeyValueStore.defaultStorage.iOptions.accessibility == KeychainAccessibility.first_unlock_this_device
    // (and the options' synchronizable flag is false)

// settings_store_test.dart
test('settings_keys_hold_no_tv_data', ...)
    // SettingsStore.keys == the 23 keys of today, verbatim; none matches /device|tv|host|mac|pin|service/i
    // (a new key must be added here on purpose)

// help_page_test.dart
testWidgets('faq_explains_a_new_phone', ...)   // the FAQ shows 'I moved to a new phone. Where are my TVs?' after the privacy item;
                                               // expanding shows faqNewPhoneA

// app_localizations_test.dart
test('phase_8_strings_load', ...)
    // l.manageAppsMoved('Netflix', 2, 5) == 'Netflix moved to position 2 of 5'; l.loadingLabel == 'Loading…';
    // l.manageAppsMoreOptions == 'More options'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/platform/backup_rules_test.dart test/core/storage test/features/settings/help_page_test.dart test/app/l10n`
Expected: FAIL (no rules file, no `database_location.dart`, missing keys). `ios_keychain_item_never_leaves_this_device` and `settings_keys_hold_no_tv_data` may already pass; they are pins.

- [ ] **Step 3: Implement.**
  1. The manifest attributes and `data_extraction_rules.xml` (P8-R1).
  2. `database_location.dart`, `AppDatabase.open({databaseDirectory})`, the provider.
  3. The Swift channel.
  4. The ARB keys, `flutter pub get` (regenerates l10n), the FAQ item.
  5. `dart format lib test`.
- [ ] **Step 4: Prove the merged manifest**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds. Then open `build/app/intermediates/merged_manifest/devDebug/processDevDebugMainManifest/AndroidManifest.xml` (or the path Gradle 9 uses; name it in the report) and confirm `allowBackup="false"`, `fullBackupContent="false"` and `dataExtractionRules` survived the merge. If the merge failed, apply the `tools:replace` fallback from P8-R1 and report which SDK conflicted.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** the Help goldens (`test/features/settings/help_golden_test.dart`), if they show the FAQ list. Nothing else.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/android/app/src/main app/ios/Runner/AppDelegate.swift app/lib app/test
git commit -m "fix(app): keep TV data out of backups and device transfer on Android and iOS" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**[owner][device]:** on the Mac, `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign`, run on an iPhone or simulator, and confirm the database file is under `Library/Application Support/Database/` and the directory reports `isExcludedFromBackup` (`xcrun simctl get_app_container booted <bundle> data`, then check the attribute). On Android: Settings → System → Backup shows no data for the app after `adb shell bmgr backupnow com.digitallinked.atvremote.dev`. Both rows are in `device-matrix.md`.

Report: decision P8-R1 (supersedes the decision #30 caveat), P8-R2; the merged-manifest path; the `store-release` skill edit (the release-blocker checkbox becomes "done: allowBackup off, extraction rules exclude everything, iOS DB excluded"); the closed carry-over.

---

### Task 8.2: The fake TV as a testing library, and the integration flows

**Files:**
- Move (git mv): `packages/atv_remote/test/fake_tv/fake_tv_server.dart` → `packages/atv_remote/lib/src/testing/fake_tv_server.dart`; `packages/atv_remote/test/fake_tv/fake_tv_identity.dart` → `packages/atv_remote/lib/src/testing/fake_tv_identity.dart`
- Create:
  - `packages/atv_remote/lib/testing.dart`
  - `app/integration_test/flows/discover_pair_press_key_flow.dart`, `app/integration_test/flows/demo_mode_flow.dart`
  - `app/integration_test/discover_pair_press_key_flow_test.dart`, `app/integration_test/demo_mode_flow_test.dart`
  - `app/integration_test/purchase_flow_sandbox.md`
  - `app/test/helpers/pump_until.dart`, `app/test/helpers/fake_tv_harness.dart`
  - `app/test/integration/flows_host_test.dart`
  - `app/test/platform/testing_library_imports_test.dart`
- Modify: every package test that imported `fake_tv/fake_tv_server.dart` or `fake_tv_identity.dart` (now `package:atv_remote/testing.dart`, or `package:atv_remote/src/testing/...` for `trustClientCertificate`); `packages/atv_remote/test/fake_tv/fake_tv_server_test.dart` (new members); `app/pubspec.yaml`, `pubspec.lock`; `app/dart_test.yaml` (tag `integration`); `tool/check.ps1`, `tool/check.sh` (format `app/integration_test`)

**Interfaces:**
- Consumes: `FakeTvServer.start`, `FakeTvServer.trustClient`, `displayedCode`, `receivedKeyCodes`, `waitForActiveClient`; `pumpRouterApp`; `FakeTvDiscoveries`; `testIdentity` from `test/helpers/test_identity.dart`; `remoteClientFactoryProvider`, `pairingClientFactoryProvider`, `tvDiscoveryFactoryProvider`.
- Produces:
  - `package:atv_remote/testing.dart` exporting `FakeTvServer` (P8-R3), plus on it: `Stream<int> get keyCodes`, `int get openRemoteConnections`, `int get acceptedRemoteConnections`.
  - `Future<void> pumpUntil(WidgetTester t, bool Function() condition, {Duration timeout = const Duration(seconds: 20), required String reason})`: loops `await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)))` then `await t.pump()` until `condition()`; on timeout throws `TestFailure('Timed out after $timeout waiting for $reason')`.
  - `class FakeTvHarness { static Future<FakeTvHarness> start(WidgetTester t); FakeTvServer get tv; DiscoveredTv get discovered; List<Override> get overrides; Future<void> close(); }`:
    - starts the server inside `t.runAsync`, calls `FakeTvServer.trustClient(testIdentity())`;
    - `discovered` = `DiscoveredTv(serviceName: 'Fake TV', displayName: 'Fake TV', host: '127.0.0.1', port: tv.remotePort, isLegacyService: false)`;
    - `overrides`: `tvDiscoveryFactoryProvider` → a `FakeTvDiscoveries` that emits `[discovered]` on `watch()`; `pairingClientFactoryProvider` → `({required host, required identity}) => PairingClient(host: host, port: tv.pairingPort, identity: identity)`; `remoteClientFactoryProvider` → the **real** factory body (`RemoteClient(host:, port:, identity:, deviceInfo: deviceInfoFor(Flavor.dev))`).
  - Flows: `Future<void> discoverPairPressKeyFlow(WidgetTester t)`, `Future<void> demoModeFlow(WidgetTester t)`.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/atv_remote/test/fake_tv/fake_tv_server_test.dart (additions)
test('key_codes_stream_emits_each_injected_key', ...)          // sendKey(home) → keyCodes emits 3
test('counts_open_and_accepted_remote_connections', ...)      // connect → open 1 / accepted 1; client close → open 0 / accepted 1

// app/test/platform/testing_library_imports_test.dart
test('app_lib_never_imports_the_testing_library', ...)
    // no file under lib/ contains "package:atv_remote/testing.dart"
test('the_main_barrel_does_not_export_the_fake_tv', ...)
    // ../packages/atv_remote/lib/atv_remote.dart has no 'testing' export

// app/test/integration/pump_until_test.dart
testWidgets('pump_until_reports_what_it_waited_for', ...)
    // condition never true, timeout 100 ms → TestFailure whose message contains the reason

// app/integration_test/flows/discover_pair_press_key_flow.dart
Future<void> discoverPairPressKeyFlow(WidgetTester t) async {
  // harness = FakeTvHarness.start(t); addTearDown(harness.close)
  // pumpRouterApp(initialLocation: AppRoutes.discover, overrides: harness.overrides, settle: false)
  // pumpUntil 'Fake TV' listed → tap it → pumpUntil the code field is shown and harness.tv.displayedCode != null
  // enterText(code field, harness.tv.displayedCode!) → pumpUntil RemoteScreen with a 'Connected' status pill
  // tap the Home key (find.bySemanticsLabel('Home')) → pumpUntil harness.tv.receivedKeyCodes.contains(KeyCodes.home)
  // tap Volume up → pumpUntil receivedKeyCodes.contains(KeyCodes.volumeUp)
  // the saved device has a non-null serverKeyPin (read through the overridden repository)
}

// app/integration_test/flows/demo_mode_flow.dart
Future<void> demoModeFlow(WidgetTester t) async {
  // counting wrappers on remoteClientFactoryProvider and pairingClientFactoryProvider (both must stay 0)
  // pumpRouterApp(AppRoutes.onboarding) → 'Try demo' → RemoteScreen with the Demo badge and the TV preview card
  // Volume up → preview shows the volume line; D-pad tab → Up → preview shows it; open the keyboard, type 'hi' →
  // preview shows typed text; leave demo from the strip → confirm → DiscoveryScreen; no sockets were ever created
}

// app/test/integration/flows_host_test.dart   @Tags(['integration'])
testWidgets('discover_pair_press_key_flow', discoverPairPressKeyFlow, timeout: const Timeout(Duration(minutes: 2)));
testWidgets('demo_mode_flow', demoModeFlow);

// app/integration_test/<flow>_test.dart: IntegrationTestWidgetsFlutterBinding.ensureInitialized(); the same testWidgets
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run (from `packages/atv_remote/`): `flutter test test/fake_tv`
Run (from `app/`): `flutter test test/platform/testing_library_imports_test.dart test/integration`
Expected: FAIL (no testing library, members, helpers or flows).

- [ ] **Step 3: Implement.**
  1. `git mv` the two files; fix imports across `packages/atv_remote/test`; add `lib/testing.dart` and the three members. Run `dart analyze --fatal-infos` from `packages/atv_remote/` (every public member documented).
  2. `flutter pub add 'dev:integration_test:{"sdk":"flutter"}'` from `app/`.
  3. The helpers, the harness, the flows and both entrypoint sets. The host test imports the flows by relative path (`../../integration_test/flows/...`).
  4. Add `integration` to `dart_test.yaml` tags; add `app/integration_test` to the format lists in `check.ps1` and `check.sh`.
  5. Write `purchase_flow_sandbox.md`: a checklist with preconditions (dev flavor, `env/dev.json` with RevenueCat dev keys, Play licence tester / App Store sandbox tester, the products and entitlement of `app-services`) and these rows, each "Steps / Expected / Result (Pass, Fail, Not run) / Date / Notes":
     - buy monthly; buy yearly; buy lifetime (each: Premium at once, banner gone on `/apps` and `/settings`, paywall closes to its source with no "You have Premium" flash);
     - cancel in the store sheet (no change, no error snackbar beyond the cancelled notice);
     - restore on a fresh install ("Restoring your purchases…", Premium);
     - offline launch with a cached entitlement (no ad flash, decision #42);
     - refund or expiry (next launch free; the UMP form shows again in the EEA, P7-R9);
     - airplane mode during purchase (a clear error, the screen never stays busy);
     - Premium styles apply only while Premium.
  6. `dart format` the touched Dart directories.
- [ ] **Step 4: Run the tests and confirm they pass**

Run (from `packages/atv_remote/`): `flutter test`
Run (from `app/`): `flutter test`
Expected: all PASS; the two host flows finish in well under their timeouts (note the times in the report).

- [ ] **Step 5 [device, optional]: Run the flows on an emulator or device**

Run: `flutter test integration_test/discover_pair_press_key_flow_test.dart -d <emulator-id>` and the same for `demo_mode_flow_test.dart`
Expected: both PASS. If no emulator or device is available, say so; it is a row in `device-matrix.md`.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add packages/atv_remote app/pubspec.yaml pubspec.lock app/dart_test.yaml app/integration_test app/test tool/check.ps1 tool/check.sh
git commit -m "test: fake TV testing library and discover-pair-press and demo integration flows" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report: decisions P8-R3 (amends #13) and P8-R4; whether host `flutter test integration_test` worked on Windows (the (unverified) item); host run times; the `flutter-app-architecture` skill edit (integration tests: where they live, how to run them on host and device).

---

### Task 8.3: Performance — latency, the resume-cycle leak test and measurement scripts

**Files:**
- Create:
  - `packages/atv_remote/test/latency_test.dart`, `packages/atv_remote/test/connection_cycles_test.dart`
  - `app/test/integration/latency_test.dart`, `app/test/integration/resume_cycles_test.dart`
  - `tool/measure_android.ps1`, `tool/measure_android.sh`
- Modify: `app/test/helpers/pump_router_app.dart` (extract the defaults as `testAppOverrides`)

**Interfaces:**
- Consumes: Task 8.2's `keyCodes`, `openRemoteConnections`, `acceptedRemoteConnections`, `FakeTvHarness`; `SessionSupervisor(session:, signals:, backgroundGrace:, now:)`; `TvRemoteSession`; `ManualSessionSignals` (its listener counts); `remoteActionsProvider`.
- Produces:
  - `List<Override> testAppOverrides({required SettingsStore store, required AppDatabase db, required String initialLocation})`: today's private `_defaults`, made public; `pumpRouterApp` and `pumpRealApp` call it.
  - `({Duration median, Duration p95}) latencyStats(List<Duration> samples)` in `app/test/integration/latency_test.dart` (and a copy in the package test; the two packages don't share test code).
  - `tool/measure_android.ps1 -Mode startup|trace|battery [-Runs 10] [-Minutes 30] [-Package com.digitallinked.atvremote.dev]` and the `.sh` twin. Each writes raw output to `build/measurements/<yyyyMMdd-HHmmss>-<mode>/` and prints a summary:
    - `startup`: requires an installed profile build (`flutter build apk --profile --flavor dev -t lib/main_dev.dart` then `adb install -r`); per run `adb shell am force-stop <pkg>`, a 2 s pause, `adb shell am start -W -n <pkg>/com.digitallinked.atvremote.MainActivity`; parses `TotalTime:`; prints every run and the median.
    - `trace`: runs `flutter run --profile --trace-startup --flavor dev -t lib/main_dev.dart` (from `app/`) and prints `timeToFirstFrameMicros` and `timeToFirstFrameRasterizedMicros` from `build/start_up_info.json`.
    - `battery`: `adb shell dumpsys batterystats --reset`, prints "Unplug, open the remote connected to the TV, leave it for N minutes", waits N minutes, saves `adb shell dumpsys batterystats --charged <pkg>` and the "Estimated power use" lines. Run it twice: once on the remote, once as the baseline with the app force-stopped (P8-R5).

- [ ] **Step 1: Write the failing tests**

```dart
// packages/atv_remote/test/latency_test.dart
test('key_press_reaches_the_fake_tv_within_30ms', () async {
  // paired RemoteClient connected to FakeTvServer; 5 warm-up presses; 50 measured presses:
  // listen to tv.keyCodes first, Stopwatch, client.sendKey(KeyCodes.dpadUp), await the event
  // print('key latency median=${s.median.inMicroseconds}us p95=${s.p95.inMicroseconds}us')
  // expect(s.p95, lessThan(const Duration(milliseconds: 30)))
});

// packages/atv_remote/test/connection_cycles_test.dart
test('no_socket_leak_after_50_disconnect_connect_cycles', ...)
    // TvConnection with a counting client factory: 50 × (disconnect(); connect()) →
    // tv.openRemoteConnections == 1, tv.acceptedRemoteConnections == 51; dispose → open 0

// app/test/integration/latency_test.dart  @Tags(['integration'])
test('key_press_to_send_under_30ms', ...)
    // ProviderContainer(overrides: testAppOverrides(...) + the harness's real client factory, a saved device pointing at
    // the fake TV with its pin); hold container.listen(remoteActionsProvider); wait for connected;
    // 5 warm-ups, 50 measured RemoteActions.tap(KeyCodes.dpadUp) → keyCodes; print median/p95; p95 < 30 ms

// app/test/integration/resume_cycles_test.dart  @Tags(['integration'])
test('no_leak_after_50_resume_cycles', ...)
    // TvRemoteSession (real RemoteClient via a counting factory) + SessionSupervisor(backgroundGrace: Duration.zero,
    // now: a clock the test moves 61 s per background) + ManualSessionSignals;
    // per cycle: signals.background() → wait for status disconnected; signals.foreground() → wait for connected
    // after 50: tv.openRemoteConnections == 1, accepted == 51, factory.created == 51, factory.closed == 50,
    // signals' visibility/network listener counts == what the supervisor holds (1 each);
    // supervisor.dispose(); session.dispose() → open 0, listeners 0
```

Waits use a `Future<void> waitFor(bool Function() condition, {required String reason, Duration timeout = const Duration(seconds: 20)})` polling every 10 ms (plain `test()`, real time).

- [ ] **Step 2: Run the tests and confirm they fail**

Run (from `packages/atv_remote/`): `flutter test test/latency_test.dart test/connection_cycles_test.dart`
Run (from `app/`): `flutter test test/integration/latency_test.dart test/integration/resume_cycles_test.dart`
Expected: FAIL (`testAppOverrides` missing). The package tests may pass at once; that is acceptable (they measure, they don't drive new code). Note it in the report.

- [ ] **Step 3: Implement** `testAppOverrides`, the tests and the two scripts. Fix any leak the tests reveal in the file that owns it and name it in the report.
- [ ] **Step 4: Run the tests and confirm they pass**

Run (from `app/`): `flutter test`
Expected: all PASS. Copy the printed median and p95 of both latency tests into the report, with the machine (they are host numbers, not device numbers).

- [ ] **Step 5: Smoke-test the scripts without a device.** Run `powershell -File tool/measure_android.ps1 -Mode startup` with no device attached.
Expected: a clear "no device" error and a non-zero exit, not a hang.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add packages/atv_remote/test app/test tool/measure_android.ps1 tool/measure_android.sh
git commit -m "test: key-press latency, 50-cycle resume leak test and Android measurement scripts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report: decision P8-R5; the host latency numbers (labelled host); any leak found and fixed. **[device]** the cold-start and battery runs belong to Task 8.14's matrix.

---

### Task 8.4: Accessibility audit — every screen, sheet and state not yet covered

**Files:**
- Create: `app/test/helpers/a11y.dart`, `app/test/app/phase8_accessibility_test.dart`
- Modify: production files only to fix defects the sweep reveals that **aren't** in Task 8.5's list (name each in the report). A failure that Task 8.5 owns is marked `skip: 'Task 8.5: <item>'` and counted in the report.

**Interfaces:**
- Consumes: `pumpRouterApp`, `FakeRemoteSession`, `FakeTvDiscoveries`, `FakePairingClients`, `TestPremium`, `nonlinear_text_scaler.dart`, `testWidgetsOn`.
- Produces:
  - `Future<void> expectMeetsGuidelines(WidgetTester t, {required String reason})`: the four guidelines in order (`textContrastGuideline`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`).
  - `Future<T> withSemantics<T>(WidgetTester t, Future<T> Function() body)`: `ensureSemantics` and dispose in `try`/`finally` (learnings: not `addTearDown`).
  - `void expectNoClipping(WidgetTester t, {required String reason})`: `t.takeException()` is null.
- **The screens** (each a named entry in a `_screens` map like Phase 7's, opened as a user would meet it, in light and dark):

  | Name | Route / how it opens |
  |---|---|
  | `discovery_searching` | `/discover`, no TVs yet (spinner) |
  | `discovery_empty` | `/discover` after 10 s with no TVs (troubleshooting link) |
  | `discovery_legacy_tv` | a legacy-service TV in the list |
  | `manual_ip_sheet`, `manual_ip_sheet_invalid` | "Enter IP address"; then `999.1.1.1` |
  | `troubleshooting_sheet_from_discovery`, `legacy_service_sheet` | their links |
  | `pairing_waiting_for_code` | `/pair/<tv>` once the fake pairing client shows a code |
  | `pairing_verifying` | a submitted code, the fake holding the answer |
  | `pairing_bad_code`, `pairing_timed_out`, `pairing_not_found` | the fake's failures |
  | `remote_reconnecting`, `remote_offline`, `remote_needs_pairing` | `FakeRemoteSession` statuses |
  | `remote_colour_row`, `remote_media_row` | quick row setting |
  | `remote_theater_palette` | the theater theme applied (as `remote_theater_golden_test` does) |
  | `demo_remote` | the demo session: badge, strip, preview card |
  | `keyboard_sheet`, `keyboard_sheet_not_connected` | the keyboard key |
  | `wol_setup_sheet` | Power hold with no MAC while disconnected |
  | `device_switcher_sheet` | tap the TV switcher with two saved TVs |
  | `identity_changed_dialog` | a `serverKeyChanged` from the fake session |
  | `remote_session_error` | the identity store failing twice |
  | `startup_failure` | the bootstrap fallback screen pumped directly |

- [ ] **Step 1: Write the tests**

```dart
// phase8_accessibility_test.dart
for (final b in Brightness.values) {
  for (final name in _screens.keys) {
    _semanticsTest('${name}_meets_the_guidelines_${b.name}', ...)   // expectMeetsGuidelines
  }
}
testWidgets('every_phase8_screen_fits_320dp_at_200_percent_text', ...)    // all names, both brightnesses, expectNoClipping
testWidgets('every_phase8_screen_fits_a_non_linear_text_scaler', ...)
testWidgets('tv_names_ellipsize_at_200_percent_text', ...)
    // a 60-character TV name in the discovery list, the switcher and the pairing title: one line, ellipsis,
    // full name in the semantics label (Phase 3 gap)
testWidgets('pairing_keys_are_48dp_and_code_cells_56dp', ...)            // Phase 3 "48/56 dp" gap, light and dark
testWidgets('pairing_failures_fit_320dp_in_dark', ...)                  // bad code, timeout, not found at 320 dp/200% dark
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/phase8_accessibility_test.dart`
Expected: some may fail. A failure is a real defect: fix it in the owning file (or skip it with the Task 8.5 reason if 8.5 owns it). Don't weaken a test.

- [ ] **Step 3: Fix** what the sweep revealed outside Task 8.5's list.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS (with only the Task 8.5 skips).

**Expected re-baselines:** only goldens of screens a fix touched; list each with its fix.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): accessibility sweep of every remaining screen, sheet and state" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision P8-R6; every defect and fix; every Task 8.5 skip.

---

### Task 8.5: Accessibility carry-overs (Phases 2–6)

**Files:**
- Modify:
  - `app/lib/app/widgets/app_dialog.dart` (route semantics; narrow insets)
  - `app/lib/app/app_shell.dart` (demo strip inert under a modal)
  - `app/lib/features/demo/presentation/tv_preview_card.dart` (one live line)
  - `app/lib/core/config/update_gate.dart` (live region)
  - `app/lib/features/apps/presentation/manage_apps_screen.dart` (handle focus, menu tooltip, move announce)
  - every file in the spinner list below
  - the `FittedBox` callers below, only if their test fails
  - `app/lib/features/remote/presentation/widgets/dpad.dart` (`OrdinalSortKey` only; the hold fix is Task 8.10)
- Create: `app/test/helpers/fit_checks.dart`
- Test: `app/test/app/widgets/app_dialog_test.dart`, `app/test/app/app_shell_test.dart` (create if absent), `app/test/features/demo/demo_mode_test.dart`, `app/test/core/config/update_gate_test.dart`, `app/test/features/apps/manage_apps_screen_test.dart`, `app/test/core/ads/tracking_preprompt_test.dart`, `app/test/features/settings/privacy_choices_page_test.dart`, `app/test/features/remote/widgets/dpad_test.dart`, `app/test/app/phase8_accessibility_test.dart` (remove the 8.5 skips), `app/test/app/theme/colour_styles_test.dart`

**Interfaces:**
- Consumes: Task 8.1's `loadingLabel`, `manageAppsMoreOptions`, `manageAppsMoved`; Task 8.4's helpers.
- Produces:
  - **AppDialog:** its content sits in `Semantics(scopesRoute: true, namesRoute: true, explicitChildNodes: true, label: title)`. `showAppDialog` uses `insetPadding: EdgeInsetsDirectional.symmetric(horizontal: width < 360 ? 16 : 40, vertical: 24)`, and the body scrolls.
  - **Demo strip:** `class ModalRouteTracker extends NavigatorObserver with ChangeNotifier { bool get modalOpen; }` counts `PopupRoute`s pushed/popped/removed/replaced; registered on the router's observers; the strip wraps its Leave button in `IgnorePointer(ignoring: modalOpen)` + `ExcludeSemantics(excluding: modalOpen)`.
  - **Preview card:** only the last-action `Text` is `Semantics(liveRegion: true)`; the card's static title isn't.
  - **Update gate:** its title and body are one `Semantics(liveRegion: true, container: true)`.
  - **Spinners:** `semanticsLabel: l10n.loadingLabel` on the `CircularProgressIndicator`s in `add_app_sheet.dart`, `apps_screen.dart`, `manage_apps_screen.dart`, `devices_screen.dart`, `edit_device_screen.dart`, `discovery_screen.dart`, `pairing_screen.dart` (both), `paywall_screen.dart` (both), `remote_screen.dart`, unless the spinner sits inside an `ExcludeSemantics` next to a visible text that says what is loading (then leave it and say so in the report).
  - **Edit apps:** the drag handle is no keyboard focus stop (`Focus(canRequestFocus: false, skipTraversal: true)` around it; its tooltip and label stay for touch exploration). The overflow `PopupMenuButton` gets `tooltip: l10n.manageAppsMoreOptions`. After a move (framework Move action, or drag end), focus stays on the moved row and `SemanticsService.sendAnnouncement(View.of(context), l10n.manageAppsMoved(name, position, count), Directionality.of(context))` runs (`position` is 1-based). **(unverified)** the announcement API name in 3.44.1 (`SemanticsService.announce` is the older one); use whichever exists and report it.
  - **D-pad:** each region gets `OrdinalSortKey` so a screen reader reads Up, Left, OK, Right, Down.
  - **FittedBox labels (Phase 2):** at text scale 1.0 no fitted label shrinks (its effective scale is 1); at 200% the effective font size (scaled font × fit scale) is never below the unscaled base size. Callers: `rocker.dart`, `app_tile.dart`, `number_pad.dart`, `pad_pager.dart`, `quick_access_row.dart`, `remote_layout_page.dart`.
  - `void expectWithinViewport(WidgetTester t, Finder f, {required String reason})`: the widget's rect lies inside its nearest `Scrollable`'s viewport rect (or the screen if none), after `ensureVisible` (Phase 6 "fit checks bounded by the scroll viewport").

- [ ] **Step 1: Write the failing tests**

```dart
// app_dialog_test.dart
testWidgets('dialog_names_its_route_with_the_title', ...)   // semantics node with namesRoute + scopesRoute, label == title
testWidgets('dialog_body_is_at_least_288dp_wide_on_a_320dp_screen', ...)

// app_shell_test.dart (or demo_mode_test.dart)
testWidgets('demo_strip_leave_is_inert_while_a_sheet_is_open', ...)
    // demo remote; open the keyboard sheet; tap the strip's Leave → no dialog; semantics tree has no Leave action;
    // close the sheet → Leave works again
testWidgets('only_the_last_action_line_is_a_live_region', ...)

// update_gate_test.dart
testWidgets('update_gate_announces_itself', ...)            // one liveRegion node containing 'Update required'

// manage_apps_screen_test.dart
testWidgets('tab_order_skips_the_drag_handle', ...)          // FocusTraversal from 'Edit Netflix' → 'Remove Netflix' → next row's 'Edit …'
testWidgets('overflow_menu_is_named_more_options', ...)      // find.byTooltip('More options')
testWidgets('a_move_keeps_focus_and_announces_the_position', ...)
    // perform the 'Move down' custom semantics action on Netflix → announcement 'Netflix moved to position 2 of N';
    // the focused/accessibility-focused node is Netflix's row

// spinners (phase8_accessibility_test.dart)
testWidgets('every_spinner_has_a_spoken_label', ...)
    // the loading states of apps, edit apps, Your TVs, edit TV, discovery, pairing, paywall, remote, add-app sheet:
    // each CircularProgressIndicator has semanticsLabel 'Loading…' or sits in an ExcludeSemantics (listed allowance)

// tracking_preprompt_test.dart (Phase 6 carry-overs)
testWidgets('preprompt_fits_320dp_at_200_percent_text', ...)  // body read from AppLocalizations, not literals;
                                                              // expectWithinViewport for title, body and both buttons
// privacy_choices_page_test.dart
testWidgets('privacy_fits_320dp_at_200_percent_including_the_switch_rows', ...)  // expectWithinViewport for each switch row

// colour_styles_test.dart (P6-C10)
for (final style in ColourStyle.values) for (final b in Brightness.values)
  testWidgets('accent_text_meets_contrast_in_${style.name}_${b.name}', ...)
    // TestPremium active; remote, apps, settings hub, paywall: meetsGuideline(textContrastGuideline)

// dpad_test.dart
testWidgets('screen_reader_order_is_up_left_ok_right_down', ...)

// FittedBox (phase8_accessibility_test.dart)
testWidgets('fitted_labels_never_shrink_at_100_percent_text', ...)
testWidgets('fitted_labels_stay_at_least_base_size_at_200_percent_text', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app test/features test/core/config test/core/ads/tracking_preprompt_test.dart`
Expected: FAIL for each item.

- [ ] **Step 3: Implement** the Produces list, remove the Task 8.5 skips from `phase8_accessibility_test.dart`, then `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS, no skips left in `phase8_accessibility_test.dart`.

**Expected re-baselines:** `app_dialog` goldens only if one is narrower than 360 dp; `tracking_preprompt` goldens at 320 dp if any exist. Name each.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): dialog route names, live regions, spinner labels, reorder announce and narrow dialogs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: every closed carry-over; the announcement API used; spinner allowances; the `remote-design-system` skill edit (dialog insets under 360 dp; live-region rule: one live line, never a whole card).

---

### Task 8.6: Reduce motion for Radio, Switch and the InputDecorator

**Files:**
- Create: `app/test/app/reduce_motion_controls_test.dart`
- Modify: only if a test fails, `app/lib/app/theme/app_theme.dart` (`ReduceMotionTheme`) and new wrappers under `app/lib/app/widgets/` (P8-R7 fallback)
- Test: `app/test/features/apps/manage_apps_screen_test.dart`

**Interfaces:**
- Consumes: `pumpRouterApp(disableAnimations:)`, `tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true)` (clear it in `addTearDown`).
- Produces: nothing new unless the fallback is needed (`AppSwitch`, `AppRadioListTile` re-keyed on value with a persistent `FocusNode`).

- [ ] **Step 1: Write the failing tests**

```dart
// reduce_motion_controls_test.dart (platform flag on)
testWidgets('switch_settles_within_one_frame', ...)        // Remote behaviour: tap Haptics → pump(16 ms) → !t.hasRunningAnimations,
                                                           // the thumb at its end position
testWidgets('radio_settles_within_one_frame', ...)         // Appearance: tap Dark → pump(16 ms) → !hasRunningAnimations
testWidgets('text_field_focus_settles_within_one_frame', ...) // Apps search: tap the field → pump(16 ms) → !hasRunningAnimations
testWidgets('with_motion_the_switch_animates', ...)        // flag off: after pump(16 ms) hasRunningAnimations (proves the test sees motion)

// manage_apps_screen_test.dart (Phase 7 carry-over)
testWidgets('overflow_menu_closes_without_animation', ...) // disableAnimations: open the menu, pick an item: one pump() → menu gone
testWidgets('reorder_drop_does_not_animate_under_reduce_motion', ...)
    // drag a row and drop: one pump() → !hasRunningAnimations; if Flutter's ReorderableListView still animates
    // (learnings, Phase 5), record it as accepted under P8-R7's one-frame rule only if it settles in ≤ 16 ms; otherwise
    // report it as a defect with the measured duration
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/reduce_motion_controls_test.dart test/features/apps/manage_apps_screen_test.dart`
Expected: the platform-flag tests likely PASS (P8-R7's premise); the `with_motion` control passes. If a platform-flag test fails, apply the P8-R7 fallback to that widget and add `toggle_keeps_focus_under_reduce_motion`.

- [ ] **Step 3: Implement** only what failed; `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** none.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): reduce motion settles switches, radios, text fields and menus within a frame" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision P8-R7 (amends #47's deferral); the measured settle time of each control; whether the fallback was needed.

---

### Task 8.7: Providers and storage

**Files:**
- Modify:
  - `app/lib/core/storage/storage_providers.dart` (`savedDevicesProvider` retry)
  - `app/lib/features/apps/application/shortcuts.dart` (`shortcutsProvider` retry)
  - `app/lib/core/storage/device_repository.dart` (`all()`; `clearServerKeyPin` clears the MAC too for `serverKeyChanged`)
  - `app/lib/features/apps/data/app_usage_repository.dart` (`watchMostUsed` filter; pruning)
  - `app/lib/features/apps/data/apps_data_providers.dart` / `domain/recommendations.dart` (pass the system filter)
  - `app/lib/features/discovery/application/discovery_controller.dart` (merge follow-up)
  - the "Pair again" re-resolve and `TvRemoteSession`'s resolver call (throwing resolver)
  - `app/test/helpers/in_memory_device_repository.dart`, `in_memory_app_usage_repository.dart`
- Test: `app/test/core/storage/device_repository_test.dart`, `app/test/features/apps/app_usage_repository_test.dart`, `app/test/features/apps/shortcuts_test.dart`, `app/test/features/apps/apps_screen_test.dart`, `app/test/features/devices/devices_screen_test.dart`, `app/test/features/discovery/discovery_controller_test.dart`, `app/test/core/session/tv_remote_session_test.dart`, `app/test/features/devices/device_actions_test.dart`

**Interfaces:**
- Consumes: `noRetry`, `ref.exists(remoteSessionProvider)`, `isSystemPackage` (whatever `recommendations.dart` uses today).
- Produces (P8-R10):
  - `Future<List<SavedDevice>> DeviceRepository.all()`: most recently connected first (same order as `watchAll`).
  - `clearServerKeyPin(String serviceName, {required String distrustedPin})`: when it clears the pin (only when the stored pin still equals `distrustedPin`, decision #14), it also sets `wolMac` to null in the same update. Its only caller is `TvRemoteSession`'s `serverKeyChanged` path, so the signature doesn't change.
  - `Stream<List<AppUsageStat>> watchMostUsed({int limit = 30, bool Function(String package)? exclude})`: excluded packages are dropped before `limit` is applied.
  - `static const int kUsageKeep = 200;` and `record` deletes everything outside the 200 most recent `lastSeenAt` rows in its transaction.
  - Merge follow-up in the discovery controller: after `adoptManualDevice` returns true, if the active target is `DeviceTarget(manualName)` → activate the merged name (as today); **else if** the active target is null **and** `ref.exists(remoteSessionProvider)` and the built session's device is `manualName` → `ref.container.invalidate(remoteSessionProvider)` so the default session rebuilds on the merged row.
  - Resolver calls: `try { host = await resolve(name).timeout(4 s); } on Object { host = null; }` then the saved host.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('shortcuts_error_shows_without_retrying', ...)
    // apps screen with a shortcut repository whose watchAll throws SqliteException-like Exception:
    // "Couldn't load your apps." after one pumpAndSettle (no 38 s spin), and the repository was subscribed once
testWidgets('saved_devices_error_shows_without_retrying', ...)  // Your TVs, same shape
test('all_returns_every_saved_tv_most_recent_first', ...)        // drift in-memory DB
test('identity_change_clears_the_mac_with_the_pin', ...)
test('ip_only_merge_keeps_the_mac', ...)                         // adoptManualDevice moves wolMac and pin unchanged
test('merge_rolls_back_when_the_delete_fails', ...)
    // a DriftDeviceRepository subclass whose delete throws → adoptManualDevice throws, find(tv.serviceName) == null,
    // the manual row is still there (Phase 5 rollback test)
test('most_used_filters_system_packages_before_the_limit', ...)
    // 30 system packages seen more often than 3 user apps → watchMostUsed(limit: 3, exclude: isSystem) gives the 3 apps
test('usage_keeps_the_200_most_recent_packages', ...)            // record 205 packages → 200 rows, the 5 oldest gone
test('merge_after_leaving_discovery_moves_the_default_session', ...)
    // active target null, session built on manual:192.168.0.20; merge → remoteSessionProvider rebuilt on the mDNS name
test('pair_again_uses_the_saved_host_when_the_resolver_throws', ...)
test('reconnect_keeps_the_saved_host_when_the_resolver_throws', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/storage test/features/apps test/features/devices test/features/discovery test/core/session`
Expected: FAIL for each item.

- [ ] **Step 3: Implement**; regenerate (`build_runner`) for the `@Riverpod` change; `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** none.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): show storage errors at once, prune usage, keep sessions and MACs right across merges" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision P8-R10; the closed Phase 5 provider and storage carry-overs.

---

### Task 8.8: Crash scrubbing terms and one connection-trouble provider

**Files:**
- Create: `app/lib/core/session/connection_trouble.dart`, `app/test/core/session/connection_trouble_test.dart`
- Modify: `app/lib/core/crash/crash_collection.dart`, `app/lib/bootstrap.dart`, `app/lib/features/discovery/application/discovery_controller.dart`, `app/lib/core/ads/interstitials.dart`, `app/lib/core/review/review_prompter.dart`, `app/lib/core/analytics/analytics_hooks.dart`
- Test: `app/test/core/crash/crash_collection_test.dart`, `app/test/bootstrap_test.dart`, `app/test/features/discovery/discovery_controller_test.dart`; the existing `interstitials*_test.dart`, `review_prompter_test.dart`, `analytics_hooks_test.dart` stay **unmodified** and green.

**Interfaces:**
- Consumes: Task 8.7's `DeviceRepository.all()`; `notConnectedNoticesProvider`; `connectionStateProvider`.
- Produces:
  - `CrashCollection.seedTerms(Iterable<SavedDevice> devices)`: adds display names, service names and nicknames now; the next `watchAll` emission replaces the saved part as today.
  - `CrashCollection.addDiscoveredTerms(Iterable<DiscoveredTv> tvs)`: the transient set of P8-R11 (cap 64, oldest out).
  - Bootstrap: after resolving the initial location, `final saved = await devices.all()` (caught; a failure seeds nothing) and `container.read(crashCollectionProvider.notifier).seedTerms(saved)`, before `runApp`.
  - The discovery controller calls `addDiscoveredTerms` with each emitted list.
  - `@Riverpod(keepAlive: true) class ConnectionTrouble extends _$ConnectionTrouble { DateTime? build(); void note(); bool troubleWithin(Duration window); }`: `build` listens to `connectionStateProvider` (entering `reconnecting`/`offline`/`needsPairing` from another status, or a failed connect) and `notConnectedNoticesProvider`, calling `note()` (`state = clock.now()`). The three callers read `troubleWithin(interstitialQuietAfterTrouble)` / `troubleWithin(reviewQuietAfterTrouble)` and drop their own `_lastTroubleAt`.

- [ ] **Step 1: Write the failing tests**

```dart
test('saved_names_are_scrubbed_before_the_first_watch_event', ...)
    // CrashCollection with a repository whose watchAll never emits; seedTerms([savedTv(name: 'Bedroom TV')]);
    // reporter.recordError(StateError('lost Bedroom TV')) → the sink sees no 'Bedroom TV'
testWidgets('bootstrap_seeds_scrub_terms_before_run_app', ...)  // bootstrap test seam: terms present at the first frame
test('discovered_unsaved_names_are_scrubbed', ...)              // addDiscoveredTerms([tv('Kitchen TV')]) → scrubbed
test('discovered_terms_survive_a_saved_list_change_and_cap_at_64', ...)
test('trouble_is_noted_on_entering_reconnecting_offline_or_needs_pairing', ...)
test('trouble_is_noted_on_a_not_connected_notice', ...)
test('trouble_within_is_false_after_the_window', ...)           // fakeAsync / clock.withClock
test('connected_after_connected_is_not_trouble', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/crash test/core/session/connection_trouble_test.dart test/bootstrap_test.dart test/features/discovery`
Expected: FAIL.

- [ ] **Step 3: Implement**, switch the three callers to the provider, regenerate, `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS, with `git diff --stat app/test/core/ads app/test/core/review app/test/core/analytics` empty (behaviour unchanged).

**Expected re-baselines:** none.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): scrub saved and discovered TV names from the first frame; one connection-trouble provider" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decisions P8-R11 (extends #39) and P8-R12; the `app-services` skill edit (scrub terms seeded at bootstrap; trouble provider).

---

### Task 8.9: Protocol, NSD and session tests

**Files:**
- Modify: `app/lib/features/discovery/data/nsd_tv_discovery.dart`; the files that hold unawaited cancel/stop calls (`grep -rn "unawaited(.*\(cancel\|stop\|close\)" app/lib packages/atv_remote/lib`); `packages/atv_remote/lib/src/*.dart` only if a test reveals a defect
- Test:
  - `app/test/features/discovery/data/nsd_tv_discovery_test.dart`
  - `packages/atv_remote/test/key_codes_test.dart`, `cli_helpers_test.dart`, `remote_client_test.dart`, `pairing_client_test.dart`, `tv_connection_test.dart`
  - `app/test/core/session/tv_remote_session_test.dart`, `session_providers_test.dart`, `session_supervisor_test.dart`

**Interfaces:**
- Consumes: `KeyCodes.named`, the CLI's `cliKeyCodes` (`lib/src/cli/key_names.dart`), `RemoteClient.serverPublicKeySha256`.
- Produces:
  - `NsdTvDiscovery`: the stream controller gets `onCancel: stop`; `stop()` completes when the stream was never listened to (it doesn't await `close()` on a controller without a listener).
  - Every `unawaited(x.cancel()/stop()/close())` in `app/lib` and `packages/atv_remote/lib` becomes `unawaited(x.cancel().catchError((Object _) {}))` (or a shared `ignoreErrors(Future<void>)` helper in the owning library), so a failing cancel never surfaces as an unhandled error.

- [ ] **Step 1: Write the failing tests**

```dart
// nsd_tv_discovery_test.dart
test('stop_completes_when_never_listened', ...)      // stop().timeout(1 s) completes
test('cancelling_the_stream_stops_discovery', ...)   // listen then cancel → the fake NSD's stopDiscovery called once
test('a_failing_stop_is_not_an_unhandled_error', ...) // runZonedGuarded: the fake NSD's stop throws → no uncaught error

// key_codes_test.dart (package)
test('named_lists_every_static_key_constant', ...)
    // reads lib/src/key_codes.dart, every `static const <name> = <int>` except digits appears in KeyCodes.named
test('cli_key_names_cover_named_exactly', ...)       // cliKeyCodes.values.toSet() == KeyCodes.named.toSet()

// remote_client_test.dart
test('server_public_key_sha256_is_set_at_remote_ready', ...)  // at the RemoteReady event, non-null and equal to the pairing key

// pairing_client_test.dart
//   widen only the setup budgets around TLS handshakes to 20 s (learnings); keep every asserted timing as it is

// tv_remote_session_test.dart / session_providers_test.dart / session_supervisor_test.dart
test('the_second_tvs_first_volume_is_null', ...)     // switch TVs: volumeProvider is null until the new TV pushes one
test('a_session_built_in_the_background_starts_its_grace_at_provider_level', ...)
    // ManualSessionSignals currentVisibility background → build remoteSessionProvider → 60 s fake → disconnected
```

Also replace the **real-time negative waits** (tests that sleep real time to prove nothing happened) found by `grep -rn "Future<void>.delayed\|Future.delayed" app/test packages/atv_remote/test` with `fakeAsync` (or, for socket tests, an event-driven proof: wait for a later event that must come after the one that must not). List each replaced test in the report.

- [ ] **Step 2: Run the tests and confirm they fail**

Run (from `app/`): `flutter test test/features/discovery test/core/session`
Run (from `packages/atv_remote/`): `flutter test`
Expected: the NSD tests FAIL; the key-code, key-pin and volume tests may pass (pins) or reveal defects.

- [ ] **Step 3: Implement**; `dart format`.
- [ ] **Step 4: Run every test**

Run: `flutter test` in both packages.
Expected: all PASS.

**Expected re-baselines:** none.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test packages/atv_remote
git commit -m "fix: NSD stop without a listener, safe cancels, key-code and session coverage" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: the closed Phase 3 NSD/async and Phase 4 key-code/session carry-overs; every replaced negative wait.

---

### Task 8.10: Remote screen — Phase 4 code and tests

**Files:**
- Modify:
  - `app/lib/features/remote/presentation/widgets/dpad.dart` (`_holdStart` uses `_downRegion`)
  - `app/lib/features/remote/presentation/widgets/remote_body.dart` (`EdgeInsetsDirectional`)
  - `app/lib/core/device/screen_services.dart` (narrowed catches)
- Create: `app/test/features/remote/widgets/dpad_pressed_golden_test.dart` (+ `goldens/`), only if `dpad_golden_test.dart` can't take a new case
- Test: `app/test/features/remote/widgets/dpad_test.dart`, `touchpad_test.dart`, `app/test/features/remote/power_test.dart`, `remote_layout_test.dart`, `remote_accessibility_test.dart`, `app/test/core/device/screen_services_test.dart` (create if absent), `app/test/app/widgets/app_key_button_test.dart`, `app/test/core/haptics/haptics_test.dart`

**Interfaces:**
- Consumes: `RecordingHaptics`, `ink_features.dart`, `nonlinear_text_scaler.dart`.
- Produces:
  - D-pad: `_holdStart` reads the region from `_downRegion` (where the finger went down), not from the long-press position.
  - Split layout: `EdgeInsetsDirectional.only(end: AppSpacing.l)` and the matching `start/end` in the second call; behaviour in LTR identical.
  - `screen_services.dart`: the two `on Object` catches become `on PlatformException` and `on MissingPluginException`; anything else propagates. Report what each wrapped call can throw.

- [ ] **Step 1: Write the failing tests**

```dart
// dpad_test.dart
testWidgets('hold_starts_on_the_region_the_finger_went_down_on', ...)
    // down on Up, drift 20 dp into the centre wedge before 300 ms → startLong(dpadUp), not dpadCenter
testWidgets('dpad_clamps_to_100x100', ...)                  // a 100×100 box: no overflow, every region ≥ 48 dp hit-testable
testWidgets('dragging_across_wedges_keeps_the_first_region', ...)
testWidgets('a_hold_stays_on_its_region_while_dragging', ...)
// dpad golden
testWidgets('dpad_pressed_up_light', ...)                   // new golden: Up pressed, light

// power_test.dart
testWidgets('dragging_off_power_before_600ms_cancels', ...) // no power action, no heavy haptic

// touchpad_test.dart
testWidgets('edge_glow_shows_in_the_step_direction', ...)
testWidgets('a_new_touch_never_shows_the_previous_touchs_glow', ...)  // "same-touch stale glow"

// app_key_button_test.dart / haptics_test.dart
testWidgets('a_transparent_key_still_shows_its_ripple', ...)
test('platform_haptics_call_the_right_feedback_type', ...)  // HapticFeedback channel: light/medium/heavy → the platform method names

// remote_layout_test.dart
testWidgets('every_layout_fits_a_non_linear_text_scaler', ...)
    // the existing layout matrix (portrait, landscape, tablet × pages) with the non-linear scaler: no exception
testWidgets('split_layout_mirrors_in_rtl', ...)            // Directionality.rtl: the right column's gutter is on the left

// screen_services_test.dart
test('unexpected_errors_are_not_swallowed', ...)           // a fake that throws StateError → it propagates
test('missing_plugin_is_tolerated', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/remote test/core/device test/app/widgets/app_key_button_test.dart test/core/haptics`
Expected: FAIL for the fixes; the pure coverage tests may pass at once (note which).

- [ ] **Step 3: Implement**; `dart format lib test`.
- [ ] **Step 4: Generate the new golden and inspect it**

Run: `flutter test --update-goldens --tags golden test/features/remote/widgets/`
Then `git status`: only `dpad_pressed_up_light.png` is new.

- [ ] **Step 5: Run every test**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** new `dpad_pressed_up_light`; no other change (the directional insets are identical in LTR).

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): D-pad hold region, RTL split layout, narrowed screen-service catches, Phase 4 test gaps" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: the closed Phase 4 code and test carry-overs; the deferral of `ExcludeSemantics` while dimmed (P8-R13).

---

### Task 8.11: Test debt and duplication

**Files:**
- Create: `app/test/flutter_test_config.dart`, `app/lib/app/widgets/settings_button.dart`, `app/lib/app/widgets/not_connected_snack_bar.dart` (or the name that fits what's shared)
- Modify:
  - `app/lib/features/discovery/presentation/discovery_screen.dart`, `app/lib/features/remote/presentation/remote_screen.dart` (the three Settings buttons)
  - `app/lib/features/apps/presentation/apps_screen.dart`, `remote_screen.dart` (shared status strip and snackbar logic)
  - `app/lib/app/l10n/app_en.arb` (`@key` descriptions only)
- Test: `app/test/features/apps/apps_screen_test.dart`, `manage_apps_screen_test.dart`, `app/test/features/devices/edit_device_screen_test.dart`, `app/test/app/app_test.dart`, `app/test/app/theme/dynamic_scheme_test.dart`, `app/test/app/phase5_accessibility_test.dart` (app-bar gap), `app/test/app/l10n/arb_test.dart`

**Interfaces:**
- Produces:
  - `flutter_test_config.dart`: `Future<void> testExecutable(FutureOr<void> Function() testMain) async { driftRuntimeOptions.dontWarnAboutMultipleDatabases = true; await testMain(); }`. Remove the per-file `setUpAll` copies.
  - `class SettingsButton extends StatelessWidget { const SettingsButton({required this.onPressed}); }`: `Icons.settings_outlined`, tooltip `pageTitleSettings`, 48 dp minimum, `foregroundOnly`-safe (decision #47: no widget-level colour). Used by all three callers.
  - One shared not-connected snackbar/status-strip helper used by Apps and the remote, keeping decision #21's "one snackbar at a time, none when not the top route".
  - ARB: every `@key` description is at least one full sentence naming where the string shows (the terse Phase 5 ones).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('hotstar_in_india_lists_disney_plus_hotstar_first', ...)
    // deviceRegion IN; Apps search 'hotstar' → 'Disney+ Hotstar' is above 'JioHotstar' (screen test, Phase 7)
testWidgets('a_stacked_edit_apps_row_drags_by_its_handle', ...)   // 200% text, 320 dp: drag row 1's handle below row 2 → order saved
testWidgets('holding_the_real_remove_button_removes_with_undo', ...) // long-press then release on 'Remove Netflix' (the real button)
testWidgets('removing_the_tv_in_use_never_pops_twice', ...)
    // Edit TV removal guard: remove → exactly one page transition back (observe the route stack through the animation)
testWidgets('app_uses_the_dynamic_scheme_when_the_setting_is_on', ...)  // pumpRealApp with a dynamic scheme seam: colours match it
testWidgets('app_treats_unreadable_premium_as_free', ...)        // pumpRealApp, premium throws → standard style, no crash
testWidgets('app_bar_actions_keep_8dp_apart_at_320dp', ...)      // every Phase 5 app bar: gaps between action hit boxes ≥ 8 dp
testWidgets('settings_button_is_the_same_everywhere', ...)       // discovery, no-TV remote, remote: SettingsButton, 48 dp, tooltip
test('every_description_is_a_sentence', ...)                     // arb_test: each @key description has ≥ 4 words and ends with '.'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features test/app`
Expected: FAIL for the new behaviour; the coverage tests may pass (note which).

- [ ] **Step 3: Implement**; `flutter pub get` after the ARB edit; `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS; no drift multiple-database warnings in the output (`flutter test 2>&1 | Select-String "multiple databases"` prints nothing).

**Expected re-baselines:** none (the Settings button and snackbar refactors are pixel-identical).

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "refactor(app): shared Settings button and not-connected notice; Phase 5-7 test gaps" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: the closed test and refactor carry-overs; the predictive-back recheck deferral (P8-R13).

---

### Task 8.12: Malay part 1 — infrastructure, pseudo-locale, iOS purpose strings and the first half

**Files:**
- Create:
  - `app/lib/app/l10n/app_ms.arb` (with `"@@locale": "ms"`)
  - `app/ios/Runner/ms.lproj/InfoPlist.strings`
  - `app/test/app/l10n/arb_parity_test.dart`, `app/test/app/l10n/pseudo_localizations_test.dart`, `app/test/helpers/pseudo_localizations.dart` (generated)
  - `app/test/app/l10n_overflow_test.dart`
  - `app/test/platform/ios_malay_test.dart`
- Modify: `app/ios/Runner/Info.plist` (`CFBundleLocalizations`), `app/ios/Runner.xcodeproj/project.pbxproj`, `app/test/helpers/pump_router_app.dart` (`Locale? locale`, `List<LocalizationsDelegate<Object?>>? localizationsDelegates`), `app/test/features/settings/appearance_page_test.dart`

**Interfaces:**
- Consumes: P8-R8 (glossary, rules), P8-R9 (pseudo rule).
- Produces:
  - `app_ms.arb` holding a Malay value for **every key from `statusConnected` through `addAppCustom` in `app_en.arb` order** (the first half, about 225 keys), with no `@key` metadata except `@` placeholder blocks where gen-l10n needs them. **(unverified)** that gen-l10n falls back to the English template for keys missing from `app_ms.arb`; if it errors instead, copy the English value for each second-half key and list those keys in `const kMalayPending = <String>{...}` in `arb_parity_test.dart`, which Task 8.13 empties.
  - `PseudoLocalizations`, `pseudo(String)` and `PseudoLocalizations.delegate` (P8-R9).
  - `pumpRouterApp(locale:, localizationsDelegates:)`: passed to `MaterialApp.router` (`localizationsDelegates` replaces `AppLocalizations.localizationsDelegates` when given, keeping the Material/Widgets/Cupertino delegates).
  - `InfoPlist.strings` (UTF-8, exact):

    ```
    "NSLocalNetworkUsageDescription" = "Remotely menggunakan rangkaian setempat anda untuk mencari dan mengawal Android TV anda.";
    "NSUserTrackingUsageDescription" = "Remotely menggunakan ini untuk menunjukkan iklan yang lebih berkaitan dengan anda. Bilangan iklan yang dipaparkan tetap sama walau apa pun pilihan anda.";
    ```
  - `project.pbxproj`: a `PBXFileReference` (`lastKnownFileType = text.plist.strings; name = ms; path = ms.lproj/InfoPlist.strings`), a `PBXVariantGroup` named `InfoPlist.strings` in the Runner group, a `PBXBuildFile` for it in the Runner target's Resources phase, and `ms` in `knownRegions`. New object ids are 24 upper-case hex characters not already in the file.
  - `l10n_overflow_test.dart`'s screen list: every route of `AppRoutes` (with a saved TV, the demo, and a paywall source) plus the sheets and dialogs that Phase 5/7 and Task 8.4 open; a shared `forEachScreen(t, check, {locale, delegates, textScale, size})`.

- [ ] **Step 1: Write the failing tests**

```dart
// arb_parity_test.dart
test('ms_translates_the_first_half', ...)
    // every en key up to and including 'addAppCustom' exists in app_ms.arb with a non-empty value
test('ms_keeps_every_placeholder', ...)
    // for every ms key: the set of {name} placeholders equals the en message's set
test('ms_has_no_metadata_drift', ...)                        // no ms key that isn't an en key; '@@locale' == 'ms'

// pseudo_localizations_test.dart
test('pseudo_localizations_source_is_current', ...)
    // autoUpdateGoldenFiles ? write test/helpers/pseudo_localizations.dart : compare with the generated source
test('pseudo_expands_and_marks_every_message', ...)
    // pseudo('Next') == '⟦Ñéxt··⟧'; PseudoLocalizations().manageAppsMoved('Netflix', 2, 5) contains 'Netflix', '2' and '5'

// l10n_overflow_test.dart
testWidgets('every_screen_fits_the_pseudo_locale_at_320dp', ...)
    // forEachScreen with PseudoLocalizations.delegate at 320×640, text scale 1, light and dark: expectNoClipping
testWidgets('malay_first_half_screens_fit_320dp_at_200_percent', ...)  // locale ms, 2.0: onboarding, discovery, pairing, remote

// ios_malay_test.dart
test('malay_purpose_strings_exist_and_name_the_app', ...)
    // ms.lproj/InfoPlist.strings has both keys, non-empty, each contains 'Remotely', none contains 'Google'
test('xcode_project_ships_the_malay_strings', ...)
    // project.pbxproj: 'ms.lproj/InfoPlist.strings', a PBXVariantGroup 'InfoPlist.strings', knownRegions contains ms
test('info_plist_lists_english_and_malay', ...)              // CFBundleLocalizations == [en, ms]

// appearance_page_test.dart
testWidgets('language_picker_offers_bahasa_melayu', ...)     // System, English, Bahasa Melayu; picking it switches the UI to ms
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/l10n test/app/l10n_overflow_test.dart test/platform/ios_malay_test.dart test/features/settings/appearance_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.**
  1. `pump_router_app.dart` parameters.
  2. Generate the pseudo file: `flutter test --update-goldens test/app/l10n/pseudo_localizations_test.dart`.
  3. Translate the first half into `app_ms.arb` following P8-R8 (natural Malaysian Malay, the glossary, "anda", untranslated names). `flutter pub get` regenerates l10n (`app_localizations_ms.dart`).
  4. The iOS files.
  5. Fix any overflow the pseudo sweep finds **in layout code** (wrap, ellipsis with a full semantics label, or scroll), never by shortening English. Name each.
  6. `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** goldens of a screen whose layout an overflow fix changed; list each. English goldens otherwise unchanged.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test app/ios/Runner app/ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(app): Malay locale (first half), Malay iOS purpose strings and a pseudo-locale overflow check" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**[owner]:** review the first half of `app_ms.arb` (tracked in `status.md` as "Malay review: part 1"). **[owner][device]:** on the Mac, set the iPhone to Bahasa Melayu and confirm the Local Network prompt shows the Malay text (a `device-matrix.md` row).

Report: decisions P8-R8 and P8-R9; whether gen-l10n fell back to English for missing keys; every overflow fix; the key range translated; the `store-release` skill edit (Malay purpose strings; update them with the final app name).

---

### Task 8.13: Malay part 2 — the second half, strict parity and the Malay sweep

**Files:**
- Modify: `app/lib/app/l10n/app_ms.arb`, `app/test/app/l10n/arb_parity_test.dart`, `app/test/app/l10n_overflow_test.dart`
- Modify (only to fix overflow): layout files the Malay sweep flags

**Interfaces:**
- Consumes: Task 8.12's tests and helpers; P8-R8.
- Produces: a complete `app_ms.arb` (every `app_en.arb` key, including Task 8.1's), and `kMalayPending` empty or removed.

- [ ] **Step 1: Write the failing tests**

```dart
// arb_parity_test.dart
test('every_key_exists_in_both_arbs', ...)
    // en keys (non-@) == ms keys (non-@), exactly; the failure lists missing and extra keys
test('ms_has_no_english_copies', ...)
    // no ms value equals its en value, except this allowlist: values made only of untranslated names and symbols
    // (e.g. 'D-pad', 'OK', 'Wi-Fi', 'Premium', 'Demo', 'Info', 'Netflix'); each allowlisted key is listed by name

// l10n_overflow_test.dart
testWidgets('every_screen_fits_320dp_in_malay_at_200_percent_text', ...)  // forEachScreen, locale ms, light and dark
testWidgets('every_screen_fits_a_non_linear_text_scaler_in_malay', ...)
testWidgets('malay_screens_meet_the_guidelines', ...)                      // expectMeetsGuidelines on every screen, light
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/l10n test/app/l10n_overflow_test.dart`
Expected: FAIL (missing keys).

- [ ] **Step 3: Implement.** Translate the remaining keys (from `addAppRecentTitle` to the end, plus any key Task 8.1 added before `addAppCustom` that 8.12 missed), then fix any Malay overflow in layout code. `flutter pub get`; `dart format lib test`.
- [ ] **Step 4: Run every test**

Run: `flutter test`
Expected: all PASS.

**Expected re-baselines:** only goldens of a layout an overflow fix changed; list each.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): complete Malay translation with strict key parity and a Malay overflow sweep" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**[owner]:** review the second half ("Malay review: part 2" in `status.md`).

Report: the allowlist and why each entry stays English; every overflow fix; the master-plan task 8.5 closed.

---

### Task 8.14: The device matrix and manual checklists

**Files:**
- Create: `docs/knowledge/device-matrix.md`

**Interfaces:**
- Consumes: `status.md` "Next up" item 1 (every bullet), Tasks 8.1–8.13's [device]/[owner] rows, `tool/measure_android.ps1`, `app/integration_test/purchase_flow_sandbox.md`, the memory rules for live testing (verify the screen before each tap, never Power without the owner, restore settings, connect via the dropdown then tap the TV).
- Produces: `device-matrix.md` with these sections, each a table `ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes`, every Result empty:
  1. **How to run:** the matrix (phones: Android 8 emulator API 26, Note10+ Android 12, an Android 14/15 emulator or device, an iPhone on iOS 16+; TVs: the MediaTek "Living Room TV 3", a Google TV/Chromecast if available); the dev install command and `env/dev.json` note; the live-testing rules; **"Ask before any Power or Wake-on-LAN step."**; where answers go (`learnings.md` → "Unverified protocol behaviour").
  2. **Protocol and connection** (from Next up): same key on 6467/6466; ping interval; `_pickHost` IPv4; reconnect time after an IP change; unpaired-client rejection; message order; 5-minute `watch`.
  3. **Remote controls:** hold feel and volume ramp; long OK; IME replace-field (`atv_cli text`); Search key on Google TV; theater dim/wake; keep-awake; landscape; the Phase 4 haptics.
  4. **Apps and TVs:** the MY default row after clearing data; which shortcut/catalogue packages open; raw MediaTek current-app packages; remove a TV then re-pair; IP→mDNS merge without re-pairing; the Astro GO, sooka, Tonton ids (`adb shell pm list packages`).
  5. **Settings:** wallpaper colours on Android 12; mail and browser links; licences page; the feedback footer "System: Android 12".
  6. **Services (Phase 6):** test banners on Apps and Settings; the Apps banner with the keyboard up (and whether AdMob flags it, P8-R13); UMP with `UMP_DEBUG_GEOGRAPHY=eea`; Premium in the EEA (P7-R9 unverified item); Firebase DebugView first screen views; the review prompt (Play internal track); and a link to `purchase_flow_sandbox.md`.
  7. **Phase 7:** onboarding on a fresh install; Try demo; Settings from discovery; launcher icon and splash on the Note10+; themed icon on Android 13+; system "Remove animations"; iOS icon, splash, Local Network explainer, reduce motion.
  8. **Phase 8:**
     - backup: `adb shell bmgr backupnow <pkg>` shows nothing backed up; after a device-transfer test (if a second phone exists) the app starts empty; iOS database directory excluded (Task 8.1);
     - integration flows on an emulator/device (Task 8.2);
     - Malay on Android and iOS, including the iOS Local Network prompt in Malay (Task 8.12);
     - Voice Access / Switch Access while theater-dimmed (P8-R13, decides the Phase 9 code).
  9. **TalkBack script (Note10+)** and **VoiceOver script (iPhone):** per screen, the expected reading order and actions: onboarding (each card, Skip/Next/Try demo), discovery (list, Settings, Enter IP), pairing (code field, paste, error), remote (status pill announces changes; D-pad Up/Left/OK/Right/Down order; a hold via double-tap-and-hold on Volume up and Power), the keyboard sheet, Apps and Edit apps (Move up/down actions; the "moved to position" announcement; the drag handle not a focus stop), Your TVs and Edit TV, Settings and every sub-page, Privacy choices, the paywall, dialogs named by their title, the demo strip ignored while a sheet is open; and maximum font size on Apps, Edit apps and the quick row.
  10. **Performance:** cold start (the `startup` and `trace` modes; target < 1.5 s; record each run's median), key-press latency on the real TV (stopwatch notes only, informational), battery (two `battery` runs, record mAh for the app and the baseline). Empty results tables; "No number is recorded until it was measured" (P8-R5).

- [ ] **Step 1: Write the document.** Every bullet of `status.md` "Next up" item 1 must map to exactly one row; add a final "Coverage" table: `Next-up bullet → row ID`.
- [ ] **Step 2: Check it.** Re-read `status.md` "Next up" and the [device]/[owner] notes of Tasks 8.1–8.13; every one has a row. Commands in the document are copied from the plan or the scripts, not invented.
- [ ] **Step 3: Commit** (documentation only; no check run needed, but run `powershell -File tool/check.ps1` if any other file changed)

```bash
git add docs/knowledge/device-matrix.md
git commit -m "docs: device matrix with TalkBack, VoiceOver and performance scripts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Expected re-baselines:** none.

Report: the coverage table; any Next-up bullet that couldn't be turned into a row and why. **[owner][device]:** the matrix is executed later by the owner with Claude.

---

### Task 8.15: Seams, the full check and the phase exit

**Files:**
- Create: `app/test/app/phase8_flow_test.dart`
- Modify: production files only to fix defects these tests reveal (name each in the report)

**Interfaces:**
- Consumes: everything above, plus the Phase 6 fakes.
- Produces: no new production API.

- [ ] **Step 1: Write the tests**

```dart
// phase8_flow_test.dart
testWidgets('malay_user_runs_onboarding_to_the_demo_remote', ...)
    // locale ms: onboarding (Malay copy) → 'Cuba demo' → remote; Volume up reaches the preview; Settings → Bantuan shows
    // the Malay new-phone FAQ
testWidgets('a_storage_error_at_startup_is_scrubbed_and_shown', ...)
    // DB read fails: Apps shows its error state at once; the crash sink saw no TV name (seeded terms)
testWidgets('every_route_meets_the_guidelines_in_both_languages', ...)  // AppRouteNames.all × {en, ms}, light
test('backup_rules_and_privacy_copy_agree', ...)                // re-runs Task 8.1's promise test (listed for the exit)
test('no_app_lib_file_imports_the_fake_tv', ...)                // re-runs Task 8.2's scan
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/phase8_flow_test.dart`
Expected: they may fail. A failure is a real defect: fix it in the owning file and name the fix.

- [ ] **Step 3: Fix** what the tests revealed.
- [ ] **Step 4: Run every test and the goldens**

Run: `flutter test` (from `app/`) and `flutter test` (from `packages/atv_remote/`)
Expected: all PASS. `git status` shows no golden changes beyond those committed by 8.1–8.13.

- [ ] **Step 5: Build the dev APK with no config and check the merged manifest**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart` on a tree with no `google-services.json`, no `env/*.json` and no `secrets.properties`.
Expected: build succeeds; the merged manifest still has `allowBackup="false"`, `fullBackupContent="false"` and `dataExtractionRules`.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): phase 8 seams in both languages and the backup promise" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: every defect the tests found, with its fix.

---

## Phase exit checklist

- [ ] **Checks:**
  - `powershell -File tool/check.ps1` → `All checks passed.`, goldens and the host integration tests included.
  - `tool/check.sh` passes with goldens excluded.
  - A clean clone with no config builds the dev APK, and its merged manifest keeps the backup rules.
- [ ] **Golden PNGs:**
  - **new:** `dpad_pressed_up_light` (8.10).
  - **re-baselined:** Help (8.1); any listed by 8.4, 8.5, 8.12, 8.13 with its fix.
  - **unchanged:** every other golden.
- [ ] **Carry-overs:** every item of `status.md` "Carry-over to Phase 8+ → Phase 8" is closed by a task report or deferred here:

  | Carry-over | Task / deferral |
  |---|---|
  | **RELEASE BLOCKER** `allowBackup` / data-extraction rules | 8.1 |
  | P7 reduce motion: Radio, Switch, InputDecorator | 8.6 |
  | P7 drift multiple-database warnings | 8.11 |
  | P7 predictive-back private class name | deferred: next Flutter bump (P8-R13) |
  | P7 'hotstar' in IN; stacked-row drag; real Remove hold | 8.11 |
  | P7 popup menu closes without animation | 8.6 |
  | P7 unreadable Premium through the real App | 8.11 |
  | P7 Settings `IconButton` extraction (now three callers) | 8.11 |
  | P6 `InfoPlist.strings` (Malay) | 8.12 |
  | P6 update-gate live region | 8.5 |
  | P6 pre-prompt insets at 320 dp / 200% | 8.5 |
  | P6 fit checks bounded by the viewport; pre-prompt body from `AppLocalizations`; privacy switch rows | 8.5 |
  | P6-C10 accent body text on `surfaceRaised`, all styles | 8.5 |
  | P6 scrub terms seeded synchronously; discovered names | 8.8 |
  | P6 real App dynamic-scheme branch | 8.11 |
  | P6 `pairing_client_test` setup budgets | 8.9 |
  | P6 one connection-trouble provider | 8.8 |
  | P6 Apps banner collapse with the keyboard up | deferred: only if the device run's AdMob check flags it (P8-R13); row in 8.14 |
  | P5 `noRetry` on shortcuts / saved devices | 8.7 |
  | P5 merge with a null active target | 8.7 |
  | P5 throwing `HostResolver` | 8.7 |
  | P5 stale `wolMac`; merge rollback test; `watchMostUsed` + pruning | 8.7 |
  | P5 320 dp app-bar 8 dp gap | 8.11 |
  | P5 terse ARB descriptions | 8.11 |
  | P5 duplicated status-strip/snackbar logic | 8.11 |
  | P5 spinner labels; drag handle focus stop; PopupMenuButton tooltip; focus and announce after a move | 8.5 |
  | P5 Edit TV removal-guard test | 8.11 |
  | P4 `KeyCodes.named` scan; `cliKeyCodes`↔`named`; key pin at `RemoteReady`; second TV's first volume; provider-level background grace | 8.9 |
  | P4 platform haptics; transparent-key ripple; edge glow; stale glow | 8.10 |
  | P4 D-pad clamp, wedge drag, hold-stays, `dpad_pressed_up_light`; Power drag-off | 8.10 |
  | P4 a11y: disconnected state, colour/media rows, theater palette | 8.4 |
  | P4 non-linear `TextScaler` across the layout matrix | 8.10 |
  | P4 code: D-pad `_holdStart`/`_downRegion`; `OrdinalSortKey` | 8.10 / 8.5 |
  | P4 code: `EdgeInsetsDirectional` split layout | 8.10 |
  | P4 code: narrow screen-service catches | 8.10 |
  | P4 code: `ExcludeSemantics` while theater-dimmed | deferred: needs the Voice/Switch Access device check first (P8-R13); row in 8.14 |
  | P3 NSD `stop()` hang / `onCancel`; real-time negative waits; unawaited cancel errors | 8.9 |
  | P3 200% TV-name ellipsis; 48/56 dp and dark tests; pairing failures at 320 dp and dark | 8.4 |
  | P3 demo strip under a modal; live regions | 8.5 |
  | P2 a11y items (dialog route label; FittedBox below 100%; headers and ripple already done in P7) | 8.5 |
  | "Drift opens lazily": callers handle errors | 8.7 (`noRetry` error states) and 8.1 (iOS open failure) |
  | Phase 9 list in `status.md` | unchanged, Phase 9 |

- [ ] **Device and owner checks:** `device-matrix.md` exists and covers every Next-up bullet (8.14's coverage table). The matrix is executed later; nothing in it is claimed passed by this phase.
- [ ] **Knowledge updates.** The task reports collectively carry:
  - **decisions:** P8-R1 (backup; supersedes the #30 caveat), P8-R2, P8-R3 (amends #13), P8-R4, P8-R5, P8-R6, P8-R7 (closes #47's deferral), P8-R8, P8-R9, P8-R10, P8-R11 (extends #39), P8-R12, P8-R13; the `integration_test` SDK dev dependency.
  - **skills (controller edits):** `store-release` (blocker done; Malay purpose strings), `flutter-app-architecture` (integration tests, the testing library rule, `testAppOverrides`, `pumpUntil`), `remote-design-system` (dialog insets, live-region rule, Malay glossary pointer), `app-services` (scrub seeding, trouble provider), `atv-remote-protocol` (`package:atv_remote/testing.dart`).
  - **learnings:** whether host `flutter test integration_test` works on Windows; gen-l10n's behaviour with a partial locale file; the announcement API in 3.44.1; the merged-manifest path under AGP 9; settle times under the platform reduce-motion flag; host latency numbers (labelled host).
  - **status:** Phase 8 done; the device matrix and the Malay review open for the owner; Phase 9 next.

## Needs the owner

1. **Review the Malay translation** (both halves) or name a native reviewer. Until signed off, Malay is "implementer translation, unreviewed" and must not be used for store copy.
2. **A Mac** for: the Swift storage channel and the excluded database directory (8.1); the Malay `InfoPlist.strings` in the Xcode build (8.12); VoiceOver (8.14).
3. **Devices** for the matrix: the Note10+ and the TV (same Wi-Fi), an Android 13+ device or emulator, an Android 8 emulator, an iPhone; optionally a Google TV/Chromecast and a second Android phone for a device-transfer test.
4. **Questions (defaults in brackets):**
   - Turn backup off entirely rather than back up settings only? [off: a restored DB is useless without the identity, and it keeps the promise simple (P8-R1)]
   - Is it acceptable that a restored iPhone keeps the theme and privacy choices (preferences hold no TV data) but no TVs? [yes]
   - A battery-drain threshold once the first measurement exists? [set after measuring]
   - Translate the app's display name for Malay? [no: "Remotely for Android TV" in both languages]
