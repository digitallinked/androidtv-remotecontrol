# Decisions log

Newest first. Each entry: date, decision, why, and what would make us revisit it. Never delete an entry; mark it `SUPERSEDED by #N` instead.

---

### #26 — 2026-10-27 — Phase 4 package pins
- wakelock_plus 1.8.2 (uses `FLAG_KEEP_SCREEN_ON`; pulls package_info_plus 10.2.2), screen_brightness 2.1.11 (app-window brightness only). No new Android permissions. iOS needs `pod install` on a Mac.

### #25 — 2026-10-27 — Quick access before the app catalogue
- Five starter apps (Netflix, YouTube, Prime Video, Disney+, Spotify) shown as monogram letter tiles — no logos, no brand colours — launched with `market://launch?id=<package>` (packages unverified on the owner's TV). Phase 5.1's catalogue replaces `quickAccessAppsProvider`'s body.
- Quick row variants: apps, colour keys (label ink picked by WCAG contrast), media keys, none. The row owns its 16 dp gutter.

### #24 — 2026-10-27 — Screen behaviour (P4-R13/R14/R15)
- Live values (volume, power, current app) clear on entering any non-connected status, never on entering `connected` — `TvConnection` sets `connected` and then flushes held-back pushes.
- `SessionSupervisor` is seeded from the current visibility, so a session built while backgrounded starts its 60 s grace.
- Keep screen awake: held while the remote is the top **page** route (`RouteObserver<PageRoute>` on GoRouter; sheets/dialogs don't count) and the app is in the foreground.
- Theater mode: dims to 5 % app brightness with `AppColors.theater` after 30 s idle; the first pointer sequence while dimmed only wakes; it never dims with a screen reader on or with a sheet/dialog over the remote (an identity dialog or keyboard auto-open therefore wakes it).
- Touchpad: steps at 24 dp then every 40 dp; "moved" means the largest displacement from the touch-down point (tremor can't cancel a tap; a wiggle past 18 dp is a dead swipe).

### #23 — 2026-10-27 — Keyboard (P4-R12)
- `kImeTextMode = replaceField` (unverified): each debounced change (150 ms) sends the whole field; `appendOnly` (grapheme-cluster deletes) is the fallback behind one constant.
- Enter flushes, sends `KEYCODE_ENTER` (66) and closes; Clear sends `''` at once; closing flushes. Offline: inline message, nothing queued, baseline not advanced.
- Auto-open on the TV's IME request only with the setting on, the remote as the top route and no keyboard sheet open (`KeyboardSheet.isOpen` is claimed by instance, released at `ModalRoute.popped`). `ImeShowSignal` uses identity equality (Riverpod drops equal consecutive values) and is ignored after 2 s.
- IME personalised learning is off on the field (users may type TV passwords). The demo's Search key emits an IME request.

### #22 — 2026-10-27 — Power and Wake-on-LAN (amends #17)
- Power key: a tap shows a hint; a 600 ms hold (or a screen-reader long press) is the power action. Connected → `KEYCODE_POWER` through `RemoteActions`. Otherwise read the device fresh → no MAC: setup sheet; MAC: Wake-on-LAN then `reconnect()`. Exactly one heavy haptic per power action.
- The MAC setup sheet is the only MAC source in Phase 4 (the mDNS `bt` TXT value is a Bluetooth MAC — never used). `parseMac` accepts `:`/`-`/dotted/bare forms and stores upper-case colon form; `setWolMac` updates only that column.
- iOS: Wake-on-LAN is off (`kIosWakeOnLanEnabled = false`) until Apple grants the multicast entitlement.
- **#17 wording correction:** the library's `sendWakeOnLan` tries each target and rethrows the first error only if all fail. The app's `WakeOnLanService.wake` sends to `255.255.255.255` immediately, then to the subnet broadcast and the TV's /24 after a lookup of up to 2 s; it returns `false` (never throws) when every send fails, and throws `FormatException` for a bad MAC before sending.

### #21 — 2026-10-27 — Remote layout (P4-R7/R8)
- Pad area is a pager with always-visible tabs: Touchpad / D-pad / Numbers. Only Touchpad and D-pad persist as `navigationStyle`; with a screen reader on it opens on the D-pad without persisting. Pages switch on the settled page, not mid-drag.
- 64 dp app bar (TV switcher + Power), 48 dp status strip under it. Portrait, or split when width ≥ 600 dp or landscape: right column `clamp(0.4 × width, 280, 400)` + 16 dp end gutter. Pad ≥ 160 dp; quick row dropped when the pad would get < 200 dp; scroll fallback. Bottom cluster 280 dp.
- While not connected the controls fade to 0.4 (tabs never fade). One "Not connected" snackbar at a time and none when the remote isn't the top route. The previous remote stays visible while a TV switch reloads.

### #20 — 2026-10-27 — Input path and holds (P4-R2..R6, R17)
- Widgets take `KeyInput`/`RemoteInput`; `RemoteActions` (autoDispose; the screen watches it) is the only send path. A press with no session, a loading/errored session or a non-connected status is refused: nothing sent, no haptic, one not-connected notice. Unsupported key codes throw `ArgumentError` even when offline.
- Hold threshold 300 ms (touchpad hold 500 ms). Smooth Press on → `startLong`/`endLong`; off → short repeats every 120 ms (centre never repeats). One hold at a time; auto-release after 15 s; dispose releases. Guard timers are armed before haptics/listeners; listener errors are swallowed.
- Haptics: light (tap, step, launch, Enter), medium (hold start), heavy (power, once). The action listener gets the first send of a hold only and text length only — never text.

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

### #17 — 2026-10-26 — Wake-on-LAN targets (wording corrected and timing amended by #22)
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
