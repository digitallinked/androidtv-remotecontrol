# Phase 5 — Apps, Devices, Settings and Help Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The free app becomes feature-complete (no services yet). Users get an Apps screen and a quick-access row filled from our own bundled catalogue, with region-aware defaults, reordering, custom shortcuts and "recently used on your TV" suggestions with system apps filtered out. They can rename and remove saved TVs and set the Wake-on-LAN MAC from a TV's page. Settings covers appearance, remote layout (with a live preview), remote behaviour, help (FAQ and troubleshooting), about (version and licences), legal links and email feedback. Phase 3 and 4 carry-overs land: hosts are refreshed and re-resolved, manual IP entries merge with mDNS, and the append-only keyboard mode is hardened. Every new screen works at 320 dp and 200% text, in light and dark, and with a screen reader. The Apps and Settings screens reserve a zero-size banner slot for Phase 6. Phase 5 itself shows no ads and sends no analytics.

**Architecture:**
- The catalogue is a bundled JSON asset parsed into an immutable `AppCatalogue`.
- Shortcuts and app usage live in the existing drift tables (`shortcuts`, `app_usage`; no schema change). They sit behind `ShortcutRepository` and `AppUsageRepository` interfaces, with in-memory fakes for widget tests.
- One `ShortcutActions` object owns every write. A keepAlive seed provider fills the region defaults exactly once.
- App launches still go through `RemoteActions` (decision #20).
- Saved-TV edits use targeted `DeviceRepository` setters. `DeviceActions.delete` also moves the session off a deleted TV.
- Settings pages are thin views over `settingsControllerProvider`.
- External links and app/OS version info sit behind interfaces (`LinkOpener`, `appInfoProvider`), so tests never call a platform channel.
- The library (`packages/atv_remote`) does not change in this phase.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2 (codegen, riverpod_generator 4.0.4), go_router 18.1.1, drift 2.34.0, dynamic_color 2.1.0, wakelock_plus 1.8.2, screen_brightness 2.1.11. New in Task 5.9: url_launcher 6.3.3, package_info_plus 10.2.2 (already in the lock file as a transitive dependency of wakelock_plus; now direct).

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md` (binding: goals 5, 6, 7, 11, 12, 13; anti-goals). This plan expands Phase 5 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md`. It keeps that plan's interfaces and test names except where a **Ruling** below says otherwise. Before starting, read:
- the `remote-design-system`, `flutter-app-architecture` and `app-services` skills (the last one for what Phase 6 will hang on the banner slot and the settings hub)
- `docs/knowledge/decisions.md` #6, #12–#26 and `learnings.md` (especially "Phase 4 Flutter gotchas" and "Riverpod 3 and widget-test gotchas")
- `app/lib/app/router.dart`, `app/lib/core/storage/{app_database,device_repository,settings_store,settings_controller,storage_providers}.dart`, `app/lib/core/session/session_providers.dart`, `app/lib/features/remote/presentation/remote_screen.dart`, `widgets/{quick_access_row,quick_app_tile,remote_body,device_switcher,wol_setup_sheet}.dart`, `app/lib/features/apps/`, `app/lib/features/discovery/presentation/discovery_screen.dart`, `app/lib/features/pairing/data/pairing_providers.dart`
- the competitor teardown `docs/competitor-analysis/remote-atv/README.md` §4.5, §5 and §8. It is reference only: never copy its code, assets, copy, FAQ text, catalogue file or branding.

## Global Constraints

- Flutter 3.44.1 / Dart 3.12.1, `environment.sdk: ^3.12.1`. Lints: `very_good_analysis` 10.3.0 with `public_member_api_docs`, so every public `lib/` member gets a `///` doc. Keep pubspec dependencies sorted.
- **Dependencies:** only Task 5.9 adds any: `url_launcher: 6.3.3` and `package_info_plus: 10.2.2`. They were resolved together against this workspace with `flutter pub add --dry-run` on 2026-10-27. Pin them exactly. Task 5.3 adds only an `assets:` entry, and Task 5.9 adds a second one.
- No socket, TLS or protobuf code in `app/`. The app imports only `package:atv_remote/atv_remote.dart`. **No library changes in this phase.**
- **Every TV command goes through `RemoteActions`** (decision #20), including app launches from the Apps screen. Screens that launch apps `ref.watch(remoteActionsProvider)` (it is autoDispose) and listen to `notConnectedNoticesProvider` for their own snackbar, shown only when `ModalRoute.isCurrentOf(context)` is true. Nothing calls `RemoteSession.send*`/`launchAppLink` directly.
- **Strings:** every Phase 5 string is added to `app/lib/app/l10n/app_en.arb` in **Task 5.1** (Ruling P5-R1), each with an `@key` description. Later tasks use those keys and don't edit the ARB file. If a task finds it needs another string, it stops and reports the key and copy to the controller, who adds it. No hard-coded UI text. Exceptions (data, not UI strings):
  - app names in the catalogue
  - language endonyms (`kLanguageNames`, Ruling P5-R11)
  - the technical footer of the feedback email (Ruling P5-R12).
- **No ads and no analytics in this phase** (Phase 6). `BannerSlot` is a zero-size placeholder (Ruling P5-R3). No `logEvent`, no review prompt, no premium rows, no mic button (decision #7). Never log or send TV names, IPs, MACs, typed text or package lists. App usage is stored on the phone only.
- **Icons and branding:** no third-party logos, no brand colours, no network-loaded icons (Ruling P5-R4). Apps show a monogram or one of our generic Material icons.
- **Navigation model** (`remote-design-system` principle 4):
  - Pushed pages have a back arrow and a title that names the page.
  - Sheets use `showAppSheet` (swipe or ✕). Confirmations use `showAppDialog`; never a stock `AlertDialog`.
  - Destructive actions use `AppDialogAction(isDestructive: true)`.
- Touch targets: ≥ 48 dp for everything in this phase (≥ 56 dp for remote keys, unchanged), ≥ 8 dp between targets. Every new screen, sheet and dialog is tested at **320 dp width and 200% text** (no exception thrown, nothing that carries meaning clipped) and in light and dark. Colour is never the only signal.
- Use `EdgeInsetsDirectional`/`AlignmentDirectional` in new layout code (RTL-safe).
- Respect reduce motion (`MediaQuery.disableAnimationsOf`): reorder and expansion animations use `Duration.zero`.
- Riverpod 3:
  - `Override` and `ProviderException` come from `package:flutter_riverpod/misc.dart`.
  - Check `ref.mounted` after every `await` in a notifier before touching `state`.
  - Watch every dependency **before** the first `await` in an async provider.
  - A notifier can't `ref.invalidate` a provider that depends on it; use `ref.container.invalidate`.
  - `riverpod_generator` can't name drift data classes (`SavedDevice`, `ShortcutRow`, `AppUsageRow`) in a provider signature. Map them to hand-written classes, or hand-write the provider.
- **drift in tests:**
  - Widget tests never subscribe to a drift `.watch()` stream: it leaves a pending timer when disposed (learnings).
  - Widget tests use the in-memory repository fakes (`InMemoryDeviceRepository` from 5.2, `InMemoryShortcutRepository`/`InMemoryAppUsageRepository` from 5.4).
  - Drift implementations are covered by plain `test()` unit tests on `AppDatabase(NativeDatabase.memory())`.
  - drift opens lazily, so the first query can throw. Every repository caller in UI code catches errors and shows the task's "couldn't save" copy, never a crash.
- **Adding a `DeviceRepository` method** also means implementing it in the private test fakes: `_ThrowingDevices` (`test/app/initial_location_test.dart`), `_FailingRepository` and `_MemoryRepository` (`test/features/pairing/pairing_controller_test.dart`), and `InMemoryDeviceRepository`.
- Timers: tests use `fakeAsync` or `tester.pump(duration)`; no real waits over 100 ms. Production code that needs the time uses `clock` (`package:clock`).
- Code generation: `flutter pub run build_runner build --delete-conflicting-outputs`, then `dart format lib test`, both from `app/`. `dart run build_runner` fails in this workspace. On Windows, revert unrelated `.g.dart` files that changed only in line endings.
- Goldens: one `*_golden_test.dart` per subject, `@Tags(['golden'])`, baselines in `goldens/` next to the test, generated on Windows with `flutter test --update-goldens --tags golden <path>`. Inspect every new or changed PNG. Never commit `failures/` folders.
- App tests need no TV, network or platform channel. Platform-backed providers get a fake default in `pumpRouterApp` (only Task 5.4 edits that helper), or are overridden by the tests that reach them (5.8, 5.9).
- `flutter`/`dart` commands in steps run from `app/`. `check.ps1` and `git` run from the repo root. Before every commit, `powershell -File tool/check.ps1` must print `All checks passed.`
- Commits end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Don't edit `docs/knowledge/*` or `CLAUDE.md`. Put knowledge updates in your task report; the controller applies them.

## Rulings (conflicts and open questions resolved for this phase)

1. **P5-R1 — Strings, routes and stub screens land first.** Several tasks would otherwise all edit `app_en.arb` and `router.dart`. Task 5.1 adds every Phase 5 ARB key (the table in Task 5.1) and the whole route table. Each new route points at its **final** screen class, created as a stub (`PlaceholderScreen` with the page's title) in its final file. Later tasks replace the stub bodies and never touch `router.dart` or the ARB file. `pageTitleDevices` changes from "Devices" to "Your TVs" ("devices" could mean phones).
2. **P5-R2 — Routes and ways in.**
   - Routes:
     - `/apps` (Apps screen) and `/apps/manage` (Edit apps)
     - `/devices` (Your TVs) and `/devices/:serviceName` (Edit TV; the name is percent-encoded like `/pair/:serviceName`)
     - `/settings` (hub), `/settings/appearance`, `/settings/remote-layout`, `/settings/remote-behaviour`, `/settings/help`, `/settings/about`.
   - The child pages are nested `GoRoute`s under their parent. Whatever structure is used, `push` from the parent must produce exactly one parent page under the child, and Back must return to it (5.10 tests this).
   - Ways in:
     - The remote's app bar gains a leading **Settings** button (`Icons.settings_outlined`, tooltip `pageTitleSettings`, 48 dp) that pushes `/settings` (Task 5.1).
     - The quick row's `apps` variant ends with an **All apps** tile that pushes `/apps` (Task 5.5).
     - The device switcher sheet gains **Manage TVs**, which pushes `/devices` (Task 5.7).
     - Settings → Apps opens `/apps/manage`; Settings → Your TVs opens `/devices`.
   - `/paywall` stays a placeholder (Phase 6).
3. **P5-R3 — Banner slot only.**
   - Task 5.1 creates `app/lib/core/ads/banner_slot.dart`: `enum AdPlacement { apps, settings }` and `BannerSlot({required AdPlacement placement})`. In this phase it builds a zero-size widget. `static const double clearance = 48`.
   - It sits in `Scaffold.bottomNavigationBar` of exactly two screens: the Apps screen (`/apps`, `AdPlacement.apps`) and the Settings hub (`/settings`, `AdPlacement.settings`). Sub-pages, sheets, the remote, discovery, pairing, onboarding and the paywall never have one (decision #6).
   - On those two screens there is no bottom-anchored control (no FAB, no bottom button bar), and their scroll views end with `BannerSlot.clearance` of padding.
   - Phase 6.3 replaces `BannerSlot.build` (keeping its constructor) and adds the clearance test.
4. **P5-R4 — Catalogue and icons.**
   - `app/assets/catalogue/apps_v1.json` is **our own** data, compiled from public Play Store listings, never from the competitor's catalogue file.
   - It holds at least 50 apps and the default rows in Task 5.3. `iconUrl` stays `null` for every entry in v1, and there are no brand colours.
   - Tiles show an upper-case monogram of the name on `surfaceRaised`, or a user-picked colour and one of our generic Material icons (`kShortcutIcons`). Apps not in the catalogue use the generic `app` icon.
   - Real app icons need a licensing decision ("Needs the owner").
   - Package names are (unverified) until the real-device run (Task 5.3 sets the rules for checking them). The default launch link stays `market://launch?id=<package>`. Deep links (`https://…`) are not offered in v1: (unverified) how TVs route them.
5. **P5-R5 — Shortcuts.**
   - Shortcuts are global (not per TV), one per package, ordered by `position`.
   - **Seeding:** the first time shortcuts are read, if the `apps.shortcuts_seeded` flag (a `SettingsStore` key, not part of `AppSettings`) is unset, then: if the table is empty, insert the region's default row; then set the flag. Emptying the list later never reseeds. A crash between the insert and the flag set leaves a non-empty table, so nothing is duplicated on the next start.
   - **Region:** the phone's first locale that has a country code (`PlatformDispatcher.locales`), upper-cased. No country or an unknown one → the `*` row. It is read when seeding and on Reset only, so changing the phone's region later doesn't rewrite the list.
   - **Reset** (with confirmation) replaces the whole list with the region defaults.
   - `kStarterApps`, `starter_apps.dart` and `quickAccessAppsProvider` are deleted. `shortcutsProvider` (a stream) replaces them. The `*` row starts with the five Phase 4 starter apps in order, so the Phase 4 tests and the demo stay valid.
6. **P5-R6 — Usage and recommendations.**
   - `appUsageTrackerProvider` listens to `currentAppProvider`. Each time the TV's foreground package becomes a non-null value different from the last one recorded, it calls `AppUsageRepository.recordSeen(package, clock.now())` (count + 1, time stamped).
   - The demo TV is never recorded. Storage errors are swallowed. Everything is recorded; filtering happens at read time.
   - "Recently used on your TV":
     - usage, minus system packages (`isSystemPackage`, Task 5.4), minus apps already on the list
     - sorted by count descending, then last seen descending; at most 8
     - catalogue apps use their catalogue name; unknown packages use `prettyPackageName` and the generic icon.
   - (unverified) which packages a MediaTek TV reports. The competitor teardown saw `android` and `com.mediatek.wwtv.tvcenter`.
7. **P5-R7 — Apps screen.**
   - Layout: status strip, a search field, then "Your apps" as a grid of tiles.
   - A non-empty query filters your apps by name (case-insensitive). It also lists matching catalogue apps that aren't on your list under "More apps"; tapping one launches it without adding it.
   - Tapping a tile calls `RemoteActions.launch`:
     - sent → `context.go(AppRoutes.remote)`, since the next thing the user does is navigate inside the app
     - refused → the not-connected snackbar, and the screen stays.
   - An empty list shows a message and **Add apps** (→ `/apps/manage`). The app bar has **Edit apps** (→ `/apps/manage`).
8. **P5-R8 — Edit apps.**
   - **Reorder** by dragging the row's handle only, so scrolling never drags. Every row also has **Move up**/**Move down** semantic actions (screen readers can't drag).
   - **Remove** is immediate, with an **Undo** snackbar that restores the previous list.
   - **Reset to suggested apps** asks for confirmation.
   - **Add** opens a sheet with:
     - **Create a custom shortcut**
     - **Recently used on your TV**
     - **Suggested apps**: catalogue apps for the region and `*` that aren't on the list
     - search over the catalogue and recent apps
     - when the query is a valid package name that matches nothing, **Add app ID "…"**.
   - Apps already on the list show as disabled with "Already on your list".
   - The custom shortcut editor (a sheet) has name (1–30 characters), app ID (validated; read-only when editing), tile colour (default or 8 swatches) and icon (first letter or 9 icons). A live preview tile updates as you edit.
   - Editing a catalogue shortcut keeps `isCustom: false`; only shortcuts created in the editor are `isCustom: true`.
9. **P5-R9 — Your TVs.**
   - **Rename:**
     - The nickname is trimmed; empty → `null` (use the TV's announced name); at most 40 characters.
     - The remote's title, the switcher, power messages and the identity dialog show the **saved label** of the session's TV (from `savedDevicesProvider`), falling back to `session.tvName`. So a rename shows at once, without rebuilding the session.
   - **MAC:**
     - The shared `MacAddressField` validates with `parseMac` on save.
     - It no longer filters or clamps input. An over-long paste shows `wolMacTooLong` instead of being silently dropped (Phase 4 carry-over); the Phase 4 setup sheet adopts the same field.
     - Empty clears `wolMac`.
     - On iOS without the entitlement the field stays editable, with `editDeviceWolUnavailable`.
   - **Remove:**
     - It deletes the device row, and its pin with it. The **client identity is never touched**: it is shared by every TV.
     - If the removed TV is the session's TV, `DeviceActions.delete` clears `activeTargetProvider` and invalidates `remoteSessionProvider`, so the remote moves to the next saved TV or to "No TV selected".
     - (unverified) the TV may still list the phone; re-pairing it later works with a new code.
   - **Pair again** pushes `/pair/<name>` **without** `extra`, so the pairing target is re-resolved (Ruling P5-R10).
10. **P5-R10 — Connect-flow carry-overs** (Phase 3):
    - (a) Tapping a paired TV in discovery first writes its discovered host with `DeviceRepository.setLastHost` (errors ignored), then activates it.
    - (b) `SavedDeviceX.toDiscoveredTv()` passes the TV's announced `displayName`, not the nickname. Re-pairing therefore never overwrites `displayName` with the nickname (the nickname is kept from the existing row, as now).
    - (c) `pairingTargetProvider` re-resolves a saved non-manual TV through `hostResolverProvider` (≤ 4 s). It falls back to the saved host. Every "Pair again" pushes without `extra`.
    - (d) **Manual → mDNS merge:**
      - Matching: a discovered TV counts as paired when a saved `manual:<ip>` device has a pin, its `lastHost == tv.host`, and no saved row has `tv.serviceName`.
      - Tapping it calls `DeviceRepository.adoptManualDevice(manualServiceName:, tv:)`. That runs in one transaction: insert a row under `tv.serviceName` with the discovered `displayName`, `host` and `port`, and the manual row's nickname, `wolMac`, pin and `lastConnectedAt`; then delete the manual row. Then activate.
      - Trust is not weakened: if the address now belongs to a different TV, the pin check on connect fails and the existing identity-changed flow runs.
      - A failed merge shows `discoverOpenFailed` and stays on the list.
11. **P5-R11 — Settings.**
    - **Hub sections:**
      - Remote: Remote layout, Remote behaviour, Apps, Your TVs.
      - App: Appearance.
      - Help and feedback: Help, Send feedback.
      - About: About this app, Privacy policy, Terms of use.
      - Phase 6 adds Premium and Privacy choices.
    - **Appearance:**
      - Theme (Same as phone / Light / Dark), applied at once through `settingsControllerProvider`.
      - **Colours from wallpaper**, shown only when `dynamicColorSupportedProvider` is true (`DynamicColorPlugin.getCorePalette()` returned non-null; any error → false).
      - Language: "Same as phone" plus one entry per `AppLocalizations.supportedLocales`, named by `kLanguageNames` (endonyms such as `'en': 'English'`, `'ms': 'Bahasa Melayu'`, which are data). Malay appears by itself when Phase 8 adds `app_ms.arb`.
    - **Remote layout:** navigation (Touchpad / D-pad) and the quick row (Apps / Colour keys / Media keys / Nothing), each with a description, over a live, non-interactive preview of `RemoteBody`.
    - **Remote behaviour:** five switches: haptics, Smooth Press, keep screen on, theater mode, open keyboard automatically.
    - Radio groups use `RadioGroup` (the `groupValue`/`onChanged` parameters of `RadioListTile` are deprecated in this SDK). The analyzer stays clean.
12. **P5-R12 — Help, about, legal, feedback.**
    - **Links:** `app/lib/app/app_links.dart` holds `AppLinks.privacyPolicy`, `AppLinks.terms` (`Uri`) and `AppLinks.supportEmail`.
      - Until the owner provides real ones they are documented **placeholders** (`https://example.com/privacy`, `https://example.com/terms`, `support@example.com`); Phase 9 replaces them.
      - Links open through `LinkOpener` (`url_launcher`, `LaunchMode.externalApplication`). A `false` or a throw → the `settingsLinkFailed` snackbar.
    - **Feedback:**
      - A themed dialog, then `mailto:`. Subject: `feedbackSubject(appName, version)`.
      - Body: the localised `feedbackPrompt` line, two blank lines, then an **English technical footer** (`---`, `App: <version> (<build>)`, `System: <os> <osVersion>`).
      - **Nothing about any TV** (no name, IP, MAC or package).
      - The query is built by hand with `Uri.encodeComponent` (`%20`, not `+`, which mail apps show literally).
      - No mail app → `feedbackNoEmailApp(email)`.
    - **About:** version and build (`package_info_plus` through `appInfoProvider`), **Open-source licences** (`showLicensePage`), the protocol credit and the trademark line. The androidtvremote2 Apache-2.0 licence (our protos derive from it) is registered with `LicenseRegistry` at bootstrap from `assets/licenses/androidtvremote2.txt`.
    - **Help:** "Can't connect?" opens the existing troubleshooting sheet. A 7-question FAQ accordion (our own copy, Task 5.1): opening one answer closes the other. At the end, "Still stuck?" with Send feedback.
13. **P5-R13 — Keyboard hardening** (Phase 4 carry-over).
    - In `appendOnly`, `_flush` advances `_sent` after **each** successful step: one backspace removes one grapheme from the confirmed text, and a sent suffix is appended. A refusal part-way therefore never deletes the same characters twice.
    - Grapheme tests cover ZWJ sequences, flags and combining marks.
    - `kImeTextMode` **stays `replaceField`.** Flipping it waits for the real-device run (decision #23) and is a one-line change once the run answers.
14. **P5-R14 — Out of scope:**
    - Phase 6: ads, consent, analytics, the review prompt, Premium and Privacy-choices rows, share-with-friends.
    - Phase 7: onboarding, icon and splash, motion polish, the quick-tile ellipsis at 200% text.
    - Phase 8: the Malay translation and the full TalkBack/VoiceOver audit.
    - Phase 9: the real legal URLs and support address.
    - Other carry-overs: the `kImeTextMode` flip (waits for the device run).
    - Not offered in v1: deep-link shortcuts, per-TV shortcut lists, cloud sync, voice (decision #7).

## Review Focus

1. **Shortcut data is never lost or duplicated.** Seeding runs once, even after the user empties the list or the app crashes mid-seed. Reorder, Undo and Reset leave a dense, gap-free order. Two shortcuts never share a package (Task 5.4 `seeding_never_runs_again_after_the_user_empties_the_list`, `seeding_after_a_crash_mid_way_does_not_duplicate`, `reorder_persists`, `reset_restores_region_defaults`; Task 5.6 `remove_then_undo_restores_the_order`).
2. **Removing or renaming the TV in use.**
   - The remote never keeps controlling a removed TV, and the switcher and title follow a rename at once.
   - Removing a TV never deletes the client identity, so every other TV still connects.
   - Task 5.7 tests: `rename_updates_switcher`, `delete_requires_confirmation_and_clears_identity_pairing_flag`, `deleting_the_active_tv_switches_to_the_next_saved_tv`.
3. **The manual → mDNS merge never trusts a different TV silently.** The pin moves with the row, so a reused IP fails the TOFU check (Task 5.2 `adopt_manual_device_moves_trust_to_the_mdns_name`, `manual_tv_found_by_mdns_shows_paired_and_merges_on_tap`; Task 5.10 `merged_tv_with_a_different_key_asks_to_pair_again`).
4. **Privacy.** The feedback email carries no TV name, address, MAC or package. Usage stays on the phone. Nothing is logged (Task 5.9 `feedback_mail_body_excludes_tv_name_and_ip`).
5. **Banner slot placement.** It appears exactly once, on `/apps` and `/settings` only, with no bottom-anchored control on those screens (Task 5.10 `banner_slot_only_on_apps_and_the_settings_hub`).
6. **320 dp at 200% text, and screen readers on every new screen.** Reordering works without dragging (Task 5.6 `move_up_semantic_action_reorders`; Task 5.10 `every_new_screen_fits_320dp_at_200_percent_text`, accessibility guideline tests).

---

## File Structure

```
app/
  pubspec.yaml                                         assets/catalogue/ (5.3); url_launcher, package_info_plus, assets/licenses/ (5.9)
  android/app/src/main/AndroidManifest.xml             <queries> mailto + https                    (5.9)
  assets/catalogue/apps_v1.json                                                                    (5.3)
  assets/licenses/androidtvremote2.txt                 copy of packages/atv_remote/proto/LICENSE-androidtvremote2 (5.9)
  lib/
    bootstrap.dart                                     registerAppLicenses()                       (5.9)
    app/l10n/app_en.arb                                every Phase 5 string                        (5.1)
    app/l10n/language_names.dart                       kLanguageNames                              (5.8)
    app/router.dart                                    every Phase 5 route + AppRoutes helpers     (5.1)
    app/app_links.dart, app/licenses.dart                                                           (5.9)
    app/theme/dynamic_color_support.dart (+ .g.dart)                                                (5.8)
    app/widgets/status_strip.dart                      extracted from remote_screen                (5.5)
    core/ads/banner_slot.dart                                                                       (5.1)
    core/links/link_opener.dart (+ .g.dart), core/app_info/app_info.dart (+ .g.dart)               (5.9)
    core/storage/device_repository.dart                setLastHost, adoptManualDevice (5.2), setNickname (5.7)
    core/storage/settings_store.dart                   shortcutsSeeded flag                        (5.4)
    core/tv/saved_device_x.dart                        toDiscoveredTv keeps the announced name     (5.2)
    features/apps/domain/app_entry.dart                (unchanged)
    features/apps/domain/app_catalogue.dart                                                         (5.3)
    features/apps/domain/package_names.dart, recommendations.dart                                   (5.4)
    features/apps/domain/shortcut_style.dart           kShortcutColors, kShortcutIcons             (5.5)
    features/apps/data/catalogue_repository.dart (+ .g.dart)  catalogueProvider, deviceRegionProvider (5.3)
    features/apps/data/shortcut_repository.dart, app_usage_repository.dart                          (5.4)
    features/apps/data/apps_data_providers.dart (+ .g.dart)                                         (5.4)
    features/apps/application/shortcuts.dart (+ .g.dart)  seed, shortcutsProvider, ShortcutActions, recommendations, tracker (5.4)
    features/apps/data/starter_apps.dart (+ .g.dart)   deleted                                     (5.4)
    features/apps/presentation/apps_screen.dart        stub (5.1) → screen (5.5)
    features/apps/presentation/widgets/app_tile.dart   AppIconSquare, AppTile                      (5.5)
    features/apps/presentation/manage_apps_screen.dart stub (5.1) → screen (5.6)
    features/apps/presentation/add_app_sheet.dart, custom_shortcut_editor.dart                      (5.6)
    features/devices/application/device_actions.dart (+ .g.dart)                                    (5.7)
    features/devices/presentation/devices_screen.dart, edit_device_screen.dart   stubs (5.1) → screens (5.7)
    features/devices/presentation/widgets/mac_address_field.dart, wol_mac_help_sheet.dart           (5.7)
    features/discovery/presentation/discovery_screen.dart  host refresh + manual merge             (5.2)
    features/pairing/data/pairing_providers.dart       re-resolve saved TVs                        (5.2)
    features/keyboard/keyboard_sheet.dart              append-only progress                        (5.2)
    features/remote/presentation/remote_screen.dart    settings button (5.1), pair again (5.2), shortcuts + tracker (5.4),
                                                       all apps + status strip (5.5), saved label + manage TVs (5.7)
    features/remote/presentation/widgets/quick_access_row.dart, quick_app_tile.dart, remote_body.dart  all-apps tile, AppIconSquare (5.5)
    features/remote/presentation/widgets/device_switcher.dart   Manage TVs                         (5.7)
    features/remote/presentation/widgets/wol_setup_sheet.dart   uses MacAddressField               (5.7)
    features/settings/presentation/settings_screen.dart, appearance_page.dart, remote_layout_page.dart,
      remote_behaviour_page.dart                       stubs (5.1) → pages (5.8); hub feedback/legal handlers (5.9)
    features/settings/presentation/help_page.dart, about_page.dart   stubs (5.1) → pages (5.9)
    features/settings/presentation/widgets/settings_tiles.dart                                      (5.8)
    features/settings/application/feedback.dart                                                     (5.9)
  test/
    helpers/in_memory_device_repository.dart (5.2, setNickname 5.7), key_input_recorder.dart budget (5.2)
    helpers/in_memory_shortcut_repository.dart, in_memory_app_usage_repository.dart, test_catalogue.dart (5.4)
    helpers/recording_link_opener.dart                                                               (5.9)
    helpers/pump_router_app.dart                       shortcut/usage/catalogue/region defaults    (5.4)
    app/apps_devices_settings_flow_test.dart, app/phase5_accessibility_test.dart                     (5.10)
```

| Task | Master task | Deliverable |
|---|---|---|
| 5.1 | prep | Every ARB key; every route with stub screens; `BannerSlot`; Settings button on the remote |
| 5.2 | carry-over | Host refresh, announced name, re-resolve before pairing, manual → mDNS merge; append-only keyboard hardening |
| 5.3 | 5.1 (data) | Catalogue JSON, `AppCatalogue`, region defaults, `catalogueProvider`, `deviceRegionProvider` |
| 5.4 | 5.1 + 5.2 (data) | Shortcut and usage repositories, seeding, `ShortcutActions`, usage tracker, system filter, pretty names, recommendations; starter apps removed |
| 5.5 | 5.1 (UI) | `AppIconSquare`/`AppTile`, upper-case monograms, Apps screen, All apps tile, `StatusStrip` |
| 5.6 | 5.2 (UI) | Edit apps (reorder, remove + undo, reset), add sheet, custom shortcut editor |
| 5.7 | 5.3 | Your TVs, Edit TV (rename, MAC, remove, pair again), MAC help sheet, shared MAC field, saved label on the remote |
| 5.8 | 5.4 (part) | Settings hub, Appearance, Remote layout (live preview), Remote behaviour |
| 5.9 | 5.4 (part) | Help (FAQ + troubleshooting), About (version, licences), legal links, feedback email |
| 5.10 | exit | End-to-end seam tests, banner sweep, accessibility guidelines, 320 dp sweep, dev APK |

**Order and parallelism** (the controller runs one implementer at a time in the shared tree; "parallel-safe" means disjoint files, so reviews don't overlap):
- **5.1 first, alone.** Every other task depends on its strings, routes and stubs.
- **Group A, parallel-safe after 5.1: 5.2, 5.3, 5.8.**
  - 5.2 owns `remote_screen.dart` in this group. 5.3 owns `pubspec.yaml`. 5.8 owns `features/settings/**` and `app/theme/dynamic_color_support.dart`.
  - 5.8's layout preview reads `quickAccessAppsProvider` as it is then; 5.4 switches it to `shortcutsProvider`.
- **Group B, after group A:**
  - **5.4 → 5.5 → 5.6 → 5.7**, in sequence: each edits `remote_screen.dart`, and 5.5/5.6 build on 5.4's data layer.
  - **5.9** is parallel-safe with that chain. It edits `pubspec.yaml` (after 5.3), the hub's three handlers (after 5.8), `bootstrap.dart` and the manifest, none of which the chain touches.
- **5.10 last**, after everything.

---

### Task 5.1: All strings, every route with stub screens, the banner slot, the Settings button

**Files:**
- Modify: `app/lib/app/l10n/app_en.arb`, `app/lib/app/router.dart`, `app/lib/features/remote/presentation/remote_screen.dart` (leading Settings button)
- Create (stubs, each a `PlaceholderScreen` with the page's title; later tasks replace the body, keeping the class name and constructor):
  - `app/lib/features/apps/presentation/apps_screen.dart` → `AppsScreen()`
  - `.../apps/presentation/manage_apps_screen.dart` → `ManageAppsScreen()`
  - `.../devices/presentation/devices_screen.dart` → `DevicesScreen()`
  - `.../devices/presentation/edit_device_screen.dart` → `EditDeviceScreen({required String serviceName})`
  - `.../settings/presentation/settings_screen.dart` → `SettingsScreen()`
  - `.../settings/presentation/appearance_page.dart` → `AppearancePage()`
  - `.../settings/presentation/remote_layout_page.dart` → `RemoteLayoutPage()`
  - `.../settings/presentation/remote_behaviour_page.dart` → `RemoteBehaviourPage()`
  - `.../settings/presentation/help_page.dart` → `HelpPage()`
  - `.../settings/presentation/about_page.dart` → `AboutPage()`
- Create: `app/lib/core/ads/banner_slot.dart`
- Modify (tests): `app/test/app/router_test.dart`, `app/test/app/l10n/app_localizations_test.dart`, `app/test/features/remote/remote_screen_test.dart`; re-baseline `app/test/features/remote/goldens/remote_{portrait_light,portrait_dark,landscape,tablet,theater}.png`
- Test: create `app/test/core/ads/banner_slot_test.dart`, `app/test/app/l10n/arb_test.dart`

**Interfaces:**
- Consumes: `PlaceholderScreen`, `AppLocalizations`, the Phase 4 remote screen.
- Produces:
  - `AppRoutes` gains:

    ```dart
    static const manageApps = '/apps/manage';
    static const settingsAppearance = '/settings/appearance';
    static const settingsRemoteLayout = '/settings/remote-layout';
    static const settingsRemoteBehaviour = '/settings/remote-behaviour';
    static const settingsHelp = '/settings/help';
    static const settingsAbout = '/settings/about';
    /// Edit page of the saved TV [serviceName]; the name is percent-encoded.
    static String editDevice(String serviceName) => '/devices/${Uri.encodeComponent(serviceName)}';
    ```

  - The router builds `AppsScreen`, `ManageAppsScreen`, `DevicesScreen`, `EditDeviceScreen(serviceName: <decoded>)`, `SettingsScreen` and the five settings pages for those paths (Ruling P5-R2). `/paywall` is unchanged.
  - `enum AdPlacement { apps, settings }`. `class BannerSlot extends StatelessWidget { const BannerSlot({required this.placement, super.key}); final AdPlacement placement; static const double clearance = 48; }`. `build` returns `SizedBox.shrink(key: ValueKey('banner_slot_${placement.name}'))`. The doc comment states Ruling P5-R3 and that Phase 6.3 replaces the body.
  - `RemoteScreen`'s app bar (connected and reloading states; not the spinner, error or no-TV scaffolds) gains `leading: IconButton(icon: const Icon(Icons.settings_outlined), tooltip: l10n.pageTitleSettings, style: minimumSize 48×48, onPressed: () => context.push(AppRoutes.settings))` and `leadingWidth: 56`. Nothing else in the screen changes.
- **ARB keys** (exact copy; placeholders are `String` unless noted). These are all of Phase 5's strings. Write each `@key` description from the "Used for" column.

  **Changed:**

  | Key | Copy | Used for |
  |---|---|---|
  | `pageTitleDevices` | `Your TVs` | title of `/devices` and its hub row (was "Devices") |

  **Common and navigation:**

  | Key | Copy | Used for |
  |---|---|---|
  | `commonCancel` | `Cancel` | dismiss action of confirmation dialogs |
  | `commonSave` | `Save` | save buttons (Edit TV, shortcut editor) |
  | `commonUndo` | `Undo` | snackbar action after removing an app |
  | `remoteManageTvs` | `Manage TVs` | row in the TV switcher sheet → Your TVs |
  | `quickAccessAllApps` | `All apps` | last tile of the quick row → Apps screen |
  | `pageTitleManageApps` | `Edit apps` | title of `/apps/manage`; Apps screen action |
  | `pageTitleEditDevice` | `Edit TV` | Edit TV title while loading or when the TV isn't found |
  | `pageTitleAppearance` | `Appearance` | page title and hub row |
  | `pageTitleRemoteLayout` | `Remote layout` | page title and hub row |
  | `pageTitleRemoteBehaviour` | `Remote behaviour` | page title and hub row |
  | `pageTitleHelp` | `Help` | page title and hub row |
  | `pageTitleAbout` | `About this app` | page title and hub row |

  **Apps screen:**

  | Key | Copy | Used for |
  |---|---|---|
  | `appsSearchLabel` | `Search apps` | label of the Apps screen search field |
  | `appsYourApps` | `Your apps` | header of the shortcuts grid |
  | `appsMoreApps` | `More apps` | header of catalogue matches while searching |
  | `appsNoMatches` | `No apps match "{query}".` | search with no results |
  | `appsEmptyTitle` | `No apps yet` | empty Apps screen |
  | `appsEmptyBody` | `Add the apps you use on your TV to open them with one tap.` | empty Apps screen |
  | `appsEmptyAction` | `Add apps` | empty Apps screen button → Edit apps |

  **Edit apps:**

  | Key | Copy | Used for |
  |---|---|---|
  | `manageAppsAdd` | `Add app` | app bar action of Edit apps |
  | `manageAppsReset` | `Reset to suggested apps` | overflow menu item |
  | `manageAppsResetTitle` | `Reset your apps?` | reset confirmation title |
  | `manageAppsResetBody` | `Your list goes back to the suggested apps for your region. Shortcuts you added or changed are removed.` | reset confirmation body |
  | `manageAppsResetConfirm` | `Reset` | destructive reset action |
  | `manageAppsReorderHint` | `Drag the handle to change the order. The remote shows your apps in this order.` | hint above the list |
  | `manageAppsDragHandle` | `Reorder {app}` | semantics label of a row's drag handle |
  | `manageAppsMoveUp` | `Move up` | semantic custom action |
  | `manageAppsMoveDown` | `Move down` | semantic custom action |
  | `manageAppsEdit` | `Edit {app}` | tooltip of a row's edit button |
  | `manageAppsRemove` | `Remove {app}` | tooltip of a row's remove button |
  | `manageAppsRemoved` | `{app} removed` | snackbar after removing (with Undo) |
  | `manageAppsEmpty` | `No apps on your list. Add one to see it on the remote.` | empty Edit apps list |
  | `manageAppsSaveFailed` | `Couldn't save your apps. Try again.` | any shortcut write failed |

  **Add sheet and shortcut editor:**

  | Key | Copy | Used for |
  |---|---|---|
  | `addAppTitle` | `Add an app` | add sheet title |
  | `addAppSearchLabel` | `Search apps or enter an app ID` | add sheet search field |
  | `addAppCustom` | `Create a custom shortcut` | first row of the add sheet |
  | `addAppRecentTitle` | `Recently used on your TV` | section header |
  | `addAppRecentEmpty` | `Apps you open on your TV show up here.` | empty recent section |
  | `addAppPopularTitle` | `Suggested apps` | section header (catalogue for the region) |
  | `addAppNoResults` | `No apps found. If you know the app's ID, type it to add it.` | search with no results |
  | `addAppById` | `Add app ID "{package}"` | row that adds a typed package name |
  | `addAppAdded` | `{app} added` | snackbar after adding |
  | `addAppAlreadyAdded` | `Already on your list` | subtitle of a disabled row |
  | `shortcutNewTitle` | `New shortcut` | editor title (create) |
  | `shortcutEditTitle` | `Edit shortcut` | editor title (edit) |
  | `shortcutNameLabel` | `Name` | editor field |
  | `shortcutNameError` | `Enter a name of up to 30 characters.` | editor validation |
  | `shortcutPackageLabel` | `App ID` | editor field |
  | `shortcutPackageHint` | `com.example.app` | editor field hint |
  | `shortcutPackageHelp` | `The app's ID on the TV. It's in the app's Play Store web address, after "id=".` | editor helper text |
  | `shortcutPackageError` | `Enter an app ID like com.example.app.` | editor validation |
  | `shortcutPackageTaken` | `This app is already on your list.` | editor validation |
  | `shortcutColourLabel` | `Tile colour` | editor group label |
  | `shortcutColourDefault` | `Default` | colour choice: no custom colour |
  | `shortcutColourSlate` | `Slate` | colour swatch name (semantics) |
  | `shortcutColourBlue` | `Blue` | 〃 |
  | `shortcutColourTeal` | `Teal` | 〃 |
  | `shortcutColourGreen` | `Green` | 〃 |
  | `shortcutColourAmber` | `Amber` | 〃 |
  | `shortcutColourOrange` | `Orange` | 〃 |
  | `shortcutColourRed` | `Red` | 〃 |
  | `shortcutColourPurple` | `Purple` | 〃 |
  | `shortcutIconLabel` | `Icon` | editor group label |
  | `shortcutIconLetter` | `First letter` | icon choice: monogram |
  | `shortcutIconApp` | `App` | generic icon name |
  | `shortcutIconMovies` | `Movies` | icon name |
  | `shortcutIconLive` | `Live TV` | icon name |
  | `shortcutIconSports` | `Sports` | icon name |
  | `shortcutIconMusic` | `Music` | icon name |
  | `shortcutIconKids` | `Kids` | icon name |
  | `shortcutIconNews` | `News` | icon name |
  | `shortcutIconGames` | `Games` | icon name |
  | `shortcutIconLearning` | `Learning` | icon name |
  | `shortcutPreview` | `Preview` | label of the live preview tile |
  | `shortcutSaved` | `Shortcut saved` | snackbar after editing |

  **Your TVs and Edit TV:**

  | Key | Copy | Used for |
  |---|---|---|
  | `devicesEmptyTitle` | `No TVs yet` | empty Your TVs |
  | `devicesEmptyBody` | `Pair a TV to control it from this phone.` | empty Your TVs |
  | `devicesInUse` | `In use` | marker on the session's TV |
  | `devicesEditTv` | `Edit {tvName}` | semantics/tooltip of a TV row |
  | `editDeviceNameLabel` | `Name on this phone` | nickname field |
  | `editDeviceNameHelp` | `Leave empty to use the TV's own name, {tvName}.` | nickname helper |
  | `editDeviceNameError` | `Use 40 characters or fewer.` | nickname validation |
  | `editDeviceWolTitle` | `Turn on from your phone` | MAC section header |
  | `editDeviceWolBody` | `Add the TV's MAC address so the power key can wake it from standby.` | MAC section text |
  | `editDeviceWolHelp` | `Where do I find it?` | link → MAC help sheet |
  | `editDeviceWolUnavailable` | `Turning the TV on from an iPhone isn't available yet. You can still save the address.` | iOS without the entitlement |
  | `wolMacTooLong` | `That's longer than a MAC address. Check what you pasted.` | MAC field: over-long input |
  | `wolHelpTitle` | `Find the TV's MAC address` | MAC help sheet title |
  | `editDeviceLastAddress` | `Last address: {host}` | Edit TV info line |
  | `editDeviceSaved` | `Saved` | snackbar after saving |
  | `editDeviceSaveFailed` | `Couldn't save. Try again.` | snackbar on write failure |
  | `editDeviceRemove` | `Remove TV` | destructive button |
  | `editDeviceRemoveTitle` | `Remove {tvName}?` | confirmation title |
  | `editDeviceRemoveBody` | `This phone forgets the TV and its settings. To use it again, pair it with a new code. The TV may still list this phone.` | confirmation body |
  | `editDeviceRemoveConfirm` | `Remove` | destructive confirm action |
  | `editDeviceRemoved` | `{tvName} removed` | snackbar after removing |
  | `editDeviceNotFound` | `This TV isn't saved on this phone anymore.` | Edit TV for an unknown name |
  | `editDeviceBackToTvs` | `Back to your TVs` | action on the not-found state |
  | `discoverOpenFailed` | `Couldn't open this TV. Try again.` | discovery: a merge or host update failed hard |

  **Settings hub:**

  | Key | Copy | Used for |
  |---|---|---|
  | `settingsSectionRemote` | `Remote` | hub section header |
  | `settingsSectionApp` | `App` | hub section header |
  | `settingsSectionSupport` | `Help and feedback` | hub section header |
  | `settingsSectionAbout` | `About` | hub section header |
  | `settingsRemoteLayoutSubtitle` | `Touchpad or D-pad, and the row of keys above it` | hub row subtitle |
  | `settingsRemoteBehaviourSubtitle` | `Vibration, Smooth Press, screen and keyboard` | hub row subtitle |
  | `settingsAppsSubtitle` | `Choose and order your app shortcuts` | hub row subtitle |
  | `settingsDevicesSubtitle` | `Rename, remove, or turn on from your phone` | hub row subtitle |
  | `settingsAppearanceSubtitle` | `Theme and language` | hub row subtitle |
  | `settingsHelpSubtitle` | `Common questions and troubleshooting` | hub row subtitle |
  | `settingsFeedback` | `Send feedback` | hub row; Help page button |
  | `settingsFeedbackSubtitle` | `Write to us by email` | hub row subtitle |
  | `settingsAboutSubtitle` | `Version and licences` | hub row subtitle |
  | `settingsPrivacy` | `Privacy policy` | hub row (external link) |
  | `settingsTerms` | `Terms of use` | hub row (external link) |
  | `settingsOpensInBrowser` | `Opens in your browser` | semantics hint of external-link rows |
  | `settingsLinkFailed` | `Couldn't open the page. Check your internet connection and try again.` | link failed |

  **Appearance:**

  | Key | Copy | Used for |
  |---|---|---|
  | `appearanceTheme` | `Theme` | group label |
  | `appearanceThemeSystem` | `Same as phone` | theme choice |
  | `appearanceThemeLight` | `Light` | theme choice |
  | `appearanceThemeDark` | `Dark` | theme choice |
  | `appearanceDynamicColour` | `Colours from wallpaper` | switch title |
  | `appearanceDynamicColourSubtitle` | `Use your phone's wallpaper colours in the app.` | switch subtitle |
  | `appearanceLanguage` | `Language` | group label |
  | `appearanceLanguageSystem` | `Same as phone` | language choice: follow the system |

  **Remote layout and behaviour:**

  | Key | Copy | Used for |
  |---|---|---|
  | `layoutPreviewTitle` | `Preview` | header over the preview |
  | `layoutPreviewSemantics` | `Preview of the remote with these choices` | semantics label of the preview |
  | `layoutNavigation` | `Navigation` | group label |
  | `layoutTouchpadSubtitle` | `Swipe to move, tap to select.` | under Touchpad (title reuses `remotePadTouchpad`) |
  | `layoutDpadSubtitle` | `Arrow keys around an OK button, like a TV remote.` | under D-pad (title reuses `remotePadDpad`) |
  | `layoutQuickAccess` | `Row above the pad` | group label |
  | `layoutQuickApps` | `App shortcuts` | choice title |
  | `layoutQuickAppsSubtitle` | `Open your TV apps with one tap.` | choice subtitle |
  | `layoutQuickColourSubtitle` | `Red, green, yellow and blue keys.` | under Colour keys (title reuses `quickAccessColourLabel`) |
  | `layoutQuickMediaSubtitle` | `Previous, rewind, play or pause, fast-forward and next.` | under Media keys (title reuses `quickAccessMediaLabel`) |
  | `layoutQuickNone` | `Nothing` | choice title |
  | `layoutQuickNoneSubtitle` | `More room for the touchpad or D-pad.` | choice subtitle |
  | `behaviourHaptics` | `Vibrate on key press` | switch |
  | `behaviourHapticsSubtitle` | `A short vibration when a key reaches the TV.` | switch subtitle |
  | `behaviourSmoothPress` | `Smooth Press` | switch |
  | `behaviourSmoothPressSubtitle` | `Holding volume, channel or arrow keys acts like holding a key on a TV remote. When off, holding repeats the key.` | switch subtitle |
  | `behaviourKeepAwake` | `Keep screen on` | switch |
  | `behaviourKeepAwakeSubtitle` | `Your phone's screen stays on while the remote is open.` | switch subtitle |
  | `behaviourTheater` | `Theater mode` | switch |
  | `behaviourTheaterSubtitle` | `Dims your phone after 30 seconds without a touch. The first touch only brightens it.` | switch subtitle |
  | `behaviourAutoKeyboard` | `Open keyboard automatically` | switch |
  | `behaviourAutoKeyboardSubtitle` | `Opens the keyboard when the TV asks for text, like in a search box.` | switch subtitle |

  **Help, about and feedback:**

  | Key | Copy | Used for |
  |---|---|---|
  | `helpCantConnectTitle` | `Can't connect?` | Help card title |
  | `helpCantConnectBody` | `Go through the checks one at a time. Most problems come from the Wi-Fi network or the TV's remote service.` | Help card text |
  | `helpTroubleshootingAction` | `Show troubleshooting steps` | opens the troubleshooting sheet |
  | `helpFaqTitle` | `Common questions` | FAQ header |
  | `helpStillStuck` | `Still stuck?` | header above Send feedback |
  | `faqTvsQ` | `Which TVs does this app work with?` | FAQ question |
  | `faqTvsA` | `TVs and streaming boxes that run Android TV or Google TV, on the same Wi-Fi network as your phone. TVs with other systems, such as Samsung (Tizen), LG (webOS), Roku or Fire TV, can't be controlled by this app.` | FAQ answer |
  | `faqNotFoundQ` | `My TV isn't in the list.` | FAQ question |
  | `faqNotFoundA` | `Make sure the TV is on and connected to the same Wi-Fi as your phone, and that "Android TV Remote Service" is up to date on the TV. You can also add the TV by its IP address. The troubleshooting steps go through each check.` | FAQ answer |
  | `faqCodeQ` | `Why does the TV ask for a code again?` | FAQ question |
  | `faqCodeA` | `Pairing makes the TV and this phone trust each other. Clearing the app's data, reinstalling the app or resetting the TV removes that trust, so you pair once more with a new code.` | FAQ answer |
  | `faqPowerQ` | `Why can't the app turn my TV on?` | FAQ question |
  | `faqPowerA` | `A TV that is fully off can't hear the app. The app can send a wake-up signal if you add the TV's MAC address under Settings → Your TVs, but some TVs ignore it in deep standby. On iPhone this isn't available yet.` | FAQ answer |
  | `faqTypingQ` | `What I type doesn't show up on the TV.` | FAQ question |
  | `faqTypingA` | `Select a text field on the TV first, such as a search box. When the TV asks for text, the keyboard opens on your phone by itself.` | FAQ answer |
  | `faqAppQ` | `An app shortcut doesn't open.` | FAQ question |
  | `faqAppA` | `The app has to be installed on the TV. Some apps have a different version in each country: add the right one by its app ID under Settings → Apps.` | FAQ answer |
  | `faqPrivacyQ` | `What does the app keep about my TV?` | FAQ question |
  | `faqPrivacyA` | `Your TV's name, network address and MAC address stay on this phone. The app doesn't send them to us.` | FAQ answer |
  | `aboutVersion` | `Version {version} ({build})` | About page |
  | `aboutVersionUnknown` | `Version unavailable` | About page when package info fails |
  | `aboutLicences` | `Open-source licences` | About row → `showLicensePage` |
  | `aboutProtocol` | `Talks to your TV over Wi-Fi with the Android TV Remote protocol. Its message formats come from the open-source androidtvremote2 project.` | About page credit |
  | `aboutTrademark` | `Android TV and Google TV are trademarks of Google LLC. This app isn't made or endorsed by Google.` | About page disclaimer |
  | `feedbackTitle` | `Send feedback?` | feedback dialog title |
  | `feedbackBody` | `Your email app opens with a message to us. It includes the app version and your phone's system version, and nothing about your TV.` | feedback dialog body |
  | `feedbackConfirm` | `Write email` | feedback dialog primary action |
  | `feedbackSubject` | `Feedback on {appName} {version}` | email subject |
  | `feedbackPrompt` | `Write your message here.` | first line of the email body |
  | `feedbackNoEmailApp` | `No email app found. Write to us at {email}.` | snackbar when mailto can't open |

- [ ] **Step 1: Write the failing tests**

```dart
// router_test.dart: replace every_route_renders_its_titled_screen (titles only; stubs still say "coming soon",
// but later tasks replace them, so don't assert the body text for the Phase 5 routes)
testWidgets('every_route_renders_its_titled_screen', (t) async {
  const titles = {
    AppRoutes.apps: 'Apps', AppRoutes.manageApps: 'Edit apps', AppRoutes.devices: 'Your TVs',
    AppRoutes.settings: 'Settings', AppRoutes.settingsAppearance: 'Appearance',
    AppRoutes.settingsRemoteLayout: 'Remote layout', AppRoutes.settingsRemoteBehaviour: 'Remote behaviour',
    AppRoutes.settingsHelp: 'Help', AppRoutes.settingsAbout: 'About this app', '/paywall': 'Premium',
  };
  for (final e in titles.entries) {
    await pumpRouterApp(t, initialLocation: e.key);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text(e.value)), findsOneWidget, reason: e.key);
  }
});
testWidgets('edit_device_route_round_trips_service_names', ...)  // like pair_route_round_trips_service_names:
    // for 'Living Room TV 3', 'Bravia/4K', '100% TV', 'Télé du salon', 'manual:192.168.0.20' →
    // tester.widget<EditDeviceScreen>(find.byType(EditDeviceScreen)).serviceName == name
test('route_helpers_encode_their_arguments', ...)   // existing + AppRoutes.editDevice('Bravia/4K') == '/devices/Bravia%2F4K'

// banner_slot_test.dart
testWidgets('banner_slot_takes_no_space_until_phase_6', ...)  // pumpApp(Column[BannerSlot(apps)]) → size == Size.zero; key 'banner_slot_apps'
test('banner_slot_clearance_is_48dp', () => expect(BannerSlot.clearance, 48));

// remote_screen_test.dart (additions)
testWidgets('settings_button_opens_settings_and_back_returns', ...)
    // tap find.byTooltip('Settings') → AppBar title 'Settings'; t.pageBack() → RemoteBody found
testWidgets('remote_app_bar_fits_320dp_at_200_percent_text', ...)  // Size(320, 640), textScale 2 → no exception; settings, switcher and power all hit-testable

// app_localizations_test.dart (addition)
test('phase_5_strings_load', ...)  // l.appsNoMatches('x') == 'No apps match "x".'; l.editDeviceRemoveTitle('TV') == 'Remove TV?';
                                   // l.aboutVersion('1.0.0', '1') == 'Version 1.0.0 (1)'; l.pageTitleDevices == 'Your TVs'

// arb_test.dart
test('every_string_has_a_description', ...)  // jsonDecode(File('lib/app/l10n/app_en.arb')): every key not starting with '@'
                                             // has '@key' with a non-empty 'description'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app test/core/ads test/features/remote/remote_screen_test.dart`
Expected: FAIL (missing routes, keys and `BannerSlot`).

- [ ] **Step 3: Implement** the ARB keys, then `flutter pub get` (regenerates l10n). Then the routes, stubs, `BannerSlot` and the Settings button. Run build_runner (the router provider file changes), then `dart format lib test`. The Phase 2 test that expected "Devices" now expects "Your TVs"; update it and say so in the report.
- [ ] **Step 4: Re-baseline the remote goldens** (the app bar has the Settings button)

Run: `flutter test --update-goldens --tags golden test/features/remote/remote_screen_golden_test.dart test/features/remote/remote_theater_golden_test.dart` and inspect all five.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): phase 5 strings, routes with stub screens, banner slot and settings entry" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decisions for Rulings P5-R1, P5-R2 and P5-R3.

---

### Task 5.2: Connect-flow carry-overs and append-only keyboard hardening

**Files:**
- Modify:
  - `app/lib/core/storage/device_repository.dart` (`setLastHost`, `adoptManualDevice`)
  - `app/lib/core/tv/saved_device_x.dart`
  - `app/lib/features/pairing/data/pairing_providers.dart`
  - `app/lib/features/discovery/presentation/discovery_screen.dart`
  - `app/lib/features/remote/presentation/remote_screen.dart` (`_pairAgain`)
  - `app/lib/features/keyboard/keyboard_sheet.dart`
- Modify (test fakes): `app/test/app/initial_location_test.dart`, `app/test/features/pairing/pairing_controller_test.dart` (new interface methods), `app/test/helpers/key_input_recorder.dart` (`budget`)
- Create: `app/test/helpers/in_memory_device_repository.dart`
- Test:
  - additions to `app/test/core/storage/device_repository_test.dart`, `app/test/features/pairing/pairing_controller_test.dart`, `app/test/features/discovery/discovery_screen_test.dart`, `app/test/features/remote/remote_screen_test.dart`, `app/test/features/keyboard/text_edit_planner_test.dart`, `keyboard_sheet_test.dart`
  - create `app/test/core/tv/saved_device_x_test.dart`, `app/test/features/pairing/pairing_providers_test.dart`

**Interfaces:**
- Consumes: `DeviceRepository`, `hostResolverProvider`, `parseIpv4`/`isManualServiceName`, `ActiveTarget.activateDevice`, `planTextEdit`, `KeyInputRecorder`.
- Produces:
  - `DeviceRepository`:
    - `/// Records [host] as where [serviceName] was last seen, leaving every other field alone. A no-op for unknown TVs. Future<void> setLastHost(String serviceName, String host);`
    - `/// Moves the saved TV [manualServiceName] (a manual:<ip> entry) to [tv]'s mDNS identity in one transaction (Ruling P5-R10 d). Returns false (and changes nothing) when the manual row is missing or a row named tv.serviceName already exists. Future<bool> adoptManualDevice({required String manualServiceName, required DiscoveredTv tv});`
    - Drift versions: a targeted `_updateOne(...).write(DevicesCompanion(lastHost: Value(host)))`, and `_db.transaction`.
  - `InMemoryDeviceRepository implements DeviceRepository` (test helper):
    - a `Map<String, SavedDevice>` and a broadcast `StreamController`.
    - `watchAll()` replays the current list (newest first) and then every change.
    - Every write emits.
    - `int writes` counts calls.
    - `Object? failNextWrite`: when set, the next write throws it and clears it.
  - `SavedDeviceX.toDiscoveredTv()` uses `displayName` (the TV's own name). `label` is unchanged.
  - `pairingTargetProvider(serviceName)`, for a saved TV that isn't manual: `final host = await resolveHost(serviceName)`, then the saved TV's `DiscoveredTv` with `host: host ?? saved.lastHost`. Watch both dependencies before the first `await`. Manual saved TVs and unsaved names behave as now.
  - `RemoteScreen._pairAgain` pushes `AppRoutes.pair(target.serviceName)` with **no** `extra`.
  - `DiscoveryScreen` (Ruling P5-R10 a, d):
    - Paired detection: `pairedNames` as now, plus `manualMatches: Map<String /* tv.serviceName */, SavedDevice /* manual row */>`, built from saved devices with `isManualServiceName`, a non-null pin, `lastHost == tv.host`, and no saved row named `tv.serviceName`.
    - Those TVs show `discoverPaired` too.
    - `_open` becomes async:
      - paired → `try { await repo.setLastHost(tv.serviceName, tv.host); } on Object {}`, then activate and `go(remote)`.
      - merge match → `adoptManualDevice` → `true`: activate `tv.serviceName` and `go(remote)`; `false` or a throw: `discoverOpenFailed` snackbar.
      - A second tap while one is in flight is ignored.
  - `KeyInputRecorder` gains `int? budget`: when non-null, each accepted `tap`/`launch`/`typeText` decrements it, and at 0 the call is refused (counted in `refused`, not recorded).
  - `KeyboardSheet._flush` (Ruling P5-R13):
    - Track `confirmed` (starts at `_sent`).
    - `SendText(t)` success → `confirmed = mode == appendOnly ? confirmed + t : t`.
    - Each successful single backspace → `confirmed` loses its last grapheme (`confirmed.characters.skipLast(1).string`).
    - On any refusal, `_sent = confirmed` and return `false`.
    - On success `_sent = text`. Replace mode is unchanged in effect.

- [ ] **Step 1: Write the failing tests**

```dart
// device_repository_test.dart (drift in-memory)
test('set_last_host_updates_only_the_host', ...)                 // other fields and lastConnectedAt unchanged
test('set_last_host_on_unknown_device_is_a_no_op', ...)
test('adopt_manual_device_moves_trust_to_the_mdns_name', () async {
  await repo.upsert(savedTv(name: 'manual:192.168.0.20', nickname: 'Den', wolMac: 'AA:BB:CC:DD:EE:F0'));
  final ok = await repo.adoptManualDevice(manualServiceName: 'manual:192.168.0.20',
      tv: const DiscoveredTv(serviceName: 'Living Room TV 3', displayName: 'Living Room TV 3', host: '192.168.0.20', port: 6466, isLegacyService: false));
  expect(ok, isTrue);
  expect(await repo.find('manual:192.168.0.20'), isNull);
  final moved = (await repo.find('Living Room TV 3'))!;
  expect((moved.nickname, moved.wolMac, moved.serverKeyPin, moved.displayName), ('Den', 'AA:BB:CC:DD:EE:F0', testPin, 'Living Room TV 3'));
});
test('adopt_manual_device_refuses_when_the_mdns_name_is_already_saved', ...) // returns false; both rows unchanged
test('adopt_manual_device_is_a_no_op_for_unknown_rows', ...)                 // false

// saved_device_x_test.dart
test('to_discovered_tv_keeps_the_announced_name', ...)   // savedTv(nickname: 'Bedroom').toDiscoveredTv().displayName == 'Living Room TV 3'

// pairing_controller_test.dart
test('re_pairing_a_renamed_tv_keeps_its_name_and_nickname', ...)
    // existing row nickname 'Bedroom'; pair via savedTv(nickname: 'Bedroom').toDiscoveredTv() → saved displayName
    // 'Living Room TV 3', nickname 'Bedroom'

// pairing_providers_test.dart (ProviderContainer.test, InMemoryDeviceRepository, hostResolverProvider override)
test('pairing_target_re_resolves_a_saved_tv', ...)       // resolver → '192.168.0.33' → target.host '192.168.0.33', displayName unchanged
test('pairing_target_falls_back_to_the_saved_host', ...) // resolver → null → '192.168.0.20'
test('manual_tv_is_never_re_resolved', ...)              // saved manual:192.168.0.20 → resolver never called
test('unsaved_name_still_resolves_on_the_network', ...)  // existing behaviour kept

// discovery_screen_test.dart (deviceRepositoryProvider → InMemoryDeviceRepository; savedDevicesProvider → its watchAll)
testWidgets('tapping_a_paired_tv_updates_its_host_before_connecting', ...)
    // saved at .20, discovered at .33 → tap → repo lastHost '.33' written before activeTarget == DeviceTarget(name); route /remote
testWidgets('a_failed_host_update_still_connects', ...)  // failNextWrite → still activates and goes to /remote
testWidgets('manual_tv_found_by_mdns_shows_paired_and_merges_on_tap', ...)
    // saved manual:192.168.0.20 with pin; discovery yields 'Living Room TV 3' @ .20 → 'Paired' shown;
    // tap → repo has 'Living Room TV 3' with the pin, no manual row; active target DeviceTarget('Living Room TV 3')
testWidgets('manual_tv_without_a_pin_is_not_merged', ...) // tap → pairing route
testWidgets('a_failed_merge_says_so_and_stays', ...)      // failNextWrite → 'Couldn't open this TV. Try again.'; still on discovery

// remote_screen_test.dart
testWidgets('pair_again_resolves_the_tv_before_pairing', ...)
    // needsPairing session; tap 'Pair again' → PairingScreen.tv == null; hostResolver called with the serviceName

// text_edit_planner_test.dart
test('append_mode_counts_zwj_sequences_flags_and_combining_marks_as_one', () {
  for (final g in ['👨‍👩‍👧', '🇲🇾', 'é']) {
    expect(planTextEdit(sent: 'a$g', next: 'a', mode: ImeTextMode.appendOnly), [const DeleteChars(1)], reason: g);
  }
});

// keyboard_sheet_test.dart
testWidgets('append_mode_partial_failure_never_deletes_twice', (t) async {
  // mode appendOnly; type 'abcd' (flushed); rec.budget = 1; type 'ab' → flush: one 'tap:67' sent, second refused;
  // rec.budget = null; type 'ab' again (any edit) → exactly one more 'tap:67'; total deletes == 2
});
testWidgets('append_mode_partial_send_is_not_resent', ...)  // a refused SendText after deletes keeps the deletes confirmed
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core test/features/pairing test/features/discovery test/features/remote/remote_screen_test.dart test/features/keyboard`
Expected: FAIL.

- [ ] **Step 3: Implement.** Add the new interface methods to the three private test fakes. Run build_runner (the pairing provider changed), then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS (Phase 3 connect-flow tests included).

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): refresh and re-resolve tv hosts, keep announced names, merge manual tvs, harden append-only typing" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: Phase 3 carry-overs closed (lastHost on tap, `toDiscoveredTv` name, re-resolve before Pair again, manual merge), and the Phase 4 append-only hardening. Decision for Rulings P5-R10 and P5-R13. Learning: (unverified) whether a TV found by mDNS presents the same key as the one paired by IP. The pin check covers a mismatch.

---

### Task 5.3: App catalogue and region defaults

**Files:**
- Create: `app/assets/catalogue/apps_v1.json`, `app/lib/features/apps/domain/app_catalogue.dart`, `app/lib/features/apps/data/catalogue_repository.dart` (+ `.g.dart`)
- Modify: `app/pubspec.yaml` (`flutter: assets: [assets/catalogue/]`)
- Test: `app/test/features/apps/app_catalogue_test.dart`, `catalogue_repository_test.dart`

**Interfaces:**
- Consumes: `AppEntry`.
- Produces:
  - **JSON format** (UTF-8, < 40 KB: `rootBundle.loadString` hands strings over 50 KB to an isolate, which never completes inside `testWidgets`' fake async):

    ```json
    {
      "version": 1,
      "apps": [
        { "package": "com.netflix.ninja", "name": "Netflix", "regions": ["*"] },
        { "package": "com.vuclip.viu", "name": "Viu", "regions": ["MY", "SG", "ID", "PH", "TH", "HK"] }
      ],
      "defaultRows": { "*": ["com.netflix.ninja", "..."], "MY": ["..."] }
    }
    ```

    An app may carry an optional `"launchLink"`. Default rows are lists of exactly 6 packages.
  - `@immutable class CatalogueApp`:
    - fields `package`, `name`, `launchLink` (`String?`), `Set<String> regions`
    - `AppEntry toEntry()`
    - `bool isAvailableIn(String? region)`: `*`, or the region is listed.
  - `@immutable class AppCatalogue`:
    - `List<CatalogueApp> apps`, `Map<String, List<String>> defaultRows`
    - `static AppCatalogue parse(String json)` throws `FormatException` for: a missing or empty field; a duplicate package; a region that isn't `*` or two upper-case letters; a default-row package not in `apps`; a row that isn't 6 long; no `*` row.
    - `CatalogueApp? byPackage(String package)`
    - `List<AppEntry> defaultShortcutsFor(String? region)`: the row for `region?.toUpperCase()`, else `*`.
    - `List<CatalogueApp> suggestedFor(String? region)`: the region's apps (catalogue order), then the `*` apps, without duplicates.
    - `List<CatalogueApp> search(String query)`: case-insensitive substring of the name or the package; region-available apps first.
  - `@Riverpod(keepAlive: true) Future<AppCatalogue> catalogue(Ref ref)` → `catalogueProvider`, loading `rootBundle.loadString('assets/catalogue/apps_v1.json')`.
  - `@Riverpod(keepAlive: true) String? deviceRegion(Ref ref)` → `deviceRegionProvider`: the country code of the first of `WidgetsBinding.instance.platformDispatcher.locales` that has one, upper-cased; `null` if none.
- **Catalogue content.** These are our own entries. Entries marked (?) have a package name we are less sure of.
  - If you can fetch web pages, check every (?) entry against `https://play.google.com/store/apps/details?id=<package>`. Drop any that doesn't resolve, except the MY row, which is kept for the owner's device run.
  - You may add more apps you **verified** this way (Malaysia/SEA first: Astro GO, sooka, Tonton, mewatch).
  - Keep at least 50 apps. List every dropped or added entry in the report.

  | Package | Name | Regions |
  |---|---|---|
  | com.netflix.ninja | Netflix | * |
  | com.google.android.youtube.tv | YouTube | * |
  | com.amazon.amazonvideo.livingroom | Prime Video | * |
  | com.disney.disneyplus | Disney+ | * |
  | com.spotify.tv.android | Spotify | * |
  | com.apple.atve.androidtv.appletv | Apple TV | * |
  | com.google.android.youtube.tvkids | YouTube Kids | * |
  | com.google.android.youtube.tvmusic | YouTube Music | * |
  | com.plexapp.android | Plex | * |
  | org.xbmc.kodi | Kodi | * |
  | org.videolan.vlc | VLC | * |
  | com.crunchyroll.crunchyroid | Crunchyroll | * |
  | tv.twitch.android.app (?) | Twitch | * |
  | com.dazn | DAZN | * |
  | com.valvesoftware.steamlink | Steam Link | * |
  | com.nvidia.geforcenow | GeForce NOW | * |
  | deezer.android.tv | Deezer | * |
  | com.wbd.stream (?) | Max | * |
  | com.viki.android | Viki | * |
  | tv.pluto.android | Pluto TV | US, GB, DE, FR, ES, IT, CA, AU, BR, MX |
  | com.tubitv | Tubi | US, CA, AU, GB, MX |
  | com.vuclip.viu (?) | Viu | MY, SG, ID, PH, TH, HK |
  | com.iqiyi.i18n.tv (?) | iQIYI | MY, SG, ID, PH, TH, VN |
  | com.tencent.qqlivei18n (?) | WeTV | MY, ID, PH, TH, VN |
  | in.startv.hotstar.dplus (?) | Disney+ Hotstar | MY, ID, TH |
  | com.vidio.android (?) | Vidio | ID |
  | com.catchplay.asiaplay (?) | CATCHPLAY+ | SG, ID, TW |
  | in.startv.hotstar | JioHotstar | IN |
  | com.graymatrix.did | ZEE5 | IN |
  | com.sonyliv (?) | Sony LIV | IN |
  | com.hulu.livingroomplus | Hulu | US |
  | com.peacocktv.peacockandroid (?) | Peacock | US |
  | com.cbs.ott (?) | Paramount+ | US, GB, AU, CA |
  | com.sling (?) | Sling TV | US |
  | com.univision.prendetv (?) | ViX | US, MX |
  | uk.co.bbc.iplayer | BBC iPlayer | GB |
  | com.channel4.ondemand (?) | Channel 4 | GB |
  | air.ITVMobilePlayer (?) | ITVX | GB |
  | tv.wuaki (?) | Rakuten TV | ES, IT, DE, FR, NL, GB |
  | com.zattoo.player (?) | Zattoo | DE, CH, AT |
  | com.zdf.android.mediathek (?) | ZDFmediathek | DE |
  | de.prosiebensat1digital.seventv (?) | Joyn | DE |
  | com.canal.android.canal (?) | myCANAL | FR |
  | tv.molotov.app (?) | Molotov | FR |
  | com.viaplay.android (?) | Viaplay | SE, NO, DK, FI, NL, PL |
  | se.svt.android.svtplay (?) | SVT Play | SE |
  | nl.uitzendinggemist (?) | NPO Start | NL |
  | au.com.stan.and (?) | Stan | AU |
  | au.net.abc.iview (?) | ABC iview | AU |
  | com.sbs.ondemand.tv (?) | SBS On Demand | AU |
  | tv.abema (?) | ABEMA | JP |
  | jp.unext.mediaplayer (?) | U-NEXT | JP |
  | net.cj.cjhv.gs.tving (?) | TVING | KR |
  | ca.bellmedia.cravetv (?) | Crave | CA |
  | com.globo.globotv (?) | Globoplay | BR |

  Default rows (6 each; if a non-MY entry is dropped, replace it with a verified app of that region and say so):

  | Region | Row |
  |---|---|
  | `*` | Netflix, YouTube, Prime Video, Disney+, Spotify, Apple TV (the first five are the Phase 4 starter apps, in order) |
  | MY | Netflix, YouTube, Viu, Prime Video, iQIYI, Disney+ Hotstar (the master's test) |
  | SG | Netflix, YouTube, Disney+, Viu, Prime Video, iQIYI |
  | ID | Netflix, YouTube, Vidio, Disney+ Hotstar, Viu, Prime Video |
  | IN | JioHotstar, YouTube, Netflix, Prime Video, ZEE5, Sony LIV |
  | US | Netflix, YouTube, Prime Video, Hulu, Disney+, Max |
  | GB | Netflix, BBC iPlayer, YouTube, Prime Video, Disney+, Channel 4 |
  | AU | Netflix, YouTube, Stan, Prime Video, Disney+, ABC iview |

- [ ] **Step 1: Write the failing tests**

```dart
// app_catalogue_test.dart (reads the real file: File('assets/catalogue/apps_v1.json'); tests run from app/)
test('catalogue_parses_and_has_unique_packages', () {                    // master name
  final c = AppCatalogue.parse(File('assets/catalogue/apps_v1.json').readAsStringSync());
  expect(c.apps.length, greaterThanOrEqualTo(50));
  expect(c.apps.map((a) => a.package).toSet(), hasLength(c.apps.length));
  for (final a in c.apps) {
    expect(a.name.trim(), isNotEmpty);
    expect(a.toEntry().launchLink, anyOf(startsWith('market://launch?id='), startsWith('https://')));
    expect(a.regions, everyElement(matches(RegExp(r'^(\*|[A-Z]{2})$'))));
  }
});
test('default_row_uses_device_region', () {                              // master name
  String names(String? r) => c.defaultShortcutsFor(r).map((e) => e.name).join(', ');
  expect(names('MY'), 'Netflix, YouTube, Viu, Prime Video, iQIYI, Disney+ Hotstar');
  expect(names('my'), names('MY'));
  expect(names('ZZ'), names(null));
  expect(c.defaultShortcutsFor(null).take(5).map((e) => e.package),
      ['com.netflix.ninja', 'com.google.android.youtube.tv', 'com.amazon.amazonvideo.livingroom', 'com.disney.disneyplus', 'com.spotify.tv.android']);
});
test('every_default_row_has_six_known_apps', ...)
test('parse_rejects_duplicates_unknown_defaults_bad_regions_and_missing_star_row', ...) // four small JSON strings → throwsFormatException
test('search_matches_name_and_package_case_insensitively', ...)  // 'netf' and 'NINJA' both find Netflix; '' → empty
test('suggested_for_region_lists_regional_then_global_apps', ...) // 'MY' → Viu before Plex; no duplicates
test('catalogue_file_stays_under_40kb', ...)                      // File(...).lengthSync() < 40 * 1024

// catalogue_repository_test.dart
test('catalogue_provider_loads_the_bundled_file', ...)  // TestWidgetsFlutterBinding.ensureInitialized(); container.read(catalogueProvider.future) → ≥ 50 apps
testWidgets('device_region_reads_the_first_locale_with_a_country', (t) async {
  t.platformDispatcher.localesTestValue = const [Locale('en'), Locale('ms', 'my')];
  addTearDown(t.platformDispatcher.clearLocalesTestValue);
  expect(ProviderContainer.test().read(deviceRegionProvider), 'MY');
});
testWidgets('device_region_is_null_without_a_country', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/apps`
Expected: FAIL.

- [ ] **Step 3: Implement** the JSON (written by hand from public listings), the model and the providers. Add the asset to `pubspec.yaml`. Run `flutter pub get`, build_runner, then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml app/assets app/lib app/test
git commit -m "feat(app): bundled app catalogue with region default rows" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P5-R4 (data source, no icons, the default rows). For learnings, the list of (?) entries kept, dropped or verified. Owner note: the device run checks the MY row.

---

### Task 5.4: Shortcut and usage storage, seeding, recommendations, tracker

**Files:**
- Create:
  - `app/lib/features/apps/data/shortcut_repository.dart`, `app_usage_repository.dart`, `apps_data_providers.dart` (+ `.g.dart`)
  - `app/lib/features/apps/domain/package_names.dart`, `recommendations.dart`
  - `app/lib/features/apps/application/shortcuts.dart` (+ `.g.dart`)
  - `app/test/helpers/in_memory_shortcut_repository.dart`, `in_memory_app_usage_repository.dart`, `test_catalogue.dart`
- Modify:
  - `app/lib/core/storage/settings_store.dart` (`shortcutsSeeded`)
  - `app/lib/features/remote/presentation/remote_screen.dart` (`shortcutsProvider`, tracker)
  - `app/lib/features/settings/presentation/remote_layout_page.dart` (its preview reads `shortcutsProvider`)
  - `app/test/helpers/pump_router_app.dart` (defaults)
  - `app/test/features/remote/widgets/quick_access_row_test.dart`, `quick_access_row_golden_test.dart` (a local test list instead of `kStarterApps`)
- Delete: `app/lib/features/apps/data/starter_apps.dart`, `starter_apps.g.dart`, `app/test/features/apps/starter_apps_test.dart`
- Test:
  - `app/test/features/apps/shortcut_repository_test.dart`, `app_usage_repository_test.dart`, `package_names_test.dart`, `recommendations_test.dart`, `shortcuts_test.dart`
  - additions to `app/test/core/storage/settings_store_test.dart`, `app/test/features/remote/remote_screen_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`shortcuts`, `app_usage` tables), `appDatabaseProvider`, `settingsStoreProvider`, `catalogueProvider`, `deviceRegionProvider` (5.3), `currentAppProvider`, `remoteSessionProvider`, `AppEntry`.
- Produces:
  - `SettingsStore`:
    - `bool get shortcutsSeeded` (default `false`) and `Future<void> setShortcutsSeeded(bool value)`.
    - The key is `apps.shortcuts_seeded`, added to `keys`. It is **not** part of `AppSettings`.
  - Repositories:

    ```dart
    abstract interface class ShortcutRepository {
      Stream<List<AppEntry>> watchAll();                 // by position, replays current list first
      Future<List<AppEntry>> all();
      Future<int> count();
      Future<bool> add(AppEntry app);                    // appends; false (no write) if the package is already there
      Future<void> update(AppEntry app);                 // matched by package; name/launchLink/isCustom/customColor/customIcon; no-op if absent
      Future<void> remove(String package);
      Future<void> reorder(List<String> packages);       // listed packages first in that order, others after in their old order; positions 0..n-1
      Future<void> replaceAll(List<AppEntry> apps);      // one transaction; positions 0..n-1; duplicate packages after the first are dropped
    }
    @immutable class AppUsageStat { const AppUsageStat({required this.package, required this.seenCount, required this.lastSeenAt}); ... value == }
    abstract interface class AppUsageRepository {
      Future<void> recordSeen(String package, DateTime at);      // insert count 1, or count + 1 and lastSeenAt = at
      Stream<List<AppUsageStat>> watchMostUsed({int limit = 30}); // seenCount desc, lastSeenAt desc
    }
    ```

    - Drift implementations: `DriftShortcutRepository(AppDatabase)` and `DriftAppUsageRepository(AppDatabase)`.
      - `customColor` is stored as `color.toARGB32()`.
      - `recordSeen` uses `insert … onConflict: DoUpdate((old) => AppUsageCompanion.custom(seenCount: old.seenCount + const Constant(1), lastSeenAt: Variable(at)))`.
      - `DateTime`s are returned in UTC (learnings).
    - Providers: `@Riverpod(keepAlive: true) ShortcutRepository shortcutRepository(Ref ref)` and `AppUsageRepository appUsageRepository(Ref ref)`, both over `appDatabaseProvider`.
    - In-memory fakes with the same semantics (broadcast stream, replay on listen, `Object? failNextWrite`).
  - In `package_names.dart`:
    - `bool isValidPackageName(String s)`: `^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$`, ≤ 255 characters.
    - `bool isSystemPackage(String package)`:
      - Exact matches: `android`, `com.android.systemui`, `com.android.tv.settings`, `com.android.vending`, `com.android.providers.tv`, `com.google.android.tvlauncher`, `com.google.android.apps.tv.launcherx`, `com.google.android.leanbacklauncher`, `com.google.android.tv.remote.service`, `com.google.android.backdrop`, `com.google.android.apps.tv.dreamx`, `com.google.android.apps.mediashell`, `com.google.android.katniss`, `com.google.android.tungsten.setupwraith`.
      - Prefixes: `com.mediatek.`, `com.google.android.inputmethod.`, `com.android.inputmethod.`, `com.google.android.gms`, `com.google.android.gsf`.
      - Any dot-separated segment containing `launcher`.
    - `String prettyPackageName(String package)`:
      - Drop the generic segments `com org net tv android app apps atv androidtv mobile ott leanback player client prod release livingroom`.
      - Take the last remaining segment, `_` → space, upper-case its first letter. With nothing left, use the package itself.
  - In `recommendations.dart`: `List<AppEntry> recommendApps({required List<AppUsageStat> usage, required AppCatalogue catalogue, required Set<String> exclude, int limit = 8})` (Ruling P5-R6). Unknown packages → `AppEntry(package:, name: prettyPackageName(p), customIcon: kGenericAppIconId)`, where `const kGenericAppIconId = 'app'` is defined here.
  - In `application/shortcuts.dart`:
    - `@Riverpod(keepAlive: true) Future<void> shortcutsSeed(Ref ref)`: Ruling P5-R5 seeding. Watch the store, repository, catalogue future and region **before** the first await. Errors are caught and complete normally (the next launch retries, because the flag stays unset).
    - `@riverpod Stream<List<AppEntry>> shortcuts(Ref ref)` → `shortcutsProvider`: `await ref.watch(shortcutsSeedProvider.future)`, then `yield* repo.watchAll()`.
    - `class ShortcutActions`, with `@riverpod ShortcutActions shortcutActions(Ref ref)`:
      - `Future<bool> add(AppEntry)`, `update(AppEntry)`, `remove(String package)`, `reorder(List<String>)`, `replaceAll(List<AppEntry>)`
      - `Future<void> resetToDefaults()`: the catalogue's `defaultShortcutsFor(region)` → `replaceAll`.
      - Errors propagate to the caller (the UI shows `manageAppsSaveFailed`).
    - `@riverpod Stream<List<AppUsageStat>> appUsage(Ref ref)` → `appUsageProvider` (`watchMostUsed()`).
    - `@riverpod Future<List<AppEntry>> recommendedApps(Ref ref)`: `recommendApps` over `appUsageProvider`, `shortcutsProvider` (as the exclude set) and `catalogueProvider`.
    - `@riverpod void appUsageTracker(Ref ref)` (Ruling P5-R6):
      - `ref.listen(currentAppProvider, …)`.
      - The demo check reads `ref.read(remoteSessionProvider).value?.isDemo`.
      - Writes go through `appUsageRepositoryProvider` with `clock.now().toUtc()`, inside `unawaited(... .catchError((_) {}))`.
  - `RemoteScreen`:
    - `apps: ref.watch(shortcutsProvider).value ?? const []`.
    - `ref.listen(appUsageTrackerProvider, (_, _) {})` next to the power controller's listen.
    - The `starter_apps.dart` import is removed. `RemoteLayoutPage`'s preview reads `shortcutsProvider` the same way.
  - `pumpRouterApp` defaults:
    - `shortcutRepositoryProvider.overrideWithValue(InMemoryShortcutRepository())`
    - `appUsageRepositoryProvider.overrideWithValue(InMemoryAppUsageRepository())`
    - `catalogueProvider.overrideWith((ref) async => testCatalogue())`
    - `deviceRegionProvider.overrideWithValue(null)`
  - `testCatalogue()` parses the real file with `File('assets/catalogue/apps_v1.json').readAsStringSync()`.

- [ ] **Step 1: Write the failing tests**

```dart
// shortcut_repository_test.dart: one contract, run against both implementations
void contract(String name, ShortcutRepository Function() make) => group(name, () {
  test('add_appends_and_rejects_a_duplicate_package', ...)
  test('reorder_persists', ...)                        // master name: add A, B, C; reorder([C, A]) → [C, A, B]; a fresh read gives the same order
  test('replace_all_rewrites_positions_densely', ...)  // positions 0..n-1 (drift: check rows); duplicate package dropped
  test('update_changes_name_colour_and_icon_only', ...)
  test('remove_deletes_one', ...)
  test('custom_colour_round_trips', ...)               // Color(0xFF2563EB) → same Color back
  test('watch_replays_then_follows_changes', ...)
});
contract('drift', () => DriftShortcutRepository(AppDatabase(NativeDatabase.memory())));
contract('in_memory', InMemoryShortcutRepository.new);

// app_usage_repository_test.dart (contract for both)
test('record_seen_counts_and_stamps', ...)
test('most_used_orders_by_count_then_recency', ...)

// package_names_test.dart
test('filters_system_packages', () {                                     // master name
  for (final p in ['android', 'com.google.android.tvlauncher', 'com.google.android.apps.tv.launcherx', 'com.android.tv.settings',
      'com.mediatek.wwtv.tvcenter', 'com.mediatek.wwtv.mediaplayer', 'com.example.launcher3', 'com.google.android.tv.remote.service',
      'com.google.android.leanbacklauncher', 'com.google.android.apps.mediashell']) {
    expect(isSystemPackage(p), isTrue, reason: p);
  }
  for (final p in ['com.netflix.ninja', 'com.google.android.youtube.tv', 'com.example.tvapp']) expect(isSystemPackage(p), isFalse, reason: p);
});
test('unknown_package_gets_pretty_name', () {                            // master name
  expect(prettyPackageName('com.foo.bar'), 'Bar');
  expect(prettyPackageName('com.example.app.tv'), 'Example');
  expect(prettyPackageName('tv.pluto.android'), 'Pluto');
  expect(prettyPackageName('com.my_videos.tv'), 'My videos');
});
test('valid_package_names', ...)   // 'com.example.app' ok; 'example', '1com.x', 'com..x', 'com.x-y' rejected

// recommendations_test.dart
test('known_packages_use_catalogue_names', ...)        // usage com.netflix.ninja → 'Netflix', customIcon null
test('unknown_packages_get_the_generic_icon', ...)     // 'com.example.tvapp' → name 'Tvapp', customIcon 'app'
test('recommendations_skip_system_apps_and_shortcuts_and_rank_by_use', ...)
test('recommendations_stop_at_the_limit', ...)

// shortcuts_test.dart (ProviderContainer.test; in-memory repos; SettingsStore on in-memory prefs; testCatalogue; region override)
test('first_read_seeds_region_defaults_once', ...)     // region 'MY' → shortcutsProvider first non-empty value == MY row; repo writes == 1; flag true
test('seeding_never_runs_again_after_the_user_empties_the_list', ...) // flag true + empty table → stays empty in a new container
test('seeding_after_a_crash_mid_way_does_not_duplicate', ...)        // flag false + table [Netflix] → no insert; flag true
test('a_failed_seed_retries_next_time', ...)           // failNextWrite → completes; flag still false
test('reset_restores_region_defaults', ...)            // master name; custom list → resetToDefaults → region row exactly
test('tracker_records_each_new_foreground_app_once', ...)  // FakeRemoteSession connected: push CurrentAppChanged(a), (a) again, (b), drop+reconnect, (b) → usage a:1, b:1
test('tracker_ignores_the_demo_tv', ...)
test('tracker_survives_a_storage_error', ...)

// settings_store_test.dart
test('shortcuts_seeded_flag_round_trips_and_is_allow_listed', ...)

// remote_screen_test.dart
testWidgets('quick_row_shows_the_seeded_shortcuts', ...)  // pumpRouterApp at /remote → 'Open Netflix' … 'Open Apple TV' in order
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/apps test/core/storage test/features/remote/remote_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the repositories, fakes, domain functions and providers. Then delete the starter apps and switch the remote screen, the layout preview, the quick-row tests and `pumpRouterApp`. Run build_runner, then `dart format lib test`. Revert unrelated `.g.dart` line-ending churn.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS, including the Phase 4 demo tests that tap "Open Netflix".

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add -A app/lib app/test
git commit -m "feat(app): shortcut and usage storage with region seeding, recommendations and usage tracking" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Rulings P5-R5 and P5-R6. Carry-over closed: `quickAccessAppsProvider` replaced by the catalogue-seeded shortcuts. Learning: the drift `DoUpdate` upsert pattern, and drift repositories behind interfaces with in-memory fakes for widget tests.

---

### Task 5.5: App tiles and the Apps screen

**Files:**
- Create: `app/lib/features/apps/domain/shortcut_style.dart`, `app/lib/features/apps/presentation/widgets/app_tile.dart`, `app/lib/app/widgets/status_strip.dart`
- Modify:
  - `app/lib/features/apps/presentation/apps_screen.dart` (stub → screen)
  - `app/lib/features/remote/presentation/widgets/quick_app_tile.dart` (draws `AppIconSquare`)
  - `quick_access_row.dart` and `remote_body.dart` (`onAllApps`)
  - `remote_screen.dart` (uses `StatusStrip`, passes `onAllApps`)
- Test:
  - create `app/test/features/apps/app_tile_test.dart`, `apps_screen_test.dart`, `apps_screen_golden_test.dart`
  - additions to `app/test/features/remote/widgets/quick_access_row_test.dart`, `remote_screen_test.dart`
  - re-baseline `quick_access_rows_{light,dark}` and the remote goldens

**Interfaces:**
- Consumes: `AppEntry`, `kGenericAppIconId` (5.4), `colourKeyLabelColor` (`quick_access_row.dart`), `contrastRatio`, `shortcutsProvider`, `catalogueProvider`, `deviceRegionProvider`, `remoteActionsProvider`, `notConnectedNoticesProvider`, `connectionStateProvider`, `currentAppProvider`, `StatusPill`, `BannerSlot`.
- Produces:
  - In `shortcut_style.dart`:
    - `const List<Color> kShortcutColors`: Slate `#475569`, Blue `#2563EB`, Teal `#0F766E`, Green `#15803D`, Amber `#F59E0B`, Orange `#EA580C`, Red `#DC2626`, Purple `#7C3AED`, each paired with its ARB name in `String shortcutColourName(AppLocalizations l, Color c)`.
    - `const Map<String, IconData> kShortcutIcons`:
      - `app` → `Icons.apps`
      - `movies` → `Icons.movie_outlined`
      - `live` → `Icons.live_tv_outlined`
      - `sports` → `Icons.sports_soccer`
      - `music` → `Icons.music_note_outlined`
      - `kids` → `Icons.child_care_outlined`
      - `news` → `Icons.newspaper_outlined`
      - `games` → `Icons.sports_esports_outlined`
      - `learning` → `Icons.school_outlined`
    - `String shortcutIconName(AppLocalizations l, String id)`.
  - `class AppIconSquare extends StatelessWidget { const AppIconSquare({required AppEntry app, double size = 56, super.key}); }`:
    - A rounded square (`AppRadii.key`).
    - Fill: `app.customColor ?? surfaceRaised`. Ink: `customColor != null ? colourKeyLabelColor(customColor) : textPrimary`.
    - Content: `kShortcutIcons[app.customIcon]` when set (unknown id → `Icons.apps`). Otherwise the first grapheme of the name, **upper-cased** (Phase 4 carry-over), in `titleLarge`, scaled to the size.
    - Excluded from semantics (the tile carries the label).
  - `QuickAppTile` uses `AppIconSquare` for its square. The key `quick_app_square`, the dot, the semantics and `heightOf` are unchanged.
  - `class AppTile extends StatelessWidget { const AppTile({required AppEntry app, required bool isCurrent, required VoidCallback onTap, super.key}); }`:
    - The grid tile: `AppIconSquare` (56) over the name (`labelMedium`, up to 2 lines, centred, ellipsis).
    - Fills its grid cell; the whole tile is one button.
    - Semantics: `quickAppOpen(name)` or `quickAppNowOnTv(name)`.
    - The current dot as in `QuickAppTile`.
  - `class StatusStrip extends StatelessWidget`: the remote's private `_StatusStrip`, moved and made public with the same constructor (`status`, `onReconnect`, `onPairAgain`). `RemoteScreen` uses it.
  - `QuickAccessBar` gains `VoidCallback? onAllApps`. For the `apps` variant, when non-null, a last tile **All apps** is shown:
    - an `Icons.apps` square on `surface` with an `outline` border, labelled `quickAccessAllApps`
    - semantics: a button labelled "All apps"
    - it is not a TV command and never calls `input`.
  - `RemoteBody` gains `VoidCallback? onAllApps`, passed to `QuickAccessBar`. `RemoteScreen` passes `() => context.push(AppRoutes.apps)`; the layout preview passes nothing.
  - `AppsScreen` (`ConsumerStatefulWidget`, Ruling P5-R7):
    - App bar: title `pageTitleApps`; action `IconButton(Icons.edit_outlined, tooltip: pageTitleManageApps)` → `context.push(AppRoutes.manageApps)`.
    - Body (`SafeArea`, `CustomScrollView`):
      - `StatusStrip` (Reconnect/Pair again as on the remote)
      - a search `TextField` (`appsSearchLabel`, `Icons.search`, a clear button when non-empty, `textInputAction: search`)
      - `appsYourApps` header, then a `SliverGrid` (`maxCrossAxisExtent: 104`, 8 dp spacing, `childAspectRatio` from the tile's height at the current text scale) of `AppTile`
      - when searching, the `appsMoreApps` header and catalogue matches (`AppCatalogue.search`, minus shortcuts) as `AppTile`s
      - a `BannerSlot.clearance` spacer at the end.
    - `bottomNavigationBar: SafeArea(child: BannerSlot(placement: AdPlacement.apps))`.
    - Empty list and no query → a centred `appsEmptyTitle`/`appsEmptyBody` and `FilledButton(appsEmptyAction)` → push `/apps/manage`. A query with no results → `appsNoMatches(query)`.
    - Launch: `if (ref.read(remoteActionsProvider).launch(app)) context.go(AppRoutes.remote);`. The build `ref.watch`es `remoteActionsProvider`.
    - `ref.listen(notConnectedNoticesProvider, …)` shows `remoteNotConnected`: one snackbar at a time, only when `ModalRoute.isCurrentOf(context)` (learnings: snackbars queue).
    - `isCurrent` uses `currentAppProvider` only while connected.

- [ ] **Step 1: Write the failing tests**

```dart
// app_tile_test.dart
testWidgets('custom_entries_show_an_upper_case_monogram', ...)  // AppEntry(package: 'com.x.y', name: 'netflix', isCustom: true) → find.text('N')
testWidgets('custom_colour_and_icon_are_drawn_with_readable_ink', ...)
test('every_shortcut_colour_has_a_readable_label', () {
  for (final c in kShortcutColors) expect(contrastRatio(colourKeyLabelColor(c), c), greaterThanOrEqualTo(4.5));
});
testWidgets('unknown_icon_id_falls_back_to_the_generic_icon', ...)
testWidgets('app_tile_is_one_labelled_button', ...)              // 'Open Netflix'; isCurrent → 'Netflix, now on TV'

// apps_screen_test.dart (pumpRouterApp at /apps with a connected FakeRemoteSession; shortcuts seeded from the * row)
testWidgets('tile_launch_calls_remote_actions', (t) async {      // master name
  await t.tap(find.bySemanticsLabel('Open YouTube')); await t.pumpAndSettle();
  expect(fake.sentLinks, ['market://launch?id=com.google.android.youtube.tv']);
  expect(find.byType(RemoteBody), findsOneWidget);                // returned to the remote
});
testWidgets('refused_launch_shows_not_connected_and_stays', ...) // offline → 'Not connected to your TV'; still on Apps; sentLinks empty
testWidgets('search_filters_your_apps_and_shows_more_apps', ...) // 'plex' → no 'Open Netflix'; 'More apps' + 'Open Plex'; tapping it launches Plex
testWidgets('no_match_says_so', ...)                            // 'zzzz' → 'No apps match "zzzz".'
testWidgets('empty_list_offers_add_apps', ...)                  // empty repo with the seeded flag → 'Add apps' → AppBar 'Edit apps'
testWidgets('edit_action_opens_edit_apps', ...)
testWidgets('current_app_is_marked', ...)                       // push CurrentAppChanged('com.netflix.ninja') → 'Netflix, now on TV'
testWidgets('apps_screen_has_one_banner_slot_and_no_fab', ...)  // find.byType(BannerSlot) one, key banner_slot_apps; find.byType(FloatingActionButton) none
testWidgets('apps_screen_fits_320dp_at_200_percent_text', ...)  // light + dark

// quick_access_row_test.dart
testWidgets('all_apps_tile_calls_back_and_sends_nothing', ...)  // onAllApps called once; rec.calls empty
testWidgets('no_all_apps_tile_without_a_callback', ...)
// remote_screen_test.dart
testWidgets('all_apps_tile_opens_the_apps_screen', ...)
// apps_screen_golden_test.dart (@Tags(['golden'])): * row, connected, Size(390, 844), light + dark → goldens/apps_screen_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/apps test/features/remote`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner if a provider changed, then `dart format lib test`.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/apps/apps_screen_golden_test.dart test/features/remote/widgets/quick_access_row_golden_test.dart test/features/remote/remote_screen_golden_test.dart test/features/remote/remote_theater_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): apps screen, app tiles with upper-case monograms and the all-apps tile" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P5-R7. Carry-over closed: upper-case monograms.

---

### Task 5.6: Edit apps, the add sheet and the custom shortcut editor

**Files:**
- Modify: `app/lib/features/apps/presentation/manage_apps_screen.dart` (stub → screen)
- Create: `app/lib/features/apps/presentation/add_app_sheet.dart`, `custom_shortcut_editor.dart`
- Test: `app/test/features/apps/manage_apps_screen_test.dart`, `add_app_sheet_test.dart`, `custom_shortcut_editor_test.dart`, `manage_apps_golden_test.dart`

**Interfaces:**
- Consumes: `shortcutsProvider`, `ShortcutActions` (incl. `resetToDefaults`), `recommendedAppsProvider`, `catalogueProvider`, `deviceRegionProvider`, `isValidPackageName`, `prettyPackageName`, `kGenericAppIconId` (5.4); `AppIconSquare`, `kShortcutColors`, `kShortcutIcons`, `shortcutColourName`, `shortcutIconName` (5.5); `showAppSheet`, `showAppDialog`.
- Produces:
  - `ManageAppsScreen` (`ConsumerStatefulWidget`, Ruling P5-R8):
    - App bar: title `pageTitleManageApps`. Actions: `IconButton(Icons.add, tooltip: manageAppsAdd)` → `showAddAppSheet`; a `PopupMenuButton` with one item `manageAppsReset`.
    - Body: `manageAppsReorderHint` (`textSecondary`), then a `ReorderableListView.builder` with `buildDefaultDragHandles: false`.
      - Each row (min 56 dp): `AppIconSquare(size: 40)`, the name (`bodyLarge`, wraps), the package (`bodySmall`, `textSecondary`, one line, ellipsis).
      - Then `IconButton(Icons.edit_outlined, tooltip: manageAppsEdit(name))` → `showCustomShortcutEditor(context, existing: app)`, and `IconButton(Icons.remove_circle_outline, color: dangerText, tooltip: manageAppsRemove(name))`.
      - Then a `ReorderableDragStartListener` wrapping a 48 dp `Icons.drag_handle` labelled `manageAppsDragHandle(name)`.
      - Each row's `Semantics(customSemanticsActions: {Move up (not on the first), Move down (not on the last)})`.
    - Empty → `manageAppsEmpty`.
    - The local list `_items` mirrors the stream, and is updated **optimistically** on reorder/remove (no flicker). Every write is awaited. An error → `manageAppsSaveFailed` snackbar and resync from the stream.
    - Remove → `actions.remove(package)` plus a snackbar `manageAppsRemoved(name)` with `SnackBarAction(commonUndo)` → `actions.replaceAll(previousList)`.
    - Reset → `showAppDialog(manageAppsResetTitle, manageAppsResetBody, [commonCancel, manageAppsResetConfirm (isDestructive)])`. Confirmed → `resetToDefaults()`.
  - `Future<void> showAddAppSheet(BuildContext context)` (`showAppSheet(title: addAppTitle)`):
    - A search field (`addAppSearchLabel`, autofocus off).
    - Then, with no query:
      - a row `addAppCustom` (`Icons.add_box_outlined`) → `showCustomShortcutEditor(context)`, after closing this sheet
      - section `addAppRecentTitle`: `recommendedAppsProvider`, or `addAppRecentEmpty`
      - section `addAppPopularTitle`: `catalogue.suggestedFor(region)`.
    - With a query: the matching recent apps first, then `catalogue.search(query)`. If the trimmed query `isValidPackageName` and matches no catalogue package and no shortcut → a row `addAppById(query)` with `prettyPackageName` and the generic icon. No results → `addAppNoResults`.
    - Every app row: `AppIconSquare(size: 40)`, name, package. If it's already a shortcut: disabled, subtitle `addAppAlreadyAdded`, a check icon.
    - Tap → `await actions.add(entry)` → pop the sheet, then a snackbar `addAppAdded(name)`. An error → `manageAppsSaveFailed`, and the sheet stays.
  - `Future<void> showCustomShortcutEditor(BuildContext context, {AppEntry? existing})` (`showAppSheet(title: existing == null ? shortcutNewTitle : shortcutEditTitle)`):
    - A live preview: `AppIconSquare(72)` with the name under it, labelled `shortcutPreview`.
    - Name `TextField`: trimmed, 1–30 characters, else `shortcutNameError`.
    - App ID `TextField`:
      - `shortcutPackageHint`, `shortcutPackageHelp`, `keyboardType: url`, no autocorrect.
      - Read-only when `existing != null`.
      - Invalid → `shortcutPackageError`. Already a shortcut (create only) → `shortcutPackageTaken`.
    - Tile colour: a wrap of 48 dp swatches (`shortcutColourDefault` first, then `kShortcutColors`). Each is a selectable button labelled with its colour name and `selected` semantics; the selection shows a check icon (never colour alone).
    - Icon: a wrap of 48 dp choices (`shortcutIconLetter` first, then `kShortcutIcons`). Labels and selection as for colours.
    - `FilledButton(commonSave)`:
      - create → `actions.add(AppEntry(package:, name:, isCustom: true, customColor:, customIcon:))` → pop + `addAppAdded`
      - edit → `actions.update(existing` with the new name/colour/icon, `isCustom` unchanged) → pop + `shortcutSaved`.
      - An error → `manageAppsSaveFailed`, and it stays open.
    - New shortcuts take the default launch link.

- [ ] **Step 1: Write the failing tests** (`pumpRouterApp(initialLocation: AppRoutes.manageApps)` with the default in-memory repos, the `*` row seeded. Usage seeded through `InMemoryAppUsageRepository.recordSeen`)

```dart
// manage_apps_screen_test.dart
testWidgets('reorder_persists', (t) async {                              // master name
  final handle = find.bySemanticsLabel('Reorder Prime Video');
  final g = await t.startGesture(t.getCenter(handle)); await t.pump(kLongPressTimeout);
  await g.moveBy(const Offset(0, -140)); await g.up(); await t.pumpAndSettle();   // two rows up
  expect((await repo.all()).take(3).map((e) => e.name), ['Prime Video', 'Netflix', 'YouTube']);
});
testWidgets('move_up_semantic_action_reorders', ...)                     // performAction(customAction 'Move up') on Disney+'s row → order updated
testWidgets('first_row_has_no_move_up_and_last_has_no_move_down', ...)
testWidgets('remove_then_undo_restores_the_order', ...)                  // remove YouTube → snackbar 'YouTube removed'; Undo → original order
testWidgets('reset_restores_region_defaults', ...)                       // master name; custom list; Reset → Cancel keeps; Reset → Reset → * row
testWidgets('a_failed_write_says_so_and_resyncs', ...)                   // failNextWrite → 'Couldn't save your apps. Try again.'; list matches repo
testWidgets('manage_apps_fits_320dp_at_200_percent_text', ...)           // light + dark

// add_app_sheet_test.dart
testWidgets('add_sheet_lists_recent_tv_apps_without_system_packages', ...)
    // usage: android, com.mediatek.wwtv.tvcenter, com.example.tvapp(×3), com.plexapp.android(×1), com.netflix.ninja (already added)
    // → 'Recently used on your TV': Tvapp then Plex; no 'android', no 'Tvcenter'; Netflix not in the recent section
testWidgets('suggested_apps_follow_the_region', ...)                     // region 'MY' → Viu shown, not Hulu
testWidgets('search_finds_catalogue_apps_and_adds_by_id', ...)           // 'kodi' → Kodi row; 'com.example.newapp' → 'Add app ID "com.example.newapp"' → added as 'Newapp' with icon 'app'
testWidgets('apps_already_added_are_disabled', ...)                      // 'netflix' → 'Already on your list', tap does nothing
testWidgets('adding_an_app_appends_it_and_says_so', ...)                 // tap Kodi → sheet closed, 'Kodi added', repo last == Kodi
testWidgets('add_sheet_fits_320dp_at_200_percent_text', ...)

// custom_shortcut_editor_test.dart
testWidgets('editor_validates_name_and_package', ...)                    // empty name / 31 chars → name error; 'example' → package error
testWidgets('editor_rejects_a_package_already_on_the_list', ...)         // 'com.netflix.ninja' → 'This app is already on your list.'
testWidgets('editor_saves_colour_and_icon', ...)                         // tap 'Teal', 'Sports', Save → repo entry customColor Teal, customIcon 'sports', isCustom true
testWidgets('editing_keeps_the_package_and_custom_flag', ...)            // edit Netflix: package field read-only; rename 'Films' → name 'Films', isCustom false
testWidgets('preview_updates_as_you_type', ...)                          // type 'zed' → preview shows 'Z'
testWidgets('selection_is_shown_without_colour_alone', ...)              // the selected swatch has a check icon and selected semantics
testWidgets('editor_fits_320dp_at_200_percent_text', ...)
// manage_apps_golden_test.dart (@Tags(['golden'])): * row, Size(390, 844), light + dark → goldens/manage_apps_{light,dark}.png;
//   the editor with Teal + Sports, light → goldens/shortcut_editor_light.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/apps`
Expected: FAIL.

- [ ] **Step 3: Implement** the screen, sheet and editor.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/apps/manage_apps_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): edit apps with reorder, undo and reset, add sheet with tv recommendations, custom shortcuts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P5-R8. Learning: anything surprising about `ReorderableListView` drag handles or custom semantic actions in tests.

---

### Task 5.7: Your TVs, Edit TV and the shared MAC field

**Files:**
- Create:
  - `app/lib/features/devices/application/device_actions.dart` (+ `.g.dart`)
  - `app/lib/features/devices/presentation/widgets/mac_address_field.dart`, `wol_mac_help_sheet.dart`
- Modify:
  - `app/lib/features/devices/presentation/devices_screen.dart`, `edit_device_screen.dart` (stubs → screens)
  - `app/lib/core/storage/device_repository.dart` (`setNickname`)
  - `app/lib/features/remote/presentation/widgets/wol_setup_sheet.dart` (uses `MacAddressField`)
  - `device_switcher.dart` (Manage TVs)
  - `remote_screen.dart` (saved label, `onManageTvs`)
  - `app/test/helpers/in_memory_device_repository.dart` and the three private fakes (`setNickname`)
- Test:
  - create `app/test/features/devices/devices_screen_test.dart`, `edit_device_screen_test.dart`, `device_actions_test.dart`, `mac_address_field_test.dart`, `devices_golden_test.dart`
  - additions to `app/test/core/storage/device_repository_test.dart`, `app/test/features/remote/widgets/wol_setup_sheet_test.dart`, `app/test/features/remote/remote_screen_test.dart`

**Interfaces:**
- Consumes: `DeviceRepository` (+ 5.2 methods), `InMemoryDeviceRepository` (5.2), `savedDevicesProvider`, `activeTargetProvider`, `remoteSessionProvider`, `parseMac`, `wakeOnLanAvailableProvider`, `identityStoreProvider` (tests only), `showAppSheet`, `showAppDialog`, `StatusPill` strings.
- Produces:
  - `DeviceRepository.setNickname(String serviceName, String? nickname)`: a targeted update; a no-op for unknown TVs.
  - `class DeviceActions`, with `@riverpod DeviceActions deviceActions(Ref ref)`:
    - `Future<void> rename(String serviceName, String? nickname)`: trims; empty → `null`.
    - `Future<void> setWolMac(String serviceName, String? mac)`
    - `Future<void> delete(String serviceName)` (Ruling P5-R9):
      - `repo.delete`, then, if `activeTargetProvider == DeviceTarget(name)` or the current session's `pairingTarget?.serviceName == name`: `activeTarget.clear()` and `ref.container.invalidate(remoteSessionProvider)`.
      - It never touches `IdentityStore`.
    - Errors propagate.
  - `String? macFieldError(AppLocalizations l, String text)`: empty → `null` (valid: clears); `text.trim().length > 17` → `wolMacTooLong`; `parseMac(text) == null` → `wolMacError`; otherwise `null`.
  - `class MacAddressField extends StatelessWidget { const MacAddressField({required TextEditingController controller, String? errorText, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, TextInputAction textInputAction = TextInputAction.done, super.key}); }`:
    - `visiblePassword` keyboard, `textCapitalization.characters`, no autocorrect or suggestions.
    - **No** filtering or length-clamping formatters (Ruling P5-R9).
    - `labelText: wolMacLabel`, `hintText: wolMacHint`, `errorMaxLines: 4`.
  - `WolSetupForm` uses `MacAddressField` and `macFieldError` (empty is invalid there: show `wolMacError`). Its `_MaxTrimmedLength` formatter is deleted.
  - `Future<void> showWolMacHelpSheet(BuildContext context)`: `showAppSheet(title: wolHelpTitle)` with `wolSetupBody`, `wolNotBluetooth` (semibold) and `wolMayNotWork`.
  - `DevicesScreen`:
    - App bar: title `pageTitleDevices`; action `IconButton(Icons.add, tooltip: remoteAddTv)` → `context.push(AppRoutes.discover)`.
    - A list of saved TVs from `savedDevicesProvider` (most recent first), each a `ListTile` (min 56 dp):
      - `leading: Icon(Icons.tv)`, title `label`
      - subtitle: the announced name when a nickname is set, then `devicesInUse` (the session's TV) and/or `statusNeedsPairing` (no pin), joined with " · "
      - a trailing chevron, semantics `devicesEditTv(label)`
      - tap → `context.push(AppRoutes.editDevice(serviceName))`.
    - Empty → `devicesEmptyTitle`/`devicesEmptyBody` + `FilledButton(remoteAddTv)`. No banner slot.
  - `EditDeviceScreen(serviceName)`:
    - Reads the device from `savedDevicesProvider` (by name). Loading → spinner with title `pageTitleEditDevice`. Not found → `editDeviceNotFound` + `FilledButton(editDeviceBackToTvs)` → `context.go(AppRoutes.devices)`.
    - Found:
      - Title: `label`.
      - Nickname field: `editDeviceNameLabel`, helper `editDeviceNameHelp(displayName)`, error `editDeviceNameError` above 40 characters.
      - `editDeviceLastAddress(lastHost)` (`textSecondary`). Shown locally only; never logged.
      - Section `editDeviceWolTitle` / `editDeviceWolBody`, a `MacAddressField` prefilled with `wolMac`, and a `TextButton(editDeviceWolHelp)` → help sheet. On iOS without the entitlement (`wakeOnLanAvailableProvider == false`), also `editDeviceWolUnavailable`.
      - `FilledButton(commonSave)`: validates both fields, then `rename` + `setWolMac` (only the changed ones). Success → `editDeviceSaved` snackbar; error → `editDeviceSaveFailed`.
      - `OutlinedButton(statusPairAgainAction)` → `context.push(AppRoutes.pair(serviceName))` (no extra; Ruling P5-R10 c). Shown first and as `FilledButton` when the pin is `null`.
      - `TextButton(editDeviceRemove)` in `dangerText` → `showAppDialog(editDeviceRemoveTitle(label), editDeviceRemoveBody, [commonCancel, editDeviceRemoveConfirm (isDestructive)])`. Confirmed → `delete` → `context.pop()` → snackbar `editDeviceRemoved(label)` on the Your TVs screen.
    - A `SingleChildScrollView` with 16 dp gutters; buttons are full width at ≥ 48 dp.
  - `DeviceSwitcher` gains `required VoidCallback onManageTvs` and a row `remoteManageTvs` (`Icons.tune`) before "Add a TV". It is called after the sheet closes.
  - `RemoteScreen`:
    - `onManageTvs: () => context.push(AppRoutes.devices)`.
    - One helper `String _label(AppLocalizations l, RemoteSession s, List<SavedDevice> devices)`: demo → `demoTvName`; otherwise the saved device whose `serviceName == s.pairingTarget?.serviceName` → its `label`, else `s.tvName`. It is used for the title, `powerWaking`, the WoL sheet title and the identity dialog (Ruling P5-R9). The reload-time label logic is kept.

- [ ] **Step 1: Write the failing tests** (screens through `pumpRouterApp` with `deviceRepositoryProvider.overrideWithValue(repo = InMemoryDeviceRepository())` and `savedDevicesProvider.overrideWith((ref) => ref.watch(deviceRepositoryProvider).watchAll())`; remote parts with a `FakeRemoteSession` whose `pairingTarget` is `savedTv().toDiscoveredTv()`)

```dart
// edit_device_screen_test.dart
testWidgets('rename_updates_switcher', (t) async {                       // master name
  // start at /remote; open switcher → 'Manage TVs' → 'Living Room TV 3' → name 'Bedroom' → Save → back twice
  expect(find.descendant(of: find.byType(AppBar), matching: find.text('Bedroom')), findsOneWidget);
  await t.tap(find.byTooltip('Switch TV')); await t.pumpAndSettle();
  expect(find.text('Bedroom'), findsWidgets);
});
testWidgets('clearing_the_name_returns_to_the_tv_name', ...)             // nickname '' → stored null; label 'Living Room TV 3'
testWidgets('name_over_40_characters_is_refused', ...)
testWidgets('mac_field_validates_format', (t) async {                    // master name
  await t.enterText(find.byType(MacAddressField), 'zz'); await t.tap(find.text('Save')); await t.pump();
  expect(find.text('Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF'), findsOneWidget);
  await t.enterText(find.byType(MacAddressField), 'aa-bb-cc-dd-ee-f0'); await t.tap(find.text('Save')); await t.pumpAndSettle();
  expect((await repo.find('Living Room TV 3'))!.wolMac, 'AA:BB:CC:DD:EE:F0');
  await t.enterText(find.byType(MacAddressField), ''); await t.tap(find.text('Save')); await t.pumpAndSettle();
  expect((await repo.find('Living Room TV 3'))!.wolMac, isNull);
});
testWidgets('over_long_pasted_mac_shows_an_error_instead_of_vanishing', ...)  // enterText 'AA:BB:CC:DD:EE:FF:00' → text kept; Save → wolMacTooLong
testWidgets('delete_requires_confirmation_and_clears_identity_pairing_flag', (t) async {   // master name
  final before = (await identityStore.loadOrCreate()).certificatePem;     // the identityStoreProvider instance used by the app
  // Remove TV → Cancel → row still there; Remove TV → Remove → row gone (and its pin); 'Living Room TV 3 removed' on Your TVs
  expect((await identityStore.loadOrCreate()).certificatePem, before);   // client identity untouched
  expect(await repo.find('Bedroom TV'), isNotNull);                       // other TVs keep their pairing
});
testWidgets('save_failure_says_so', ...)                                  // failNextWrite → 'Couldn't save. Try again.'
testWidgets('pair_again_from_edit_screen_resolves_the_host', ...)         // PairingScreen.tv == null; resolver called
testWidgets('unpaired_tv_puts_pair_again_first', ...)
testWidgets('edit_screen_for_an_unknown_tv_offers_the_way_back', ...)
testWidgets('wol_help_sheet_explains_where_to_find_the_mac', ...)
testWidgets('ios_without_entitlement_notes_wol_unavailable', ...)         // wakeOnLanAvailableProvider false → editDeviceWolUnavailable text
testWidgets('edit_device_fits_320dp_at_200_percent_text', ...)            // light + dark

// devices_screen_test.dart
testWidgets('devices_list_marks_the_tv_in_use_and_unpaired_tvs', ...)
testWidgets('add_a_tv_opens_discovery', ...)
testWidgets('empty_list_offers_to_add_a_tv', ...)
testWidgets('manage_tvs_in_switcher_opens_your_tvs', ...)                 // from /remote
testWidgets('devices_screen_has_no_banner_slot', ...)
testWidgets('devices_screen_fits_320dp_at_200_percent_text', ...)

// device_actions_test.dart (ProviderContainer.test)
test('deleting_the_active_tv_switches_to_the_next_saved_tv', ...)  // two TVs; active A → delete A → remoteSessionProvider rebuilt for B
test('deleting_the_last_tv_leaves_no_session', ...)                // → remoteSessionProvider value null
test('deleting_another_tv_keeps_the_session', ...)                 // same session instance
test('rename_trims_and_empty_clears', ...)

// mac_address_field_test.dart
test('mac_field_error_rules', ...)   // '' → null; ' aa:bb:cc:dd:ee:f0 ' → null; 'AA:BB:CC:DD:EE:FF:00' → wolMacTooLong; 'zz' → wolMacError
// wol_setup_sheet_test.dart (addition)
testWidgets('setup_sheet_over_long_paste_shows_an_error', ...)
// device_repository_test.dart
test('set_nickname_updates_only_the_nickname', ...)
// devices_golden_test.dart (@Tags(['golden'])): two TVs (one nicknamed, one unpaired), Size(390, 844), light + dark →
//   goldens/devices_screen_{light,dark}.png; edit screen with a MAC, dark → goldens/edit_device_dark.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/devices test/core/storage test/features/remote`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/devices/devices_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS (Phase 4 power and WoL sheet tests included).

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): your tvs with rename, mac setup and removal; shared mac field" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P5-R9. Carry-overs closed: the edit screen reuses `parseMac`/the MAC field, and an over-long paste is no longer dropped silently. Learning: (unverified) whether the TV keeps trusting a removed phone.

---

### Task 5.8: Settings hub, Appearance, Remote layout and Remote behaviour

**Files:**
- Create: `app/lib/features/settings/presentation/widgets/settings_tiles.dart`, `app/lib/app/l10n/language_names.dart`, `app/lib/app/theme/dynamic_color_support.dart` (+ `.g.dart`)
- Modify (stubs → pages): `app/lib/features/settings/presentation/settings_screen.dart`, `appearance_page.dart`, `remote_layout_page.dart`, `remote_behaviour_page.dart`
- Test: `app/test/features/settings/settings_screen_test.dart`, `appearance_page_test.dart`, `remote_layout_page_test.dart`, `remote_behaviour_page_test.dart`, `settings_golden_test.dart`; addition to `app/test/app/app_test.dart`

**Interfaces:**
- Consumes: `settingsControllerProvider` (`update`), `SettingsStore` setters, `AppLocalizations.supportedLocales`, `localeFromCode`, `DynamicColorPlugin` (dynamic_color 2.1.0), `RemoteBody`, `PadPage`, `quickAccessAppsProvider` (as it is now; 5.4 switches the preview to `shortcutsProvider`), `BannerSlot`, `buildRootWidget` (tests).
- Produces:
  - In `settings_tiles.dart`:
    - `SettingsSectionHeader(String title)`: `titleSmall` in accent, 16 dp start padding, semantics `header: true`.
    - `SettingsNavTile({required String title, String? subtitle, IconData? icon, required VoidCallback onTap, bool external = false})`:
      - min 56 dp; title and subtitle wrap
      - trailing `Icons.chevron_right`, or `Icons.open_in_new` with semantics hint `settingsOpensInBrowser` when `external`.
    - `SettingsSwitchTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged})`: a `SwitchListTile` whose whole row toggles.
    - `SettingsChoiceGroup<T>({required String label, required T value, required List<(T value, String title, String? subtitle)> choices, required ValueChanged<T> onChanged})`: a labelled `RadioGroup` of `RadioListTile`s, min 56 dp each.
  - `const Map<String, String> kLanguageNames = {'en': 'English', 'ms': 'Bahasa Melayu'};` (endonyms; data). An unknown code shows the code itself.
  - `@Riverpod(keepAlive: true) Future<bool> dynamicColorSupported(Ref ref)` → `(await DynamicColorPlugin.getCorePalette()) != null`. Any error → `false`.
  - `SettingsScreen` (hub, Ruling P5-R11): a `ListView` of sections and rows, ending with a `BannerSlot.clearance` spacer, and `bottomNavigationBar: SafeArea(child: BannerSlot(placement: AdPlacement.settings))`. Rows:
    - Remote: Remote layout → push `settingsRemoteLayout`; Remote behaviour → `settingsRemoteBehaviour`; Apps (`pageTitleApps`, `settingsAppsSubtitle`) → `manageApps`; Your TVs → `devices`.
    - App: Appearance.
    - Help and feedback: Help → `settingsHelp`; Send feedback, which in this task shows `settingsLinkFailed`. Task 5.9 wires it.
    - About: About this app → `settingsAbout`; Privacy policy and Terms of use (`external: true`), same placeholder handler until 5.9.
  - `AppearancePage`:
    - `SettingsChoiceGroup<ThemePreference>` (Same as phone / Light / Dark) → `setThemePreference`.
    - When `dynamicColorSupportedProvider` is `AsyncData(true)`: `SettingsSwitchTile(appearanceDynamicColour)` → `setDynamicColor`.
    - `SettingsChoiceGroup<String?>`: `null` = `appearanceLanguageSystem`, then one entry per supported locale → `setLocaleCode`.
  - `RemoteLayoutPage`:
    - **Preview** (`layoutPreviewTitle`, then a 280 dp-high box):
      - `Semantics(label: layoutPreviewSemantics, image: true, child: ExcludeSemantics(child: IgnorePointer(child: FittedBox(child: SizedBox(360 × 640, child: MediaQuery(size 360×640, textScaler: TextScaler.noScaling, disableAnimations: true, accessibleNavigation: false, child: RemoteBody(...)))))))`
      - with a private no-op `RemoteInput`, `enabled: true`, `volume: VolumeChanged(12, 100, false)`, `initialPage` from the chosen style, `onPageChanged: (_) {}`, `onKeyboard: () {}`, the apps from the provider, and a `ValueKey((navigationStyle, quickAccessRow))` so it rebuilds on a change.
    - Navigation: Touchpad / D-pad with subtitles → `setNavigationStyle`.
    - Row above the pad: App shortcuts / Colour keys / Media keys / Nothing with subtitles → `setQuickAccessRow`.
  - `RemoteBehaviourPage`: five `SettingsSwitchTile`s in this order: haptics, Smooth Press, keep screen on, theater mode, open keyboard automatically. Each writes its setter through `settingsControllerProvider.notifier.update`.

- [ ] **Step 1: Write the failing tests**

```dart
// settings_screen_test.dart (pumpRouterApp at /settings)
testWidgets('hub_lists_every_section_and_opens_its_page', ...)
    // for (row, title) in [('Remote layout','Remote layout'), ('Remote behaviour','Remote behaviour'), ('Apps','Edit apps'),
    //   ('Your TVs','Your TVs'), ('Appearance','Appearance'), ('Help','Help'), ('About this app','About this app')]:
    //   scrollUntilVisible, tap → AppBar title; pageBack → AppBar 'Settings'
testWidgets('hub_has_one_banner_slot_and_no_fab', ...)                   // key banner_slot_settings
testWidgets('external_rows_say_they_open_the_browser', ...)              // semantics hint 'Opens in your browser' on Privacy policy and Terms of use
testWidgets('settings_hub_fits_320dp_at_200_percent_text', ...)          // light + dark

// app_test.dart (buildRootWidget, so the real App applies the theme)
testWidgets('theme_switch_applies_immediately', (t) async {               // master name
  _prefs({'settings.onboarding_complete': true}); await t.pumpWidget(await _root()); await t.pumpAndSettle();
  router(t).push(AppRoutes.settingsAppearance); await t.pumpAndSettle();
  await t.tap(find.text('Dark')); await t.pump();
  expect(Theme.of(t.element(find.text('Appearance').first)).brightness, Brightness.dark);
  await t.tap(find.text('Light')); await t.pump();
  expect(Theme.of(t.element(find.text('Appearance').first)).brightness, Brightness.light);
});

// appearance_page_test.dart
testWidgets('dynamic_colour_switch_shows_only_when_supported', ...)      // override dynamicColorSupportedProvider false → absent; true → toggling writes store.dynamicColor
testWidgets('language_choices_come_from_supported_locales', ...)         // 'Same as phone' + 'English'; choose English → store.localeCode 'en'; Same as phone → null
testWidgets('stored_theme_is_selected', ...)
testWidgets('appearance_fits_320dp_at_200_percent_text', ...)

// remote_layout_page_test.dart
testWidgets('navigation_style_choice_persists_and_the_remote_opens_on_it', ...) // D-pad → store dpad; go /remote → Dpad visible
testWidgets('quick_access_choice_updates_the_preview', ...)              // Colour keys → preview subtree contains QuickAccessBar(variant: colourKeys)
testWidgets('preview_is_one_image_node_and_takes_no_taps', ...)          // semantics: one node 'Preview of the remote with these choices'; tapping it sends nothing
testWidgets('remote_layout_fits_320dp_at_200_percent_text', ...)

// remote_behaviour_page_test.dart
testWidgets('switches_show_stored_values', ...)                          // prepareSettings sets each off/on → matching Switch.value
testWidgets('each_behaviour_switch_writes_its_setting', ...)             // tap each title → store getter flipped
testWidgets('remote_behaviour_fits_320dp_at_200_percent_text', ...)
// settings_golden_test.dart (@Tags(['golden'])): hub, Size(390, 844), light + dark → goldens/settings_hub_{light,dark}.png;
//   remote layout page, light → goldens/remote_layout_page_light.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/settings test/app/app_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/settings/settings_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): settings hub with appearance, remote layout preview and remote behaviour" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P5-R11. Carry-over closed: settings pages for every Phase 4 toggle and the quick-access variant. Learning: the `RadioGroup` API and the preview `MediaQuery` trick.

---

### Task 5.9: Help, About, legal links and feedback

**Files:**
- Modify:
  - `app/pubspec.yaml` (deps `url_launcher: 6.3.3`, `package_info_plus: 10.2.2`; asset `assets/licenses/`)
  - `app/android/app/src/main/AndroidManifest.xml` (`<queries>`)
  - `app/lib/bootstrap.dart` (`registerAppLicenses()`)
  - `app/lib/features/settings/presentation/settings_screen.dart` (the feedback and legal handlers only)
  - `help_page.dart`, `about_page.dart` (stubs → pages)
- Create:
  - `app/assets/licenses/androidtvremote2.txt` (a byte-for-byte copy of `packages/atv_remote/proto/LICENSE-androidtvremote2`)
  - `app/lib/app/app_links.dart`, `app/lib/app/licenses.dart`
  - `app/lib/core/links/link_opener.dart` (+ `.g.dart`), `app/lib/core/app_info/app_info.dart` (+ `.g.dart`)
  - `app/lib/features/settings/application/feedback.dart`
  - `app/test/helpers/recording_link_opener.dart`
- Test: `app/test/features/settings/help_page_test.dart`, `about_page_test.dart`, `feedback_test.dart`, `legal_links_test.dart`, `help_golden_test.dart`, `app/test/app/licenses_test.dart`, `app/test/platform/android_queries_test.dart`

**Interfaces:**
- Consumes: `SettingsNavTile` and friends (5.8), `showTroubleshootingSheet` (discovery), `showAppDialog`, `showLicensePage`, `LicenseRegistry`.
- Produces:
  - `abstract final class AppLinks`:
    - `static final Uri privacyPolicy = Uri.parse('https://example.com/privacy');`
    - `static final Uri terms = Uri.parse('https://example.com/terms');`
    - `static const String supportEmail = 'support@example.com';`
    - Each documented `/// PLACEHOLDER until the owner provides the real address (Phase 9 replaces it).`
  - `abstract interface class LinkOpener { Future<bool> open(Uri uri); }`:
    - `UrlLauncherLinkOpener`: `launchUrl(uri, mode: LaunchMode.externalApplication)`; any throw → `false`.
    - `@Riverpod(keepAlive: true) LinkOpener linkOpener(Ref ref)`.
    - Test helper `RecordingLinkOpener` (`List<Uri> opened`, `bool result = true`).
  - `@immutable class AppInfo { appName, version, buildNumber, os, osVersion }`, with `@Riverpod(keepAlive: true) Future<AppInfo> appInfo(Ref ref)` from `PackageInfo.fromPlatform()`, `Platform.operatingSystem` and `Platform.operatingSystemVersion`. Tests override it.
  - In `feedback.dart`:
    - `Uri feedbackMailUri({required AppInfo info, required String subject, required String prompt})`:
      - `mailto:${AppLinks.supportEmail}?subject=…&body=…`, built with `Uri.encodeComponent` (spaces → `%20`).
      - Body = `'$prompt\n\n\n---\nApp: ${info.version} (${info.buildNumber})\nSystem: ${info.os} ${info.osVersion}'` (Ruling P5-R12).
    - `Future<void> sendFeedback(BuildContext context, WidgetRef ref)`:
      - `showAppDialog(feedbackTitle, feedbackBody, [commonCancel, feedbackConfirm (isPrimary)])`.
      - Confirmed → `await ref.read(appInfoProvider.future)`. A failure gives `AppInfo('?', '?', '?', os, osVersion)`, so feedback still works.
      - Then `opener.open(feedbackMailUri(...))`. `false` → snackbar `feedbackNoEmailApp(AppLinks.supportEmail)`.
    - `Future<void> openExternal(BuildContext context, WidgetRef ref, Uri uri)` → `opener.open`; `false` → `settingsLinkFailed` snackbar.
  - Hub: Send feedback → `sendFeedback`; Privacy policy → `openExternal(AppLinks.privacyPolicy)`; Terms of use → `openExternal(AppLinks.terms)`.
  - `HelpPage`:
    - A card with `helpCantConnectTitle`, `helpCantConnectBody` and `FilledButton.tonal(helpTroubleshootingAction)` → `showTroubleshootingSheet(context)`.
    - `helpFaqTitle`, then 7 `ExpansionTile`s (Q/A pairs in the Task 5.1 order), each with its own controller (`ExpansibleController` in this SDK; `ExpansionTileController` is its older name). Expanding one collapses the others (an accordion).
    - Answers in `bodyLarge`, `textPrimary`. Reduce motion → `Duration.zero`.
    - Then `helpStillStuck` with `OutlinedButton(settingsFeedback)` → `sendFeedback`.
  - `AboutPage`:
    - The flavor's app name (`flavorProvider.displayName`, `titleLarge`).
    - `aboutVersion(version, build)`, or `aboutVersionUnknown` on error.
    - `SettingsNavTile(aboutLicences)` → `showLicensePage(context: context, applicationName: displayName, applicationVersion: version)`.
    - `aboutProtocol` and `aboutTrademark` (`bodyMedium`, `textSecondary`). No banner slot.
  - `void registerAppLicenses()` (in `app/licenses.dart`): `LicenseRegistry.addLicense(() async* { yield LicenseEntryWithLineBreaks(['androidtvremote2'], await rootBundle.loadString('assets/licenses/androidtvremote2.txt')); })`. Called once from `bootstrap` before `runApp`.
  - `AndroidManifest.xml` `<queries>`: `<intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>` and `<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>`. No new permissions. iOS needs no `Info.plist` change (`launchUrl` doesn't need `LSApplicationQueriesSchemes`).

- [ ] **Step 1: Write the failing tests**

```dart
// feedback_test.dart
testWidgets('feedback_mail_body_excludes_tv_name_and_ip', (t) async {   // master name
  // pumpRouterApp at /settings; a saved TV 'Living Room TV 3' @ 192.168.0.20, wolMac AA:BB:CC:DD:EE:F0, nickname 'Den';
  // linkOpenerProvider → RecordingLinkOpener; appInfoProvider → AppInfo('Remotely Dev', '1.0.0', '1', 'android', '12')
  await t.tap(find.text('Send feedback')); await t.pumpAndSettle(); await t.tap(find.text('Write email')); await t.pumpAndSettle();
  final mail = Uri.decodeFull(opener.opened.single.toString());
  for (final s in ['Living Room TV 3', 'Den', '192.168.0.20', 'AA:BB:CC:DD:EE:F0', 'com.netflix.ninja']) expect(mail, isNot(contains(s)));
  expect(RegExp(r'\b\d{1,3}(\.\d{1,3}){3}\b').hasMatch(mail), isFalse);
  expect(mail, contains('App: 1.0.0 (1)'));
});
test('feedback_mail_encodes_spaces_as_percent_20', ...)   // feedbackMailUri(...).toString() contains '%20' and no '+'
testWidgets('feedback_cancel_opens_nothing', ...)
testWidgets('no_email_app_shows_the_address', ...)        // opener.result = false → 'No email app found. Write to us at support@example.com.'
testWidgets('feedback_works_when_app_info_fails', ...)    // appInfoProvider throws → still opens mailto with '?'

// legal_links_test.dart
testWidgets('privacy_and_terms_open_in_the_browser', ...) // opened == [AppLinks.privacyPolicy, AppLinks.terms]
testWidgets('a_link_that_fails_to_open_says_so', ...)     // result false → settingsLinkFailed text
test('links_are_https_and_the_email_is_valid', ...)

// help_page_test.dart (pumpRouterApp at /settings/help)
testWidgets('faq_opens_one_answer_at_a_time', ...)        // tap Q1 → A1 visible; tap Q2 → A2 visible, A1 gone
testWidgets('faq_answers_are_ours', ...)                  // every Q/A pair from the 5.1 table is present (7)
testWidgets('troubleshooting_button_opens_the_steps', ...) // → "Can't find your TV?" sheet
testWidgets('help_feedback_button_starts_feedback', ...)
testWidgets('help_fits_320dp_at_200_percent_text', ...)   // light + dark, all answers expanded one by one

// about_page_test.dart
testWidgets('about_shows_version_and_build', ...)         // 'Version 1.0.0 (1)'; trademark line present
testWidgets('about_survives_missing_package_info', ...)   // provider error → 'Version unavailable'
testWidgets('licences_row_opens_the_licence_page', ...)   // tap → LicensePage found
testWidgets('about_fits_320dp_at_200_percent_text', ...)

// licenses_test.dart
testWidgets('licences_include_androidtvremote2', (t) async {
  registerAppLicenses();
  final entries = await t.runAsync(() => LicenseRegistry.licenses.toList());
  expect(entries!.expand((e) => e.packages), contains('androidtvremote2'));
});
test('bundled_licence_matches_the_package_copy', ...)     // File('assets/licenses/androidtvremote2.txt') == File('../packages/atv_remote/proto/LICENSE-androidtvremote2')

// android_queries_test.dart (reads the manifest as text, like the existing platform tests)
test('android_manifest_declares_mailto_and_https_queries', ...)
// help_golden_test.dart (@Tags(['golden'])): Help with the first answer open, Size(390, 844), dark → goldens/help_page_dark.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/settings test/app/licenses_test.dart test/platform`
Expected: FAIL.

- [ ] **Step 3: Add the dependencies**

Run: `flutter pub add url_launcher:6.3.3 package_info_plus:10.2.2`

- [ ] **Step 4: Implement.** Copy the licence file and add the asset. Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Generate the golden, run the tests, build the dev APK**

Run `flutter test --update-goldens --tags golden test/features/settings/help_golden_test.dart` (inspect), then `flutter test`, then `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
Expected: all PASS, and the build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/android app/assets app/lib app/test
git commit -m "feat(app): help with faq and troubleshooting, about with licences, legal links and email feedback" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P5-R12 and the pins url_launcher 6.3.3 and package_info_plus 10.2.2. Owner notes: the placeholder links and support address, and the Mac `pod install` for the two new plugins. Learning: `Uri(queryParameters:)` encodes spaces as `+` in `mailto:`.

---

### Task 5.10: Seam tests, banner sweep, accessibility and the phase exit

**Files:**
- Create (tests): `app/test/app/apps_devices_settings_flow_test.dart`, `app/test/app/phase5_accessibility_test.dart`
- Modify: production files only to fix defects these tests reveal (name each one in the report)

**Interfaces:**
- Consumes: everything above. The real `TvRemoteSession` path with `FakeRemoteClients` and an `InMemoryDeviceRepository` (with `savedDevicesProvider` following it); `DemoRemoteSession`.
- Produces: no new production API. This task proves that the pieces work together through the real session, providers and router.

- [ ] **Step 1: Write the tests**

```dart
// apps_devices_settings_flow_test.dart
testWidgets('edit_apps_then_the_remote_row_follows', ...)
    // /remote → Settings → Apps → add custom 'Zed' (com.example.zed) → move it to the top → back ×3 → quick row's first tile 'Open Zed'
testWidgets('recently_used_on_tv_appears_in_the_add_sheet', ...)
    // client.push(CurrentAppChanged('com.mediatek.wwtv.tvcenter')), push('com.example.tvapp') → Edit apps → Add → 'Tvapp' listed, no 'Tvcenter'
testWidgets('apps_screen_launch_reaches_the_client_and_returns_to_the_remote', ...)
    // All apps → 'Open Plex' (More apps via search) → clients.created.last.sentLinks ends with market://launch?id=com.plexapp.android; RemoteBody shown
testWidgets('demo_launch_from_the_apps_screen_shows_in_the_preview_and_is_not_recorded', ...)
    // demo → All apps → 'Open Netflix' → preview 'Opened market://launch?id=com.netflix.ninja'; usage repo empty
testWidgets('renaming_the_active_tv_updates_the_title_and_switcher', ...)
testWidgets('deleting_the_active_tv_switches_to_the_next_saved_tv', ...)   // two saved TVs → remove active → title is the other TV, status connects
testWidgets('deleting_the_only_tv_shows_no_tv_selected', ...)
testWidgets('mac_saved_in_edit_tv_is_used_by_power', ...)       // offline; Edit TV MAC → back → hold Power → FakeWakeOnLan.wakes [(mac, host)]
testWidgets('merged_tv_with_a_different_key_asks_to_pair_again', ...)
    // saved manual:192.168.0.20 (pin of key A); discovery 'Living Room TV 3' @ .20; FakeRemoteClients present key B → after the merge tap:
    // identity-changed dialog shown; repo pin for 'Living Room TV 3' cleared
testWidgets('settings_toggles_change_the_remote_live', ...)     // Remote behaviour: Smooth Press off → back → hold Volume up 400 ms → repeated shorts
testWidgets('settings_subpage_back_returns_to_the_hub', ...)    // push hub → Appearance → pageBack → 'Settings' (one hub page: pageBack again → remote)
testWidgets('each_settings_page_title_names_the_page', ...)     // master name; every /settings/* route, /apps/manage, /devices: AppBar title == page name, never just 'Settings'
testWidgets('banner_slot_only_on_apps_and_the_settings_hub', (t) async {
  // for every route (onboarding, discover, pair, remote, apps, apps/manage, devices, devices/<tv>, settings and each sub-page, paywall):
  // find.byType(BannerSlot) → one on /apps (AdPlacement.apps) and /settings (AdPlacement.settings), none elsewhere;
  // also open every sheet reachable from those screens: none contains a BannerSlot
});
testWidgets('no_mic_button_anywhere', ...)                      // Icons.mic / mic_none / mic_outlined absent on every Phase 5 screen (decision #7)

// phase5_accessibility_test.dart: for each of /apps, /apps/manage, /devices, /devices/<tv>, /settings and its 5 sub-pages,
// in light and dark:
testWidgets('${route}_meets_text_contrast_${b.name}', ...)      // meetsGuideline(textContrastGuideline)
testWidgets('${route}_meets_tap_target_guidelines_${b.name}', ...) // androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline
testWidgets('every_new_screen_fits_320dp_at_200_percent_text', ...) // Size(320, 640), textScale 2, each route and each sheet (add app, editor, MAC help): no exception
testWidgets('every_new_screen_fits_a_non_linear_text_scaler', ...)  // a TextScaler subclass that scales 14 → 28 but 28 → 40 (learnings): no exception
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/apps_devices_settings_flow_test.dart test/app/phase5_accessibility_test.dart`
Expected: they may fail. A failure here is a real defect: fix it in the owning file, name the fix in the report, and don't weaken the test.

- [ ] **Step 3: Fix** what the tests revealed.
- [ ] **Step 4: Run every test and the goldens**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Build the dev APK**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): apps, devices and settings seams, banner sweep and accessibility guidelines" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: every defect the seam tests found, with its fix.

---

## Phase exit checklist

- [ ] `powershell -File tool/check.ps1` → `All checks passed.` (goldens included). `tool/check.sh` passes with goldens excluded.
- [ ] Golden PNGs:
  - new: `apps_screen_{light,dark}`, `manage_apps_{light,dark}`, `shortcut_editor_light`, `devices_screen_{light,dark}`, `edit_device_dark`, `settings_hub_{light,dark}`, `remote_layout_page_light`, `help_page_dark`
  - re-baselined: `remote_portrait_{light,dark}`, `remote_landscape`, `remote_tablet`, `remote_theater` (Settings button, All apps tile), `quick_access_rows_{light,dark}`.
- [ ] Every carry-over to Phase 5 in `status.md` is closed by a task report, or deferred:
  - Phase 4:
    - settings pages for the toggles and the quick-access variant (5.8)
    - catalogue replaces `quickAccessAppsProvider` (5.4) and monograms are upper-case (5.5)
    - the edit-device screen reuses `parseMac`/the MAC field, and an over-long paste is no longer dropped (5.7)
    - append-only hardening and grapheme tests (5.2); the `kImeTextMode` flip itself is **deferred** to the device run (P5-R13)
  - Phase 3: `lastHost` on tap, the `toDiscoveredTv` name, re-resolve before Pair again, the manual → mDNS merge (all 5.2).
- [ ] **Real-device run (owner + Claude).** The Phase 3 and 4 runs are still open, so do them first or together. Phone: Note10+ over ADB Wi-Fi. TV: "Living Room TV 3". Run `flutter run --flavor dev -t lib/main_dev.dart`. Follow the live-testing rules: check the screen before each tap, never use Power without the owner's agreement, and restore settings afterwards.
  1. **Apps:**
     - With the phone's region set to Malaysia, clear the app data (this needs a re-pair), so the MY row seeds.
     - Open each default app from the row and from the Apps screen. Record which packages open, which open the Play Store page, and which do nothing.
     - Open YouTube and Netflix with the TV's own remote, then check "Recently used on your TV": real apps listed, MediaTek/launcher packages filtered. Record the raw packages the TV reported.
     - Add an app by its ID. Reorder, remove + Undo, Reset.
  2. **Your TVs:**
     - Rename and check the title and switcher.
     - Enter the MAC in Edit TV; with the owner's agreement, test waking from standby.
     - Remove the TV and pair again: does the TV ask for a new code at once? Record it.
     - Add the TV by IP, then let discovery find it by name and tap it: it merges and connects without pairing.
  3. **Settings:**
     - Every behaviour switch changes the remote live.
     - Theme Light/Dark/System, and "Colours from wallpaper" (the Note10+ runs Android 12).
     - The layout preview matches the remote.
     - Privacy/Terms open the browser (placeholder pages). Send feedback opens the mail app with the footer and nothing about the TV.
     - About shows the version; Licences lists androidtvremote2.
  4. **Accessibility spot check:** the phone's font size at maximum on Apps, Edit apps, Your TVs and Settings, plus TalkBack on Edit apps: reorder with Move up/down.

  If no device is available, say so in the report; don't claim the check passed.
- [ ] The task reports collectively carry these knowledge updates:
  - **decisions:** Rulings P5-R1 to P5-R13, grouped as:
    - navigation and banner slot (R1–R3)
    - catalogue, shortcuts and recommendations (R4–R8)
    - TVs and the connect-flow carry-overs (R9, R10)
    - settings, help and feedback (R11, R12)
    - keyboard (R13)
    - plus the pins url_launcher 6.3.3 and package_info_plus 10.2.2.
  - **learnings:** the catalogue verification results, and the device-run answers above. Add to "Unverified protocol behaviour":
    - `market://launch` for apps that aren't installed
    - the packages a MediaTek TV reports as the current app
    - whether a removed phone stays trusted by the TV
    - whether a TV found by mDNS presents the same key as when paired by IP.
  - **status:** Phase 5 done; carry-overs closed; carry-overs to Phase 6:
    - the Premium and Privacy-choices rows in the hub
    - `BannerSlot` body
    - the FAQ's privacy answer must stay true once analytics and Crashlytics land
    - replace the placeholder links and support address before any store upload.

## Needs the owner

- **The real-device run above** (together with the still-open Phase 3 and 4 runs), with agreement before any Power test.
- **Support email, privacy policy URL and terms URL.** They are placeholders (`example.com`) until provided. Phase 9 blocks store submission on them.
- **Question (optional):** should app tiles ever show real app icons? v1 uses monograms and generic icons because third-party logos need permission (Ruling P5-R4). The default is "no" unless you decide otherwise.
- **On a Mac:** `pod install` and `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` after Task 5.9 (new pods: url_launcher_ios, package_info_plus).
