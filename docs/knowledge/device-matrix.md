# Device matrix and manual checklists

The owner runs this file with Claude on real phones and TVs. It covers everything the automated tests can't prove: the real-device run that closes Phases 3–7, the Phase 8 `[device]`, `[Mac]` and `(unverified)` items, the TalkBack and VoiceOver scripts, and the performance runs.

- **No result is written down before it was observed.** Every Result cell starts empty. **No number is recorded until it was measured** (Ruling P8-R5). Host and emulator figures from the task reports are not device results and don't belong here.
- **Row ids are stable.** Refer to rows as `DM-nnn`. A new row takes the next free number at the end of its section's list; rows are never renumbered or reused. A dropped row keeps its id and gets "Withdrawn: <reason>" in Notes.
- **Result** is one of **Pass**, **Fail** or **Not run**. A Fail gets a one-line description in Notes and an entry in `status.md`. Fill in **Device** (model and OS version actually used) and **Date** (YYYY-MM-DD) for every row that ran.
- Each row's Steps start with **Target**, the device(s) to use, and Expected ends with **Record**, where else the answer goes besides this table.

## 1. How to run

### The matrix

| Kind | Device | Use for |
|---|---|---|
| Phone | **Android 8 emulator (API 26)** | the oldest supported Android: install, onboarding, backup flags, integration flows |
| Phone | **Samsung Galaxy Note10+ (SM-N975F, Android 12)** | the main device: every row unless another target is named; TalkBack; performance |
| Phone | **An Android 14/15 emulator or device** | themed icon (Android 13+), API 31+ device-transfer rules, integration flows |
| Phone | **An iPhone on iOS 16+** | VoiceOver, iOS icon/splash/Local Network, Malay purpose strings, iOS backup checks |
| Mac | the owner's Mac with Xcode | iOS builds, pods, simulator runs, the Swift storage channel |
| TV | **MediaTek Android TV "Living Room TV 3"** (home LAN, 192.168.0.x) | every TV row unless another target is named |
| TV | **A Google TV / Chromecast with Google TV, if available** | the Search key, Google TV behaviour; mark rows "Not run" if there is none |

### Install the dev build

From `app/`:

```
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

- Copy `env/example.json` to `env/dev.json` first. **Empty values keep every service off.** Rows in section 6 need real dev values (Firebase, AdMob test ids, RevenueCat dev keys, `UMP_DEBUG_GEOGRAPHY`, `UMP_TEST_DEVICE_ID`). `env/dev.json` is git-ignored and never committed.
- The dev package is `com.digitallinked.atvremote.dev` (Android and iOS).
- The Note10+ is reachable over ADB Wi-Fi when the owner turns it on. ADB wireless pairing needs the pairing code **and** the connect port from the main Wireless debugging screen (they differ). `adb` lives in `%LOCALAPPDATA%\Android\Sdk\platform-tools` on the dev PC.
- The CLI runs from `packages/atv_remote`: `dart run bin/atv_cli.dart <pair|key|watch|text|hold> <host> ...`. Its identity is `%USERPROFILE%\.atv_cli\identity.json`.

### Live-testing rules (read before every session)

1. **Verify the screen before each tap.** Take a screenshot (or a pixel check) before every tap whenever the remote screen could be showing. An unverified tap can press a key on the TV, open an app or click an ad. A Back press can go one screen further than expected.
2. **Never press Power without asking.** **Ask the owner before any Power or Wake-on-LAN step**, because it turns the TV off or on. The rows that need it say **ASK OWNER** in their Steps; if the owner says no, record "Not run" with "owner declined" in Notes.
3. **Restore settings afterwards.** Anything changed on the phone or the TV (volume, input, language, font size, accessibility services, Wi-Fi, IP address, app settings, Developer options) is put back at the end of the row that changed it.
4. **Connect via the dropdown, then tap the TV.** To (re)connect, open the TV switcher in the app bar and tap the TV, even if it already says "Connected". Don't assume a connection from a badge.
5. ADB screenshots from PowerShell: `adb shell screencap -p /sdcard/x.png` then `adb pull`, never `adb exec-out screencap -p > file.png` (it corrupts the PNG). Delete screenshots that show the phone's home screen, contacts or a share sheet.

### Where answers go

- Every row: its Result, Device, Date and Notes in this file.
- Protocol and TV behaviour answers: `docs/knowledge/learnings.md` → "Unverified protocol behaviour — checklist for the real-TV smoke test". Replace the question with the answer and the date; don't delete the history.
- Failures and follow-up work: `docs/knowledge/status.md` ("Next up" or a carry-over).
- Performance numbers: the results tables in section 10 only.

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-001 | **Target:** Note10+ (repeat on each phone used that session). Copy `env/example.json` to `env/dev.json`. From `app/` run `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json`. | The app installs and starts. A fresh install opens on onboarding. With empty values, no service starts (no banner, no consent form). **Record:** the build's version from About in Notes. | | | | |
| DM-002 | **Target:** Note10+ + Living Room TV 3. TV on, same Wi-Fi as the phone. Discover the TV, open it, read the pairing code from the TV to Claude, enter it. Then open the TV switcher and tap the TV. Press D-pad Up, Down and OK once each. | The TV appears in the list, pairing succeeds, the status pill says "Connected", and each key moves the TV's focus exactly once. This paired TV is the baseline for every later row. | | | | |
| DM-003 | **Target:** the session. Before any other row: the owner confirms they are present, which Power and Wake-on-LAN rows (DM-012, DM-013, DM-014, DM-075, DM-089) may run this session, and the TV's current volume, input and picture settings are written in Notes for restoring. | The agreed rows are listed in Notes. Nothing else needing Power runs this session. | | | | |
| DM-004 | **Target:** the session. At the end: copy every protocol answer into `learnings.md` → "Unverified protocol behaviour"; put every Fail in `status.md`; restore every setting listed in DM-003 and changed since. | Knowledge files match the results; the TV and phone are as they were. **Record:** which files were updated, in Notes. | | | | |

## 2. Protocol and connection

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-005 | **Target:** Note10+ + Living Room TV 3 (and the Google TV if available). Same key on 6467 (pairing) and 6466 (control)? Pair a TV that isn't saved yet (as in DM-002), then let the app connect straight away. | The connection after pairing succeeds with no "This TV's identity changed" dialog: the TOFU pin taken on 6467 matches the key on 6466 (decision #11). A Fail means the TV uses two keys and pinning needs a redesign. **Record:** learnings → same-key question. | | | | |
| DM-006 | **Target:** the dev PC + Living Room TV 3. Ping interval. From `packages/atv_remote` run `dart run bin/atv_cli.dart watch <host>` and leave the TV idle (no key presses) for 2 minutes. For the exact interval, capture the TV↔PC traffic on port 6466 with Wireshark while idle and note the time between the TV's small periodic TLS records. | `watch` stays connected for the whole idle period, so the TV sends something at least every 15 s (`RemoteClient.idleTimeout`). The capture gives the interval in seconds (target: dead-socket detection within 10 s, decision #10). **Record:** learnings → ping interval; the interval in Notes, or "capture not taken". | | | | |
| DM-007 | **Target:** Note10+ + Living Room TV 3. Does `_pickHost` get IPv4? Discover the TV by mDNS (not Enter IP address), pair it, then open Settings → Your TVs → Edit TV. | The stored address shown is a dotted IPv4 address (192.168.0.x), not an IPv6 address or a `.local` host name. **Record:** learnings → `_pickHost` question. | | | | |
| DM-008 | **Target:** Note10+ + Living Room TV 3. Reconnect time after an IP change. With the remote connected, give the TV a new IP address (TV Settings → Network & Internet → the network → IP settings → static, a free address; or a new DHCP reservation on the router). Start a stopwatch when the TV's network comes back. | The status pill goes Reconnecting… and then Connected without the user doing anything, or offers Reconnect, which then works. Discovery finds the TV under its new address. **Record:** the seconds to "Connected" in Notes; learnings → reconnect after an IP change. **Restore** the TV's original IP settings. | | | | |
| DM-009 | **Target:** the dev PC + Living Room TV 3. How does the TV reject an unpaired client on 6466? Rename `%USERPROFILE%\.atv_cli\identity.json` to `identity.json.bak`. Run `dart run bin/atv_cli.dart key <host> home` (this makes a fresh, unpaired identity). | The CLI prints "Not paired - run: pair <host>" (an alert or clean close before `RemoteConfigure`, mapped to `certificateRejected`), not a network error. If it prints a network error, the TV resets the TCP connection instead (rulings R4/R12 need another look). **Record:** learnings → unpaired client cert. **Restore:** delete the new `identity.json`, rename the `.bak` back, and run `key <host> home` once to prove the old identity still works. | | | | |
| DM-010 | **Target:** the dev PC + Living Room TV 3. Message order. Run `dart run bin/atv_cli.dart watch <host>` and note the order and timestamps of the first events (`RemoteReady`, volume, current app, power). | `watch` prints `RemoteReady` followed by volume, current-app and power events, with no error, whatever order the TV used (the client accepts any order). The raw wire order (`RemoteConfigure` vs `RemoteSetActive`, and whether `RemoteStart`/volume/current app come before `SetActive`) is visible only in a decrypted capture or a debug log; if neither was available, write "raw order not determined". **Record:** learnings → message order. | | | | |
| DM-011 | **Target:** the dev PC + Living Room TV 3. Run `dart run bin/atv_cli.dart watch <host>` for 5 minutes. Press one key on the TV's own remote at about 2 and 4 minutes. | `watch` runs the full 5 minutes with no drop and no reconnect (pings answered), and prints the volume or current-app events caused by the TV-remote presses. **Record:** learnings → 5-minute `watch`. | | | | |
| DM-012 | **Target:** Note10+ + Living Room TV 3. **ASK OWNER (Power).** Does the 6466 socket survive TV standby? With the remote connected, the owner puts the TV into standby with the TV's own remote. Wait 1 minute, then the owner wakes it the same way. Start a stopwatch when the TV wakes. | Either the connection survives (pill stays Connected) or the app shows Offline/Reconnecting… and reconnects on its own after the TV wakes. The pill never says Connected while the socket is gone. There is no time target. **Record:** learnings → standby question; which of the two happened, and the seconds from the TV waking to Connected, in Notes. | | | | |
| DM-013 | **Target:** Note10+ + Living Room TV 3. **ASK OWNER (Wake-on-LAN).** Does Wake-on-LAN wake the MediaTek TV, and how soon does `reconnect()` find it? Save the TV's Wi-Fi/Ethernet MAC in Edit TV. The owner turns the TV off with its own remote and waits until it is fully in standby. **Precondition:** the status pill shows Offline or Reconnecting… before the hold. If it still shows Connected, the app sends the Power key, not Wake-on-LAN: don't hold; record "WoL not exercised" (see DM-012) and stop. Otherwise hold Power in the app for 600 ms and start a stopwatch. | The app shows "Waking Living Room TV 3…". If the TV wakes, the pill reaches Connected. If it doesn't wake, the expected result is "Waking Living Room TV 3…" followed by no Connected (the pill stays Offline or Reconnecting…), with nothing hanging and the app still usable; the app can't detect a TV that ignores the packet. **Record:** woke or not, and the seconds to Connected, in Notes; learnings → Wake-on-LAN question. | | | | |
| DM-014 | **Target:** iPhone + Living Room TV 3. **ASK OWNER (Wake-on-LAN).** **Precondition:** the Apple multicast entitlement (`com.apple.developer.networking.multicast`) is granted **and** the build has `kIosWakeOnLanEnabled = true`. With both, repeat DM-013 on the iPhone (same Offline/Reconnecting… precondition). Without both, hold Power once with the pill Offline and record "WoL not available". | With both: as DM-013. Without both: no packet is sent; the app shows "Turn the TV on with its own remote. This app reconnects by itself." (`powerTurnOnWithTvRemote`) and doesn't crash. **Record:** status.md → Apple entitlement; which case ran, in Notes. | | | | |

## 3. Remote controls

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-015 | **Target:** Note10+ + Living Room TV 3. Hold feel and volume ramp. Set the TV volume low first. With Smooth Press **on** (Settings → Remote behaviour), hold Volume up for 2 s, then Volume down for 2 s; hold D-pad Right in a long list for 2 s. Turn Smooth Press **off** and repeat. | On: the TV ramps like its own remote held down, and stops the moment the finger lifts. Off: short repeats about every 120 ms, also stopping on release. A tap still moves exactly one step in both modes. Nothing overshoots after release. **Restore** the volume and the Smooth Press setting. | | | | |
| DM-016 | **Target:** the dev PC + Living Room TV 3. Does a `startLong` volume key auto-repeat on the TV, and what happens if `endLong` never arrives? Set the TV volume low. Run `dart run bin/atv_cli.dart hold <host> volumeUp 2000`. Then in the app, with Smooth Press on, start holding Volume up and turn the phone's Wi-Fi off while still holding. | The CLI hold ramps the volume for about 2 s and stops. With Wi-Fi cut mid-hold, the TV either stops by itself or keeps ramping; note which and for how long. **Record:** learnings → `startLong`/`endLong` question. **Restore** the volume and the phone's Wi-Fi. | | | | |
| DM-017 | **Target:** Note10+ + Living Room TV 3. Long-press OK. On a TV home-screen tile, hold the app's OK (D-pad centre) for 1.5 s. Repeat with `dart run bin/atv_cli.dart hold <host> dpadCenter 1500`. | The TV does what a long OK on its own remote does (usually a tile options menu), once; OK never auto-repeats. **Record:** learnings → long-press OK behaviour. Back out of any menu that opened. | | | | |
| DM-018 | **Target:** Note10+ and the dev PC + Living Room TV 3. IME replace-field. Open the TV's search box. From `packages/atv_remote` run `dart run bin/atv_cli.dart text <host> hello`, then `dart run bin/atv_cli.dart text <host> help`. Then in the app's keyboard sheet type "abc", move the phone's cursor between a and b, and type "x". | After the two CLI calls the TV field shows "help", not "hellohelp": `RemoteImeBatchEdit` with the whole field replaces it (`kImeTextMode = replaceField`). The app's edit leaves "axbc" on the TV. **Record:** learnings → IME replace-field. Clear the TV field. | | | | |
| DM-019 | **Target:** Note10+ + Living Room TV 3. IME counters and emoji. In the TV's search box, type "a😀b" in the app's keyboard sheet, then add "c" at the end, then delete the emoji. | The TV shows "a😀b", then "a😀bc", then "abc", with the TV's cursor at the end each time; nothing is dropped or doubled (the counters come from the latest TV IME message; we count UTF-16 code units). **Record:** learnings → IME counters / emoji cursor. Clear the TV field. | | | | |
| DM-020 | **Target:** none today. How does the TV's backspace count (graphemes or code units) under `appendOnly`? The app ships `replaceField` (decision record: `kImeTextMode`), so this only runs if `appendOnly` is ever switched on. | Record "Not run: `appendOnly` not in use" until then. **Record:** learnings → backspace question stays open. | | | | |
| DM-021 | **Target:** Note10+ + the Google TV (and Living Room TV 3 for comparison). The Search key. Run `dart run bin/atv_cli.dart key <host> search`; then in the app open the keyboard sheet and tap "Open search on TV". | Google TV: the search or Assistant screen opens. Note what the MediaTek TV does. **Record:** learnings → `KEYCODE_SEARCH` (84) on Google TV; what each TV did, in Notes. Press Back on the TV to leave. | | | | |
| DM-022 | **Target:** Note10+ + Living Room TV 3. Theater dim and wake. Turn on Settings → Remote behaviour → Theater mode. On the remote, don't touch for 30 s. Then tap the D-pad's Up wedge once, then tap Up again. Then open the keyboard sheet and wait 30 s. | After 30 s the phone dims to about 5 % with the dark theater palette. The first tap only brightens the screen: **no key reaches the TV**. The second tap sends Up. It never dims with a sheet or dialog open. Leaving the remote restores the phone's normal brightness. **Restore** the Theater mode setting. | | | | |
| DM-023 | **Target:** iPhone (needs the Mac build, DM-058). Does iOS restore the system brightness after `resetApplicationScreenBrightness`? Note the system brightness. Turn on Theater mode, let it dim, then leave the remote (and separately, send the app to the background while dimmed). | The phone returns to the brightness it had before the dim in both cases. **Record:** learnings → iOS brightness question; status.md → Mac checklist. **Restore** Theater mode. | | | | |
| DM-024 | **Target:** Note10+. Keep-awake. Note the phone's screen timeout (for example 30 s). Turn on Settings → Remote behaviour → Keep screen on; leave the remote open and untouched for twice the timeout. Turn it off and repeat. | On: the screen stays on while the remote is open (and turns off normally on any other screen). Off: the phone's own timeout applies. **Restore** the setting. | | | | |
| DM-025 | **Target:** Note10+ (and the iPhone). Landscape. With the remote connected, turn on auto-rotate and rotate to landscape; use the D-pad, the volume keys and the quick row; rotate back. | Landscape uses the split layout: the pad on one side, the controls in a right column, with a 16 dp end gutter. Nothing clips or overlaps; keys keep working; the connection survives the rotation. **Restore** auto-rotate. | | | | |
| DM-026 | **Target:** Note10+ + Living Room TV 3. Phase 4 haptics. With Settings → Remote behaviour → Vibrate on key press on: tap D-pad keys, a volume key and a quick-row app; swipe the touchpad. Turn the phone's Wi-Fi off and tap a key. Turn haptics off and tap a key. | One short vibration per key that reaches the TV; touchpad steps give light ticks. A refused key (not connected) gives **no** vibration, only the not-connected notice. With the setting off, nothing vibrates. **Restore** Wi-Fi and the setting. | | | | |
| DM-027 | **Target:** Note10+ and the iPhone, default font size, the narrowest screen available. Pad tab and colour key labels with the real font (Task 8.5). On the remote look at the pad tabs (Touchpad, D-pad, Numbers); switch Remote layout's row to Colour keys and look at Red, Green, Yellow, Blue. Repeat in Malay (Bahasa Melayu). | No label ends in an ellipsis or shrinks visibly at the default font size, on Roboto (Android) or SF Pro (iOS, about 5–8 % wider; "Yellow" and "Touchpad" are the tightest). **Restore** the layout and language. | | | | |

## 4. Apps and TVs

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-028 | **Target:** Note10+ with the phone's region set to Malaysia. The MY default row after clearing data. Phone Settings → Apps → the dev app → Storage → Clear data. Open the app, pair the TV again, look at the quick row and Apps → Your apps. | The default row is the MY row from `apps_v1.json`, in order: Netflix, YouTube, Viu, Prime Video, iQIYI, Disney+ Hotstar (`in.startv.hotstar.dplus`). | | | | |
| DM-029 | **Target:** Note10+ + Living Room TV 3 (and the Google TV). Which shortcut and catalogue packages open? Open each default app from the quick row, then from Apps → More apps open at least `in.startv.hotstar.dplus`, `uk.co.bbc.iplayer`, `deezer.android.tv` and `com.google.android.youtube.tvkids`. Include one app that isn't installed on the TV. | Each installed app opens on the TV (`market://launch?id=<package>`) and the app returns to the remote. For the app that isn't installed, note what the TV does (Play Store page, error or nothing). **Record:** learnings → starter apps that open, and `market://launch` for an app that isn't installed; list which packages opened and which didn't in Notes. | | | | |
| DM-030 | **Target:** Note10+ + Living Room TV 3. Raw MediaTek current-app packages. With `dart run bin/atv_cli.dart watch <host>` running, move between the TV home screen, Live TV / the input source, Settings and two apps. Then look at the app's quick row "now on TV" dot and Apps recommendations. | `watch` shows the raw packages the TV reports (for example `android`, `com.mediatek.wwtv.tvcenter`). The app never shows system packages as an app or recommendation; known packages show their catalogue name. **Record:** learnings → MediaTek current-app packages; the raw list in Notes. | | | | |
| DM-031 | **Target:** Note10+ + Living Room TV 3. Remove a TV, then pair again. Settings → Your TVs → Edit TV → Remove TV → Remove. Note whether the TV still lists or trusts the phone (TV Settings, the Android TV Remote Service connected-devices list if the TV has one). Discover the TV again and pair. | The TV is gone from Your TVs and the switcher. Pairing again asks for a new code and works; the client identity was not touched. **Record:** learnings → whether the TV still lists or trusts a removed phone. | | | | |
| DM-032 | **Target:** Note10+ + Living Room TV 3. IP→mDNS merge without pairing again. Remove the TV (as DM-031). Discovery → Enter IP address → the TV's IP → pair. Then go back to discovery and let mDNS find the same TV; open it. | The two entries merge into one TV with the announced name; it connects **without** a new pairing code and without an "identity changed" dialog (the TV presents the same key over mDNS as over the IP). Your TVs shows one entry. **Record:** learnings → mDNS same-key / merge question. | | | | |
| DM-033 | **Target:** the dev PC + Living Room TV 3 (ADB over the network enabled on the TV by the owner). The real ids of Astro GO, sooka and Tonton. Run `adb shell pm list packages` against the TV. | The package names of Astro GO, sooka and Tonton, if installed. **Record:** the ids in Notes and in status.md → "Store listing details" (they feed a later catalogue update). **Restore:** the owner turns TV ADB debugging off again if it was off. | | | | |

## 5. Settings

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-034 | **Target:** Note10+ (Android 12). Wallpaper colours. Settings → Appearance → choose the wallpaper-colours style. Change the phone's wallpaper/colour palette, return to the app. | The app's colours follow the phone's Material You palette, and the text stays readable. **Restore** the wallpaper and style. | | | | |
| DM-035 | **Target:** Note10+. Mail and browser links. Settings → Send feedback → Write email; Settings → Privacy policy; Settings → Terms of use. | The email app opens a draft to our (placeholder) address; the links open in the browser (placeholder pages for now, decision #35). The "Couldn't open the page" snackbar shows only when nothing on the phone can open the link, not when the network is down, so it isn't tested here. Discard the draft. | | | | |
| DM-036 | **Target:** Note10+. The licences page. Settings → About this app → Open-source licences; scroll; open androidtvremote2. | The licence list opens with a back arrow and a title, scrolls, and includes androidtvremote2. | | | | |
| DM-037 | **Target:** Note10+. The feedback footer. Settings → Send feedback → Write email; read the draft's footer. | The footer is English and reads "System: Android 12" (with the app version). No TV name, address or MAC. Discard the draft. | | | | |

## 6. Services (Phase 6)

Needs `env/dev.json` with real dev values (AdMob **test** ids, a dev Firebase project, RevenueCat dev keys). Rows that need a missing value are "Not run: no dev config".

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-038 | **Target:** Note10+ (free user, consent given). Test banners. Open Apps, then the Settings hub, then the remote, discovery, pairing and onboarding. **Verify the screen before each tap; never tap the banner.** | A test banner, labelled "Advertisement", shows only at the bottom of Apps and the Settings hub, at least 48 dp from any navigation control. No ad anywhere else (decision #6). | | | | |
| DM-039 | **Target:** Note10+. The Apps banner with the keyboard up (P8-R13). On Apps, tap Search apps so the keyboard opens; look at the banner; then check the AdMob console (test ids) for any covered-impression or policy flag over the next days. | Note whether the keyboard covers the banner. If AdMob flags covered impressions, Phase 9 collapses the banner while the keyboard is up (P8-R13); otherwise no change. **Record:** status.md → the P8-R13 banner item, either way. | | | | |
| DM-040 | **Target:** Note10+. The UMP form in the EEA. Set `UMP_DEBUG_GEOGRAPHY` to `eea` and `UMP_TEST_DEVICE_ID` to the id the UMP SDK logs, reinstall clean (DM-001), get to the remote. | The consent form shows once, on the first remote visit, never on onboarding, discovery or pairing. Ads load only after consent. Settings → Privacy choices → Ad privacy choices reopens the form. | | | | |
| DM-041 | **Target:** Note10+. Premium in the EEA (the P7-R9 (unverified) item). As DM-040, but as a sandbox Premium user (purchase_flow_sandbox.md), relaunch. | No consent form for the Premium user. Note whether Ad privacy choices shows in Privacy choices (UMP may not report privacy options as required before any form was shown; then the row stays hidden until the user is free). **Record:** decisions → P7-R9 note; the answer in Notes. | | | | |
| DM-042 | **Target:** Note10+ (dev Firebase project). Firebase DebugView. Run `adb shell setprop debug.firebase.analytics.app com.digitallinked.atvremote.dev`, clear data, open the app and go onboarding → discovery → remote. | DebugView shows the first screen views of the fresh install with route names, and only catalogue events; no TV name, address or MAC in any parameter. **Restore:** turn debug mode off again (set the same property back to `.none.`, as the Firebase docs describe). | | | | |
| DM-043 | **Target:** Note10+ with a build from the Play **internal** track. The review prompt (decision #43). Meet the prompt's conditions (several clean connected sessions, no connection trouble in the last 60 s). | The in-app review sheet shows once, never during pairing or right after trouble, and never again within its cooldown. | | | | |
| DM-044 | **Target:** Note10+ and iPhone (store sandbox testers). RevenueCat purchase and restore: run every row of `app/integration_test/purchase_flow_sandbox.md` and copy each result there. | All sandbox checklist rows pass, including: the paywall never flashes "You have Premium" while closing; restore brings Premium back. **Record:** a summary line here (rows passed / failed) and the full table in `purchase_flow_sandbox.md`. | | | | |
| DM-045 | **Target:** the Mac + an iOS simulator (or iPhone). The `ADMOB_APP_ID_PROD` fallback. There is no build-time guard yet: the iOS `check_admob_app_id.sh` Run Script is a Phase 9 item. `GADApplicationIdentifier` is `$(ADMOB_APP_ID)`; prod configs use `$(ADMOB_APP_ID_PROD)`, which `Debug/Release.xcconfig` set to Google's test id and a git-ignored `Secrets.xcconfig` overrides (`#include?`). **First move any existing `app/ios/Flutter/Secrets.xcconfig` aside** (rename it; never delete it). Then from `app/` run `flutter run --flavor prod -t lib/main_prod.dart -d <simulator>` for each case: **(a)** no `Secrets.xcconfig`; **(b)** a `Secrets.xcconfig` with `ADMOB_APP_ID_PROD =` (empty); **(c)** a copy of `Secrets.example.xcconfig` with its `XXXXXXXX` placeholder left in. In each case check the built `Runner.app/Info.plist` with `plutil -p`. | **(a)** The prod build succeeds, `GADApplicationIdentifier` is `ca-app-pub-3940256099942544~1458002511`, and the app launches. This is the pass condition and closes the Phase 6 Mac item. **(b)** The documented behaviour (`Secrets.example.xcconfig`) is that an empty id replaces the test id and the Mobile Ads SDK stops the app at launch. Record what happened: a launch stop confirms the known hazard and the need for the Phase 9 script, and is not a Phase 8 Fail. **(c)** iOS has no placeholder filter (Android's Gradle has one): record whether the placeholder id reaches `Info.plist` and what the SDK does. **Record:** each case in Notes; status.md → Mac checklist and the Phase 9 `check_admob_app_id.sh` item. **Restore:** remove the test files and put the owner's `Secrets.xcconfig` back exactly as it was. | | | | |
| DM-046 | **Target:** iPhone (dev build with AdMob test ids). `ensureInitialized` and UMP with test ids on iOS. Fresh install, through the ATT pre-prompt, to the remote; then Apps. | The Mobile Ads SDK initializes (no crash, no "not initialized" log), the UMP form shows in the EEA debug geography, and a test banner loads on Apps. **Record:** status.md → Mac checklist. | | | | |

## 7. Phase 7

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-047 | **Target:** Note10+ and the Android 8 emulator (API 26). Onboarding on a fresh install. Install clean; go through the three cards with Next, then Get started. Reinstall and use Skip. Relaunch. | Three cards, "Card 1 of 3" etc.; Next, Skip and Get started work; onboarding never shows again after it was finished or skipped. | | | | |
| DM-048 | **Target:** Note10+. Try demo. From onboarding tap Try demo; press keys; open the keyboard sheet; tap Leave → Leave demo. | The demo remote works with no TV: the TV preview shows "Pressed …" for each key; nothing goes to any real TV. The demo strip (now on `surface` with an outline border, Task 8.5) looks right to the owner in light and dark. Leave returns to the TV list. **Record:** the owner's view of the strip in Notes. | | | | |
| DM-049 | **Target:** Note10+. Settings from discovery. On discovery (no TV paired) open Settings; open Help, Privacy choices and Send feedback; go back. | Settings opens before pairing; every row works without a TV; Back returns to discovery; no interstitial. | | | | |
| DM-050 | **Target:** Note10+. Launcher icon and splash. Look at the home-screen icon and the app drawer; cold-start the app from the icon. | The adaptive icon is our own (not cropped, no "Google", no Android TV logo); the splash shows our mark on the right background and goes straight into the app. | | | | |
| DM-051 | **Target:** an Android 14/15 emulator or device. The themed (monochrome) icon. Turn on themed icons (Wallpaper & style → Themed icons) and look at the home screen. | The icon shows the monochrome layer in the system's tint, clearly recognisable. **Restore** the setting. | | | | |
| DM-052 | **Target:** Note10+. System "Remove animations" (Settings → Accessibility → Visibility enhancements → Remove animations) on. Open pages, sheets, dialogs and menus; press keys; toggle a Switch and a Radio (Remote behaviour, Appearance); focus a text field (Enter IP address); reorder in Edit apps. | No page, sheet, menu, press, Switch, Radio, text-field label or reorder drop visibly animates (Task 8.6: each settles within one frame). Everything still works. **Restore** the setting. | | | | |
| DM-053 | **Target:** iPhone (needs DM-058). The iOS icon set and splash. Look at the home-screen icon, Settings and Spotlight icons; cold-start the app. | Our own icon at every size, no transparency artefacts; the launch screen matches the Android splash. | | | | |
| DM-054 | **Target:** iPhone. The Local Network explainer. Fresh install; go through onboarding to discovery. | Before discovery the app shows "Allow local network access" with Continue; then iOS shows its Local Network prompt with our purpose string; after Allow, the TV is found. If denied, discovery explains how to allow it in Settings. | | | | |
| DM-055 | **Target:** iPhone. Reduce motion (Settings → Accessibility → Motion → Reduce Motion) on. Open pages, sheets and menus; type in a text field; swipe back from the left edge. | Nothing visibly animates (including the caret); the iOS edge swipe-back still works. **Restore** the setting. | | | | |

## 8. Phase 8

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-056 | **Target:** Note10+ (and the Android 8 emulator, API 26). Backup off (P8-R1, Task 8.1). With a paired TV in the app, run `adb shell bmgr backupnow com.digitallinked.atvremote.dev`; then Settings → Accounts and backup → Back up data (or Settings → System → Backup) → look for the app. | The app has no backed-up data (`allowBackup="false"`, and the extraction rules exclude every domain). **Record:** the exact `bmgr` output in Notes (no expected text is defined, so copy whatever it prints), plus what Settings shows. | | | | |
| DM-057 | **Target:** Note10+ (Android 12) as the source and a second Android 12+ phone, only if one exists; otherwise "Not run: no second phone". Device-to-device transfer (Smart Switch or the Android setup copy) of the source phone with a paired TV; open the app on the new phone. | The app starts empty on the new phone: onboarding or discovery, no saved TVs, pins, MACs or usage, and pairing works as on a fresh install (the `<device-transfer>` rules). | | | | |
| DM-058 | **Target:** the Mac. iOS builds and pods. From `app/ios` run `pod install` (deployment target iOS 15.0); from `app/` run `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` and `flutter build ios --flavor prod -t lib/main_prod.dart --no-codesign`. | Both build. In particular `AppDelegate.swift` compiles: `engineBridge.applicationRegistrar.messenger()` and `return result(FlutterMethodNotImplemented)` inside `guard` (Task 8.1, (unverified) on Windows). Pods since Phase 4 install (wakelock_plus, screen_brightness_ios, package_info_plus, url_launcher_ios, the Firebase, AdMob, ATT, RevenueCat, in_app_review and device_info_plus pods). **Record:** status.md → Mac checklist. | | | | |
| DM-059 | **Target:** the Mac with an iOS simulator (or an iPhone). The database location (Task 8.1). Run the dev build, pair a TV (or add one by IP), then run `xcrun simctl get_app_container booted com.digitallinked.atvremote.dev data` and look inside. Check the `Library/Application Support/Database` directory with `xattr -l` (look for `com.apple.metadata:com_apple_backup_excludeItem`). Quit and relaunch the app. | `Library/Application Support/Database/remotely.sqlite` exists (with any `-wal`/`-shm` beside it); nothing named `remotely.sqlite` is in `Documents/`. The directory is excluded from backup. After the relaunch the saved TV is still there (the channel resolves on every cold start). | | | | |
| DM-060 | **Target:** iPhone, only if the owner agrees to a backup and restore. Make an iCloud or computer backup with a paired TV; restore it onto the same or another iPhone; open the app. | The app has no saved TVs (the database was excluded and the keychain item is `ThisDeviceOnly`); preferences such as theme may come back (P8-R1). Pairing works as on a fresh install. **Also check** what the preferences carry (the code's known behaviour, Phase 8 final review M3): (1) the Apps row and Apps show the region's default shortcuts, not an empty list (the database is created on this phone, so the restored `apps.shortcuts_seeded` flag is ignored); (2) `settings.onboarding_complete` comes back, so the app opens on discovery, not onboarding, and our Local Network explainer is skipped; iOS shows its own Local Network prompt when discovery starts; (3) `privacy.att_preprompt_shown` comes back, so with ads configured and ATT not yet decided on this phone the system ATT prompt appears without our pre-prompt; (4) `review.launch_count` comes back and keeps counting, so the interstitial and review-prompt launch rules count the old phone's launches. **Record:** for each of (1)–(4) what you saw, in Notes; a difference from the above is input for Phase 9, not a Fail of this row. | | | | |
| DM-061 | **Target:** two iPhones, only if available. iOS Quick Start direct migration (device to device, not via iCloud) of a phone with a paired TV; open the app on the new phone. | The `Application Support/Database` directory marked `isExcludedFromBackup` is **not** carried: no saved TVs on the new phone. `faqNewPhoneA` depends on it. **If the TVs are carried, this is a release issue:** record it in status.md and stop before Phase 9 store copy. **Also check** what the preferences carry (the code's known behaviour, Phase 8 final review M3): (1) the Apps row and Apps show the region's default shortcuts, not an empty list (the database is created on this phone, so the restored `apps.shortcuts_seeded` flag is ignored); (2) `settings.onboarding_complete` comes back, so the app opens on discovery, not onboarding, and our Local Network explainer is skipped; iOS shows its own Local Network prompt when discovery starts; (3) `privacy.att_preprompt_shown` comes back, so with ads configured and ATT not yet decided on this phone the system ATT prompt appears without our pre-prompt; (4) `review.launch_count` comes back and keeps counting, so the interstitial and review-prompt launch rules count the old phone's launches. **Record:** for each of (1)–(4) what you saw, in Notes; a difference from the above is input for Phase 9, not a Fail of this row. | | | | |
| DM-062 | **Target:** the Android 8 emulator (API 26), an Android 14/15 emulator, and the Note10+. The integration flows (Task 8.2, P8-R4). From `app/` run `flutter test integration_test/discover_pair_press_key_flow_test.dart -d <device-id>` and `flutter test integration_test/demo_mode_flow_test.dart -d <device-id>` on each device (`adb devices` lists the ids). | Both flows pass on each device ("All tests passed!"). The fake TV binds 127.0.0.1 inside the app; no real TV is touched. Re-run every device here, including any emulator that a task report already used. **Record:** one line per device in Notes. | | | | |
| DM-063 | **Target:** the Mac with an iOS simulator. The same two commands as DM-062 with `-d <simulator-id>`. | Both flows pass on the simulator. | | | | |
| DM-064 | **Target:** the Windows dev PC, no device. Informational (P8-R4 (unverified)): from `app/` run `flutter test integration_test/demo_mode_flow_test.dart` with no device attached. | Note whether Flutter targets the host `flutter-tester` or refuses. Nothing depends on it (the host runner is `app/test/integration/flows_host_test.dart`). **Record:** learnings → Flutter tooling, either way. | | | | |
| DM-065 | **Target:** Note10+ + Living Room TV 3. Malay on Android (Tasks 8.12–8.13). Settings → Appearance → Language → Bahasa Melayu. Walk onboarding (reinstall or clear data), discovery, pairing, the remote and its sheets, Apps, Settings. Then set the phone's font size to maximum and look again. | The UI is Malay throughout: the translation is complete (Task 8.13), so no English string shows except the terms P8-R8 keeps in English (Remotely, Android TV, app names, Smooth Press and the like), and no blank or key-name strings. Nothing clips at 320 dp-class widths or at maximum font. "Bahasa Melayu" stays its own name in the picker. **Restore** the language and font size. | | | | |
| DM-066 | **Target:** the Mac. The Malay iOS resources (Task 8.12 Mac list a–d, f). Open `app/ios/Runner.xcworkspace` in Xcode. Check the Runner group, Project → Info → Localizations, and Runner → Build Phases → Copy Bundle Resources. Build with `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign`; run `plutil -lint` on `Runner.app/ms.lproj/InfoPlist.strings` in the product. | Xcode opens the project without a "damaged" error. `InfoPlist.strings` shows a Malay variant; Localizations lists English and Malay; Copy Bundle Resources lists `InfoPlist.strings`; the product contains `ms.lproj/InfoPlist.strings` and `plutil -lint` says OK. If Xcode rewrites `project.pbxproj` on first open, commit its normalised form (the structure test still passes). | | | | |
| DM-067 | **Target:** iPhone set to Bahasa Melayu (Settings → General → Language & Region); Living Room TV 3 for the optional part. Fresh install of the dev build; go to discovery; then (with ads configured) reach the ATT prompt. Then, still in Malay, open the iPhone's Settings app, go to Privacy & Security → Local Network, and compare what iOS shows with our copy in `onboardingLocalNetworkBody` and `troubleshootLocalNetwork` ("Seting → Privasi & Keselamatan → Rangkaian Setempat", button "Benarkan"; the TV paths in the optional part keep Android's "Tetapan"). Optional: set the TV's menus to Malay and compare its paths with `troubleshootManualIp`, `manualIpHelp` and `wolSetupBody`. | The iOS Local Network prompt and the ATT prompt show our Malay purpose strings. Our menu-path copy matches the iOS Malay UI exactly: the Settings app's name (our iOS copy says "Seting"; the TV and Android paths say "Tetapan"), "Privasi & Keselamatan", "Rangkaian Setempat", and the prompt's Allow button ("Benarkan" or otherwise). A mismatch is a copy fix, not a code Fail. **Record:** the exact iOS labels (and the TV's, if checked) in Notes, as input to DM-068. **Restore** the phone's (and TV's) language. | | | | |
| DM-068 | **Target:** the owner (or a native reviewer they choose); no device needed beyond DM-067's labels. **[owner]** Review every Malay string in `app/lib/app/l10n/app_ms.arb` and `app/ios/Runner/ms.lproj/InfoPlist.strings`. Inputs: (1) the list in Task 8.12's report (iOS and Android TV menu paths, VOL/CH/Enter kept in English, "Edit" vs "Sunting", the long page titles, the media keys, the TV-preview lines, the statuses, the wake label); (2) the 8.12 review's wording table (for example Mundur/Undur, `remoteIdentityChangedMessage`, `legacyBody`) — Task 8.13 applies part of it, so check against the current file; (3) the exact labels recorded in DM-067. | Every string is signed off or corrected. **Record:** the sign-off in `status.md` (P8-R8: required before Phase 9 store copy). | | | | |
| DM-069 | **Target:** Note10+ + Living Room TV 3. Voice Access and Switch Access while theater-dimmed (P8-R13; decides the Phase 9 code). Theater mode on, TalkBack off. Turn on Voice Access; let the remote dim; say "Tap Screen dimmed" (or use a number overlay) and then a key name. Turn Voice Access off; set up Switch Access (one switch, for example a volume key); let it dim; scan and select. | While dimmed, the wake cover is one labelled target ("Screen dimmed. Touch to brighten."); selecting it only wakes the screen; no TV key is sent through the cover. Note whether the hidden remote's keys are also offered as targets while dimmed. If they are, Phase 9 adds `ExcludeSemantics` under the cover; if not, the deferral closes. **Record:** status.md → the P8-R13 `ExcludeSemantics` item. **Restore:** turn Voice Access, Switch Access and Theater mode off. | | | | |

## 9. Screen-reader scripts

How to move:
- **TalkBack (Note10+):** swipe right = next, swipe left = previous, double-tap = activate, double-tap and hold = long press, swipe up then right (or three-finger tap) = the TalkBack menu with **Actions**. Turn TalkBack on and off with both volume keys held for 3 s (set up the shortcut first).
- **VoiceOver (iPhone):** swipe right/left = next/previous, double-tap = activate, double-tap and hold = long press, swipe up/down = custom **Actions** (rotor on Actions), two-finger scrub = back. Use the Accessibility Shortcut (triple-click the side button).

Every row: each control is read with a label and its role (button, switch, text field, tab, heading), nothing is read twice, no unlabelled "button" or empty stop, headers are announced as headings, and the order follows the screen from top to bottom. **Restore** the screen reader to off at the end of the session.

### TalkBack (Note10+)

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-070 | **Target:** Note10+, TalkBack on, fresh install. Onboarding: swipe through each card; activate Next twice, then reinstall and activate Skip; reinstall and activate Try demo. | Each card reads its title (as a heading), body and "Card n of 3", then Skip, Next (or Get started on the last card) and Try demo. Each button does what it says. | | | | |
| DM-071 | **Target:** Note10+ + Living Room TV 3, TalkBack on. Discovery: swipe through the screen; open Enter IP address; type an invalid address and Continue; close the sheet; open Settings and come back. | Order: title, Settings, the TV list (each TV read by name; long names read in full), Enter IP address, troubleshooting. The searching spinner reads "Loading…". The manual IP sheet reads its title, the "TV IP address" field and its help; the error is announced. Settings opens and Back returns. | | | | |
| DM-072 | **Target:** Note10+ + Living Room TV 3, TalkBack on. Pairing: open the TV; on the code screen, swipe through; copy a wrong 6-character code to the clipboard and activate Paste code; then enter the real code. | Reads "Enter the code shown on <TV name>", the code field (as one text field), Paste code, and the help. A wrong code announces the error and offers Get a new code / Try again. The right code pairs and lands on the remote. | | | | |
| DM-073 | **Target:** Note10+ + Living Room TV 3, TalkBack on, connected, D-pad style. The remote: swipe through the whole screen once; activate Up, Left, OK, Right and Down. | Order: TV switcher (TV name), Power, Settings, the status pill ("Connection: Connected"), the quick row (each "Open <app>"; the app now on TV reads "<app>, now on TV"), the pad tabs (Control style: Touchpad, D-pad, Numbers), the D-pad in the order **Up, Left, OK, Right, Down**, then the bottom cluster (volume, channel, Home, Back, Keyboard, …). Each activation sends one key to the TV. | | | | |
| DM-074 | **Target:** Note10+ + Living Room TV 3, TalkBack on, on the remote. Status changes: turn the phone's Wi-Fi off; wait; turn it on. While not connected, activate a D-pad key and a volume key. | The status pill announces each change by itself (Reconnecting…, Offline, then Connected) without moving focus. While not connected, the faded keys are still read with their labels and activating one announces the not-connected notice; nothing is sent. **Restore** Wi-Fi. | | | | |
| DM-075 | **Target:** Note10+ + Living Room TV 3, TalkBack on. Holds. Set the TV volume low. Double-tap and hold on Volume up for 2 s. **ASK OWNER**, then double-tap and hold on Power. | Volume up ramps while held and stops on release. Power's long press is the power action (the TV turns off; the owner turns it back on with its own remote). A plain double-tap on Power only shows the hold hint. **Restore** the volume. | | | | |
| DM-076 | **Target:** Note10+, Theater mode on. With TalkBack on, leave the remote untouched for 60 s. Then turn TalkBack off, let it dim, and turn TalkBack on with the volume-key shortcut. | With TalkBack on it never dims (decision #24). If it was already dimmed, TalkBack reads one node, "Screen dimmed. Touch to brighten.", and double-tap wakes it without sending a key (Task 8.10: one labelled node). **Restore** Theater mode. | | | | |
| DM-077 | **Target:** Note10+ + Living Room TV 3, TalkBack on. The keyboard sheet: open Keyboard; swipe through; type "abc"; activate Clear; activate Open search on TV; close the sheet. Repeat once while not connected. | Reads the sheet title "Type on your TV", the Text field, Clear, Open search on TV and the TV hint. Typing reaches the TV field. While not connected it reads "Not connected to your TV. What you type isn't sent." Closing returns focus to the remote. | | | | |
| DM-078 | **Target:** Note10+, TalkBack on. Apps and Edit apps. On Apps swipe through search, Your apps, More apps. Open Edit apps; on the second row open the TalkBack Actions menu and choose Move up; then Move down on the first row. Swipe through a row. Open More options. | Each Apps tile reads its name. In Edit apps the Actions menu offers Move up / Move down; after a move TalkBack announces "<app> moved to position n of m" and **focus stays on the moved row** (Task 8.5 (unverified)). The drag handle is **not** a separate focus stop (its "Reorder <app>" label is part of the row). The overflow reads "More options". Undo the moves. | | | | |
| DM-079 | **Target:** Note10+, TalkBack on. Your TVs and Edit TV. Swipe through Your TVs; open Edit TV; swipe through name, MAC, Pair again, Remove TV; activate Remove TV, then dismiss the dialog without removing. | Your TVs reads each TV and "In use" for the active one. Edit TV reads its title, the name field, the MAC field with its hint and help, Pair again and Remove TV. The remove dialog is announced by its title "Remove <TV name>?" and closes without removing the TV. | | | | |
| DM-080 | **Target:** Note10+, TalkBack on. The Settings hub and every sub-page: Remote layout, Remote behaviour, Apps (Edit apps), Your TVs, Appearance, Help (expand "I moved to a new phone. Where are my TVs?"), Send feedback (dialog), About this app (Open-source licences), Privacy policy, Terms. | The hub reads the section headings (Remote, App, Help and feedback, About) as headings and each row with its subtitle. Every sub-page has a back arrow read as "Back" and a title naming the page. Switches and radios read their state and change it on double-tap. The new-phone FAQ expands and reads its answer. | | | | |
| DM-081 | **Target:** Note10+, TalkBack on. Privacy choices and the paywall. Settings → Privacy choices: swipe through, toggle Share usage statistics twice. Settings → Premium: swipe through the plans and buttons, then close. | Privacy choices reads the intro, headings, both switches with state, and Ad privacy choices (when shown). The paywall reads its title, each plan (Monthly, Yearly, Lifetime) as a selectable item with its price and selected state, Continue, Restore purchases and the close button; loading reads "Loading…". **Restore** the switch. | | | | |
| DM-082 | **Target:** Note10+, TalkBack on. Dialogs and the demo strip. Open each dialog you can reach: Leave demo?, Reset your apps?, Send feedback?, Remove <TV>?, This TV's identity changed (if it can be caused). In the demo, open the keyboard sheet and try to reach the demo strip's Leave. | Each dialog is announced by its title when it opens, and focus is inside it until it closes. While a sheet or dialog is open over the demo, the demo strip's Leave is not reachable (Task 8.5). | | | | |
| DM-083 | **Target:** Note10+, TalkBack off. Maximum font size (Settings → Display → Font size and style → largest; Screen zoom as is). Look at Apps, Edit apps and the remote's quick row; scroll each. | Quick tiles use two lines; Edit apps rows stack; nothing clips, overlaps or hides a control; everything is reachable by scrolling. **Restore** the font size. | | | | |

### VoiceOver (iPhone)

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-084 | **Target:** iPhone, VoiceOver on, fresh install. Onboarding as DM-070, plus the Local Network explainer and Continue. | As DM-070; the explainer reads its title "Allow local network access" (heading), body and Continue; then the iOS prompt is read by VoiceOver. | | | | |
| DM-085 | **Target:** iPhone + Living Room TV 3, VoiceOver on. Discovery as DM-071. | As DM-071. | | | | |
| DM-086 | **Target:** iPhone + Living Room TV 3, VoiceOver on. Pairing as DM-072. | As DM-072. | | | | |
| DM-087 | **Target:** iPhone + Living Room TV 3, VoiceOver on, connected. The remote as DM-073. | As DM-073, including the D-pad order **Up, Left, OK, Right, Down**. | | | | |
| DM-088 | **Target:** iPhone + Living Room TV 3, VoiceOver on. Status changes as DM-074 (Wi-Fi off and on from Control Centre). | As DM-074. **Restore** Wi-Fi. | | | | |
| DM-089 | **Target:** iPhone + Living Room TV 3, VoiceOver on. Holds as DM-075: double-tap and hold Volume up; **ASK OWNER** before Power. | As DM-075. **Restore** the volume. | | | | |
| DM-090 | **Target:** iPhone, Theater mode on, VoiceOver on. Leave the remote untouched for 60 s; then repeat DM-076's second half with VoiceOver. | As DM-076. **Restore** Theater mode. | | | | |
| DM-091 | **Target:** iPhone + Living Room TV 3, VoiceOver on. The keyboard sheet as DM-077. | As DM-077. | | | | |
| DM-092 | **Target:** iPhone, VoiceOver on. Apps and Edit apps as DM-078, using the Actions rotor (swipe down) for Move up / Move down. | As DM-078: the announcement "<app> moved to position n of m", VoiceOver focus stays on the moved row, the drag handle is not a separate stop, "More options" is read. Undo the moves. | | | | |
| DM-093 | **Target:** iPhone, VoiceOver on. Your TVs and Edit TV as DM-079. | As DM-079. | | | | |
| DM-094 | **Target:** iPhone, VoiceOver on. Settings and every sub-page as DM-080; also a two-finger scrub to go back on each page. | As DM-080; the scrub goes back one page. | | | | |
| DM-095 | **Target:** iPhone, VoiceOver on. Privacy choices and the paywall as DM-081, plus the ATT pre-prompt on a fresh install with ads configured. | As DM-081; the pre-prompt reads its title, body and Continue, and its body scrolls at large text. **Restore** the switch. | | | | |
| DM-096 | **Target:** iPhone, VoiceOver on. Dialogs and the demo strip as DM-082. | As DM-082. | | | | |
| DM-097 | **Target:** iPhone, VoiceOver off. Maximum text size (Settings → Accessibility → Display & Text Size → Larger Text, Larger Accessibility Sizes on, slider at max). Apps, Edit apps and the quick row as DM-083. | As DM-083. **Restore** the text size. | | | | |

## 10. Performance

Ruling P8-R5. **No number is recorded until it was measured.** Raw output goes to `build/measurements/<yyyyMMdd-HHmmss>-<mode>/` (git-ignored); copy only the summary line into the results tables below. The scripts pick the one attached device, or `ANDROID_SERIAL`.

| ID | Steps | Expected | Result (Pass / Fail / Not run) | Device | Date | Notes |
|---|---|---|---|---|---|---|
| DM-098 | **Target:** Note10+, nothing else attached (or `ANDROID_SERIAL` set). Cold start. From `app/`: `flutter build apk --profile --flavor dev -t lib/main_dev.dart`, then `adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk`. From the repo root: `powershell -File tool/measure_android.ps1 -Mode startup` (10 runs by default). Repeat on another day for a second run. | The script prints every `TotalTime` and the median and writes `summary.txt`. Pass when the median is **under 1.5 s** (master plan target). **Record:** each run's median, run count and date in the cold-start table. | | | | |
| DM-099 | **Target:** Note10+. Startup trace. From the repo root: `powershell -File tool/measure_android.ps1 -Mode trace` (it runs `flutter run --profile --trace-startup` and builds the profile build itself). | The script prints `timeToFirstFrameMicros` and `timeToFirstFrameRasterizedMicros` from `app/build/start_up_info.json`. This mode has never completed a run (Task 8.3); if it fails, note how (lost connection, missing field). **Record:** both values in the cold-start table. | | | | |
| DM-100 | **Target:** Note10+ + Living Room TV 3. Key-press latency on the real TV, informational only. Film the phone and the TV together (slow-motion video if possible) while pressing D-pad Right 10 times, or use a stopwatch. | A rough tap-to-TV-reaction figure, which includes Wi-Fi and the TV's own reaction. There is no pass/fail: the < 30 ms budget is enforced by the host tests on our code path. **Record:** "stopwatch notes" in Notes only, never in a table. | | | | |
| DM-101 | **Target:** Note10+, charged above 50 %, ADB over Wi-Fi if possible (so the phone can stay unplugged). Battery, app run. Turn on Keep screen on; connect the remote to the TV. From the repo root: `powershell -File tool/measure_android.ps1 -Mode battery` (30 minutes by default). Unplug when told; leave the remote open and connected, screen on; plug back in only when the countdown ends ("Time is up"). | The script saves `dumpsys batterystats --charged` for the app and prints the "Estimated power use" section. No pass/fail threshold until the first measurement exists; the owner sets one then (P8-R5). **Record:** the app's mAh and the phone's total in the battery table. **Restore** Keep screen on. | | | | |
| DM-102 | **Target:** Note10+, same conditions as DM-101. Battery baseline. Force-stop the app, screen on (same brightness and screen timeout as DM-101), and run `powershell -File tool/measure_android.ps1 -Mode battery`. | As DM-101, with the app not running. **Record:** the baseline mAh in the battery table, next to the DM-101 run it pairs with. | | | | |

### Results: cold start (DM-098, DM-099)

| Date | Device (model, Android) | Build | Mode | Runs | Median TotalTime (ms) | timeToFirstFrameMicros | timeToFirstFrameRasterizedMicros | Notes |
|---|---|---|---|---|---|---|---|---|

### Results: battery (DM-101, DM-102)

| Date | Device (model, Android) | Run | Minutes | App mAh | Phone total mAh | Brightness / screen | Notes |
|---|---|---|---|---|---|---|---|

## Coverage

Every source item maps to the row that checks it. A source item can share a row with another when one test answers both.

### `status.md` → "Next up" item 1 (real-device run)

| Next-up bullet | Row |
|---|---|
| Setup: install the dev flavor on the Note10+ (`env/dev.json` from `env/example.json`) | DM-001 |
| Setup: discover the TV, pair, then use every control and screen | DM-002 (then sections 3–9) |
| Setup: record the answers in `learnings.md` → "Unverified protocol behaviour" | DM-004 |
| Protocol: same key on 6467/6466 (decision #11) | DM-005 |
| Protocol: ping interval (decision #10) | DM-006 |
| Protocol: does `_pickHost` get IPv4? | DM-007 |
| Protocol: reconnect time after an IP change | DM-008 |
| Remote: hold feel and volume ramp | DM-015 |
| Remote: long OK | DM-017 |
| Remote: IME replace-field (`atv_cli text`) | DM-018 |
| Remote: the Search key on Google TV | DM-021 |
| Remote: theater dim/wake | DM-022 |
| Remote: keep-awake | DM-024 |
| Remote: landscape | DM-025 |
| Apps and TVs: the MY default row after clearing data | DM-028 |
| Apps and TVs: which shortcut and catalogue packages open | DM-029 |
| Apps and TVs: raw MediaTek current-app packages | DM-030 |
| Apps and TVs: remove a TV, then re-pair | DM-031 |
| Apps and TVs: IP→mDNS merge without re-pairing | DM-032 |
| Settings: wallpaper colours on Android 12 | DM-034 |
| Settings: mail and browser links | DM-035 |
| Settings: the licences page | DM-036 |
| Accessibility: TalkBack Move up/down | DM-078 |
| Accessibility: maximum font size | DM-083 |
| Phase 6: the test banner on Apps and Settings | DM-038 |
| Phase 6: the Apps-screen banner with the keyboard up | DM-039 |
| Phase 6: the UMP form with `UMP_DEBUG_GEOGRAPHY=eea` | DM-040 |
| Phase 6: Firebase DebugView, first screen views of a fresh install | DM-042 |
| Phase 6: RevenueCat sandbox purchase and restore; no "You have Premium" flash | DM-044 |
| Phase 6: the review prompt (Play internal track only) | DM-043 |
| Phase 6: the feedback footer shows "System: Android 12" | DM-037 |
| Phase 7: onboarding on a fresh install | DM-047 |
| Phase 7: Try demo | DM-048 |
| Phase 7: Settings from discovery | DM-049 |
| Phase 7: the launcher icon and splash on the Note10+ | DM-050 |
| Phase 7: the themed (monochrome) icon on Android 13+ | DM-051 |
| Phase 7: system "Remove animations": pages, sheets, presses, menus | DM-052 |
| Phase 7: … iOS swipe-back still works | DM-055 |
| Phase 7: TalkBack through onboarding | DM-070 |
| Phase 7: maximum font size on Apps, Edit apps and the quick row | DM-083 |
| Phase 7: on a Mac/iPhone, the iOS icon set and splash | DM-053 |
| Phase 7: on a Mac/iPhone, the Local Network explainer | DM-054 |
| Phase 7: on a Mac/iPhone, reduce motion | DM-055 |
| Ask before any Power or Wake-on-LAN test | Live-testing rule 2; DM-003 (agreed per session) |

### `learnings.md` → "Unverified protocol behaviour"

| Item | Row |
|---|---|
| How a TV rejects an unpaired client cert on 6466 | DM-009 |
| The TV's ping interval (15 s idle timeout, ≤ 10 s target) | DM-006 |
| Message order (`RemoteConfigure`/`RemoteSetActive`/`RemoteStart`/volume/current app) | DM-010 |
| IME counters for `sendText`; emoji cursor position | DM-019 |
| Same key on 6467 and 6466 | DM-005 |
| `watch` runs 5 minutes with no drop | DM-011 |
| Phase 4: `RemoteImeBatchEdit` with the whole field replaces the TV field | DM-018 |
| Phase 4: the TV's backspace count if `appendOnly` is ever used | DM-020 |
| Phase 4: does a `startLong` volume key auto-repeat; what if `endLong` never arrives | DM-016 |
| Phase 4: long-press OK behaviour | DM-017 |
| Phase 4: what `KEYCODE_SEARCH` (84) does on Google TV | DM-021 |
| Phase 4: does the 6466 socket survive TV standby | DM-012 |
| Phase 4: does Wake-on-LAN wake the MediaTek TV; how soon `reconnect()` finds it | DM-013 |
| Phase 4: which starter apps open via `market://launch?id=` | DM-029 |
| Phase 4: does iOS restore system brightness after `resetApplicationScreenBrightness` | DM-023 |
| Phase 5: `market://launch?id=` for an app that isn't installed | DM-029 |
| Phase 5: which packages a MediaTek TV reports as the current app | DM-030 |
| Phase 5: does the TV still list or trust a phone removed in the app | DM-031 |
| Phase 5: does a TV found by mDNS present the same key as when paired by IP | DM-032 |
| Phase 5: which starter/catalogue packages open (incl. the four named) | DM-029 |
| Phase 5: the real ids of Astro GO, sooka and Tonton | DM-033 |

### Phase 8 tasks 8.1–8.12 (`progress.md` and the task reports)

| Source | Item | Row |
|---|---|---|
| 8.1 report, P8-C1 | [Mac] the Swift storage channel compiles (`engineBridge.applicationRegistrar.messenger()`, `FlutterMethodNotImplemented` in `guard`) | DM-058 |
| 8.1 report | [Mac] the database is in `Library/Application Support/Database`, nothing in `Documents/` | DM-059 |
| 8.1 report | [Mac] the `Database` directory reports `isExcludedFromBackup` | DM-059 |
| 8.1 report | [Mac] saved TVs survive a relaunch (the channel resolves on every cold start) | DM-059 |
| 8.1 report, P8-R1 | [device] `bmgr backupnow` → Settings shows no app data | DM-056 |
| 8.1 report | [device] Android 12+ device-to-device transfer brings no TVs | DM-057 |
| 8.1 review (Review Focus 1, P8-R1) | a restored iPhone keeps prefs but no TVs | DM-060 |
| 8.1 fix round minor 5, controller addendum | iOS Quick Start direct migration skips the excluded directory | DM-061 |
| 8.2 report, P8-R4 | (unverified) flows on the Note10+ (and other Android devices) | DM-062 |
| 8.2 report, P8-R4 | (unverified) flows on iOS (simulator needs the Mac) | DM-063 |
| 8.2 report, P8-R4 | (unverified) `flutter test integration_test` on Windows targeting `flutter-tester` | DM-064 |
| 8.3 report, P8-R5 | [device] cold start, `startup` mode, target < 1.5 s | DM-098 |
| 8.3 report | (unverified) `trace` mode never completed a run | DM-099 |
| 8.3 report, P8-R5 | (unverified) [device] `battery` mode (app run and baseline; operator plugs back in) | DM-101, DM-102 |
| P8-R5 | key-press latency on the real network (informational) | DM-100 |
| 8.4 report concern 4, P8-R6 | TalkBack and VoiceOver passes of the audited screens | DM-070–DM-097 |
| 8.4 report concern 2 | faded (0.85) controls still announce and act while not connected | DM-074, DM-088 |
| 8.5 report concern 1, 8.5 review | (unverified) TalkBack/VoiceOver keep focus on the moved row | DM-078, DM-092 |
| 8.5 report concern 2, 8.5 review | real-font glance at the pad tabs and colour keys (Roboto and SF Pro) | DM-027 |
| 8.5 report concern 4 | the demo strip's new look (`surface` + outline) for the owner | DM-048 |
| 8.5 | the drag handle isn't a focus stop; More options; spinner "Loading…"; dialogs named by title; demo strip inert under a modal | DM-071, DM-078, DM-081, DM-082 (and VoiceOver twins) |
| 8.6 report concern 4 | (unverified) Remove animations on the Note10+ (Switch, Radio, decorator, reorder) | DM-052 |
| 8.10 report and review, P8-R13 | (unverified) the wake cover with TalkBack | DM-076, DM-090 |
| 8.10 report and review, P8-R13 | (unverified) the wake cover with Switch Access and Voice Access; decides `ExcludeSemantics` | DM-069 |
| 8.12 report concern 2 (a)–(d), (f) | [Mac] Xcode opens the project; Malay variant; Copy Bundle Resources; `ms.lproj` in the product; `plutil -lint`; commit a normalised pbxproj | DM-066 |
| 8.12 report concern 2 (e) | [owner][device] the Local Network (and ATT) prompt in Malay | DM-067 |
| 8.12 review Minor 1, 8.12 report | [owner][device] the iOS Malay menu path ("Seting" vs "Tetapan", Privasi & Keselamatan → Rangkaian Setempat, Benarkan) matches the real iOS UI; optionally the TV's Malay menu paths | DM-067 |
| 8.12 report and review, P8-R8 | [owner] review of the 225 Malay strings and the purpose strings, including the 8.12 review's wording table | DM-068 |
| 8.12, P8-R8 | Malay on an Android device | DM-065 |
| P8-R13 | the Apps banner with the keyboard up, if AdMob flags covered impressions | DM-039 |

### Other device-run items folded in

| Source | Item | Row |
|---|---|---|
| status.md "Blocked" → Mac | `pod install` at iOS 15.0; the iOS flavor builds; the new pods since Phase 4 | DM-058 |
| status.md "Blocked" → Mac | iOS restores system brightness after Theater mode | DM-023 |
| status.md "Blocked" → Mac | the empty `ADMOB_APP_ID_PROD` guard works | DM-045 |
| status.md "Blocked" → Mac | `ensureInitialized` runs; UMP works with test ids | DM-046 |
| status.md "Blocked" → Apple entitlement | the multicast entitlement for Wake-on-LAN on iOS | DM-014 |
| status.md "Blocked" → Store listing details | the real ids of Astro GO, sooka, Tonton | DM-033 |
| P7-R9 (unverified) | Premium in the EEA: no form; is Ad privacy choices shown | DM-041 |
| Task 8.14 brief §3 | the Phase 4 haptics | DM-026 |
| Task 8.14 brief §6 | a link to `purchase_flow_sandbox.md` | DM-044 |
| Memory rules for live testing | verify before each tap; never Power without asking; restore settings; connect via the dropdown then tap the TV | Live-testing rules 1–4 |

### Not turned into rows

| Source | Item | Why |
|---|---|---|
| 8.8 report | riverpod_generator hashes may differ between LF and CRLF checkouts | A tooling question, not a device check; progress.md sends it to the phase-exit chore. |
| 8.10 report | the D-pad's wedges are 22 dp deep in a 100 dp box | A design note; the layout never gives the pad less than 160 dp, so no device can show it. |
| P8-R13 | the predictive-back test's private Flutter class name; Android 13 `localeConfig` | Rechecked at the next Flutter bump and in Phase 9; not device checks. |
