# Phase 4 — Remote Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The remote screen becomes the full remote: a touchpad, D-pad and number pad you swipe or tab between; Back, Home, Mute, Keyboard and the Volume/Channel rockers with press-and-hold (Smooth Press); a quick-access row (apps, colour keys, media keys or none); a long-press Power key that falls back to Wake-on-LAN; a keyboard sheet that opens by itself when the TV asks for text; Keep Screen Awake and Theater Mode. Every press goes through one `RemoteActions` object that adds haptics and never drops a press silently. Portrait, landscape and tablet layouts all work at 320 dp and 200% text.

**Architecture:** Control widgets (touchpad, D-pad, number pad, quick-access row, rockers, keyboard sheet) are plain widgets that call a narrow `KeyInput`/`RemoteInput` interface. `RemoteActions` implements it on top of the active `RemoteSession`: it checks the live connection state, applies the Smooth Press or repeat rules, fires haptics through a `Haptics` interface, and bumps a "not connected" notice the screen turns into a snackbar. The screen composes the widgets into a portrait or split layout. Platform services (haptics, wakelock, screen brightness, Wake-on-LAN) sit behind interfaces with fakes in tests. The library only gains two key codes, a key-code check and two CLI commands for checking unverified TV behaviour.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2 (codegen, riverpod_generator 4.0.4), go_router 18.1.1, drift 2.34.0, nsd 5.0.1, connectivity_plus 7.3.2, network_info_plus 8.2.2, fake_async 1.3.3 (dev). New in Task 4.11: wakelock_plus 1.8.2, screen_brightness 2.1.11.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md` (binding, goals 4, 7, 10, 11, 12). This plan expands Phase 4 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md` and keeps its interfaces and test names except where a **Ruling** below says otherwise. Before starting, read:
- the `remote-design-system`, `flutter-app-architecture` and `atv-remote-protocol` skills (and `protocol-reference.md`)
- `docs/knowledge/decisions.md` #6, #7, #10–#19 and `learnings.md`
- `app/lib/core/session/remote_session.dart`, `session_providers.dart`, `app/lib/features/remote/presentation/remote_screen.dart`, `app/lib/app/widgets/{app_key_button,rocker,status_pill,app_sheet}.dart`
- the competitor teardown `docs/competitor-analysis/remote-atv/README.md` §4 and §8 (reference only: never copy its code, assets, copy or branding).

## Global Constraints

- Flutter 3.44.1 / Dart 3.12.1, `environment.sdk: ^3.12.1`. Lints: `very_good_analysis` 10.3.0 with `public_member_api_docs`, so every public `lib/` member gets a `///` doc. Keep pubspec dependencies sorted.
- Pin each new app dependency to the **exact** version its task gives. Task 4.11's `wakelock_plus:1.8.2` and `screen_brightness:2.1.11` were resolved together against this workspace with `flutter pub add --dry-run` on 2026-10-26. No other task adds a dependency.
- No socket, TLS or protobuf code in `app/`. The app imports only `package:atv_remote/atv_remote.dart`. Library changes stay pure Dart (no Flutter imports), with tests in `packages/atv_remote/test`.
- **Every press of a remote control goes through `RemoteActions`** (the `flutter-app-architecture` rule). Control widgets receive a `KeyInput` or `RemoteInput` (Task 4.1) and never read `remoteSessionProvider` or call `RemoteSession.send*` themselves. Only `RemoteScreen` and the power controller read `remoteActionsProvider`.
- Haptics only through the `Haptics` interface (Task 4.3); never call `HapticFeedback` elsewhere.
- **Strings:** every Phase 4 string is added to `app/lib/app/l10n/app_en.arb` in **Task 4.1** (Ruling P4-R1), each with an `@key` description. Later tasks use those keys and don't edit the ARB file. If a task finds it needs another string, it stops and reports the key and copy to the controller, who adds it. No hard-coded UI text. Brand names of apps (Task 4.7) are data, not strings.
- No ads, no analytics calls, no microphone/voice button anywhere in this phase (decisions #6, #7). Never log TV names, IPs, MACs or typed text.
- Touch targets: ≥ 56 dp for remote keys, ≥ 48 dp for everything else, ≥ 8 dp between keys. Every new screen or widget is tested at **320 dp width and 200% text** (no exceptions thrown, nothing clipped that carries meaning) and in light and dark. Colour is never the only signal.
- Respect reduce motion: with `MediaQuery.disableAnimationsOf(context)` true, trails, glows and scale animations are skipped (Duration.zero).
- Riverpod 3:
  - `Override` and `ProviderException` come from `package:flutter_riverpod/misc.dart`.
  - Check `ref.mounted` after every `await` in a notifier before touching `state`.
  - Watch every dependency **before** the first `await` in an async provider.
  - A notifier can't `ref.invalidate` a provider that depends on it; use `ref.container.invalidate`.
- Timers: tests use `fakeAsync` or `tester.pump(duration)`; no real waits over 100 ms. Production code that needs the time uses `clock` (`package:clock`).
- Code generation: `flutter pub run build_runner build --delete-conflicting-outputs`, then `dart format lib test`, both from `app/`. `dart run build_runner` fails in this workspace. On Windows, revert unrelated `.g.dart` files that changed only in line endings.
- Goldens: one `*_golden_test.dart` per subject, `@Tags(['golden'])`, baselines in `goldens/` next to the test, generated on Windows with `flutter test --update-goldens --tags golden <path>`. Never commit `failures/` folders.
- App tests need no TV, network or platform channel. Platform-backed providers get a fake default in `pumpRouterApp` (Tasks 4.3, 4.10 and 4.11 add them).
- `flutter`/`dart` commands in steps run from `app/`. Library commands run from `packages/atv_remote/` (`flutter test`, not `dart test`). `check.ps1` and `git` run from the repo root. Before every commit, `powershell -File tool/check.ps1` must print `All checks passed.`
- Commits end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Don't edit `docs/knowledge/*` or `CLAUDE.md`. Put knowledge updates in your task report; the controller applies them.

## Rulings (conflicts and open questions resolved for this phase)

1. **P4-R1 — All strings land first.** Tasks 4.2–4.8 run in parallel and would all edit `app_en.arb`. Task 4.1 adds every Phase 4 key (the table in Task 4.1) and the new key labels, so the parallel tasks never touch the ARB file or `key_labels.dart`.
2. **P4-R2 — Narrow input interfaces.** Task 4.1 defines `KeyInput` (`tap`, `holdStart`, `holdEnd`) and `RemoteInput` (adds `launch`, `typeText`) in `features/remote/application/key_input.dart`, and the `AppEntry` model from master Task 5.1 in `features/apps/domain/app_entry.dart`. `RemoteActions` (4.3) implements `RemoteInput`. The widgets of 4.5–4.8 take these interfaces, so they can be built and tested in parallel with `RemoteActions` using `RecordingRemoteInput`.
3. **P4-R3 — `RemoteActions` semantics.**
   - A command is sent only when a session exists, the session provider is **not loading** (a TV switch in progress counts as not connected, so nothing goes to the old, disposed session), and `session.current.status == connected`. It still catches `NotConnectedException` from the send, because the state lags the socket.
   - A refused command sends nothing, fires no haptic and bumps `notConnectedNoticesProvider`; `RemoteScreen` turns each bump into the `remoteNotConnected` snackbar (with Reconnect when the status is `disconnected`, as in Phase 3).
   - Unknown key codes are programming errors: they throw `ArgumentError` and are never caught.
   - Releasing a hold (`holdEnd`, an auto-release, or `dispose`) is best effort and never shows the snackbar.
4. **P4-R4 — Holds (Smooth Press and repeat).**
   - Holdable keys: D-pad up/down/left/right/center, volume up/down, channel up/down. `holdStart` on any other key is a single `tap`.
   - Hold threshold: 300 ms (`kHoldThreshold`) for holdable keys on keys and the D-pad; the touchpad's centre hold uses Flutter's `kLongPressTimeout` (500 ms). A shorter press is a tap, sent on release.
   - Smooth Press **on**: `holdStart` sends `startLong` (medium haptic); `holdEnd` sends `endLong`. D-pad center is included (a long OK opens context menus on the TV).
   - Smooth Press **off**: `holdStart` sends `short` at once and then every 120 ms until `holdEnd` (no haptic per repeat). D-pad center is not repeated: its hold is one `short`.
   - One hold at a time: a `holdStart` while another hold is active ends the active one first.
   - **Stuck-key guard:** a hold auto-releases after 15 s (`endLong` sent). `dispose()` (the provider rebuilds on a TV switch or a settings change) releases an active hold. `AppKeyButton` keeps calling `onLongPressEnd` when it is disposed mid-hold (Phase 2 behaviour, kept on purpose). Widgets capture the `RemoteActions` instance at build time and never touch `ref` inside hold callbacks.
   - (unverified) Whether a TV auto-repeats volume while a `startLong` is held, and what it does if `endLong` never arrives. The real-device run checks both.
5. **P4-R5 — Semantic long press.** TalkBack/VoiceOver "double-tap and hold" arrives as one semantic long-press action, not a real hold. `AppKeyButton` gains `onSemanticLongPress`; when it is null, a semantic long press calls `onTap` (one press) instead of the Phase 2 start+end pair. The power key passes its power action. Rocker keys become transparent on the rocker's pill (Phase 2 carry-over: they shared `surfaceRaised`).
6. **P4-R6 — Haptics.** Light: a sent tap, a touchpad step, an app launch, Enter. Medium: a hold start. Heavy: power (exactly once per power action, whichever path it takes). None for repeats, releases or refused commands. The `hapticsEnabled` setting gates all of them.
7. **P4-R7 — Pad area.** Three pages in a `PageView`: Touchpad, D-pad, Numbers, with a labelled, always-visible segmented control above them (no icon whose meaning changes with state; teardown §8).
   - The pager opens on the page of `settings.navigationStyle`. Choosing Touchpad or D-pad (by tab or swipe) persists `navigationStyle`; Numbers is never persisted.
   - With a screen reader on (`MediaQuery.accessibleNavigationOf`), the pager opens on the D-pad, without persisting.
   - The touchpad claims every gesture that starts on it (an `EagerGestureRecognizer`), and the `PageView` can't be swiped while the Touchpad page shows. Swiping works from the D-pad and Numbers pages; the tabs always work.
8. **P4-R8 — Layout.**
   - The status pill moves from the app bar into a 48 dp status strip under it. The app bar (toolbar 64 dp) holds the device switcher (title) and the Power key (action). At 320 dp and 200% text, an app bar holding the switcher, the pill and a 56 dp key leaves the TV name no room. The master's `widgets/top_bar.dart` becomes `power_button.dart` (4.10) plus a private `_StatusStrip` in the screen.
   - **Portrait** (width < 600 and width ≤ height): status strip, demo preview card (demo only), quick-access row, pad area (`Expanded`), bottom cluster.
   - **Split** (width ≥ 600, or landscape): pad area on the left (`Expanded`); on the right a column of width `clamp(width × 0.4, 280, 400)` with the quick-access row and the bottom cluster. This covers phone landscape and tablets (spec goal 12's "two panes").
   - The pad area needs at least 160 dp. The quick-access row is dropped when the pad would get less than 200 dp. If the pad still gets less than 160 dp, the body scrolls with the pad fixed at 160 dp (the touchpad keeps its gestures, Ruling 7).
   - Bottom cluster: volume rocker, a 2 × 2 grid (top: Mute, Keyboard; bottom: Back, Home), channel rocker. That is 280 dp wide, which fits 288 dp (320 minus 2 × 16).
   - Controls draw at 0.4 opacity while not connected but still take taps (so the snackbar explains why nothing happened). The pad tabs are never faded.
   - The volume rocker shows the level (or "Muted") only while connected. Mute keeps one icon whatever the state; the state shows on the rocker.
9. **P4-R9 — Quick-access "apps" before the catalogue exists.** Phase 5 owns the catalogue, icons and shortcuts. Phase 4 adds `quickAccessAppsProvider`, returning five starter apps (`kStarterApps`, Task 4.7) shown as monogram tiles on `surfaceRaised`: no logos and no brand colours. Phase 5.1 replaces the provider's body with the catalogue and shortcuts table. Launch links are `market://launch?id=<package>`. The colour and media rows scroll horizontally when they don't fit (the 5-key media row needs 312 dp).
10. **P4-R10 — Power.**
    - A tap shows the `powerHoldHint` snackbar and sends nothing. A 600 ms hold (or a semantic long press) is the power action.
    - Connected → `KEYCODE_POWER`. This also wakes a TV whose screen is off but which still holds the socket (`isPowerOn == false`). The master's "power state off" means the TV can't be reached.
    - Not connected (offline, reconnecting, disconnected or connecting) with Wake-on-LAN available → read the device fresh from the repository. No `wolMac` → the setup sheet (Ruling 11). Otherwise `WakeOnLanService.wake(mac:, tvHost: lastHost)`, then `session.reconnect()` (fresh backoff, host re-resolved).
    - `needsPairing`, demo, or no session → the not-connected notice.
    - Wake-on-LAN is unavailable on iOS until Apple grants the multicast entitlement: `kIosWakeOnLanEnabled = false`. There, the power action off-line shows `powerTurnOnWithTvRemote`.
11. **P4-R11 — MAC address source.** The setup sheet opened by the power key is the only way to fill `SavedDevice.wolMac` in Phase 4. Phase 5.3's edit-device screen reuses `parseMac` and the sheet's field. The Bluetooth MAC from the mDNS TXT record is never used (`protocol-reference.md`).
12. **P4-R12 — Keyboard text.**
    - (unverified) androidtvremote2's `send_text` sends a `RemoteImeBatchEdit` whose `text_field_status.value` appears to be the **whole field**. So the default `ImeTextMode.replaceField` sends the whole field on every change. `ImeTextMode.appendOnly` (send only the new suffix, with `KEYCODE_DEL` for deletions, counted in grapheme clusters) is a fallback behind one constant (`kImeTextMode`), switched only if the real-device run shows duplicated text.
    - Live typing is debounced: 150 ms after the last change. Enter flushes the pending text, sends `KeyCodes.enter` (66) and closes the sheet. Clear sends the empty field at once. Closing the sheet flushes pending text.
    - Not connected → an inline message in the sheet; nothing is queued. Because replace mode sends the whole field, the next edit after a reconnect catches up.
    - Auto-open on `ImeShowRequested` only when `autoOpenKeyboard` is on, the remote route is the current route (no sheet or dialog above it), and the keyboard sheet isn't already open.
    - The sheet also has "Open search on TV" (`KEYCODE_SEARCH`), so the user doesn't have to find the TV's search box first. (unverified) what Google TV does with 84.
13. **P4-R13 — Live values reset** (Phase 3 carry-over). `TvRemoteSession` clears `volume`, `isPowerOn` and `currentApp` when its status **enters** any non-connected status, never on entering `connected`: pushes held back until `RemoteReady` can arrive just before the `connected` state. `volumeProvider`, `powerStateProvider` and `currentAppProvider` emit `null` when the session leaves `connected`. The demo session clears on `disconnect()` and republishes on `connect()`.
14. **P4-R14 — Keep Screen Awake and Theater Mode.**
    - Keep awake: the wakelock is on while the setting is on and `/remote` is the top **page** route. Sheets and dialogs over it don't count as leaving (a `RouteObserver<PageRoute<dynamic>>` registered on the `GoRouter`).
    - Theater: after 30 s with no touch on the remote screen, the app brightness drops to 5 % and the screen switches to the extra-dark theater palette. The first touch restores both and is absorbed: the whole pointer sequence it starts goes to the overlay, never to a control.
    - The idle timer runs only while the setting is on, the remote route is current (`ModalRoute.isCurrentOf`; an open sheet pauses it), the app is resumed and no screen reader is on. Leaving the screen, disposing it, backgrounding the app or opening a sheet restores the brightness.
    - Theater never un-dims by itself when the connection state changes.
15. **P4-R15 — Session supervisor seeding** (Phase 3 carry-over). `SessionSignals` gains `AppVisibility get currentVisibility`. A supervisor created while the app is in the background starts as if it had just been backgrounded: `_backgroundSince = now()` and the 60 s grace timer running. `connect()` still runs.
16. **P4-R16 — Wake-on-LAN timing** (Phase 3 carry-over). `WakeOnLanService.wake` sends to `255.255.255.255` immediately, then sends to the remaining targets (subnet broadcast, `/24` of the TV) after the ≤ 2 s lookup. It returns `true` if any send succeeded. A lookup that throws synchronously, throws `OSError`, or times out counts as "no subnet".
17. **P4-R17 — Hooks, not services.** `RemoteActions` reports each sent command to `remoteActionListenerProvider` (a no-op by default). Phase 6 attaches analytics (`key_press` sampled, `app_launch`) and the review prompter's press counter. The event carries the key code, the app package or the text **length**, never the text.
18. **P4-R18 — Settings UI is Phase 5.4.** Phase 4 reads `settingsControllerProvider` (defaults: touchpad, apps row, haptics on, Smooth Press on, keep awake on, theater off, auto-open keyboard on). Tests override them through the store. The only setting Phase 4 writes is `navigationStyle` (Ruling 7).
19. **P4-R19 — Library additions** (Task 4.1): `KeyCodes.enter` (66), `KeyCodes.delete` (67, `KEYCODE_DEL` = backspace), `KeyCodes.named` (every named constant), and `isSupportedKeyCode(int)`. `RemoteClient.sendKey` uses `isSupportedKeyCode`. The CLI gains `enter`/`delete` key names and the `text` and `hold` commands, so the owner can check the unverified IME and long-press behaviour before the app is installed. No other wire behaviour changes.
20. **P4-R20 — Out of scope:** Settings pages, the Apps screen, catalogue and icons (Phase 5); device rename/delete (Phase 5); analytics, ads and the review prompt (Phase 6); onboarding and motion polish beyond what's specified here (Phase 7); voice (decision #7); the Phase 5 discovery carry-overs.

## Review Focus

1. **A stuck long press.** A `startLong` whose `endLong` never comes (the finger lifts after the socket dropped, the key is disposed mid-hold, the app goes to the background, the user switches TVs mid-hold) could leave the TV ramping the volume. Every path must release, and the 15 s guard must fire (Task 4.3 `dispose_releases_an_active_hold`, `hold_auto_releases_after_15s`, `a_new_hold_ends_the_previous_one`, `provider_rebuild_on_tv_switch_releases_the_hold_on_the_old_session`; Task 4.4 `removing_a_held_key_ends_the_hold_once`).
2. **No silent drops, no ghost sends.** A press while offline, reconnecting or during a TV switch shows "Not connected to your TV" and sends nothing, and never reaches the disposed previous session (Task 4.3 `not_connected_shows_snackbar_and_sends_nothing`, `reloading_session_refuses_commands`; Task 4.9 `switching_tv_keeps_the_remote_visible_while_loading`, `refused_press_shows_not_connected_snackbar`).
3. **Theater Mode swallows exactly one touch.** The touch that wakes the screen never reaches a control, the next one does, and the screen never dims under a screen reader or with a sheet open (Task 4.11 `first_touch_restores_without_sending_key`, `theater_suspended_with_screen_reader`, `open_sheet_pauses_the_idle_timer`).
4. **Touchpad ambiguity.** Jitter between the touch slop and 24 dp sends nothing. A two-finger tap sends Back, not OK. A fast long drag sends one step per 40 dp, even within one move event. A swipe on the touchpad never changes the pad page (Task 4.5 `small_jitter_sends_nothing`, `two_finger_tap_sends_back`, `long_drag_sends_multiple_steps`; Task 4.9 `swipe_on_touchpad_does_not_change_page`).
5. **Typed text arrives once, in order.** Fast typing becomes one send. Enter sends the pending text before 66. Nothing is sent while not connected, and the field catches up after a reconnect (Task 4.8 `typing_sends_text_debounced`, `enter_flushes_pending_text_before_enter_key`, `reconnecting_then_typing_sends_the_whole_field`).
6. **320 dp at 200% text in every variant.** Every pad page × every quick-access variant × portrait and landscape renders without exceptions (Task 4.9 `remote_fits_320dp_at_200_percent_text_in_every_variant`).

---

## File Structure

```
packages/atv_remote/lib/src/key_codes.dart            enter, delete, named, isSupportedKeyCode   (4.1)
packages/atv_remote/lib/src/remote_client.dart         sendKey uses isSupportedKeyCode            (4.1)
packages/atv_remote/lib/atv_remote.dart                export isSupportedKeyCode                  (4.1)
packages/atv_remote/lib/src/cli/key_names.dart, bin/atv_cli.dart   enter/delete, text + hold commands (4.1)
app/
  pubspec.yaml                                         wakelock_plus, screen_brightness            (4.11)
  lib/
    app/l10n/app_en.arb                                every Phase 4 string                        (4.1)
    app/widgets/app_key_button.dart, rocker.dart       semantic long press, key colour, hold time  (4.4)
    app/theme/tokens.dart, app_theme.dart              theater palette and theme                   (4.11)
    app/router.dart                                    page-route observer                         (4.11)
    core/haptics/haptics.dart                                                                       (4.3)
    core/session/session_signals.dart, lifecycle_observer.dart, session_supervisor.dart           (4.2)
    core/session/tv_remote_session.dart, session_providers.dart   live-value reset                 (4.2)
    core/wake/wake_on_lan_service.dart                 limited broadcast first (4.2), availability (4.10)
    core/tv/mac_address.dart                                                                        (4.10)
    core/storage/device_repository.dart                setWolMac                                   (4.10)
    core/device/screen_services.dart, keep_awake.dart, theater_mode.dart                           (4.11)
    features/apps/domain/app_entry.dart                                                             (4.1)
    features/apps/data/starter_apps.dart (+ .g.dart)                                                (4.7)
    features/remote/application/key_input.dart                                                      (4.1)
    features/remote/application/remote_actions.dart (+ .g.dart)                                     (4.3)
    features/remote/application/ime_requests.dart (+ .g.dart)                                       (4.9)
    features/remote/application/power_controller.dart (+ .g.dart)                                   (4.10)
    features/remote/presentation/key_labels.dart       enter, delete                               (4.1)
    features/remote/presentation/remote_screen.dart    rewritten (4.9), power (4.10), behaviour (4.11)
    features/remote/presentation/widgets/touchpad.dart                                              (4.5)
    features/remote/presentation/widgets/dpad.dart, number_pad.dart                                 (4.6)
    features/remote/presentation/widgets/quick_access_row.dart, quick_app_tile.dart                 (4.7)
    features/remote/presentation/widgets/pad_pager.dart, bottom_cluster.dart, remote_body.dart      (4.9)
    features/remote/presentation/widgets/power_button.dart, wol_setup_sheet.dart                    (4.10)
    features/remote/presentation/widgets/basic_controls.dart          deleted                       (4.9)
    features/keyboard/keyboard_sheet.dart, text_edit_planner.dart                                   (4.8)
    features/demo/demo_remote_session.dart             value reset (4.2), Search → keyboard (4.12)
  test/
    helpers/key_input_recorder.dart (4.1), fake_remote_client.dart, fake_remote_session.dart (4.1)
    helpers/manual_session_signals.dart (4.2), recording_haptics.dart (4.3)
    helpers/fake_wake_on_lan.dart (4.10), fake_screen_services.dart (4.11)
    helpers/pump_router_app.dart                       default overrides grow (4.3, 4.10, 4.11)
    app/remote_flow_test.dart                                                                      (4.12)
```

| Task | Master task | Deliverable |
|---|---|---|
| 4.1 | carry-over + 4.1 prep | Library key codes + CLI; `KeyInput`/`RemoteInput`, `AppEntry`; every ARB key; fakes aligned with the real classes |
| 4.2 | carry-over | Supervisor seeding, live-value reset, Wake-on-LAN limited broadcast first |
| 4.3 | 4.1 | `Haptics`, `RemoteActions` (Smooth Press, repeat, stuck-key guard, notices, listener hook) |
| 4.4 | carry-over | `AppKeyButton` semantic long press and colour, `Rocker` transparent keys and hold time |
| 4.5 | 4.3 | Touchpad |
| 4.6 | 4.4 | D-pad and number pad |
| 4.7 | 4.5 | Quick-access row (apps, colour keys, media keys, none) and starter apps |
| 4.8 | 4.6 | Keyboard sheet and text-edit planner |
| 4.9 | 4.2 | Remote screen: pager, bottom cluster, layouts, reload, keyboard wiring and auto-open |
| 4.10 | 4.2 (power) | Power key, Wake-on-LAN, MAC setup sheet |
| 4.11 | 4.7 | Keep Screen Awake and Theater Mode |
| 4.12 | carry-over + exit | Demo polish, TV-preview tests, end-to-end seam tests, accessibility guidelines |

**Order and parallelism:**
- **4.1 first, alone.** Everything else depends on its interfaces and strings.
- **Group A, parallel-safe after 4.1: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8.** Their files are disjoint: only 4.3 edits `pump_router_app.dart`, only 4.2 edits `manual_session_signals.dart`, and none edits the ARB file. They share golden folders but not file names. Each runs build_runner only for its own providers; revert unrelated `.g.dart` churn.
- **Group B, sequential after all of group A: 4.9 → 4.10 → 4.11 → 4.12.** Each edits `remote_screen.dart`.

---

### Task 4.1: Library key codes and CLI; input interfaces; all strings; fakes aligned

**Files:**
- Modify (library): `packages/atv_remote/lib/src/key_codes.dart`, `lib/src/remote_client.dart`, `lib/atv_remote.dart`, `lib/src/cli/key_names.dart`, `bin/atv_cli.dart`
- Test (library): create `packages/atv_remote/test/key_codes_test.dart`; modify `test/remote_client_test.dart`, `test/cli_helpers_test.dart`, `test/public_api_test.dart`
- Create (app): `app/lib/features/remote/application/key_input.dart`, `app/lib/features/apps/domain/app_entry.dart`, `app/test/helpers/key_input_recorder.dart`
- Modify (app): `app/lib/app/l10n/app_en.arb`, `app/lib/features/remote/presentation/key_labels.dart`, `app/test/features/remote/key_labels_test.dart`, `app/test/helpers/fake_remote_client.dart`, `app/test/helpers/fake_remote_session.dart`
- Test (app): create `app/test/helpers/fakes_contract_test.dart`, `app/test/features/apps/app_entry_test.dart`

**Interfaces:**
- Consumes: `RemoteKeyCode.valueOf` (generated proto, package-private), `RemoteClient`, `FakeTvServer`, the CLI's saved identity (`lib/src/cli/identity_store.dart`).
- Produces (library):
  - `KeyCodes.enter = 66`, `KeyCodes.delete = 67` (documented: `KEYCODE_DEL`, deletes the character before the cursor).
  - `static const List<int> KeyCodes.named`: every named constant (not the digits), in declaration order.
  - `bool isSupportedKeyCode(int keyCode)` (top-level in `key_codes.dart`): `RemoteKeyCode.valueOf(keyCode) != null`. Exported from the barrel. `RemoteClient.sendKey` uses it for its `ArgumentError` check.
  - `cliKeyCodes` gains `'enter'` and `'delete'`. New `int? parseHoldMillis(String raw)`: an integer from 1 to 30000, otherwise `null`.
  - CLI commands, added to the usage text:
    - `text <host> <text>`: connect with the saved identity, `sendText(text)`, wait 500 ms, close. Prints `sent N characters` (never the text).
    - `hold <host> <keyName> <ms>`: `sendKey(code, direction: startLong)`, wait `ms`, `sendKey(code, direction: endLong)`, wait 300 ms, close.
- Produces (app):
  - In `key_input.dart`:

    ```dart
    /// How long a holdable key must be pressed before it counts as a hold (Ruling P4-R4).
    const Duration kHoldThreshold = Duration(milliseconds: 300);

    /// What key widgets call. Implemented by `RemoteActions`; tests use `KeyInputRecorder`.
    abstract interface class KeyInput {
      /// Presses and releases [keyCode]. Returns whether it was sent.
      bool tap(int keyCode);
      /// A press on [keyCode] became a hold.
      void holdStart(int keyCode);
      /// The hold on [keyCode] ended (always called once after [holdStart]).
      void holdEnd(int keyCode);
    }

    /// [KeyInput] plus app launches and text, for the quick-access row and the keyboard.
    abstract interface class RemoteInput implements KeyInput {
      /// Opens [app] on the TV. Returns whether it was sent.
      bool launch(AppEntry app);
      /// Replaces or extends the TV's focused text field (see the keyboard sheet). Returns whether it was sent.
      bool typeText(String text);
    }
    ```

  - In `app_entry.dart` (the master Task 5.1 interface, `@immutable`, value `==`/`hashCode`): `class AppEntry { const AppEntry({required this.package, required this.name, String? launchLink, this.iconUrl, this.isCustom = false, this.customColor, this.customIcon}) : launchLink = launchLink ?? 'market://launch?id=$package'; final String package; final String name; final String launchLink; final String? iconUrl; final bool isCustom; final Color? customColor; final String? customIcon; }`. The initialiser is a potentially constant expression (`??` and interpolation of a `String` parameter), so the constructor stays `const`. If the analyzer disagrees, drop `const` and say so in the report.
  - `keyLabel` covers `KeyCodes.enter` → `keyEnter` and `KeyCodes.delete` → `keyDelete`.
  - Test helper `KeyInputRecorder implements RemoteInput`:
    - `bool connected = true`.
    - `final List<String> calls`, recording `tap:<code>`, `holdStart:<code>`, `holdEnd:<code>`, `launch:<package>` and `text:<text>`.
    - `tap`, `launch` and `typeText` return `connected` and record only when connected; `holdStart`/`holdEnd` always record.
    - `int refused` counts calls refused while not connected.
  - **Fakes aligned with the real classes** (Phase 3 carry-over):
    - `FakeRemoteClient`:
      - `serverPublicKeySha256` is set once the "TLS handshake" passes (outcome `succeed`, before `RemoteReady`), as `RemoteClient` does. It stays `null` for `networkError`, `certificateRejected` and `hang`.
      - `push(event)` before ready is held back and emitted right after `RemoteReady` (the real client's order).
      - `connect()` after `close()` throws `StateError`, like a used `RemoteClient`.
      - `sendKey` throws `ArgumentError` when `!isSupportedKeyCode(keyCode)`.
    - `FakeRemoteSession`:
      - New `final List<(int, KeyDirection)> sentPresses`. `sentKeys` (codes only) stays for the Phase 3 tests.
      - `sendKey` throws `ArgumentError` for unsupported codes.
      - New `int failNextSends = 0`: while positive, a `sendKey`/`launchAppLink`/`sendText` on a connected session decrements it and throws `NotConnectedException` (the socket dropped between the state check and the send).
- **ARB keys** (exact copy; placeholders typed as noted, otherwise `String`). These are all of Phase 4's strings:

  | Key | Copy |
  |---|---|
  | `keyEnter` | `Enter` |
  | `keyDelete` | `Delete` |
  | `keyKeyboard` | `Keyboard` |
  | `remotePadTabsLabel` | `Control style` |
  | `remotePadTouchpad` | `Touchpad` |
  | `remotePadDpad` | `D-pad` |
  | `remotePadNumbers` | `Numbers` |
  | `touchpadLabel` | `Touchpad` |
  | `touchpadHint` | `Swipe to move, tap to select, tap with two fingers to go back.` |
  | `touchpadIdleHint` | `Swipe to move · Tap to select` |
  | `channelLabel` | `CH` |
  | `remoteVolumeValue` | `{level}` (int) |
  | `remoteMutedValue` | `Muted` |
  | `remoteVolumeSemantics` | `Volume {level} of {max}` (ints) |
  | `remoteVolumeMutedSemantics` | `Volume muted` |
  | `quickAccessAppsLabel` | `Apps on your TV` |
  | `quickAccessColourLabel` | `Colour keys` |
  | `quickAccessMediaLabel` | `Media keys` |
  | `quickAppOpen` | `Open {app}` |
  | `quickAppNowOnTv` | `{app}, now on TV` |
  | `powerHoldHint` | `Hold to turn the TV on or off` |
  | `powerWaking` | `Waking {tvName}…` |
  | `powerWakeFailed` | `Couldn't send the wake-up signal. Make sure your phone is on the same Wi-Fi as the TV.` |
  | `powerTurnOnWithTvRemote` | `Turn the TV on with its own remote. This app reconnects by itself.` |
  | `wolSetupTitle` | `Turn on {tvName} from your phone` |
  | `wolSetupBody` | `Your phone can wake the TV over the network with its MAC address. On the TV, open Settings → System → About → Status (or Settings → Network & Internet) and copy the Wi-Fi or Ethernet MAC address.` |
  | `wolNotBluetooth` | `Use the Wi-Fi or Ethernet MAC address, not the Bluetooth one.` |
  | `wolMayNotWork` | `Some TVs can't be woken when they're fully off or in deep standby.` |
  | `wolMacLabel` | `MAC address` |
  | `wolMacHint` | `AA:BB:CC:DD:EE:FF` |
  | `wolMacError` | `Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF` |
  | `wolSaveAndWake` | `Save and turn on` |
  | `wolSaveFailed` | `Couldn't save the MAC address. Try again.` |
  | `keyboardTitle` | `Type on your TV` |
  | `keyboardFieldLabel` | `Text` |
  | `keyboardHint` | `Start typing…` |
  | `keyboardTvHint` | `Select a text field on the TV first, like the search box.` |
  | `keyboardClear` | `Clear` |
  | `keyboardOpenTvSearch` | `Open search on TV` |
  | `keyboardNotConnected` | `Not connected to your TV. What you type isn't sent.` |
  | `theaterWakeLabel` | `Screen dimmed. Touch to brighten.` |

- [ ] **Step 1: Write the failing tests**

```dart
// packages/atv_remote/test/key_codes_test.dart
test('every_named_key_code_and_digit_is_supported', () {
  for (final code in [...KeyCodes.named, for (var d = 0; d <= 9; d++) KeyCodes.digit(d)]) {
    expect(isSupportedKeyCode(code), isTrue, reason: '$code');
  }
  expect(KeyCodes.named, containsAll([KeyCodes.enter, KeyCodes.delete, KeyCodes.power]));
  expect(KeyCodes.named.toSet(), hasLength(KeyCodes.named.length));
});
test('unknown_codes_are_not_supported', () {
  for (final code in [-1, 9999]) expect(isSupportedKeyCode(code), isFalse);
});

// remote_client_test.dart (existing pair-first setUp and FakeTvServer)
test('sends_enter_and_delete', ...)          // sendKey(KeyCodes.enter); sendKey(KeyCodes.delete) → server.receivedKeyCodes ends with [66, 67]
test('empty_text_clears_the_field', ...)     // sendText('abc') then sendText('') → server.receivedText == ''
test('unsupported_key_code_throws_argument_error', ...) // sendKey(9999) → ArgumentError; connection still ready

// cli_helpers_test.dart
test('parses_enter_and_delete', ...)         // parseKeyName('Enter') == 66, parseKeyName('delete') == 67
test('parses_hold_millis_in_range', ...)     // '800' → 800; '0', '-1', 'abc', '30001' → null

// public_api_test.dart: the export list includes isSupportedKeyCode.

// app/test/helpers/fakes_contract_test.dart
test('fake_client_reports_the_server_key_before_ready_like_the_real_one', ...)
    // outcome succeed: a listener on events sees RemoteReady; at that moment serverPublicKeySha256 is non-null
test('fake_client_holds_pushes_until_ready', () async {
  final c = FakeRemoteClients().create(host: 'h', port: 6466, identity: testIdentity()) as FakeRemoteClient;
  final seen = <RemoteEvent>[]; c.events.listen(seen.add);
  c.push(const VolumeChanged(3, 20, false));
  await c.connect(); await pumpEventQueue();
  expect(seen, [const RemoteReady(), const VolumeChanged(3, 20, false)]);
});
test('fake_client_connect_after_close_throws_state_error', ...)
test('fake_client_rejects_unsupported_key_codes', ...)   // ArgumentError for 9999; 66 accepted
test('fake_session_records_directions_and_can_fail_a_send', ...)
    // connected; sendKey(19, direction: startLong) → sentPresses [(19, startLong)], sentKeys [19];
    // failNextSends = 1 → next sendKey throws NotConnectedException, the one after succeeds

// key_labels_test.dart: iterate KeyCodes.named (+ digits) instead of a hand-written list;
// keyLabel(l, KeyCodes.enter) == 'Enter', keyLabel(l, KeyCodes.delete) == 'Delete'; labels still all different.

// app/test/features/apps/app_entry_test.dart
test('launch_link_defaults_to_market_launch', ...)  // AppEntry(package: 'com.netflix.ninja', name: 'Netflix').launchLink == 'market://launch?id=com.netflix.ninja'
test('entries_compare_by_value', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run (library): `flutter test test/key_codes_test.dart test/remote_client_test.dart test/cli_helpers_test.dart test/public_api_test.dart`
Run (app): `flutter test test/helpers/fakes_contract_test.dart test/features/remote/key_labels_test.dart test/features/apps`
Expected: FAIL (missing members).

- [ ] **Step 3: Implement** the library additions and CLI commands (cite androidtvremote2 `remote.py` for `send_text` in a comment). Then the app side: `key_input.dart`, `app_entry.dart`, the ARB keys, `keyLabel`, the recorder and the fake changes. Run `flutter pub get` (regenerates l10n), then `dart format lib test`. Run the **whole** app suite: the fake changes must not break the Phase 3 tests. If one relied on a push before ready being delivered at once, fix the test to push after `connect()`, and say so in the report.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test` in `packages/atv_remote`, then in `app/`.
Expected: all PASS. `dart analyze --fatal-infos` is clean in the package.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add packages/atv_remote app/lib app/test
git commit -m "feat: enter/delete keys, input interfaces, phase 4 strings and aligned test fakes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: carry-over closed: the fakes match the real classes. Decision for Rulings P4-R1, P4-R2 and P4-R19. Owner note: `dart run bin/atv_cli.dart text <host> "abc"` and `hold <host> volumeup 1500` are ready for the real-device checks.

---

### Task 4.2: Carry-over fixes — supervisor seeding, live-value reset, Wake-on-LAN limited broadcast first

**Files:**
- Modify: `app/lib/core/session/session_signals.dart`, `lifecycle_observer.dart`, `session_supervisor.dart`, `tv_remote_session.dart`, `session_providers.dart`; `app/lib/features/demo/demo_remote_session.dart`; `app/lib/core/wake/wake_on_lan_service.dart`; `app/test/helpers/manual_session_signals.dart`
- Test: additions to `app/test/core/session/session_supervisor_test.dart`, `lifecycle_observer_test.dart`, `tv_remote_session_test.dart`, `session_providers_test.dart`, `app/test/features/demo/demo_remote_session_test.dart`, `app/test/core/wake/wake_on_lan_service_test.dart`

**Interfaces:**
- Consumes: Phase 3's session classes, `FakeRemoteClients` (aligned in 4.1), `WakeOnLanSender`.
- Produces:
  - `SessionSignals` gains `/// The visibility right now, for a supervisor created mid-flight. AppVisibility get currentVisibility;`.
    - `LifecycleObserver.current`: seeded from `(binding ?? WidgetsBinding.instance).lifecycleState`. `hidden`/`paused` → `background` (and `_inBackground = true`, so the next `resumed` emits `foreground`); `resumed`/`inactive`/`detached`/`null` → `foreground`. It follows later transitions.
    - `PlatformSessionSignals.currentVisibility` → `_lifecycle.current`.
    - `ManualSessionSignals`: a `currentVisibility` field (default `foreground`); `background()`/`foreground()` update it before emitting; constructor `ManualSessionSignals({AppVisibility initial = AppVisibility.foreground})`.
  - `SessionSupervisor` constructor: if `signals.currentVisibility == background`, behave as rule 1 of the Phase 3 supervisor (Ruling P4-R15).
  - `TvRemoteSession._onState`: on entering any status other than `connected`, set `_volume`, `_isPowerOn` and `_currentApp` to `null` **before** forwarding the state (Ruling P4-R13). Document the "never on entering connected" reason in a comment.
  - `session_providers.dart`: `_cachedThenEvents` becomes `_liveValue`. It starts with `session.current.status == connected ? cached : null`, adds the value of each matching event, and also listens to `session.states`: on a non-connected status it emits `null` once (only if the last emitted value was non-null). Both subscriptions are cancelled together.
  - `DemoRemoteSession.disconnect()` clears volume, power and current app (it already republishes them on `connect()`).
  - `WakeOnLanService.wake({required String mac, String? tvHost})` (Ruling P4-R16):
    1. Validate with `buildMagicPacket(mac)`, which throws `FormatException` before anything is sent.
    2. Send to `[255.255.255.255]` immediately.
    3. Look up the subnet broadcast with `Future.sync(_subnetBroadcast).timeout(_lookupTimeout)`. Any error (including a synchronous throw or an `OSError`) or the timeout → `null`.
    4. `rest = wakeOnLanTargets(subnetBroadcast:, tvHost:)` minus the limited broadcast. Send to `rest` when it isn't empty.
    5. Each send catches only `SocketException`/`OSError`. Return `true` if any send succeeded.

- [ ] **Step 1: Write the failing tests**

```dart
// session_supervisor_test.dart (fakeAsync, FakeRemoteSession, ManualSessionSignals(initial: background))
test('session_built_in_background_disconnects_after_the_grace', () => fakeAsync((a) {
  final signals = ManualSessionSignals(initial: AppVisibility.background);
  SessionSupervisor(session: s, signals: signals, now: () => clock);
  a.elapse(const Duration(seconds: 59)); expect(s.disconnectCalls, 0);
  a.elapse(const Duration(seconds: 1)); expect(s.disconnectCalls, 1);
}));
test('session_built_in_background_reconnects_on_return_after_the_grace', ...) // 61 s, foreground → (disconnect, connect) == (2, 1)
test('session_built_in_background_returning_quickly_nudges', ...)            // 5 s, foreground → no disconnect; resumeCalls 1 after 500 ms

// lifecycle_observer_test.dart
testWidgets('seeds_from_the_current_lifecycle_state', ...)  // drive the binding to paused, then create the observer → current == background; resumed → emits [foreground]

// tv_remote_session_test.dart
test('live_values_reset_when_the_connection_drops', () async {
  final s = session(savedTv()); await s.connect(); await until(s, ConnectionStatus.connected);
  clients.created.last..push(const VolumeChanged(8, 20, false))..push(const PowerStateChanged(true))..push(const CurrentAppChanged('com.netflix.ninja'));
  await pumpEventQueue();
  clients.created.last.drop(); await until(s, ConnectionStatus.reconnecting);
  expect((s.volume, s.isPowerOn, s.currentApp), (null, null, null));
});
test('pushes_that_arrive_just_before_connected_are_kept', ...)
    // the next FakeRemoteClient gets a push before ready (held back, 4.1) → after `connected`, s.volume is that value

// session_providers_test.dart
test('volume_provider_emits_null_when_the_connection_drops', ...) // values: [null, VolumeChanged(8,20,false), null] after push then drop
test('current_app_provider_emits_null_when_the_connection_drops', ...)

// demo_remote_session_test.dart
test('disconnect_clears_the_simulated_tv_state', ...)  // connected → disconnect → volume/isPowerOn/currentApp null; connect → volume 8 of 20 again

// wake_on_lan_service_test.dart (recording sender: List<List<String>> calls)
test('limited_broadcast_is_sent_before_the_lookup_finishes', () => fakeAsync((a) {
  final calls = <List<String>>[];
  final service = WakeOnLanService(subnetBroadcast: () => Completer<String?>().future,
      send: (mac, {broadcastAddresses, port = 9}) async => calls.add([for (final x in broadcastAddresses!) x.address]));
  service.wake(mac: 'AA:BB:CC:DD:EE:FF', tvHost: '192.168.0.20'); a.flushMicrotasks();
  expect(calls, [['255.255.255.255']]);
  a.elapse(const Duration(seconds: 2));
  expect(calls, [['255.255.255.255'], ['192.168.0.255']]);
}));
test('sync_throwing_lookup_still_sends_the_tv_fallback', ...)  // subnetBroadcast: () => throw StateError('x') → second call ['192.168.0.255']
test('os_error_lookup_still_sends_the_tv_fallback', ...)       // () async => throw const OSError('denied')
test('returns_true_when_any_send_succeeds', ...)               // first send throws SocketException, second succeeds → true
test('returns_false_when_every_send_fails', ...)
test('no_second_send_when_nothing_else_to_try', ...)           // subnet null, tvHost null → exactly one call
test('provider_builds_a_service', ...)                         // ProviderContainer.test().read(wakeOnLanServiceProvider) is WakeOnLanService
// existing malformed_mac_throws_format_exception_without_sending must still pass.
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/session test/core/wake test/features/demo/demo_remote_session_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the seeding, the reset, `_liveValue` and the WoL change. Run build_runner if a provider signature changed, then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "fix(app): seed the supervisor from visibility, reset live TV values, wake with limited broadcast first" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: carry-overs closed: supervisor seeding, live-value reset, WoL timing and lookup tests. Decision for Rulings P4-R13, P4-R15 and P4-R16.

---

### Task 4.3: `Haptics` and `RemoteActions`

**Files:**
- Create: `app/lib/core/haptics/haptics.dart` (+ `.g.dart`), `app/lib/features/remote/application/remote_actions.dart` (+ `.g.dart`), `app/test/helpers/recording_haptics.dart`
- Modify: `app/test/helpers/pump_router_app.dart` (default `hapticsProvider.overrideWithValue(RecordingHaptics())`)
- Test: `app/test/core/haptics/haptics_test.dart`, `app/test/features/remote/application/remote_actions_test.dart`, `remote_actions_provider_test.dart`

**Interfaces:**
- Consumes: `KeyInput`/`RemoteInput`/`AppEntry` (4.1), `RemoteSession`, `remoteSessionProvider`, `settingsControllerProvider` (`hapticsEnabled`, `smoothPressEnabled`), `FakeRemoteSession` (`sentPresses`, `failNextSends`).
- Produces:
  - `abstract interface class Haptics { Future<void> light(); Future<void> medium(); Future<void> heavy(); }`.
    - `class PlatformHaptics implements Haptics` calls `HapticFeedback.lightImpact` / `mediumImpact` / `heavyImpact` and swallows platform errors.
    - `@Riverpod(keepAlive: true) Haptics haptics(Ref ref) => const PlatformHaptics();` → `hapticsProvider`.
    - Test helper `RecordingHaptics implements Haptics` with `final List<String> events` (`'light'`, `'medium'`, `'heavy'`).
  - `sealed class RemoteActionEvent` (`@immutable`, value `==`):
    - `KeySent(int keyCode, KeyDirection direction)`
    - `AppLaunched(String package)`
    - `TextSent(int length)`: the length only, never the text (Ruling P4-R17).
  - `typedef RemoteActionListener = void Function(RemoteActionEvent event);` and `@Riverpod(keepAlive: true) RemoteActionListener remoteActionListener(Ref ref) => (_) {};`
  - `@Riverpod(keepAlive: true) class NotConnectedNotices extends _$NotConnectedNotices { int build() => 0; void notify() => state++; }` → `notConnectedNoticesProvider`.
  - `class RemoteActions implements RemoteInput`:

    ```dart
    RemoteActions({
      required RemoteSession? session,          // null: no TV, or the session is reloading (Ruling P4-R3)
      required bool smoothPress,
      required bool hapticsEnabled,
      required Haptics haptics,
      required VoidCallback onRefused,
      RemoteActionListener? onSent,
      Duration repeatInterval = const Duration(milliseconds: 120),
      Duration maxHold = const Duration(seconds: 15),
    });
    static const Set<int> holdableKeys = {dpadUp, dpadDown, dpadLeft, dpadRight, dpadCenter, volumeUp, volumeDown, channelUp, channelDown};
    static const Set<int> repeatableKeys = holdableKeys minus dpadCenter;
    bool tap(int keyCode);
    void holdStart(int keyCode);
    void holdEnd(int keyCode);
    bool launch(AppEntry app);
    bool typeText(String text);
    void dispose();                              // releases an active hold, cancels timers; later calls do nothing and return false
    ```

  - **Rules:**
    - `tap(code)`:
      1. Refused → `onRefused()`, return `false`.
      2. Otherwise `session.sendKey(code)`; on `NotConnectedException` → refused.
      3. On success: haptic (`heavy` for `KeyCodes.power`, otherwise `light`), `onSent(KeySent(code, short))`, return `true`.
    - `holdStart(code)`:
      - Not in `holdableKeys`, or center with Smooth Press off → behave exactly like `tap(code)`.
      - Otherwise end any active hold first.
      - Smooth on: send `startLong`, medium haptic, start the `maxHold` timer.
      - Smooth off: send `short`, medium haptic, then a periodic `repeatInterval` timer sending `short` (no haptic). A repeat that fails stops the timer and calls `onRefused()` once.
      - If the first send is refused → `onRefused()`, and no hold becomes active.
    - `holdEnd(code)`: only when `code` is the active hold. Smooth: send `endLong`, catching `NotConnectedException` silently and calling no `onRefused`. Repeat: cancel the timer. Clear the active hold.
    - The `maxHold` timer fires `holdEnd(activeCode)`.
    - `launch(app)` → `session.launchAppLink(app.launchLink)`, light haptic, `AppLaunched(app.package)`.
    - `typeText(text)` → `session.sendText(text)`, no haptic, `TextSent(text.length)`.
    - Haptics fire only when `hapticsEnabled`.
    - An unsupported key code throws `ArgumentError` from the session (not caught).
  - `@riverpod RemoteActions remoteActions(Ref ref)` → `remoteActionsProvider` (autoDispose):
    - `session = ref.watch(remoteSessionProvider.select((s) => s.isLoading ? null : s.value))`.
    - `ref.watch(settingsControllerProvider.select((s) => (s.smoothPressEnabled, s.hapticsEnabled)))`.
    - `haptics = ref.watch(hapticsProvider)`, `onSent = ref.watch(remoteActionListenerProvider)`, `notices = ref.read(notConnectedNoticesProvider.notifier)` (captured: `onRefused: notices.notify`).
    - `ref.onDispose(actions.dispose)`.

- [ ] **Step 1: Write the failing tests** (`remote_actions_test.dart`: `fakeAsync`; `FakeRemoteSession(initial: connected)`; `RecordingHaptics`; `var refused = 0`; `final sent = <RemoteActionEvent>[]`)

```dart
RemoteActions actions({bool smooth = true, bool haptics = true, RemoteSession? s}) => RemoteActions(
    session: s ?? session, smoothPress: smooth, hapticsEnabled: haptics, haptics: h,
    onRefused: () => refused++, onSent: sent.add);

test('smooth_press_sends_start_and_end_long', () => fakeAsync((a) {      // master name
  final x = actions(); x.holdStart(KeyCodes.volumeUp); a.elapse(const Duration(seconds: 2)); x.holdEnd(KeyCodes.volumeUp);
  expect(session.sentPresses, [(KeyCodes.volumeUp, KeyDirection.startLong), (KeyCodes.volumeUp, KeyDirection.endLong)]);
  expect(h.events, ['medium']);
}));
test('repeat_mode_sends_short_every_120ms', () => fakeAsync((a) {        // master name
  final x = actions(smooth: false); x.holdStart(KeyCodes.dpadDown);
  expect(session.sentPresses, hasLength(1));
  a.elapse(const Duration(milliseconds: 360)); expect(session.sentPresses, hasLength(4));
  x.holdEnd(KeyCodes.dpadDown); a.elapse(const Duration(seconds: 1)); expect(session.sentPresses, hasLength(4));
  expect(session.sentPresses.map((p) => p.$2).toSet(), {KeyDirection.short});
}));
test('haptics_respect_setting', ...)            // haptics: false → tap, holdStart, power tap → h.events isEmpty; true → ['light','medium','heavy']
test('not_connected_shows_snackbar_and_sends_nothing', ...)  // master name; session offline → tap/launch/typeText return false, refused == 3, sentPresses empty, no haptics
test('reloading_session_refuses_commands', ...)  // session: null → tap returns false, refused 1
test('a_send_that_fails_mid_flight_is_refused', ...)  // failNextSends = 1 → tap false, refused 1, no haptic
test('center_hold_is_a_long_press_with_smooth_press_and_a_tap_without', ...)
test('non_holdable_keys_hold_as_a_single_tap', ...)   // holdStart(home) → [(3, short)]; holdEnd(home) → nothing more
test('a_new_hold_ends_the_previous_one', ...)         // holdStart(volUp), holdStart(chUp) → volUp endLong precedes chUp startLong
test('hold_auto_releases_after_15s', ...)             // smooth: 15 s → endLong sent; later holdEnd sends nothing
test('dispose_releases_an_active_hold', ...)          // smooth: holdStart → dispose → endLong; tap after dispose returns false and sends nothing
test('release_after_the_connection_dropped_is_silent', ...) // holdStart; session.emit(offline); holdEnd → no throw, refused == 0
test('repeat_stops_and_reports_once_when_the_connection_drops', ...) // repeat mode; failNextSends = 5 after the first send → refused == 1, timer stopped
test('power_tap_uses_heavy_haptic', ...)
test('launch_sends_the_app_link', ...)                // AppEntry(netflix) → session.sentLinks ['market://launch?id=com.netflix.ninja'], sent [AppLaunched('com.netflix.ninja')]
test('type_text_reports_length_only', ...)            // typeText('hello') → sentTexts ['hello'], sent [TextSent(5)]
test('unsupported_key_code_throws', ...)              // tap(9999) → throwsArgumentError

// remote_actions_provider_test.dart (ProviderContainer.test: settings store on in-memory prefs, remoteSessionProvider overridden)
test('provider_follows_the_smooth_press_setting', ...)  // store.setSmoothPressEnabled(false) via settingsControllerProvider.notifier.update → new instance repeats
test('provider_rebuild_on_tv_switch_releases_the_hold_on_the_old_session', ...)
    // holdStart(volumeUp) on actions over session A → invalidate remoteSessionProvider (now B) → A.sentPresses ends with endLong
test('refusals_bump_the_not_connected_notices', ...)    // offline session → tap → notConnectedNoticesProvider == 1
test('listener_sees_each_sent_command', ...)            // override remoteActionListenerProvider with a recorder

// haptics_test.dart
testWidgets('platform_haptics_use_impact_feedback', ...) // mock SystemChannels.platform → 'HapticFeedback.vibrate' args 'HapticFeedbackType.lightImpact' / mediumImpact / heavyImpact
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/haptics test/features/remote/application`
Expected: FAIL.

- [ ] **Step 3: Implement** `Haptics`, `RemoteActions`, the providers and the recorder. Add the `pumpRouterApp` default. Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): remote actions with smooth press, repeat, stuck-key guard and haptics" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Rulings P4-R3, P4-R4, P4-R6 and P4-R17. Learning: the provider rebuild releases holds, so settings changes mid-hold are safe.

---

### Task 4.4: `AppKeyButton` and `Rocker` updates

**Files:**
- Modify: `app/lib/app/widgets/app_key_button.dart`, `app/lib/app/widgets/rocker.dart`
- Modify (tests): `app/test/app/widgets/app_key_button_test.dart`, `rocker_test.dart` (create if missing), re-baseline `app/test/app/widgets/goldens/rocker_{light,dark}.png` (and `app_key_button_*` only if they change)

**Interfaces:**
- Consumes: Phase 2's `AppKeyButton`, `Rocker`, tokens.
- Produces:
  - `AppKeyButton` gains:
    - `VoidCallback? onSemanticLongPress`. The semantic `onLongPress` action calls `onSemanticLongPress` when given, otherwise `onTap` (Ruling P4-R5). It is offered only when the key has long-press callbacks or `onSemanticLongPress`.
    - `Color? color`: the key's fill, defaulting to `surfaceRaised`. The ripple and the press scale still show on a transparent key.
    - Existing behaviour kept: `onLongPressEnd` is called once when the widget is disposed mid-hold.
  - `Rocker` gains:
    - `Duration longPressDuration = kLongPressTimeout`, passed to both keys.
    - `String? valueSemantics`: when given, the centre label/value is one semantics node with this label (for example "Volume 8 of 20"); otherwise the label and value are read as they are.
    - Its keys use `color: Colors.transparent` on the `surfaceRaised` pill, so the pill reads as one control (Phase 2 carry-over).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('semantic_long_press_defaults_to_one_tap', (t) async {
  var taps = 0, starts = 0, ends = 0;
  await pumpApp(t, AppKeyButton(semanticLabel: 'Volume up', icon: const Icon(Icons.add), onTap: () => taps++,
      onLongPressStart: () => starts++, onLongPressEnd: () => ends++));
  final id = t.getSemantics(find.bySemanticsLabel('Volume up')).id;
  t.binding.pipelineOwner.semanticsOwner!.performAction(id, SemanticsAction.longPress);
  expect((taps, starts, ends), (1, 0, 0));
});
testWidgets('semantic_long_press_uses_the_override', ...)    // onSemanticLongPress given → it runs, onTap does not
testWidgets('no_semantic_long_press_without_hold_callbacks', ...) // a tap-only key has no longPress action
testWidgets('removing_a_held_key_ends_the_hold_once', ...)   // hold past the duration, replace the tree → ends == 1 (existing behaviour, now pinned by a test)
testWidgets('key_colour_override_is_painted', ...)           // color: Colors.transparent → the Material's color is transparent
testWidgets('rocker_passes_the_hold_duration_to_its_keys', ...) // longPressDuration 300 ms: hold 310 ms → onUpLongPressStart called
testWidgets('rocker_value_semantics_is_one_node', ...)       // valueSemantics 'Volume 8 of 20' → find.bySemanticsLabel('Volume 8 of 20') findsOneWidget
testWidgets('rocker_keys_are_transparent_on_the_pill', ...)
// rocker_golden_test: re-baseline rocker_{light,dark} (keys no longer drawn as separate raised squares).
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/widgets`
Expected: FAIL.

- [ ] **Step 3: Implement.** Then re-baseline: `flutter test --update-goldens --tags golden test/app/widgets/rocker_golden_test.dart` and inspect the result.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS (the Phase 3 remote screen tests still pass, since they don't use semantic long press).

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): screen-reader friendly holds and transparent rocker keys" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: carry-overs closed: semantic long press and the rocker colour. Decision for Ruling P4-R5.

---

### Task 4.5: Touchpad

**Files:**
- Create: `app/lib/features/remote/presentation/widgets/touchpad.dart`
- Test: `app/test/features/remote/widgets/touchpad_test.dart`, `touchpad_golden_test.dart`

**Interfaces:**
- Consumes: `KeyInput` (4.1), `KeyInputRecorder`, `keyLabel`, tokens, ARB `touchpadLabel`, `touchpadHint`, `touchpadIdleHint`.
- Produces:
  - `class Touchpad extends StatefulWidget { const Touchpad({required KeyInput input, super.key}); static const double firstStep = 24; static const double repeatStep = 40; }`
  - **Gesture rules.** Raw `Listener` pointer events are used for the logic, and an `EagerGestureRecognizer` in a `RawGestureDetector` claims every gesture that starts here (Ruling P4-R7):
    - **Step:** one pointer down. `delta = position − anchor` (the anchor starts at the down position). The threshold is `firstStep` before the first step of this touch and `repeatStep` after it.
      - While the dominant-axis component of `delta` (horizontal when `|dx| ≥ |dy|`) reaches the threshold: `input.tap(direction)` (D-pad up/down/left/right) and advance the anchor by the threshold along that axis. One move event can produce several steps.
      - After each step, set the anchor's cross-axis coordinate to the current position.
    - **Tap:** one pointer that moved less than `kTouchSlop` (18) in total, released before `kLongPressTimeout`, with no step sent → `input.tap(dpadCenter)`.
    - **Dead zone:** a touch that moved at least `kTouchSlop` but sent no step sends nothing.
    - **Hold:** one pointer held `kLongPressTimeout` without moving `kTouchSlop` → `input.holdStart(dpadCenter)`; on release or cancel → `input.holdEnd(dpadCenter)`. Movement after the hold starts is ignored.
    - **Two-finger tap:** exactly two pointers down at once, each moving less than `firstStep`, all released within 400 ms of the first down, and no step sent → `input.tap(back)`. Never a center. Three or more pointers do nothing.
    - A second pointer that arrives after a step was sent is ignored. Pointer cancel ends any hold and sends nothing else.
  - **Visuals:** a `surfaceRaised` rounded rect (radius `AppRadii.key × 1.5`) with an `outline` border, and a centred `touchpadIdleHint` in `textSecondary` (`labelLarge`, scaling, at most 2 lines).
    - A fading trail of the last 250 ms of touch points (accent at 24 % alpha, `CustomPainter`).
    - An edge glow (an accent gradient 24 dp deep) on the edge of each step's direction, fading over 200 ms.
    - With reduce motion: no trail and no glow.
  - **Semantics:** one node with `label: touchpadLabel`, `hint: touchpadHint`, `onTap` → center, and `customSemanticsActions` for Up, Down, Left, Right and Back (labels from `keyLabel`). TalkBack users can drive it from the actions menu.

- [ ] **Step 1: Write the failing tests** (`pumpApp` with a 320 × 320 `SizedBox` around `Touchpad(input: rec)`; use `t.startGesture` / `TestGesture.moveBy` for drags)

```dart
testWidgets('swipe_right_sends_dpad_right', (t) async {                  // master name
  final g = await t.startGesture(t.getCenter(find.byType(Touchpad)));
  await g.moveBy(const Offset(30, 2)); await g.up();
  expect(rec.calls, ['tap:${KeyCodes.dpadRight}']);
});
testWidgets('long_drag_sends_multiple_steps', (t) async {                // master name
  final g = await t.startGesture(t.getCenter(find.byType(Touchpad)) - const Offset(80, 0));
  await g.moveBy(const Offset(24 + 40 * 3, 0)); await g.up();           // a single move event
  expect(rec.calls, List.filled(4, 'tap:${KeyCodes.dpadRight}'));
});
testWidgets('tap_sends_center', ...)                                     // master name; t.tap → ['tap:23']
testWidgets('two_finger_tap_sends_back', ...)                            // master name; two startGesture, both up within 100 ms → ['tap:4'], no 23
testWidgets('small_jitter_sends_nothing', ...)                           // master name; move 20 dp, up → calls isEmpty
testWidgets('long_press_holds_center', ...)                              // down, pump 500 ms → ['holdStart:23']; up → + 'holdEnd:23'
testWidgets('vertical_swipe_up_sends_dpad_up', ...)
testWidgets('direction_follows_the_dominant_axis_after_a_turn', ...)     // right 30 (step), then down 45 → [right, down]
testWidgets('second_finger_after_a_step_is_ignored', ...)
testWidgets('pointer_cancel_ends_a_hold', ...)                           // hold, then g.cancel() → holdEnd sent once
testWidgets('touchpad_wins_against_an_ancestor_scrollable', ...)         // inside a vertical ListView: drag up 100 → steps sent, the list did not scroll
testWidgets('touchpad_exposes_semantic_actions', ...)                    // performAction(customAction 'Up') → 'tap:19'; tap action → 'tap:23'
testWidgets('reduce_motion_paints_no_trail', ...)                        // disableAnimations: true → after a swipe, find.byKey(Touchpad.trailKey) paints nothing
testWidgets('touchpad_fits_320dp_at_200_percent_text', ...)
// touchpad_golden_test.dart (@Tags(['golden'])): idle, Size(360, 360), light + dark → goldens/touchpad_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/remote/widgets/touchpad_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the touchpad. Keep the gesture interpreter a private class with no Flutter rendering, so the rules read in one place.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/remote/widgets/touchpad_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): touchpad with steps, tap, hold and two-finger back" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for the touchpad's gesture numbers (Ruling P4-R7 and this task's rules).

---

### Task 4.6: D-pad and number pad

**Files:**
- Create: `app/lib/features/remote/presentation/widgets/dpad.dart`, `number_pad.dart`
- Test: `app/test/features/remote/widgets/dpad_test.dart`, `number_pad_test.dart`, `dpad_golden_test.dart`, `number_pad_golden_test.dart`

**Interfaces:**
- Consumes: `KeyInput`, `kHoldThreshold` (4.1), `AppKeyButton` (Phase 2 API), `keyLabel`, tokens.
- Produces:
  - `enum DpadRegion { up, down, left, right, center }` and `int dpadKeyCode(DpadRegion region)`.
  - `DpadRegion? dpadRegionAt(Offset local, Size size)`:
    - The pad is a circle of diameter `d = min(size.width, size.height)`, centred in `size`.
    - Distance `r` from the centre: `r > d/2` → `null`. `r ≤ centerRadius(d)` → `center`, where `centerRadius(d) = max(28, d × 0.18)` (≥ 56 dp across).
    - Otherwise: `|dx| ≥ |dy|` → left/right, else up/down.
  - `class Dpad extends StatefulWidget { const Dpad({required KeyInput input, super.key}); }`:
    - Size: `LayoutBuilder`, diameter `clamp(min(maxWidth, maxHeight), 160, 320)`.
    - Gestures: one `RawGestureDetector` with:
      - a `TapGestureRecognizer` (`onTapUp` → region → `input.tap`)
      - a `LongPressGestureRecognizer(duration: kHoldThreshold)` (`onLongPressStart` → region → `input.holdStart`; `onLongPressEnd`/`onLongPressCancel` → `input.holdEnd(sameRegion)`).
      - A press outside the circle does nothing.
    - Visual (`CustomPainter`):
      - a `surfaceRaised` disc with an `outline` ring
      - chevrons in `textPrimary` at the four points
      - a centre disc with an accent ring
      - the pressed region tinted with accent at 24 % alpha while the pointer is down.
    - Semantics: through the painter's `semanticsBuilder`, five nodes labelled with `keyLabel` and an `onTap`:
      - each direction's rect is the bounding box of its wedge, minus the centre rect
      - the centre rect is the centre disc's bounding square (≥ 56 × 56).
  - `class NumberPad extends StatelessWidget { const NumberPad({required KeyInput input, super.key}); }`:
    - A 3-column grid, 5 rows: `1 2 3 / 4 5 6 / 7 8 9 / TV input · 0 · Menu / Guide · Info · Captions`.
    - Every key is an `AppKeyButton` (tap only) at least 56 dp, stretched to equal width, with 8 dp gaps.
    - Digits show `Text('n')` (`titleLarge`); the others show an icon over a `labelSmall` caption (the `keyLabel` text, one line, `FittedBox(scaleDown)`). Icons: `Icons.input`, `Icons.menu`, `Icons.view_list_outlined`, `Icons.info_outline`, `Icons.closed_caption_outlined`.
    - `semanticLabel` from `keyLabel`. The grid sits in a vertical `SingleChildScrollView` so it scrolls when its page is short.

- [ ] **Step 1: Write the failing tests**

```dart
test('dpad_hit_regions_map_to_directions', () {                          // master name
  const s = Size(300, 300); const c = Offset(150, 150);
  expect(dpadRegionAt(c, s), DpadRegion.center);
  expect(dpadRegionAt(c + const Offset(0, -100), s), DpadRegion.up);
  expect(dpadRegionAt(c + const Offset(0, 100), s), DpadRegion.down);
  expect(dpadRegionAt(c + const Offset(-100, 10), s), DpadRegion.left);
  expect(dpadRegionAt(c + const Offset(100, -10), s), DpadRegion.right);
  expect(dpadRegionAt(const Offset(2, 2), s), isNull);                    // corner, outside the circle
  expect(dpadRegionAt(c + const Offset(70, 70), s), DpadRegion.right);     // a diagonal tie goes horizontal
});
testWidgets('center_button_is_56dp_minimum', ...)                         // master name; at Size(160,160): the OK semantics node rect is ≥ 56 × 56
testWidgets('tapping_each_region_sends_its_key', ...)                    // taps at offsets → calls [19, 20, 21, 22, 23]
testWidgets('holding_a_direction_holds_its_key', ...)                    // down at up region, pump 300 ms → holdStart:19; up → holdEnd:19
testWidgets('press_outside_the_circle_does_nothing', ...)
testWidgets('dpad_semantics_has_five_labelled_buttons', ...)             // Up, Down, Left, Right, OK each with a tap action; tap action on 'OK' → tap:23
testWidgets('numpad_digit_sends_keycode_7_plus_n', (t) async {           // master name
  for (var n = 0; n <= 9; n++) { await t.tap(find.bySemanticsLabel('Number $n')); }
  expect(rec.calls, [for (var n = 0; n <= 9; n++) 'tap:${7 + n}']);
});
testWidgets('numpad_extra_keys_send_their_codes', ...)                   // TV input 178, Menu 82, Guide 172, Info 165, Captions 175
testWidgets('numpad_keys_are_at_least_56dp_with_8dp_gaps', ...)
testWidgets('dpad_and_numpad_fit_320dp_at_200_percent_text', ...)        // 288 × 200 box (numpad scrolls) → no exception
// goldens (@Tags(['golden'])), light + dark: dpad at Size(320, 320) → goldens/dpad_{b}.png;
// number pad at Size(320, 420) → goldens/number_pad_{b}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/remote/widgets/dpad_test.dart test/features/remote/widgets/number_pad_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** both widgets.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/remote/widgets/dpad_golden_test.dart test/features/remote/widgets/number_pad_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): d-pad with hit regions and holds, and number pad" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4.7: Quick-access row and starter apps

**Files:**
- Create: `app/lib/features/remote/presentation/widgets/quick_access_row.dart`, `quick_app_tile.dart`, `app/lib/features/apps/data/starter_apps.dart` (+ `.g.dart`)
- Test: `app/test/features/remote/widgets/quick_access_row_test.dart`, `quick_access_row_golden_test.dart`, `app/test/features/apps/starter_apps_test.dart`

**Interfaces:**
- Consumes: `RemoteInput`, `AppEntry` (4.1), `QuickAccessRow` (the settings enum), `AppKeyButton`, `keyLabel`, tokens (`tvRed`, `tvGreen`, `tvYellow`, `tvBlue`), ARB `quickAccess*`, `quickAppOpen`, `quickAppNowOnTv`.
- Produces:
  - `const List<AppEntry> kStarterApps`. Order: Netflix `com.netflix.ninja`, YouTube `com.google.android.youtube.tv`, Prime Video `com.amazon.amazonvideo.livingroom`, Disney+ `com.disney.disneyplus`, Spotify `com.spotify.tv.android`. (unverified on the owner's TV) Phase 5's catalogue supersedes these (Ruling P4-R9).
  - `@riverpod List<AppEntry> quickAccessApps(Ref ref) => kStarterApps;` → `quickAccessAppsProvider`. The doc comment says Phase 5.1 replaces the body.
  - `Color colourKeyLabelColor(Color key)` returns `Color(0xFF0F1115)` or `Colors.white`, whichever contrasts more with `key` (WCAG relative luminance).
  - `class QuickAppTile extends StatelessWidget { const QuickAppTile({required AppEntry app, required bool isCurrent, required VoidCallback onTap, super.key}); }`:
    - 72 dp wide: a 56 dp `surfaceRaised` square with the app's first letter (`titleLarge`), then the name (`labelSmall`, one line, ellipsis).
    - When `isCurrent`, an 8 dp accent dot at the top-right of the square.
    - Semantics: a button labelled `quickAppOpen(name)`, or `quickAppNowOnTv(name)` when current.
  - `class QuickAccessBar extends StatelessWidget`. The settings enum is already called `QuickAccessRow`, so the widget can't use that name.

    ```dart
    const QuickAccessBar({required QuickAccessRow variant, required RemoteInput input,
        required List<AppEntry> apps, String? currentApp, super.key});
    ```

    - `apps`: a horizontal `ListView` of `QuickAppTile` (8 dp gaps, 16 dp side padding). Tap → `input.launch(app)`. `isCurrent` is `app.package == currentApp`. Semantics container `quickAccessAppsLabel`.
    - `colourKeys`: four equal `Expanded` pill keys (height 56, `StadiumBorder`) in TV red/green/yellow/blue, each with its `keyLabel` name in `colourKeyLabelColor(fill)` (`labelLarge`, `FittedBox(scaleDown)`). Tap → `input.tap(183…186)`. Below 4 × 64 + 3 × 8 dp it becomes a horizontal list of 64 dp pills. Semantics container `quickAccessColourLabel`.
    - `mediaKeys`: five `AppKeyButton`s (56 dp, 8 dp gaps): previous `Icons.skip_previous`, rewind `Icons.fast_rewind`, play/pause `Icons.play_arrow` (one constant icon: we don't know the TV's play state), fast-forward `Icons.fast_forward`, next `Icons.skip_next`. Tap → `input.tap` with 88, 89, 85, 90, 87. Centred when they fit, otherwise a horizontal list. Semantics container `quickAccessMediaLabel`.
    - `none`: `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('colour_keys_send_183_to_186', (t) async {                   // master name
  await pumpBar(t, QuickAccessRow.colourKeys);
  for (final name in ['Red', 'Green', 'Yellow', 'Blue']) { await t.tap(find.bySemanticsLabel(name)); }
  expect(rec.calls, ['tap:183', 'tap:184', 'tap:185', 'tap:186']);
});
testWidgets('media_row_sends_media_codes', ...)                          // master name; Previous, Rewind, Play or pause, Fast forward, Next → [88, 89, 85, 90, 87]
testWidgets('none_renders_nothing', ...)                                 // QuickAccessBar(none) has zero height (master's none_expands_pad_area is in Task 4.9)
testWidgets('app_tile_launches_the_app', ...)                            // tap 'Open Netflix' → ['launch:com.netflix.ninja']
testWidgets('current_app_is_marked_and_announced', ...)                  // currentApp 'com.google.android.youtube.tv' → 'YouTube, now on TV'
test('colour_key_labels_meet_4_5_contrast', () {
  for (final c in [AppColors.dark.tvRed, AppColors.dark.tvGreen, AppColors.dark.tvYellow, AppColors.dark.tvBlue]) {
    expect(contrastRatio(colourKeyLabelColor(c), c), greaterThanOrEqualTo(4.5));
  }
});   // reuse the contrast helper from the Phase 2 token tests (move it to test/helpers/contrast.dart if it's private)
testWidgets('rows_scroll_instead_of_overflowing_at_320dp_and_200_percent_text', ...) // all three variants in a 288 dp box → no exception
testWidgets('quick_keys_are_at_least_56dp', ...)
test('starter_apps_have_unique_packages_and_market_links', ...)          // 5 entries, unique packages, launchLink starts with 'market://launch?id='
// quick_access_row_golden_test.dart (@Tags(['golden'])): the three visible variants stacked, Size(390, 300), light + dark → goldens/quick_access_rows_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/remote/widgets/quick_access_row_test.dart test/features/apps`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/remote/widgets/quick_access_row_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): quick-access row with apps, colour keys and media keys" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P4-R9 (starter apps until Phase 5). Learning if `contrastRatio` had to move to a shared helper.

---

### Task 4.8: Keyboard sheet and text-edit planner

**Files:**
- Create: `app/lib/features/keyboard/text_edit_planner.dart`, `app/lib/features/keyboard/keyboard_sheet.dart`
- Test: `app/test/features/keyboard/text_edit_planner_test.dart`, `keyboard_sheet_test.dart`, `keyboard_sheet_golden_test.dart`

**Interfaces:**
- Consumes: `RemoteInput`, `KeyInputRecorder` (4.1), `KeyCodes.enter`/`delete`/`search`, `connectionStateProvider`, `showAppSheet`, ARB `keyboard*`, `keyEnter`, `remoteNotConnected`.
- Produces:
  - In `text_edit_planner.dart`:
    - `enum ImeTextMode { replaceField, appendOnly }`
    - `/// (unverified) See Ruling P4-R12. const ImeTextMode kImeTextMode = ImeTextMode.replaceField;`
    - `sealed class TextEdit` with `SendText(String text)` and `DeleteChars(int count)`, value `==`.
    - `List<TextEdit> planTextEdit({required String sent, required String next, ImeTextMode mode = kImeTextMode})`:
      - `replaceField`: `next == sent` → `[]`, otherwise `[SendText(next)]` (including `''`).
      - `appendOnly`, working in grapheme clusters (`package:characters`): find the common prefix `p`. Removed = `sent.characters.length − p`. `[if (removed > 0) DeleteChars(removed), if (next has more after p) SendText(rest)]`.
  - `Future<void> showKeyboardSheet(BuildContext context, {required RemoteInput input, ImeTextMode mode = kImeTextMode, Duration debounce = const Duration(milliseconds: 150)})` opens `showAppSheet(title: keyboardTitle, builder: KeyboardSheet(...))`. A static `bool get KeyboardSheet.isOpen` (true between open and close) lets the screen avoid opening it twice.
  - `class KeyboardSheet extends ConsumerStatefulWidget`:
    - **Layout:**
      - When `connectionStateProvider` isn't `connected` (loading counts as not), an inline `keyboardNotConnected` row (`Icons.link_off`, `dangerText`) as a live region.
      - `keyboardTvHint` (`textSecondary`).
      - A `TextField`: autofocus, `labelText: keyboardFieldLabel`, `hintText: keyboardHint`, `textInputAction: TextInputAction.send`, `autocorrect: false`, `enableSuggestions: true`. A clear `IconButton` (`Icons.clear`, tooltip `keyboardClear`, ≥ 48 dp) shows when the field isn't empty.
      - A row: `TextButton.icon(Icons.search, keyboardOpenTvSearch)` → `input.tap(KeyCodes.search)`, then a `FilledButton.icon(Icons.keyboard_return, keyEnter)`.
    - **Behaviour:**
      - `String _sent = ''`.
      - Each change restarts the `debounce` timer. When it fires → `_flush()`.
      - `_flush()` applies `planTextEdit(sent: _sent, next: text, mode: mode)` in order: `SendText` → `input.typeText`; `DeleteChars(n)` → `n × input.tap(KeyCodes.delete)`. It stops at the first refused call and updates `_sent = text` only when every call succeeded.
      - Enter (button or keyboard action): cancel the timer, `_flush()`, then `input.tap(KeyCodes.enter)`. If it was sent, pop the sheet.
      - Clear: clear the field and `_flush()` at once.
      - `dispose`: if a timer is pending, cancel it and `_flush()`.

- [ ] **Step 1: Write the failing tests**

```dart
// text_edit_planner_test.dart
test('replace_mode_sends_the_whole_field', () {
  expect(planTextEdit(sent: 'hel', next: 'help', mode: ImeTextMode.replaceField), [const SendText('help')]);
  expect(planTextEdit(sent: 'help', next: '', mode: ImeTextMode.replaceField), [const SendText('')]);
});
test('replace_mode_sends_nothing_when_unchanged', ...)
test('append_mode_deletes_then_sends_the_new_suffix', ...)  // ('hello', 'help') → [DeleteChars(2), SendText('p')]; ('ab', 'abc') → [SendText('c')]
test('append_mode_counts_graphemes', ...)                    // ('a👍🏽', 'a') → [DeleteChars(1)]

// keyboard_sheet_test.dart (pumpApp with a button that calls showKeyboardSheet(context, input: rec);
// override connectionStateProvider with Stream.value(const TvConnectionState(status: ConnectionStatus.connected)))
testWidgets('typing_sends_text_debounced', (t) async {                    // master name
  await openSheet(t);
  for (final s in ['h', 'he', 'hel']) { await t.enterText(find.byType(TextField), s); await t.pump(const Duration(milliseconds: 50)); }
  expect(rec.calls, isEmpty);
  await t.pump(const Duration(milliseconds: 150));
  expect(rec.calls, ['text:hel']);
});
testWidgets('enter_sends_66', ...)                                        // master name; tap 'Enter' → calls end with 'tap:66'; the sheet closed
testWidgets('enter_flushes_pending_text_before_enter_key', ...)           // type 'hi', tap 'Enter' at once → ['text:hi', 'tap:66']
testWidgets('keyboard_action_send_acts_as_enter', ...)                    // t.testTextInput.receiveAction(TextInputAction.send)
testWidgets('clear_sends_an_empty_field_at_once', ...)                    // after 'abc' flushed → tap 'Clear' → last call 'text:'
testWidgets('closing_the_sheet_flushes_pending_text', ...)                // type 'yo', tap the ✕ → ['text:yo']
testWidgets('not_connected_shows_inline_message_and_sends_nothing', ...)  // rec.connected = false + state offline → 'Not connected to your TV. What you type isn't sent.'; calls empty
testWidgets('reconnecting_then_typing_sends_the_whole_field', ...)        // offline: type 'ab' (refused); connected: type 'abc' → 'text:abc'
testWidgets('open_tv_search_sends_search_key', ...)                       // 'Open search on TV' → 'tap:84'
testWidgets('append_mode_uses_delete_keys', ...)                          // mode: appendOnly; 'abc' then 'ab' → [..., 'tap:67']
testWidgets('sheet_is_open_flag_tracks_the_sheet', ...)
testWidgets('keyboard_sheet_fits_320dp_at_200_percent_text', ...)
// keyboard_sheet_golden_test.dart (@Tags(['golden'])): open with 'netflix' typed, connected, Size(390, 844), light + dark → goldens/keyboard_sheet_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/keyboard`
Expected: FAIL.

- [ ] **Step 3: Implement** the planner and the sheet.
- [ ] **Step 4: Generate the goldens and run the tests**

Run: `flutter test --update-goldens --tags golden test/features/keyboard`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): keyboard sheet with debounced live typing and enter" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P4-R12. Learning: replace-field is (unverified) until the real-device run.

---

### Task 4.9: Remote screen composition

**Files:**
- Create: `app/lib/features/remote/presentation/widgets/pad_pager.dart`, `bottom_cluster.dart`, `remote_body.dart`, `app/lib/features/remote/application/ime_requests.dart` (+ `.g.dart`)
- Modify: `app/lib/features/remote/presentation/remote_screen.dart`
- Delete: `app/lib/features/remote/presentation/widgets/basic_controls.dart`, `app/test/features/remote/goldens/remote_basic_{light,dark}.png`
- Modify (tests): `app/test/features/remote/remote_screen_test.dart` (keep every Phase 3 test; replace `BasicControls` finders with `RemoteBody`; the pill is now under the app bar), `remote_screen_golden_test.dart` (new goldens), `app/test/features/demo/demo_mode_test.dart` (only finders that named `BasicControls`)
- Modify (helper): `app/test/helpers/pump_router_app.dart` gains `Future<void> Function(SettingsStore store)? prepareSettings` (run after the store opens, before `pumpWidget`) and `bool accessibleNavigation = false` (applied in the same `MediaQuery` as `textScale`). Tasks 4.10–4.12 use both.
- Test: `app/test/features/remote/remote_layout_test.dart`, `app/test/features/remote/widgets/pad_pager_test.dart`, `bottom_cluster_test.dart`

**Interfaces:**
- Consumes: everything from group A. `remoteActionsProvider`, `notConnectedNoticesProvider` (4.3); `Touchpad` (4.5); `Dpad`, `NumberPad` (4.6); `QuickAccessBar`, `quickAccessAppsProvider` (4.7); `showKeyboardSheet`, `KeyboardSheet.isOpen` (4.8); `Rocker` with `longPressDuration`/`valueSemantics` (4.4); `volumeProvider`, `currentAppProvider`, `connectionStateProvider`, `settingsControllerProvider`; `StatusPill`, `DeviceSwitcher`, `TvPreviewCard`.
- Produces:
  - `enum PadPage { touchpad, dpad, numbers }`.
  - `class PadPager extends StatefulWidget { const PadPager({required KeyInput input, required PadPage initialPage, required ValueChanged<PadPage> onPageChanged, super.key}); }`:
    - A `SegmentedButton<PadPage>` (labels `remotePadTouchpad`, `remotePadDpad`, `remotePadNumbers`; each label in a one-line `FittedBox(scaleDown)`; minimum height 48; semantics container labelled `remotePadTabsLabel`) over a `PageView`.
    - `physics: NeverScrollableScrollPhysics()` while the touchpad page is current, otherwise `PageScrollPhysics()` (Ruling P4-R7).
    - A tab tap animates to the page (`AppMotion.standard`, or a jump with reduce motion). Every page change calls `onPageChanged`.
  - `class BottomCluster extends StatelessWidget`:

    ```dart
    const BottomCluster({required KeyInput input, required VolumeChanged? volume /* null unless connected */,
        required VoidCallback onKeyboard, super.key});
    ```

    - The volume `Rocker`: `volumeLabel`; value `remoteVolumeValue(level)` or `remoteMutedValue`; `valueSemantics` `remoteVolumeSemantics(level, max)` or `remoteVolumeMutedSemantics`.
    - The 2 × 2 grid: Mute, Keyboard (`Icons.keyboard_outlined`, label `keyKeyboard`, → `onKeyboard`) / Back, Home.
    - The channel `Rocker` (`channelLabel`, `Icons.keyboard_arrow_up`/`down`).
    - Both rockers use `longPressDuration: kHoldThreshold`, `onUp`/`onDown` → `input.tap`, and hold callbacks → `input.holdStart`/`holdEnd`.
    - Laid out per Ruling P4-R8 (280 dp).
  - `class RemoteBody extends StatelessWidget`:

    ```dart
    const RemoteBody({required RemoteInput input, required bool enabled, required QuickAccessRow quickAccess,
        required List<AppEntry> apps, required String? currentApp, required PadPage initialPage,
        required ValueChanged<PadPage> onPageChanged, required VolumeChanged? volume,
        required VoidCallback onKeyboard, Widget? preview, super.key});
    static const double padMinHeight = 160; static const double quickRowMinPad = 200;
    ```

    - Implements Ruling P4-R8's portrait and split layouts, the dropping order, and the scroll fallback.
    - `Opacity(0.4)` on the TV controls when `!enabled`, never on the pad tabs.
    - `preview` (the demo card) sits under the status strip in portrait and at the top of the right column in split.
  - `@riverpod Stream<ImeShowRequested> imeShowRequests(Ref ref)`: awaits `remoteSessionProvider.future`; `null` → an empty stream; otherwise `session.events.whereType<ImeShowRequested>()`.
  - **`RemoteScreen` changes:**
    - **Reload:** `sessionState.isLoading && !sessionState.hasValue` → the Phase 3 spinner scaffold. While it reloads **with** a previous value, keep rendering the full remote with that session's scaffold. The status is forced to `connecting`, `volume` and `currentApp` are `null`, and `remoteActionsProvider` refuses everything (P4-R3). The switcher shows the target device's label from `savedDevicesProvider` when the target is a `DeviceTarget`, otherwise the old name. (Phase 3 carry-over.)
    - **App bar:** `toolbarHeight: 64`, title `DeviceSwitcher`, no pill. The status strip (`_StatusStrip`: 48 dp min height, 16 dp side padding, pill start-aligned, wraps at large text) is the first child of the body.
    - **Body:** `RemoteBody` with:
      - `input: ref.watch(remoteActionsProvider)`
      - `enabled: status == connected`
      - `quickAccess` and `navigationStyle` from settings
      - `apps: ref.watch(quickAccessAppsProvider)`
      - `currentApp` and `volume` from their providers, only when connected
      - `preview: session.isDemo ? const TvPreviewCard() : null`.
    - **Initial pad page:** `accessibleNavigation` → `dpad`; else `navigationStyle == dpad` → `dpad`; else `touchpad`. `onPageChanged`: `touchpad`/`dpad` → `settingsController.update((s) => s.setNavigationStyle(...))` when it differs; `numbers` → nothing.
    - **Not-connected snackbar:** `ref.listen(notConnectedNoticesProvider, ...)` → the Phase 3 snackbar logic (with Reconnect when `disconnected`). `_press` and the direct `session.sendKey` call are removed.
    - **Keyboard:** `onKeyboard` → `showKeyboardSheet(context, input: ref.read(remoteActionsProvider))`.
    - **Auto-open:** `ref.listen(imeShowRequestsProvider, ...)` → open the keyboard sheet only if `settings.autoOpenKeyboard`, `ModalRoute.isCurrentOf(context) == true`, and `!KeyboardSheet.isOpen` (Ruling P4-R12).
    - The identity-changed dialog and every other Phase 3 behaviour are unchanged.

- [ ] **Step 1: Write the failing tests** (`pumpRouterApp(initialLocation: AppRoutes.remote, overrides: [remoteSessionProvider.overrideWith((ref) async => fake), hapticsProvider…])` with `fake = FakeRemoteSession(initial: connected)`. A local helper `pumpRemote(t, {QuickAccessRow? quick, NavigationStyle? nav, bool? autoOpen, Size? size, double textScale = 1, bool accessibleNavigation = false})` sets the view size and writes the settings through `prepareSettings`, then pumps.)

```dart
// remote_layout_test.dart
testWidgets('semantics_labels_present_for_all_controls', (t) async {      // master name
  final handle = t.ensureSemantics();
  for (final page in ['Touchpad', 'D-pad', 'Numbers']) {
    await t.tap(find.text(page)); await t.pumpAndSettle();
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
  }
  for (final label in ['Back', 'Home', 'Mute', 'Keyboard', 'Volume up', 'Volume down', 'Channel up', 'Channel down']) {
    expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
  }
  handle.dispose();
});
testWidgets('pad_tabs_switch_pages_and_persist_navigation_style', ...)  // tap 'D-pad' → Dpad visible; store.navigationStyle == dpad; re-pump → opens on D-pad
testWidgets('numbers_page_is_not_persisted', ...)
testWidgets('opens_on_dpad_when_a_screen_reader_is_on', ...)            // MediaQuery accessibleNavigation: true (wrap via textScale helper's MediaQuery) → Dpad visible; store unchanged
testWidgets('swipe_on_touchpad_does_not_change_page', ...)              // fling left on the touchpad → still Touchpad; sentPresses has dpadRight steps
testWidgets('swipe_from_dpad_page_moves_to_numbers', ...)
testWidgets('none_expands_pad_area', (t) async {                        // master name
  await pumpRemote(t, quick: QuickAccessRow.apps); final withRow = t.getSize(find.byType(PageView)).height;
  await pumpRemote(t, quick: QuickAccessRow.none); final without = t.getSize(find.byType(PageView)).height;
  expect(without, greaterThan(withRow));
});
testWidgets('quick_access_row_follows_the_setting', ...)                // colourKeys → 'Red' visible, tap → sentPresses [(183, short)]
testWidgets('quick_row_hidden_when_the_pad_would_be_too_small', ...)    // Size(320, 480) → QuickAccessBar absent, PageView height ≥ 160
testWidgets('landscape_uses_split_layout', ...)                         // Size(844, 390) → the PageView is left of the BottomCluster
testWidgets('remote_fits_320dp_at_200_percent_text_in_every_variant', (t) async {
  for (final quick in QuickAccessRow.values) for (final page in ['Touchpad', 'D-pad', 'Numbers']) {
    await pumpRemote(t, quick: quick, size: const Size(320, 568), textScale: 2);
    await t.tap(find.text(page)); await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '$quick $page');
  }
});
testWidgets('volume_rocker_shows_level_only_when_connected', ...)       // fake.push(VolumeChanged(12, 100, false)) → '12'; emit offline → '12' gone
testWidgets('holding_volume_up_sends_start_and_end_long', ...)          // long press on 'Volume up' ≥ 300 ms → sentPresses [(24, startLong), (24, endLong)]
testWidgets('refused_press_shows_not_connected_snackbar', ...)          // offline → tap 'Home' → 'Not connected to your TV'; sentPresses empty
testWidgets('switching_tv_keeps_the_remote_visible_while_loading', (t) async {
  // remoteSessionProvider override: first build returns fake A; later builds await a Completer.
  // activateDevice('Bedroom TV') → pump → RemoteBody still found, no CircularProgressIndicator,
  // pill 'Connecting…', tap 'Home' → snackbar, A.sentPresses empty. Complete with B → B's state shows.
});
testWidgets('keyboard_key_opens_the_keyboard_sheet', ...)
testWidgets('auto_opens_on_ime_show', (t) async {                       // master name
  await pumpRemote(t); fake.push(const ImeShowRequested()); await t.pumpAndSettle();
  expect(find.text('Type on your TV'), findsOneWidget);
});
testWidgets('auto_open_respects_the_setting', ...)                      // autoOpen false → no sheet
testWidgets('ime_show_while_a_sheet_is_open_does_nothing', ...)         // device switcher sheet open → push → still only the switcher sheet
testWidgets('ime_show_twice_opens_one_sheet', ...)

// pad_pager_test.dart / bottom_cluster_test.dart (KeyInputRecorder, no providers)
testWidgets('cluster_keys_send_their_codes', ...)                       // Back 4, Home 3, Mute 164, Volume up/down 24/25, Channel up/down 166/167
testWidgets('cluster_fits_288dp', ...)
testWidgets('tab_tap_reports_the_page', ...)

// remote_screen_golden_test.dart (@Tags(['golden'])), connected FakeRemoteSession with VolumeChanged(12, 100, false):
//   remote_portrait_{light,dark}: Size(390, 844), touchpad, apps row
//   remote_landscape: Size(844, 390), dark, D-pad
//   remote_tablet: Size(834, 1194), light, touchpad
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/remote`
Expected: FAIL.

- [ ] **Step 3: Implement** the pager, cluster, body, IME provider and screen changes. Delete `BasicControls` and its goldens. Update the Phase 3 remote and demo tests' finders without weakening their assertions. Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Generate the goldens**

Run: `flutter test --update-goldens --tags golden test/features/remote/remote_screen_golden_test.dart` and inspect all four.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS, including every Phase 3 remote, demo and connect-flow test.

- [ ] **Step 6: Build the dev APK**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add -A app/lib app/test
git commit -m "feat(app): full remote layout with pad pager, bottom cluster, quick row and keyboard" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Rulings P4-R7 and P4-R8. Carry-over closed: the previous remote stays visible while the session reloads.

---

### Task 4.10: Power key, Wake-on-LAN and the MAC setup sheet

**Files:**
- Create: `app/lib/core/tv/mac_address.dart`, `app/lib/features/remote/application/power_controller.dart` (+ `.g.dart`), `app/lib/features/remote/presentation/widgets/power_button.dart`, `wol_setup_sheet.dart`, `app/test/helpers/fake_wake_on_lan.dart`
- Modify: `app/lib/core/storage/device_repository.dart` (`setWolMac`), `app/lib/core/wake/wake_on_lan_service.dart` (`kIosWakeOnLanEnabled`, `wakeOnLanAvailableProvider`), `remote_screen.dart` (power key in the app bar), `app/test/helpers/pump_router_app.dart` (defaults `wakeOnLanServiceProvider.overrideWithValue(FakeWakeOnLan())`, `wakeOnLanAvailableProvider.overrideWithValue(true)`)
- Test: `app/test/core/tv/mac_address_test.dart`, additions to `app/test/core/storage/device_repository_test.dart`, `app/test/features/remote/application/power_controller_test.dart`, `app/test/features/remote/power_test.dart`, `app/test/features/remote/widgets/wol_setup_sheet_test.dart`

**Interfaces:**
- Consumes: `RemoteActions`, `notConnectedNoticesProvider`, `hapticsProvider` (4.3); `WakeOnLanService.wake` (4.2); `DeviceRepository.find`; `RemoteSession.pairingTarget`/`reconnect`/`current`; `AppKeyButton.onSemanticLongPress` (4.4); `showAppSheet`.
- Produces:
  - `String? parseMac(String input)`:
    - Trims, then accepts 12 hex digits written with `:` or `-` between pairs, `.` between groups of four (`aabb.ccdd.eeff`), or no separators.
    - Returns upper-case `AA:BB:CC:DD:EE:FF`.
    - Rejects all zeros, `FF:FF:FF:FF:FF:FF`, and multicast addresses (the low bit of the first octet set).
  - `DeviceRepository.setWolMac(String serviceName, String? mac)`: a targeted update of `wolMac` only; a no-op for unknown names.
  - `const bool kIosWakeOnLanEnabled = false;` (documented: flip it when Apple grants `com.apple.developer.networking.multicast`).
  - `@Riverpod(keepAlive: true) bool wakeOnLanAvailable(Ref ref) => defaultTargetPlatform != TargetPlatform.iOS || kIosWakeOnLanEnabled;`
  - `enum PowerOutcome { sentPowerKey, waking, wakeFailed, needsMac, cannotWake, notConnected }`
  - `class PowerController`:

    ```dart
    PowerController({required RemoteSession? session, required RemoteActions actions, required DeviceRepository devices,
        required WakeOnLanService wakeOnLan, required bool wakeOnLanAvailable, required Haptics haptics,
        required bool hapticsEnabled, required VoidCallback onRefused});
    Future<PowerOutcome> press();
    Future<PowerOutcome> saveMacAndWake(String mac);   // mac is already normalised by parseMac
    ```

    `press()` (Ruling P4-R10):
    1. `session == null` → `onRefused()`, `notConnected`.
    2. `connected` → `actions.tap(KeyCodes.power)` (its heavy haptic is the only one) → `sentPowerKey`, or `notConnected` if refused.
    3. `needsPairing`, or `pairingTarget == null` (demo) → `onRefused()`, `notConnected`.
    4. Otherwise a heavy haptic (when enabled), then:
       - `!wakeOnLanAvailable` → `cannotWake`.
       - `device = await devices.find(target.serviceName)`; `device?.wolMac == null` → `needsMac`.
       - `await wakeOnLan.wake(mac:, tvHost: device.lastHost)`: `true` → `session.reconnect()`, `waking`; `false` → `wakeFailed`.

    `saveMacAndWake(mac)`:
    - `setWolMac(target.serviceName, mac)`. An error → rethrow (the sheet shows `wolSaveFailed`).
    - Then the wake steps of rule 4, without a second haptic.
  - `@riverpod PowerController powerController(Ref ref)`: built like `remoteActionsProvider` (session `null` while loading), with `onRefused: ref.read(notConnectedNoticesProvider.notifier).notify`.
  - `class PowerButton extends StatelessWidget { const PowerButton({required VoidCallback onHint, required VoidCallback onPower, super.key}); }`:
    - An `AppKeyButton` (56 dp, `Icons.power_settings_new` in `dangerText`, `semanticLabel: keyLabel(power)`).
    - `onTap: onHint`, `onLongPressStart: onPower`, `longPressDuration: Duration(milliseconds: 600)`, `onSemanticLongPress: onPower`.
  - `Future<String?> showWolSetupSheet(BuildContext context, {required String tvName, required Future<void> Function(String mac) onSave})`:
    - An `AppSheet(wolSetupTitle(tvName))` with `wolSetupBody`, `wolNotBluetooth` and `wolMayNotWork`.
    - A `TextField`: label `wolMacLabel`, hint `wolMacHint`, `keyboardType: TextInputType.visiblePassword`, `textCapitalization: characters`, `autocorrect: false`; input limited to hex digits and `:-.` plus spaces, max 17 characters after trimming.
    - `FilledButton(wolSaveAndWake)`: `parseMac == null` → `errorText: wolMacError` and the sheet stays open. Otherwise `await onSave(mac)`: an error → `errorText: wolSaveFailed`; success → pop with the MAC.
  - In `RemoteScreen`'s app bar actions: `PowerButton(onHint: show powerHoldHint snackbar, onPower: _power)`. `_power` awaits `ref.read(powerControllerProvider).press()` and maps the outcome:
    - `waking` → `powerWaking(tvName)` snackbar
    - `wakeFailed` → `powerWakeFailed`
    - `cannotWake` → `powerTurnOnWithTvRemote`
    - `needsMac` → `showWolSetupSheet(onSave: (mac) async { outcome = await controller.saveMacAndWake(mac); })`, then the outcome's snackbar
    - `sentPowerKey` / `notConnected` → nothing more (the notice listener shows the snackbar).
  - Test helper `FakeWakeOnLan implements WakeOnLanService`: `List<(String mac, String? tvHost)> wakes` and `bool result = true`.

- [ ] **Step 1: Write the failing tests**

```dart
// mac_address_test.dart
test('parse_mac_accepts_common_formats_and_normalises', () {
  for (final raw in ['aa:bb:cc:dd:ee:f0', 'AA-BB-CC-DD-EE-F0', 'aabb.ccdd.eef0', ' AABBCCDDEEF0 ']) expect(parseMac(raw), 'AA:BB:CC:DD:EE:F0');
});
test('parse_mac_rejects_invalid_multicast_and_reserved', () {
  for (final raw in ['', 'AA:BB:CC:DD:EE', 'GG:BB:CC:DD:EE:FF', '00:00:00:00:00:00', 'FF:FF:FF:FF:FF:FF', '01:00:5E:00:00:01', 'AA:BB:CC:DD:EE:FF:00']) expect(parseMac(raw), isNull);
});

// device_repository_test.dart (additions)
test('set_wol_mac_updates_only_the_mac', ...)   // other fields unchanged; null clears it
test('set_wol_mac_on_unknown_device_is_a_no_op', ...)

// power_controller_test.dart (FakeRemoteSession with pairingTarget savedTv().toDiscoveredTv(), in-memory repo, FakeWakeOnLan, RecordingHaptics)
test('connected_sends_the_power_key', ...)                 // → sentPowerKey; sentPresses [(26, short)]; haptics ['heavy']
test('standby_tv_still_connected_gets_power_key_not_wol', ...) // isPowerOn false via push, status connected → sentPowerKey, wakes empty
test('wol_sent_when_tv_off_and_mac_known', () async {      // master name
  await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0')); fake.emit(const TvConnectionState(status: ConnectionStatus.offline));
  expect(await controller.press(), PowerOutcome.waking);
  expect(wol.wakes, [('AA:BB:CC:DD:EE:F0', '192.168.0.20')]); expect(fake.reconnectCalls, 1); expect(haptics.events, ['heavy']);
});
test('offline_without_mac_needs_mac', ...)
test('save_mac_and_wake_stores_then_wakes_once_with_one_haptic', ...)
test('wake_failure_reports_wake_failed_and_does_not_reconnect', ...)
test('needs_pairing_is_refused', ...)                      // → notConnected, onRefused called, nothing sent
test('demo_offline_is_refused', ...)                       // pairingTarget null
test('unavailable_wol_reports_cannot_wake', ...)

// power_test.dart (pumpRouterApp at /remote)
testWidgets('power_requires_long_press', (t) async {      // master name
  await t.tap(find.bySemanticsLabel('Power')); await t.pump();
  expect(find.text('Hold to turn the TV on or off'), findsOneWidget); expect(fake.sentPresses, isEmpty);
  await t.longPress(find.bySemanticsLabel('Power')); await t.pump();   // longPress holds past 600 ms
  expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
});
testWidgets('a_550ms_press_is_still_a_tap', ...)           // startGesture, pump 550 ms, up → hint, nothing sent
testWidgets('semantic_long_press_on_power_sends_power', ...)
testWidgets('waking_shows_a_snackbar_with_the_tv_name', ...)   // offline + MAC → 'Waking Living Room TV 3…'
testWidgets('no_mac_opens_setup_sheet_and_saving_wakes', ...)  // offline, no MAC → 'Turn on Living Room TV 3 from your phone'; 'zz' → error; 'aa-bb-cc-dd-ee-f0' → repo wolMac 'AA:BB:CC:DD:EE:F0', wakes 1, sheet closed
testWidgets('ios_without_entitlement_explains_turning_on_by_hand', ...) // override wakeOnLanAvailableProvider false → 'Turn the TV on with its own remote…'
testWidgets('power_key_fits_the_app_bar_at_320dp_and_200_percent_text', ...)

// wol_setup_sheet_test.dart
testWidgets('save_failure_keeps_the_sheet_open_with_an_error', ...)
testWidgets('wol_sheet_fits_320dp_at_200_percent_text', ...)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/tv test/core/storage test/features/remote`
Expected: FAIL.

- [ ] **Step 3: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass; re-baseline the remote goldens** (the app bar now has the power key)

Run: `flutter test --update-goldens --tags golden test/features/remote/remote_screen_golden_test.dart`, inspect, then `flutter test`.
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): long-press power with wake-on-lan and mac setup" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: carry-over closed: `wolMac` now has a source. Decision for Rulings P4-R10 and P4-R11. Owner note: WoL stays Android-only until the iOS entitlement.

---

### Task 4.11: Keep Screen Awake and Theater Mode

**Files:**
- Modify: `app/pubspec.yaml` (deps `wakelock_plus: 1.8.2`, `screen_brightness: 2.1.11`), `app/lib/app/theme/tokens.dart` (`AppColors.theater`), `app/lib/app/theme/app_theme.dart` (`buildTheaterTheme`), `app/lib/app/router.dart` (`pageRouteObserverProvider`, `GoRouter(observers: [...])`), `remote_screen.dart` (wraps its scaffold), `app/test/helpers/pump_router_app.dart` (fake defaults)
- Create: `app/lib/core/device/screen_services.dart` (+ `.g.dart`), `keep_awake.dart`, `theater_mode.dart`, `app/test/helpers/fake_screen_services.dart`
- Test: `app/test/core/device/keep_awake_test.dart`, `theater_mode_test.dart`, `app/test/app/theme/theater_palette_test.dart`, `app/test/features/remote/remote_behaviour_test.dart`, `remote_theater_golden_test.dart`

**Interfaces:**
- Consumes: `settingsControllerProvider` (`keepScreenAwake`, `theaterMode`), `appRouterProvider`, `AppColors`, `buildAppTheme`.
- Produces:
  - In `screen_services.dart`:
    - `abstract interface class ScreenWakeLock { Future<void> enable(); Future<void> disable(); }` with `WakelockPlusScreenWakeLock` (`WakelockPlus.enable/disable`).
    - `abstract interface class ScreenDimmer { Future<void> dim(double brightness); Future<void> restore(); }` with `ScreenBrightnessDimmer` (`ScreenBrightness.instance.setApplicationScreenBrightness` / `resetApplicationScreenBrightness`).
    - Both swallow platform errors.
    - `@Riverpod(keepAlive: true)` providers `screenWakeLockProvider` and `screenDimmerProvider`.
    - Test helpers `RecordingWakeLock` (`bool enabled`, `List<bool> changes`) and `RecordingDimmer` (`double? level`, `int restores`).
  - `@Riverpod(keepAlive: true) RouteObserver<PageRoute<dynamic>> pageRouteObserver(Ref ref) => RouteObserver<PageRoute<dynamic>>();`, registered in `GoRouter(observers: [ref.watch(pageRouteObserverProvider)])`.
  - `class KeepAwake extends ConsumerStatefulWidget { const KeepAwake({required bool enabled, required Widget child}); }`:
    - `RouteAware` on its `ModalRoute` (when that is a `PageRoute`).
    - Desired state: `enabled && !_covered`, where `_covered` is set by `didPushNext` and cleared by `didPopNext`.
    - Calls `enable`/`disable` only on changes, and `disable` in `dispose` if enabled (Ruling P4-R14).
  - `AppColors.theater`, a dark-based token set: `bg #000000`, `surface #050608`, `surfaceRaised #0D0F13`, `outline #1A1D24`, `textPrimary #B8BEC9`, `textSecondary #8A919E`, `accent #5A72C8`, `onAccent #000000`. The status and TV colours equal the dark set's.
  - `ThemeData buildTheaterTheme()`: `buildAppTheme(brightness: dark)` with the `AppColors.theater` extension and a matching `ColorScheme`.
  - `class TheaterMode extends ConsumerStatefulWidget { const TheaterMode({required bool enabled, required Widget child, Duration idle = const Duration(seconds: 30), double dimLevel = 0.05}); }`:
    - The idle timer runs only while `enabled`, `ModalRoute.isCurrentOf(context) != false`, the app lifecycle is `resumed` (an `AppLifecycleListener`), and `!MediaQuery.accessibleNavigationOf(context)`.
    - A `Listener(behavior: translucent, onPointerDown:)` restarts it.
    - When it fires: `dimmer.dim(dimLevel)`, `_dimmed = true`. The child is wrapped in `Theme(data: buildTheaterTheme())` and covered by `Positioned.fill` of an opaque `GestureDetector`. Its `onTapDown`/`onPanDown`/`onLongPressDown` → restore, so the whole first pointer sequence is absorbed. Semantics label `theaterWakeLabel`, with an `onTap` that restores.
    - Restore = `dimmer.restore()`, `_dimmed = false`, restart the timer.
    - Losing any run condition, or `dispose`, cancels the timer and restores if dimmed.
  - `RemoteScreen` wraps its `Scaffold` in `KeepAwake(enabled: settings.keepScreenAwake, child: TheaterMode(enabled: settings.theaterMode, child: Scaffold(...)))`, for every session state that shows the remote.

- [ ] **Step 1: Write the failing tests**

```dart
// remote_behaviour_test.dart (pumpRouterApp; RecordingWakeLock/RecordingDimmer overrides; connected FakeRemoteSession)
testWidgets('wakelock_only_on_remote_screen', (t) async {                 // master name
  await pumpRemote(t); expect(lock.enabled, isTrue);
  router.push(AppRoutes.discover); await t.pumpAndSettle(); expect(lock.enabled, isFalse);
  router.pop(); await t.pumpAndSettle(); expect(lock.enabled, isTrue);
  router.go(AppRoutes.settings); await t.pumpAndSettle(); expect(lock.enabled, isFalse);
});
testWidgets('keep_awake_off_setting_never_enables', ...)
testWidgets('sheet_over_remote_keeps_the_wakelock', ...)                 // open the keyboard sheet → lock.enabled still true
testWidgets('theater_dims_after_30s_idle', (t) async {                   // master name
  await pumpRemote(t, theater: true);
  await t.pump(const Duration(seconds: 29)); expect(dimmer.level, isNull);
  await t.pump(const Duration(seconds: 1)); expect(dimmer.level, 0.05);
  expect(Theme.of(t.element(find.byType(RemoteBody))).extension<AppColors>(), AppColors.theater);
});
testWidgets('first_touch_restores_without_sending_key', (t) async {     // master name
  await pumpRemote(t, theater: true, nav: NavigationStyle.dpad); await t.pump(const Duration(seconds: 30));
  await t.tap(find.bySemanticsLabel('Home')); await t.pump();
  expect(fake.sentPresses, isEmpty); expect(dimmer.restores, 1);
  await t.tap(find.bySemanticsLabel('Home')); await t.pump();
  expect(fake.sentPresses, [(KeyCodes.home, KeyDirection.short)]);
});
testWidgets('a_long_first_touch_is_absorbed_whole', ...)                // long-press 'Volume up' while dimmed → nothing sent, no hold
testWidgets('touches_reset_the_idle_timer', ...)                        // tap at 20 s → still bright at 45 s, dim at 50 s
testWidgets('theater_off_never_dims', ...)
testWidgets('theater_suspended_with_screen_reader', ...)                // accessibleNavigation true → no dim after 60 s
testWidgets('open_sheet_pauses_the_idle_timer', ...)                    // keyboard sheet open 60 s → no dim; close → dims 30 s later
testWidgets('leaving_the_remote_restores_brightness', ...)              // dimmed → router.go(settings) → restores 1
testWidgets('backgrounding_restores_brightness', ...)                   // dimmed → binding lifecycle paused → restores 1; resumed → dims again after 30 s

// keep_awake_test.dart / theater_mode_test.dart: the same rules on a bare MaterialApp with the observer (fast unit coverage).
// theater_palette_test.dart
test('theater_palette_text_contrast_at_least_4_5', ...)   // textPrimary and textSecondary vs bg, surface and surfaceRaised ≥ 4.5 (shared contrast helper)
// remote_theater_golden_test.dart (@Tags(['golden'])): dimmed remote, Size(390, 844) → goldens/remote_theater.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/device test/app/theme test/features/remote/remote_behaviour_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the dependencies**

Run: `flutter pub add wakelock_plus:1.8.2 screen_brightness:2.1.11`

- [ ] **Step 4: Implement.** Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Generate the golden, run the tests, build the dev APK**

Run `flutter test --update-goldens --tags golden test/features/remote/remote_theater_golden_test.dart` (inspect), then `flutter test`, then `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
Expected: all PASS, and the build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): keep screen awake and theater mode on the remote" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling P4-R14 and the pins wakelock_plus 1.8.2 and screen_brightness 2.1.11. Learning: (unverified) on iOS, `setApplicationScreenBrightness` changes the system brightness while the app is in front and `reset` restores it; check on an iPhone. Owner note: the Mac build must run `pod install` for the two new plugins.

---

### Task 4.12: Demo polish, TV-preview states, end-to-end seam tests, accessibility guidelines

**Files:**
- Modify: `app/lib/features/demo/demo_remote_session.dart` (Search → keyboard)
- Modify (tests): `app/test/features/demo/demo_remote_session_test.dart`, `demo_mode_test.dart`
- Create (tests): `app/test/app/remote_flow_test.dart`, `app/test/features/remote/remote_accessibility_test.dart`

**Interfaces:**
- Consumes: everything above; `FakeRemoteClients` (real `TvRemoteSession` path), `DemoRemoteSession`, `TvPreviewCard`.
- Produces:
  - `DemoRemoteSession.sendKey(KeyCodes.search)` records the press, then emits `ImeShowRequested()`, so reviewers see the keyboard open by itself (Ruling P4-R12). Document it.
  - No other production changes. This task closes the Phase 3 carry-over "demo TV preview states need tests", and proves the pieces work together through the real session and providers.

- [ ] **Step 1: Write the failing tests**

```dart
// demo_remote_session_test.dart
test('search_key_asks_for_the_keyboard', ...)        // connected; sendKey(84) → events emits ImeShowRequested; lastAction DemoKeyPressed(84, short)

// demo_mode_test.dart (Try demo from onboarding, as in Phase 3)
testWidgets('preview_shows_holding_and_released', ...)  // long-press 'Volume up' → 'Holding Volume up' during; after release 'Released Volume up'
testWidgets('preview_shows_opened_app', ...)            // tap 'Open Netflix' → 'Opened market://launch?id=com.netflix.ninja'
testWidgets('preview_shows_typed_text', ...)            // Keyboard → type 'hi' → pump 150 ms → 'Typed "hi"'
testWidgets('preview_shows_screen_off_after_power', ...) // long-press 'Power' → 'Screen off'
testWidgets('demo_search_from_the_sheet_keeps_one_sheet', ...) // open Keyboard → tap 'Open search on TV' → the demo's ImeShowRequested
                                                       // opens no second sheet (find.text('Type on your TV') findsOneWidget); preview 'Pressed Search'

// remote_flow_test.dart (pumpRouterApp with a seeded database: savedTv(); FakeRemoteClients; real remoteSessionProvider)
testWidgets('touchpad_dpad_and_numbers_reach_the_client', ...)  // swipe right on the touchpad, switch to D-pad and tap OK, Numbers → '5'
    // → clients.created.single.sentKeys == [(22, short), (23, short), (12, short)]
testWidgets('smooth_press_hold_reaches_the_client_as_start_and_end_long', ...)
testWidgets('drop_mid_hold_does_not_crash_and_the_next_press_is_refused', ...)
    // hold Volume up → client.drop() → release → no exception; tap Home → 'Not connected to your TV'
testWidgets('typing_reaches_the_client_once_debounced', ...)    // keyboard 'abc' → sentTexts ['abc']; Enter → sentKeys ends with (66, short)
testWidgets('volume_value_clears_after_a_drop_and_returns_with_the_tv', ...) // push VolumeChanged → '12'; drop → gone; reconnect + push → back
testWidgets('remote_screen_has_no_mic_button', ...)             // find.byIcon(Icons.mic) and Icons.mic_none / mic_outlined → findsNothing (decision #7)

// remote_accessibility_test.dart (connected FakeRemoteSession), for light and dark, portrait and landscape:
testWidgets('remote_meets_text_contrast_${b.name}', ...)        // meetsGuideline(textContrastGuideline)
testWidgets('remote_meets_tap_target_guidelines', ...)          // androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/demo test/app/remote_flow_test.dart test/features/remote/remote_accessibility_test.dart`
Expected: the demo Search test fails. If any seam or accessibility test fails, it found a real defect: fix it in the owning file and name the fix in the report. Don't weaken the test.

- [ ] **Step 3: Implement** the demo change and whatever fixes the seam tests revealed.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 5: Build the dev APK**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): remote end-to-end seams, demo preview states and accessibility guidelines" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: carry-over closed: demo preview states. Every defect the seam tests found, with its fix.

---

## Phase exit checklist

- [ ] `powershell -File tool/check.ps1` → `All checks passed.` (goldens included). `tool/check.sh` passes with goldens excluded.
- [ ] Golden PNGs (light and dark unless noted):
  - new: `touchpad`, `dpad`, `number_pad`, `quick_access_rows`, `keyboard_sheet`, `remote_portrait`, `remote_landscape` (dark), `remote_tablet` (light), `remote_theater` (dark)
  - re-baselined: `rocker`
  - deleted: `remote_basic_*`.
- [ ] Every Phase 3 carry-over to Phase 4 in `status.md` is closed by a task report: supervisor seeding (4.2), reload keeps the remote (4.9), live-value reset (4.2), fakes aligned (4.1), WoL timing + MAC source (4.2, 4.10), demo preview tests (4.12), `AppKeyButton`/`Rocker` items (4.4; dispose-ends-hold kept by design, P4-R4).
- [ ] **Real-device run (owner + Claude; this is the exit criterion, and it includes the still-open Phase 3 run).** Phone: Note10+ over ADB Wi-Fi. TV: "Living Room TV 3". Run `flutter run --flavor dev -t lib/main_dev.dart`. Follow the live-testing rules: check the screen before each tap, and never use Power unless the owner is present and agrees.
  1. **Phase 3 checklist first** (`2026-10-25-phase-3-connect-flow.md`, exit item 1–7), including the identity-changed check and the ping interval.
  2. **CLI pre-checks** (before the app, from `packages/atv_remote`):
     - `dart run bin/atv_cli.dart text <host> "abc"` with the YouTube search box focused, then `text <host> "abcd"`. If the box shows `abcd`, replace-field is right. If it shows `abcabcd`, set `kImeTextMode = appendOnly` and record it.
     - `hold <host> volumeup 1500`: does the volume ramp while held, and stop at `endLong`?
     - `hold <host> dpadcenter 1000` on a launcher tile: does a context menu open?
  3. **Every control acts on the TV:** touchpad (step, multi-step drag, tap, hold, two-finger Back), D-pad (each region and holds), number pad (on a live-TV input if there is one), Back, Home, Mute, both rockers (tap and hold, Smooth Press on), colour keys, media keys, each starter app (record which packages open and which don't), the keyboard (typing, Clear, Enter, Open search on TV, auto-open in YouTube search).
  4. **Smooth Press off.** There's no settings page until Phase 5, so flip `AppSettings.defaults.smoothPressEnabled` in a local, uncommitted change, then uninstall and reinstall (a stored value would win over the default; re-pairing is needed afterwards). Holding volume repeats about 8 times per second. Revert the change afterwards.
  5. **Power:** with the owner's agreement, hold Power → the TV goes to standby. Does the pill stay "Connected" (socket kept) or go Offline? Hold again → the TV wakes (key or WoL path). Enter the TV's MAC through the setup sheet and test waking from standby. Record: does WoL work on this MediaTek TV over Wi-Fi?
  6. **Theater Mode and keep awake:** with Theater on, wait 30 s → it dims; the first touch only brightens. The phone doesn't lock while the remote is open with keep awake on.
  7. **Usability check** (master exit criterion): the owner uses YouTube for 5 minutes with the phone in one hand without looking at it, and counts mis-taps (target: 0 unintended commands). Record the result and any layout complaints.
  8. Landscape and (if available) a tablet: the split layout is usable.

  If no device is available, say so in the report; don't claim the check passed.
- [ ] The task reports collectively carry these knowledge updates:
  - **decisions:** Rulings P4-R1 to P4-R19 (group them as in Phase 3: input/actions/holds, layout, power/WoL, keyboard, behaviour), plus the pins wakelock_plus 1.8.2 and screen_brightness 2.1.11.
  - **learnings:** every real-device answer from the checklist above. Add to "Unverified protocol behaviour": IME replace vs append, `startLong` auto-repeat and a missing `endLong`, long OK, `KEYCODE_SEARCH` on Google TV, socket survival in standby, WoL on the MediaTek TV, the starter apps' `market://launch` behaviour, and iOS app brightness.
  - **status:** Phase 4 done; carry-overs closed; carry-overs to Phase 5 (Settings pages for the Phase 4 toggles and quick-access variant, `quickAccessAppsProvider` → catalogue, edit-device reuse of `parseMac`/the MAC field, flip `kImeTextMode` if needed).

## Needs the owner

- **The real-device run above** (Phase 3 + Phase 4 together), with agreement before any Power test.
- **Closed-test clock** (master plan: starts at the end of Phase 4). This needs the Play Console account, 12 testers, and an **upload keystore**. Phase 9 owns release signing, but a closed-test upload must be signed now. **Question:** confirm the final application ID and app name before the first upload. The Play package name can never change after it (placeholder `com.digitallinked.atvremote`, "Remotely for Android TV").
- **On a Mac:** `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` after Task 4.11 (new pods: wakelock_plus, screen_brightness), and a quick check on an iPhone that Theater Mode's brightness is restored when leaving the remote.
- **Apple multicast entitlement** for Wake-on-LAN on iOS. Until it is granted, `kIosWakeOnLanEnabled` stays `false` and iPhone users are told to turn the TV on with its own remote.
