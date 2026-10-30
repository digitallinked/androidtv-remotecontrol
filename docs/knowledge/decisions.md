# Decisions log

Newest first. Each entry: date, decision, why, and what would make us revisit it. Never delete an entry; mark it `SUPERSEDED by #N` instead.

---

### #48 — 2026-10-30 — Phase 7 pins and branding pipeline
- flutter_launcher_icons 0.14.4 and flutter_native_splash 2.4.8 (dev dependencies, exact). The icon is our own painter mark (ring, centre dot, four triangles on #3D5AFE); `test/branding/` renders every master and `brand_icon.svg`.
- `tool/brand.ps1` / `brand.sh`: step 1 is `flutter test --update-goldens test/branding` with **no tag filter** (amends P7-R6), so the svg regenerates; then the two generators. `adaptive_icon_foreground_inset: 0`; the mark radius 26.07 of 33 units keeps clear of every launcher mask.
- `*.svg text eol=lf` in `.gitattributes`: the svg test compares bytes.
- **Revisit:** when the app name or brand colour is final (owner).

### #47 — 2026-10-30 — Reduce motion means no visible motion (P7-R4, P7-C1, P7-C5–C7)
- Under `disableAnimations` (MediaQuery or platform flag) nothing visible animates: pages, sheets, dialogs, snackbars, onboarding paging, the status pill, the touchpad, menus (`AnimationStyle.noAnimation`), the iOS caret (`AppMotion.cursorFadesOf`).
- `ReduceMotionTheme` sets `NoSplash`, a transparent `highlightColor`, and transparent pressed overlays with `animationDuration: Duration.zero` on filled, text, outlined, elevated, icon and segmented button themes. Hover and focus overlays stay.
- Widget-level colours must not derive their own overlay: use `foregroundOnly(c)` instead of `styleFrom(foregroundColor:)`, and no `IconButton(color:)`.
- An invisible (transparent) ink ticker is accepted. iOS swipe-back under reduce motion is a static Cupertino paint that doesn't track the finger (P7-C2), accepted.
- **Deferred to Phase 8:** Radio and Switch animations; the InputDecorator focus transition (167 ms; about 8 ms under the platform flag).
- **Revisit:** if a Flutter release honours `disableAnimations` in ink or the decorator.

### #46 — 2026-10-30 — Phase 7 product rulings (P7-R1–R12, P7-C2–C4)
- **Onboarding:** 3 cards with Skip, Get started and Try demo, shown once. The storage write is never awaited, so a failing store can't trap the user. iOS-only Local Network explainer before discovery.
- **Navigation:** every route builds through `appPage(state, child)` → `MaterialPage` (go_router 18.1.1 doesn't detect Flutter 3.44.1's MaterialApp, so builders became `NoTransitionPage`). Settings is reachable from discovery and the no-TV remote as `/settings?from=setup`: no interstitial when leaving it; the hub banner rules are unchanged (amends P7-R7 wording; allowed by #6/#41).
- **Update gate** reads `kAppVersion` on the first frame (no flash). **Premium skips the UMP form** on launch (P7-R9, amends #41); an unreadable Premium is treated as free; ads never load without consent; Ad privacy choices stays reachable.
- **Apps:** search ranks name prefix, then word prefix, then contains, then region, then catalogue order (`nameMatchRank`, `rankedByName`). The now-on-TV dot has a contrasting ring (≥ 4.5:1 on every fill).
- **Large text:** quick tiles grow to at most 112 dp with 2-line names above 1.3× (`AppSizes.largeTextGrowth`). Edit apps rows stack only above 1.3× **and** with a name column under 160 dp (P7-C3, amends P7-R11). The pad's 200 dp minimum still wins over the quick row on short phones (P7-C4).
- **Haptics:** one heavy haptic, only when something is actually sent (amends #22); touchpad reach updates from the up position.
- **Revisit:** after the real-device run and first store feedback.

### #45 — 2026-10-29 — Interface↔adapter import pairs are the accepted cycle shape
- Each SDK has an interface file that holds the provider and builds its adapter. The adapter imports the interface. The pairs are `consent_service`↔`ump_consent_service`, `tracking_service`↔`att_tracking_service`, `ads_service`↔`google_mobile_ads_sdk`, `app_config`↔`firebase_remote_config_source`, `purchase_service`↔`revenuecat_purchase_service`/`unavailable_purchase_service` and `review_prompter`↔`in_app_review_requester`.
- `test/platform/vendor_imports_test.dart` keeps each SDK import in exactly one adapter file, so vendor types never leak.
- **Revisit:** if a pair grows a third member or the cycle check becomes a CI gate.

### #44 — 2026-10-29 — Phase 6 pins
- firebase_core 5.1.0, firebase_analytics 13.0.1, firebase_crashlytics 6.0.1, firebase_remote_config 7.0.1;
- google_mobile_ads 9.2.0, app_tracking_transparency 2.0.7, purchases_flutter 10.18.1;
- in_app_review 2.0.12, device_info_plus 13.3.0.
- Gradle plugins: google-services 4.5.0 and firebase-crashlytics 3.0.8 (AGP 9.0.1). All pins are exact.

### #43 — 2026-10-29 — Review prompt (P6-R13, P6-C11, P6-C12)
- `in_app_review` is asked at most once per install, and only when all of these hold:
  - cumulative key presses ≥ `review_prompt_min_key_presses` (Remote Config, default 150);
  - launch count ≥ 2;
  - not the demo;
  - a non-demo session has just become `connected` at the start of a session (a recovery doesn't count);
  - there was no connection trouble or not-connected notice in the previous 60 s.
- The press count is kept in memory and written every 10 presses, on pause and on dispose.
- `ReviewRequester.request()` returns `bool`. The flag and the `review_prompt_shown` event are written only on `true`, so a failed request marks nothing.
- No prompt on a launch where the UMP consent form is pending or was shown (`ConsentResult.formShown`). While consent is pending, the prompt is deferred and every condition is re-checked once consent is gathered.
- The launch count is written, not awaited, after the initial route resolves, so "Try again" never counts twice.

### #42 — 2026-10-29 — Premium, paywall and colour styles (P6-R10–R12, P6-C6, P6-C7, P6-C10)
- RevenueCat Premium. The entitlement is cached, so offline Premium users never see an ad flash. `known` settles within 5 s.
- The paywall is one scroll view with plans in the order monthly → yearly → lifetime. Restore shows "Restoring your purchases…". After a purchase the plans stay on screen through the close (no "You have Premium" flash), and the screen is never left busy.
- Four colour styles (standard plus three Premium) with the P6-R12 hex values, pinned by tests. A free user tapping a locked style opens the paywall. The real `App` applies the style only for Premium users.
- The Ember light accent is 4.39:1 on `surfaceRaised` and is kept. Standard light is already 4.42:1 there, and both pass 3:1 for icons and large text. Phase 8 audits any accent body text across all styles.

### #41 — 2026-10-29 — Consent, ATT and ads (P6-R8, P6-R9, P6-C8, P6-C9, P6-C13)
- Ads wait for the consent step, which only the remote screen starts. `AdsController.ready()` waits for consent and never shows the UMP form. The form step has no timeout, so a hanging form means no ads that launch.
- The ATT decision comes before the SDK starts. An undetermined or unreadable ATT status means no SDK start.
- The pre-prompt is shown at most once per install. If iOS never showed its question (it shows nothing while the app is inactive), iOS is asked again on the next banner visit, with no second pre-prompt.
- "Ad privacy choices" is shown whenever UMP requires it, Premium included.
- Banners only on `/apps` and the `/settings` hub, labelled "Advertisement", with a 48 dp clearance from navigation controls. A banner SDK that throws leaves an empty slot. Interstitials are paced by Remote Config and are off by default.
- A malformed prod AdMob app id fails the Gradle build.
- Don't create the UMP IDFA explainer message, because our pre-prompt owns the ATT flow. Publish the UMP GDPR message before Firebase is enabled in prod.
- **Revisit:** whether a cached-Premium user should skip the UMP form (Phase 7 ruling).

### #40 — 2026-10-29 — Remote Config (P6-R7)
- Fetched values apply from the next launch. Config is activated within 5 s at startup, then sealed.
- Ranges: interstitial interval 60 s–7 d; review presses 1–10000 (default 150). `paywall_variant` must be a safe token, checked with the analytics guard's string rules.

### #39 — 2026-10-29 — Privacy: analytics, crash reports, buffering (P6-R4–R6)
- Choices are tri-state. Effective sharing = `choice ?? (UMP region == notRequired)`. UMP ad consent never counts as analytics consent, and Analytics `ad_*` consent is always denied.
- Events wait in a 50-event buffer while undecided. They are flushed on yes and dropped on no. Sends wait until the collection switch has reached the platform.
- Debug builds never send crash reports.
- Every crash report goes through the scrubber. Its rule order is documented in `crash_scrubber.dart`: PEM, UUID, base64, URIs, then the whole TV segment of `/pair/` and `/devices/` route paths (everything `Uri.encodeComponent` can produce, so a bracketed name never partly leaks), then saved names, mDNS hosts, `manual:` entries, email, MAC, IPv6 (valid forms plus a four-group fallback) and IPv4, hex runs, and pairing codes. Over-scrubbing is accepted; a partial name is not.
- The analytics guard allows only the exact P6-R6 event catalogue. No TV names, IPs, MACs, codes, typed text, custom packages or route paths are ever sent. Turning analytics off disables native collection even if the consent call fails.
- Remote Config fetches regardless of the choices: the kill switches need it, and it carries only the Firebase Installation ID.

### #38 — 2026-10-29 — Phase 6 config and startup order (P6-R2, P6-R3)
- 9 env keys come from `--dart-define-from-file=env/<flavor>.json`. Only `env/example.json` is committed.
- Native Firebase config is git-ignored per flavor, and the Gradle plugins apply only when that flavor's file exists. AdMob app ids come from `app/android/secrets.properties` and `app/ios/Flutter/Secrets.xcconfig` (both git-ignored), with test-id fallbacks for non-prod builds.
- iOS floor 15.0 (Firebase iOS SDK 13); minSdk 24.
- Startup order:
  1. Firebase (bounded at 4.5 s)
  2. Remote Config activate (5 s, then sealed)
  3. the first frame
  4. UMP silent update and RevenueCat, in parallel
  5. the consent form on `/remote`
  6. the ATT pre-prompt and system prompt
  7. the ads SDK
  8. the banner

  `StartupGate` is bounded at 20 s and retries on the next tap after a failed build. Premium is known before any ad.

### #37 — 2026-10-27 — Phase 5 package pins
- url_launcher 6.3.3 and package_info_plus 10.2.2 (both behind injectable providers: `linkOpenerProvider`, `appInfoProvider`). Android manifest `<queries>` adds SENDTO `mailto` and VIEW `https`; no iOS `LSApplicationQueriesSchemes` needed.
- `pumpRouterApp` supplies safe defaults for every platform-backed provider (flavor, app info, link opener, screen services, haptics, …); new platform providers get a default there.

### #36 — 2026-10-27 — Keyboard hardening (P5-R13)
- Append-only mode advances its baseline per confirmed step (no double deletes after a partial failure); grapheme-cluster deletes. `kImeTextMode` stays `replaceField` until the device run answers.

### #35 — 2026-10-27 — Help, About, legal and feedback (P5-R12)
- Privacy/terms links and the support address in `AppLinks` are **placeholders** (`example.com`, `support@example.com`) until the owner supplies real ones (before any store upload). Links open externally.
- Feedback mail is hand-encoded (`Uri(queryParameters:)` writes spaces as `+`) with a fixed English footer: app version/build and OS only — never TV names, IPs, MACs or pins.
- The androidtvremote2 Apache-2.0 licence ships as a byte-identical asset registered once at bootstrap.

### #34 — 2026-10-27 — Settings structure (P5-R11)
- Hub (sections Remote / App / Help & feedback / About) + Appearance, Remote layout (live preview of `RemoteBody`, no session), Remote behaviour (the Phase 4 toggles), Help, About. `RadioGroup` choice groups are labelled semantics containers. Language names are endonyms in data; the wallpaper-colour switch shows only where supported.
- **Theme changes apply instantly** (`themeAnimationDuration: Duration.zero`, ruling P5-C4): `AnimatedTheme` ignores reduce-motion and a 200 ms `ColorScheme` lerp adds nothing; theater mode has its own theme and is unaffected.
- A navigation style chosen in Settings reaches the already-open remote (body re-keyed only when the stored style differs from what the pad shows).

### #33 — 2026-10-27 — Connect-flow carry-overs (P5-R10)
- Tapping a paired TV in discovery writes the fresh `lastHost`. `toDiscoveredTv()` carries the announced name; the nickname stays separate. "Pair again" re-resolves the host (≤ 4 s, then the saved host).
- A TV added by IP is merged into its mDNS entry in one transaction; the stored pin moves with the row unchanged and the merge never overwrites an existing row, so a different TV at the old address still triggers "identity changed" (decision #14).

### #32 — 2026-10-27 — Your TVs and device removal (P5-R9)
- The TV label is read from saved devices everywhere, so a rename shows at once without rebuilding the session.
- One `MacAddressField` (Edit TV and the Wake-on-LAN sheet); validation `macFieldError` (empty is valid in Edit TV, invalid in the setup sheet; an over-long paste shows an error).
- Removing a TV deletes its row (pin, MAC, nickname) but **never the client identity**. Removing the TV in use clears the target and rebuilds the session, so the remote moves to the next saved TV or "No TV selected".

### #31 — 2026-10-27 — Apps screen (P5-R7, P5-C5)
- Launch from Apps then `go('/remote')` (the remote's State survives); "More apps" from the catalogue launch without being added. A refused launch shows the single not-connected notice.
- The **All apps** tile is the main way into `/apps`; it is pinned at the end of the quick row outside the scroller (always visible) and shown in the layout preview.

### #30 — 2026-10-27 — Usage tracking privacy (P5-R6)
- The current app reported by the TV is counted on the phone only (package, count, last seen) — never for the demo TV, never logged or sent; system packages are filtered when read. Recommendations exclude system apps and existing shortcuts. Caveat: Android Auto Backup is on by default and copies the DB off the phone — decide `allowBackup` in Phase 8.

### #29 — 2026-10-27 — Shortcuts (P5-R5, P5-R8)
- Global, one per package, dense positions. Seeded once from the region's default row (`seedIfEmpty` + a stored flag; emptying the list never re-seeds). Region = first phone locale with a country code, read at seeding and on Reset (Reset asks first and replaces the whole list).
- Edit apps: reorder by the handle (plus the framework's own localised Move actions — ours removed to avoid duplicates); remove with Undo (re-inserted at its original index into the *current* list; a second removal replaces the first Undo); suggestions exclude listed apps; custom shortcuts pick a monogram colour and a generic icon.

### #28 — 2026-10-27 — App catalogue (P5-R4)
- Our own `apps_v1.json`: 55 apps and 8 region default rows (`*`, MY, SG, ID, IN, US, GB, AU), < 40 KB (bigger strings are decoded on an isolate that never finishes in `testWidgets`). The schema is **closed**: `version` 1; app keys `package`/`name`/`regions`/`launchLink`; unknown keys, duplicate packages and repeated packages in a row are rejected. No icons, icon URLs or brand colours — monograms or generic icons; launch via `market://launch?id=`.
- `com.wbd.stream` is named "HBO Max" (its Play title). Four packages are kept although Play web returns 404 (geo/TV-only listings; device run). No verified ids yet for Astro GO, sooka, Tonton or mewatch.
- `search(query, {region})` ranks region-available apps first. `catalogueProvider` and `catalogueSourceProvider` use `retry: noRetry`.

### #27 — 2026-10-27 — Navigation and the banner slot (P5-R1..R3)
- Routes `/apps` (+ `/apps/manage`), `/devices` (+ `/devices/:serviceName`), `/settings` (+ appearance, remote-layout, remote-behaviour, help, about). Ways in: the remote's Settings button, the All apps tile, "Manage TVs" in the switcher, and the Settings rows. `pageTitleDevices` = "Your TVs".
- `BannerSlot` (empty until Phase 6) sits only on `/apps` and the `/settings` hub, in `bottomNavigationBar`, with 48 dp scroll clearance and no bottom-anchored controls (decision #6).
- All Phase 5 strings landed in one task (P5-R1); the fix wave added four load/remove error strings (P5-C6).

### #26 — 2026-10-27 — Phase 4 package pins
- wakelock_plus 1.8.2 (uses `FLAG_KEEP_SCREEN_ON`; pulls package_info_plus 10.2.2), screen_brightness 2.1.11 (app-window brightness only). No new Android permissions. iOS needs `pod install` on a Mac.

### #25 — 2026-10-27 — Quick access before the app catalogue (SUPERSEDED by #28/#29: `kStarterApps` and `quickAccessAppsProvider` were replaced by the catalogue and `shortcutsProvider` in Phase 5)
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
