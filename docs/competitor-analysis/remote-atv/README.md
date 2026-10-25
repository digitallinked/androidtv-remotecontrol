# Competitor teardown: Remote ATV (Simha Software)

| | |
|---|---|
| App name | **Remote ATV** (store title "Remote for Android TV") |
| Package | `tech.simha.androidtvremote` |
| Version analysed | 6.1.0 (versionCode 45), installed from Google Play, last updated 2026-10-17 |
| Developer | Simha Software — `support@simhasoftware.com`, web `simha.tech` / `simhasoftware.com` |
| iOS sibling | App Store id `1668755298` ("remote-for-android-tv") |
| Analysed on | 2026-10-25, Samsung Galaxy Note10+ (SM-N975F, Android 12), over ADB Wi-Fi |
| Method | Static analysis with REA (JADX, Dart AOT inspector, Flutter build ID), APK/asset inspection, string-pool extraction from `libapp.so`, live screenshots |

Evidence labels used below: **[observed]** = seen on the device screen, **[static]** = read from the shipped APK, **[inferred]** = a reasonable conclusion from static evidence that was not exercised at runtime.

---

## 1. Summary

- A **Flutter** app; every screen is drawn by Dart code compiled into `libapp.so`. The Android/Java layer is only the Flutter embedding plus third-party SDKs (`MainActivity` is empty).
- Talks to the TV using Google's **Android TV Remote v2 protocol** (mDNS discovery, TLS, protobuf, on-screen passcode pairing), including **voice streaming** and **app-link launch**.
- Core UX: **touchpad-first remote** with a swappable number pad, a scrolling **app-launcher row** fed by a built-in catalogue of ~100 TV apps, and a compact bottom control cluster.
- Business model: **ads first** (AdMob banner + interstitial, mediated through Meta, DT Exchange/Fyber, InMobi, Unity, plus Yandex), with a **RevenueCat "Premium" subscription that only removes ads**.
- Heavy **analytics and remote control of behaviour**: Firebase Analytics, Crashlytics, Remote Config + A/B testing, Yandex AppMetrica, key-press counting, review prompts and forced updates.
- Protected with **Google Play Integrity / PairIP** (anti-tamper wrapper and licence check) and **Dart obfuscation**.

---

## 2. Architecture

### 2.1 Build and runtime [static]

| Item | Value |
|---|---|
| Framework | Flutter (embedding v2), Dart AOT. `libapp.so` 8.4 MB, `libflutter.so` 11.2 MB |
| Dart snapshot hash | `97ff04a728735e6b6b098bdf983faaba` (maps to a Dart SDK release through an external table; not looked up) |
| libflutter build-id | `131eeda3d8b650ac635d8e496936981e3f591338`, built with Android clang 18.0.1 |
| Renderer | Impeller **disabled** (`io.flutter.embedding.android.EnableImpeller=false`), so it uses the legacy Skia renderer |
| Obfuscation | Dart built with `--obfuscate`. Class and library names are stripped; only string literals survive |
| SDK levels | minSdk 24 (Android 7.0), targetSdk 36, compileSdk 36 |
| ABIs shipped | arm64-v8a split (also `libpairipcore.so`, `libdatastore_shared_counter.so`) |
| Splits | base + ABI + density (xxhdpi) + language splits (en, in, ms, zh seen on device) |
| Protection | `com.pairip.application.Application` wraps the app, `com.pairip.licensecheck.LicenseActivity`, encrypted VM-code assets (17 random-named ~140 KB files in `assets/`), `CHECK_LICENSE` permission |
| Activity model | Single `MainActivity`: `singleTop`, **portrait only**, `adjustResize`, handles all config changes itself |
| Own native/Java code | None. `tech.simha.androidtvremote.MainActivity` has only a constructor |

### 2.2 Flutter plugins (from `GeneratedPluginRegistrant`) [static]

| Area | Plugins |
|---|---|
| TV discovery and network | `nsd_android` (mDNS), `connectivity_plus` |
| Voice | `flutter_sound` (mic capture for voice search), `permission_handler` |
| Ads | `google_mobile_ads`, `gma_mediation_dtexchange`, `gma_mediation_inmobi`, `gma_mediation_meta`, `gma_mediation_unity` |
| Purchases | `purchases_flutter` (RevenueCat) |
| Firebase | `firebase_core`, `firebase_analytics`, `firebase_crashlytics`, `firebase_remote_config` |
| Device UX | `wakelock_plus` (Keep Screen Awake), `screen_brightness_android` (Theater Mode dimming), `in_app_review`, `share_plus`, `url_launcher`, `webview_flutter_android` |
| Storage | `shared_preferences`, `sqflite`, `path_provider` (plus pure-Dart **Hive**) |
| Info | `device_info_plus`, `package_info_plus` |

### 2.3 Pure-Dart libraries of note (from `NOTICES.Z` and strings) [static]

- **Crypto and pairing:** `pointycastle`, `basic_utils`, `asn1lib`, `encrypt`. Together these generate the RSA client certificate used for TV pairing.
- **Protocol:** `protobuf` (GeneratedMessage, CodedBufferReader strings).
- **Storage:** `hive`, `sqflite`, `shared_preferences`.
- **Reactive/state:** `rxdart`, `equatable`, `nested` (a dependency of `provider`) and a `Provider<` string, so Provider-style state is likely. No Riverpod, Bloc, GetX or go_router strings.
- **UI kit:** `flutter_screenutil` (responsive sizing), `flutter_svg`, `cached_network_image` + `flutter_cache_manager` + `octo_image` (Play Store app icons), `shimmer` (loading placeholders), `flutter_spinkit` (spinners), `avatar_glow` (pulsing mic animation), `marquee` (scrolling long names), `auto_size_text`, `fading_edge_scrollview`, `flutter_staggered_grid_view`, `spring_animation`, `cupertino_icons`.
- **Other:** `upgrader` (update dialogs), `logger`, `uuid`, `synchronized`, `html` (parses HTML-formatted FAQ text), `intl`, `app_tracking_transparency` (iOS code path).

The full list is in [data/dependencies.txt](data/dependencies.txt).

### 2.4 Inferred module map [inferred]

The Dart code is obfuscated, so this map is reconstructed from strings, assets and plugins:

```
App shell (MaterialApp, dark theme, OpenSans, screenutil)
├── Onboarding ............ layout picker, settings picker, GDPR consent
├── Discovery ............. nsd (mDNS) → _androidtvremote2._tcp / legacy _androidtvremote._tcp
├── Pairing ............... RSA cert (pointycastle/basic_utils) → TLS → Pairing* protobuf → passcode
├── Remote session ........ RemoteMessage protobuf: KeyInject, ImeKeyInject, SetVolumeLevel,
│                           AppLinkLaunch, SetActive, Configure, Voice{Begin,Payload,End}
├── Remote UI ............. touchpad | D-pad | number pad, quick-access row, bottom cluster
├── Application manager ... default catalogue + user shortcuts + usage-based suggestions (sqflite/Hive)
├── Devices ............... saved TVs, nickname, delete, certificate handling, auto-connect
├── Settings .............. layout, behaviour toggles, FAQ, legal, share, rate, feedback
├── Monetisation .......... AdManager (banner + interstitial, rate-limited) + RevenueCat paywall
├── Analytics ............. Firebase Analytics + AppMetrica events, key counters
└── Remote Config ......... ad limits, banner config, min app version, feature flags
```

---

## 3. TV connection and protocol [static]

- **Discovery:** mDNS service `_androidtvremote2._tcp.` (current Android TV Remote Service) **and** `_androidtvremote._tcp.` (legacy v1).
  - Events `first_android_tv_with_old_app_found` and `tried_connecting_android_tv_with_old_app` track TVs that only expose the old service.
  - Users are told: *"This device is using an older version of Android TV Remote Service, please update the service on your television."*
  - The in-app update guide reads: *"Follow these steps to update:-" → "Open Google Play Store on your TV" → "Search for Android TV Remote Service" → "Click on Update" → "After update, Restart your TV"*.
- **Pairing:** messages `pairingRequest`, `pairingRequestAck`, `pairingOption`, `pairingSecret`, `PairingSecretAck`.
  - UI copy: *"Enter passcode displayed on your television."*, *"Passcode not generated?"*, *"Passcode verification failed"*, "Regenerate passcode" (localised).
  - Client certificates are generated on the phone (X509 and PEM strings).
  - Certificate housekeeping events: `tv_certi_deleted_bcz_unknown` and `tv_certi_not_deleted_bcz_autoconnect` (the cert is deleted on a `certificate_unknown` TLS error).
- **Remote channel messages:** `RemoteMessage`, `RemoteConfigure`, `remoteSetActive`, `RemoteKeyInject`, `remoteImeKeyInject` (text typing), `remoteSetVolumeLevel` (shows the TV volume number on the rocker), `remoteAppLinkLaunchRequest` (opens TV apps by link), `RemoteVoiceBegin`, `RemoteVoicePayload`, `RemoteVoiceEnd` (mic).
- **Keycodes:** about 290 `KEYCODE_*` constants, listed in [data/protocol-and-keycodes.txt](data/protocol-and-keycodes.txt).
- **TV metadata collected:** `tv_brand`, `tv_model`, `tv_os_version`, `tv_app_version` (version of the TV remote service).
- **Error copy:**
  - *"TV services didn't start as expected, please restart your TV and try again."*
  - *"Please ensure your television is switched on and connect to the same Wi-Fi network."*
  - *"Please connect to the Wi-Fi network on this device."*
  - *"Connection failed"*
- **Keyboard and search copy:**
  - *"Search expects TV keyboard to be opened already."*
  - *"The application running on your television does not support search."*
  - *"Your language might not be fully supported by the application running on your television, please try in English language."*
- **Power:** an FAQ entry, *"Why can't I turn on my TV using the app?"*, sets the expectation that power-on over Wi-Fi isn't reliable.
- **Compatibility:** an FAQ entry, *"Why is the app not working on my Samsung or LG Smart TV?"*. Only Android TV / Google TV is supported.

---

## 4. Features

### 4.1 Main remote screen [observed] — `screenshots/10_main.png` (disconnected), `screenshots/10b_main_connected.png` (connected)

The status dot next to the TV name is **red when disconnected and green when connected**. The banner ad rotates creatives (SmartMaster, ShopeePay, Pinduoduo, Jobstreet / WorldFirst "Ads served by Meta").

**Connection behaviour (live test with a MediaTek-based Android TV)** [observed]:

- On launch the app **sometimes auto-reconnects and sometimes stays red**. The picker can still show the TV with a "Connected" badge while the remote is disconnected (`screenshots/11a_device_picker_connected_badge.png`), so the badge really means "paired/saved".
- To actually reconnect: tap the ▼ dropdown, then **tap the TV row**. It connected within about 1 s (green dot, volume label shows the TV level, "VOL 0").
- The connection **dropped by itself** a few minutes later (after voice + Home + navigation commands) and didn't recover until the TV was tapped again. **No visible reconnect indicator or toast** appears when it drops.
- Tapping an app tile while disconnected shows a **blue snackbar**: "Please ensure your television is switched on and connect to the same Wi-Fi network." with ✕ (`screenshots/15_snackbar_not_connected.png`).
- The mute icon reflects the TV's mute state (speaker-with-× when muted). The volume number stayed at 0 after + / − on this TV (the TV likely routes audio to an external device, or doesn't report level changes).

Top to bottom:

1. **Banner ad** (AdMob, full width, about 145 px tall) pinned under the status bar.
2. **Header row:** ⚙ Settings (left), **TV name with status dot and ▼** (opens the TV picker), ⏻ **Power** (red, right).
3. **Quick-access row:** horizontally scrolling app tiles (Netflix, YouTube, Viu, Prime Video, iQIYI…) with labels. Tap to launch the app on the TV.
4. **Main pad:** large rounded **touchpad** (swipe to navigate, tap to select), with a 2-page indicator. Page 2 is the **number pad**.
5. **Bottom cluster:**
   - **VOL rocker** (+ / − with the live TV volume level, e.g. "VOL 0")
   - **CH rocker** (˄ / ˅)
   - a 2×3 grid between the rockers: ⌨ Keyboard, ⌂ Home, ⠿ Number-pad toggle (becomes ✥ D-pad/touchpad toggle when the number pad is showing), 🔇 Mute, 🎤 Voice, ↩ Back

### 4.2 Number pad [observed] — `screenshots/12_numpad.png`

A 3×4 grid of 1–9, then **TV**, 0, **Menu**. TV and Menu are outlined keys; digits are filled.

### 4.3 TV picker [observed] — `screenshots/11_device_picker.png`

- A full-screen sheet over a blurred, colourful background.
- Title "Televisions", with a card per TV (icon, nickname, MAC address, **Connected** badge).
- A scanning page indicator, and the hint *"Please ensure your television is switched on and connect to the same Wi-Fi network."*
- Other strings: "Choose a TV", "Search Again", "No connected device" (with `no_connected_device.svg`), "Device connected", "Delete this device?", "Give a nickname to this device.", "Device nickname".

### 4.4 Keyboard, search and voice [observed + static]

- **Keyboard** (`screenshots/13_keyboard_sheet.png`): a full-screen sheet over the blurred colour backdrop.
  - ✕ close (top right); an info line "ⓘ Search expects TV keyboard to be opened already."; a large "Start typing…" field with a TV-search icon; the phone's soft keyboard opens automatically.
  - Text goes to the TV through `remoteImeKeyInject`. Strings also offer "Search Web" and "Scan text" (Android Live Text).
- **Voice** (`screenshots/14_voice_listening.png`): **tap to toggle**. The mic button turns red with a pulsing glow (`avatar_glow`) and Android's mic indicator appears.
  - Audio is captured with `flutter_sound` and streamed to the TV (`RemoteVoiceBegin/Payload/End`).
  - In the test it kept recording for about 40 s until tapped again (no silence auto-stop observed), and a quick second tap was ignored (debounced).
  - If the permission is missing it is requested at first use (permission was already granted on the test phone).

### 4.5 Application launcher / quick launch [observed + static]

- **Manage applications** (`screenshots/04_manage_apps.png`): drag-handle (≡) reorderable list with an icon, name and red ⊗ delete on each row; ⊕ add; the ⋮ overflow holds a single **"Reset"** item with a history icon (`screenshots/04b_manage_apps_reset_menu.png`).
- **Add application screen** (`screenshots/04a_add_application.png`), titled "Manage applications":
  - **"Recommendations — (Frequently used apps are shown as recommendations)"**: a list of pill rows built from apps the **TV itself reports as recently used**. On the test TV (a MediaTek-based Android TV) it showed raw package names: `com.mediatek.wwtv.mediaplayer`, `android`, `com.mediatek.wwtv.tvcenter`. It doesn't filter system packages or map them to friendly names or icons when they aren't in the catalogue — a UX gap.
  - **"Default apps"**: catalogue apps not yet added; showed "No suggestions to show" because all region defaults were already on the list.
- **Add / customise:** *"Customize quick launch"* — *"Personalize your application quick launch shortcut by selecting a background color, icon, and name."* There are 8 bundled custom icons (`basketball, leaf, live, play, reel, stadium, sun, wave`). *"Please enter a name for the application shortcut."*
- **Dialogs:** *"Add this application?"*, *"Are you sure you want to delete this application?"*, *"Are you sure you want to reset applications to defaults?"*, *"Cannot find application to delete"*, *"is not installed on your television."*, *"You can tap the above icon to launch the application on your television."*
- **Suggestions:** *"Frequently used apps are shown as recommendations"*, "Recommendations", "No recommendations to show", "No suggestions to show", "No applications to show", "Default apps", "Shortcuts".
  - Events/keys: `suggested_application_added`, `customized_application_added`, `user_application_suggestion_keys`, `deleted_default_applications`, `showing_default_apps_reason`, `application_priorities`.
- **Catalogue:** about 100 TV apps by package name, with Play Store icon URLs (`play-lh.googleusercontent.com/...=w240-h480`). Coverage is global, with Malaysian/SEA apps (Viu, iQIYI, WeTV, Viki, iFlix, Vidio, Vivamax), Indian (Hotstar), Middle East (Shahid, OSN, Jawwy), Korean (Wavve/pooq, TVING, Coupang Play), Japanese (TVer), European (Canal+, TF1, M6, RTL, Joyn, Sky, Viaplay, Ziggo, Swisscom, Videoland, RaiPlay, RTVE, Movistar+), Russian (ivi, Kinopoisk, More.tv, Rutube, MTS, START, Smotrim, VK) and Turkish (Exxen, puhutv, TOD, tabii). Full list: [data/tv-app-catalogue.txt](data/tv-app-catalogue.txt).
- **Default order seen on device:** Netflix, YouTube, Viu, Prime Video, iQIYI Video, JioHotstar, WeTV, Viki, iFlix, HBO Max. The defaults appear to be **region-aware** (Malaysian user) [inferred].
- **System packages referenced:** TV launcher, Leanback launcher, `com.google.android.tv.remote.service`, Chromecast built-in (`mediashell`), screensaver (`backdrop`, `dreamx`), `com.android.tv.settings`. These are probably used to filter out system apps or to check the remote-service version [inferred].

### 4.6 Navigation and quick-access variants [observed]

Under Settings → Remote layout, the row under the header can be:

- **Applications** (default): scrolling app tiles
- **Colored Buttons**: four wide pill buttons, red `#CC5954`, green `#5DB86E`, yellow `#DBDD4F`, blue `#5272D6` (`screenshots/16_main_dpad_colored_buttons.png`)
- **Media Buttons**: five round `#353535` keys: ⏮ ⏪ ⏯ ⏩ ⏭ (`screenshots/17_main_dpad_media_buttons.png`)
- **None**: "Size of the navigation will increase". The pad grows into the freed space (`screenshots/18_main_dpad_no_quick_access.png`, `02a_remote_layout_none_option.png`)

**D-pad navigation** replaces the touchpad with a large circle (`#232323`–`#2E2E2E`) with a thin **purple→blue gradient ring** (`#68429F` top → `#3B5591` bottom), white chevrons at the 4 compass points, and a centre OK disc ringed with the same gradient. The number pad remains on page 2.

**Theater Mode** (tested): after roughly 30–60 s with no touches, the app sets its **window brightness override to 0.01** (≈1 %), dimming the phone to minimum. The first touch restores brightness and is not consumed (the tap still acted). **Keep Screen Awake** is implemented as a window keep-screen-on flag (`SCREEN_BRIGHT_WAKE_LOCK` held by WindowManager for the app).

### 4.7 Unreleased / dormant feature: TV picture settings [static, inferred]

`assets/images/` ships `picture_mode`, `picture_options`, `color_temperature`, `hdr`, `brightness`, `light_sensor`, `power_savings`, `power_savings_high`, `power_savings_low`, `power_savings_off`, `rocket` and `workspace_premium` SVGs. **No matching UI strings** were found, so this is likely an upcoming picture-settings panel, possibly premium-gated, or one switched off by Remote Config.

---

## 5. Settings (complete tree) [observed]

`screenshots/01_settings.png`, `02_remote_layout.png`, `03_remote_behavior.png`, `05_connected_devices.png`, `06_faq.png`, `07_legal.png`

```
Settings (✕ close)
├─ Remote
│  ├─ Remote layout
│  │   ├─ Navigation:   ◉ Touchpad "Swipe based touchpad, quick and convenient."   (default)
│  │   │                ○ D-pad    "Tap based control, as found on physical remote."
│  │   └─ Quick access: ◉ Applications "Easily open applications installed on your television"
│  │                    ○ Colored Buttons "Red, Green, Yellow and Blue buttons"
│  │                    ○ Media Buttons "Media previous, rewind, play/pause, fast forward and next buttons"
│  │                    ○ None
│  ├─ Remote behavior
│  │   ├─ Haptic Feedback  [on]  "A light vibration feedback when remote buttons are pressed"
│  │   ├─ Smooth Press     [on]  "Try to mimic physical remote natural behavior when you Press and Hold volume, channel and navigation keys"
│  │   ├─ Keep Screen Awake[on]  "Your screen will stay on while using the remote so you don't need to keep unlocking it"
│  │   └─ Theater Mode     [off] "Dims the screen when idle to save battery and reduce glare while watching TV"
│  ├─ Manage applications   (reorder / add ⊕ / delete ⊗ / ⋮ reset)
│  └─ Connected devices     (TV icon, nickname, MAC, [Edit] → full page: TV's own name as header
│                            e.g. "Living Room TV 3", "Device nickname" text field, red [Delete] + gradient [Update])
└─ Application
   ├─ FAQ's
   │   ├─ Connectivity & Compatibility
   │   │   ├─ Why is the app not working on my Samsung or LG Smart TV?
   │   │   ├─ I am unable to find my Android Smart TV in the list
   │   │   ├─ How do I add an application of my choice as a shortcut?
   │   │   ├─ Why can't I turn on my TV using the app?
   │   │   └─ I'm unable to connect to my TV. Should I buy the premium version to fix it?
   │   └─ Purchase & Subscription
   │       ├─ I purchased the premium version but still see ads. What should I do?
   │       └─ How do I request a refund for the premium version?
   ├─ Share with friends    (Play / App Store links with utm_campaign=share_with_friends)
   ├─ Rate and Review       (in_app_review)
   ├─ Feedback              (white system AlertDialog "Do you want to open the mail app to write feedback?" NO / YES
   │                         → mailto, subject "Imp: Feedback for Remote for Android TV - …"; `screenshots/19_feedback_dialog.png`)
   ├─ Legal → Privacy policy (simhasoftware.com/remote-atv/privacy), Terms (…/remote-atv/terms)
   └─ Activate premium      (→ paywall; after purchase: "Your active plans", "Manage purchases", "Purchased on", "Expires on")
```

**FAQ answers (all 7)** [observed, `screenshots/06a–06e`; Q2 and Q6 from strings]. The FAQ is an accordion: one item open at a time, a pink ˄ chevron when open, and divider lines above and below the open item.

| # | Question | Answer (verbatim) |
|---|---|---|
| 1 | Why is the app not working on my Samsung or LG Smart TV? | "Please note that some Samsung and LG TVs run on custom operating systems (like Tizen or webOS) instead of Android/Google TV OS. Our app is currently compatible only with Android-based Smart TVs. If your TV uses Android OS and you're still facing issues, please contact us at support@simhasoftware.com — our team is ready to help you troubleshoot and resolve the issue." |
| 2 | I am unable to find my Android Smart TV in the list | "Please visit https://www.simha.tech/troubleshoot-device-not-found for detailed troubleshooting steps." |
| 3 | How do I add an application of my choice as a shortcut? | "Go to Settings → Manage Applications → Add (button in the top-right corner). You will see a list of frequently used applications as recommendations — simply tap on the application you want to add." |
| 4 | Why can't I turn on my TV using the app? | "Some Android TV devices — especially Android TV Boxes — may fully shut down all background services when turned off. This includes the services required for the app to communicate with your device. Because of this, the app may not be able to turn the TV on if it has been powered off completely. This is a limitation of the TV/device itself, not the app. Once your device is turned on manually, the app should work as expected." |
| 5 | I'm unable to connect to my TV. Should I buy the premium version to fix it? | "No — if the app is not working for you in the free version, the premium version will not resolve the issue. We strongly recommend trying the app with your TV before purchasing. The premium version only removes ads and does not affect compatibility or core functionality." |
| 6 | I purchased the premium version but still see ads. What should I do? | "If you've purchased the premium version but are still seeing ads, please go to the Purchase screen in the app and tap "Restore Purchases". This should unlock your premium access. If the problem persists, please reach out to us at support@simhasoftware.com" |
| 7 | How do I request a refund for the premium version? | "We're sorry to hear you'd like a refund. As purchases are handled by the respective app stores, you will need to request a refund directly through Google Play Store. You can request a refund directly by visiting: https://support.google.com/googleplay/answer/1557489" + (from strings) follow the instructions to submit the request, and contact support@simhasoftware.com if there are problems. |

**Onboarding** [static]: *"Please select your preferred layout"*, *"Please select your preferred settings"*, *"You can also change it later from settings"* (event `layout_selection_showed`).

**Update prompts** [static, `upgrader`]: *"Update App?"*, *"Would you like to update it now?"*, "UPDATE NOW", "LATER", "Release Notes", "Current Version"; events `force_update_dialog_shown`, `optional_update_dialog_shown`, `update_button_press`, `later_update_button_press`, `ignore_update_button_press`; Remote Config `min_app_version`.

---

## 6. Monetisation

### 6.1 Ads [static + observed]

| Item | Detail |
|---|---|
| Primary SDK | Google Mobile Ads (AdMob), app id `ca-app-pub-5506461561907650~7791002717`, with `OPTIMIZE_INITIALIZATION` and `OPTIMIZE_AD_LOADING` on |
| Mediation (Flutter + Android adapters) | **Meta Audience Network** (`FacebookMediationAdapter`), **DT Exchange / Fyber** (`FyberMediationAdapter`), **InMobi** (`InMobiMediationAdapter`), **Unity Ads** (`UnityMediationAdapter`) |
| Extra network | **Yandex Mobile Ads** via its AdMob adapter (`com.admob.mobileads`), plus Yandex **AppMetrica** |
| Formats | **Banner** at the top of the remote [observed]; **Interstitial** [static: `interstitial_ad_impression`, "Unable to load interstitial ad"] |
| Banner control | Adaptive sizing ("AdSizeHelper… falling back to STANDARD BANNER"), `banner_ad_configuration`, `dispose_banner_when_inactive`, `pauseBannerAd` |
| Live ad units (from logcat) | Banner `ca-app-pub-5506461561907650/1430653667`; Meta Audience Network placement `769491521107527_887916092598402` (Meta frequently wins: "Ads served by Meta"); DT Exchange bids observed ("No Ad Found" / network errors). Banner refreshes about every 2–3 min. No interstitial appeared during ~25 min of use |
| Interstitial throttling | `interstitial_ads_timestamps`, `last_ad_shown_time`, `ad_difference_time`, `ad_expiry_seconds`, `ad_limits_data_v2`, `load_ad_buffer_keys`. Likely shown after N key presses within time windows tuned from Remote Config [inferred] |
| Consent | Google UMP. *"We care about your privacy and data security, we keep this app free by showing ads, Can we use your data to tailor ads for you?"* / *"You can change your choice anytime in the app settings, Our partners will collect data and use a unique identifier on your device to show you ads."* Shown after a key-press threshold (`consent_keys_threshold`, "falling back to 20"); keys `gdpr_consent`, `gdpr_ad_consent_type`, `consent_prompted`, event `change_privacy_pref_clicked` |
| Ad identifiers | `AD_ID`, Privacy Sandbox `ACCESS_ADSERVICES_TOPICS / ATTRIBUTION / AD_ID`, install referrer |

### 6.2 Premium subscription (RevenueCat) [observed + static]

- **Value proposition:** ad removal only. *"Upgrade to premium for an Ad-Free Experience"*, *"Premium access — Now enjoy uninterrupted and ad-free experience"*.
- **Paywall** (`screenshots/09_paywall.png`): award icon, title, subtitle, "Choose your plan", a horizontal carousel of plan cards with a radio button, a purple→blue **gradient "Continue"** button and a "Restore purchases" link.
- **Prices seen (Malaysia)** — four cards in a horizontal carousel (`screenshots/09_paywall.png`, `09a_paywall_12m_lifetime.png`):

  | Plan | Price | Billing text |
  |---|---|---|
  | 3 Months (pre-selected) | RM 18.99 | "Billed every 3 months, until cancelled" |
  | 6 Months | RM 27.99 | "Billed every 6 months, until cancelled" |
  | 12 Months | RM 42.99 | "Billed every 12 months, until cancelled" |
  | Lifetime | RM 91.99 | "One time payment" |

  Pricing anchors on the cheapest short plan; lifetime ≈ 2.1× the annual price.
- **Store product id** seen in logs: `premium_lifetime` (RevenueCat first queries it as `subs` → PRODUCT_NOT_FOUND, then as an in-app product).
- **UX bug:** closing the paywall with ✕ returns straight to the **remote screen**, not to Settings where it was opened. A second tap in the same spot then hits the banner ad.
- **RevenueCat packages:** `$rc_three_month`, `$rc_six_month`, `$rc_annual`, `$rc_lifetime`. There's also non-renewing copy (*"3/6/12 Months access to premium features, This plan will not auto renew"*) and labels MONTH / YEAR / LIFETIME / "Auto renew", so plan sets are switched by Remote Config / RevenueCat offerings (`renewing_and_lifetime`) [inferred].
- **Stores:** Google Play Billing 8.3.0 and **Amazon Appstore IAP** (`com.amazon.device.iap`, RevenueCat Amazon proxy), so there's probably an Amazon build too.
- A RevenueCat public Google SDK key (`goog_…`) is embedded (normal for RevenueCat; redacted here).
- **Events:** `purchase_continue_press`, `restore_purchases_press`, `purchase_restored`, `user_cancelled_purchase`, `manage_purchases_press`, `subscription_info`, `no_of_subscription_failure_checks`, `entitlementVerificationMode`.
- **Error copy:** *"We were unable to complete your purchase"*, *"No active subscription"*.

---

## 7. Analytics, telemetry and growth

| SDK | Use |
|---|---|
| Firebase Analytics | screen views + custom events |
| Firebase Crashlytics | crash and non-fatal reporting |
| Firebase Remote Config + A/B Testing (`abt`) | feature flags, ad limits, min version, plan sets |
| Firebase Sessions / Installations | session tracking |
| Yandex AppMetrica | second analytics stack (comes with Yandex ads) |

**Custom events and keys** (full list in [data/keys-events-config.txt](data/keys-events-config.txt)):

- **Usage:** `key_press`, `total_key_press`, `total_key_counts`, `lifetime_key_counts`, `review_key_counts`, `last_logged_key_count`
- **TV lifecycle:** `first_android_tv_found`, `new_android_tv_connected`, `first_connection`, `last_device_uuid`, `tv_brand/model/os_version/app_version`
- **Preferences:** `navigation_choice`, `quick_access_choice`, `haptic_feedback_choice`, `smooth_press_choice`, `screen_wake_choice`, `theater_mode_choice`, `show_apps`, `show_colored_buttons`, `show_media_buttons`, `num_nav_icon`, `wakelock_off_by_default`
- **Growth:** `request_review`, `review_prompted`, `review_requested`, `rate_and_review_clicked`, `share_with_friends_clicked`, `share_with_friends_url_android/ios`, `feedback_clicked`, `terms_of_use_press`
- **Review strategy:** the in-app review is requested after enough key presses (`key_counts_for_review`) [inferred]; *"cancelling_review_request_for_ad"* means a review prompt is skipped if an ad is about to show.

---

## 8. UI / UX design system [observed]

| Token | Value |
|---|---|
| Theme | Dark only (no light theme), Material 3 colour roles |
| Background | `#1E1E1E` |
| Surface / cards / plan cards | `#282828` |
| Touchpad surface | `#2E2E2E` |
| Buttons (round keys, rockers, number keys) | `#353535` / `#343434` |
| Outlined keys (TV, Menu) | fill `#1E1E1E`, border `#353535` |
| Primary text | `#FFFFFF`; section headers `#A9A9A9`; descriptions `#565656` (low contrast) |
| Accent / selection / links | blue `#4994EC` (radio buttons, selected card border, "Restore purchases", not-connected snackbar) |
| Toggle on | green `#66CA65` (iOS-style switch), off track `#3A3A3D` |
| Power / status | red `#E15241` power icon, `#EB645E` disconnected dot |
| CTA | linear gradient `#7842B7` → `#4E78DA` |
| Typography | OpenSans Light 300 / Regular 400 / SemiBold 600, generous letter-spacing |
| Icons | custom SVG set (`assets/images/*.svg`) + Material Icons + Cupertino Icons |
| Shape | large radii (cards ~16dp, touchpad ~40dp, round 72dp keys, pill rockers) |
| Layout | portrait only, `flutter_screenutil` scaling, no tablet/landscape layout |
| Motion | shimmer placeholders, spinkit loaders, glow on mic, marquee for long names, spring animations |
| Languages | about 15 locales including English, Malay, Indonesian, Chinese, Dutch, Danish, Norwegian, Swedish, Finnish, German, French, Spanish (+ es_419), Portuguese, Italian, Filipino, Turkish |

**UX strengths**

- Touchpad-first with a one-tap swap to the number pad. Thumb-reachable bottom cluster; volume level shown live from the TV.
- Very fast app launching through a reorderable, customisable shortcut row with usage-based suggestions and region-aware defaults.
- Clear behaviour toggles with plain-language descriptions (Smooth Press, Theater Mode).
- An honest FAQ that says premium won't fix compatibility, which cuts refund requests.
- Guided recovery for the legacy remote service (step-by-step update instructions).

**UX weaknesses**

- The banner ad occupies the top of the main screen, right above the TV picker and power button.
- Navigation is inconsistent: Settings uses ✕ at the root but ← on sub-pages, and every sub-page header says just "Settings".
- Contradictory status: the main screen showed a red (disconnected) dot while the picker showed "Connected".
- The number-pad / navigation toggle icon changes meaning depending on the current page, which makes it hard to discover.
- Low-contrast description text (`#565656` on `#1E1E1E`).
- The add-app "Recommendations" list shows raw TV package names (`android`, `com.mediatek.wwtv.tvcenter`) with no icons, friendly names or system-app filtering.
- Back navigation from settings sub-pages drops straight to the live remote. One extra Back press lands on an active touchpad, where a stray tap sends a command to the TV.
- The banner ad sits exactly where Settings and the paywall put their ✕ close button, so a double-tap on ✕ easily becomes an accidental ad click.
- The connection silently drops and needs a manual "tap the TV in the picker" to recover. The "Connected" badge in the picker is misleading.
- The Feedback confirmation is a white stock AlertDialog that breaks the dark theme.
- No light theme, no landscape or tablet layout, no widgets or notification controls (no foreground remote notification found).

---

## 9. Permissions and components [static]

| Permission | Purpose |
|---|---|
| INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE | TV discovery (mDNS multicast) and connection |
| RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, `Manifest.permission.CAPTURE_AUDIO_OUTPUT` (malformed name) | voice search |
| BLUETOOTH | declared; no Bluetooth remote feature found |
| WAKE_LOCK, FOREGROUND_SERVICE | keep screen awake, WorkManager |
| AD_ID, ACCESS_ADSERVICES_* , BIND_GET_INSTALL_REFERRER_SERVICE | ads and attribution |
| com.android.vending.BILLING, CHECK_LICENSE | purchases, PairIP licence check |

**Other manifest notes:**

- Package-visibility `<queries>` cover mailto/sms/tel/https/market, Custom Tabs, Facebook app, billing services, `MediaBrowserService` and Digital Turbine Ignite.
- An exported `PreloadInfoContentProvider` (AppMetrica).
- WorkManager, Room and Picasso come in through ad SDKs.

---

## 10. Gaps and next steps

| Item | Status |
|---|---|
| Behaviour while connected to a TV | **Done**: connect flow, keyboard sheet, voice, number pad, volume, Home, touchpad swipes, layout variants, Theater Mode. What the TV itself displayed was not recorded (only the phone side) |
| FAQ answers | **Done**: all 7 recorded |
| Add-application screen, ⋮ menu | **Done** |
| Edit-device page, all plan cards, D-pad / Colored / Media / None layouts | **Done** |
| Banner ad unit id | **Done** (from logcat). Interstitial unit id and trigger thresholds still unknown (Remote Config) |
| Share sheet | Opens the Android system chooser (not screenshotted because it shows personal contacts) |
| Internal Dart class structure | Not recoverable (obfuscated) |
| Network traffic (analytics and ad endpoints) | Not captured |

---

## Appendix A — Screenshots

| File | Screen |
|---|---|
| `screenshots/01_settings.png` | Settings root |
| `screenshots/02_remote_layout.png` | Remote layout (navigation + quick access) |
| `screenshots/03_remote_behavior.png` | Remote behaviour toggles |
| `screenshots/04_manage_apps.png` | Manage applications |
| `screenshots/04a_add_application.png` | Add application (recommendations from TV + default apps) |
| `screenshots/04b_manage_apps_reset_menu.png` | ⋮ menu → Reset |
| `screenshots/05_connected_devices.png` | Connected devices |
| `screenshots/06_faq.png` | FAQ list |
| `screenshots/06a…06e_faq_*.png` | FAQ answers expanded |
| `screenshots/07_legal.png` | Legal |
| `screenshots/09_paywall.png` | Premium paywall |
| `screenshots/02a_remote_layout_none_option.png` | Remote layout, scrolled (None option) |
| `screenshots/05a_edit_device.png` | Edit device page |
| `screenshots/09a_paywall_12m_lifetime.png` | Paywall, 12-month and lifetime cards |
| `screenshots/10_main.png` | Main remote (touchpad) with banner ad, disconnected |
| `screenshots/10b_main_connected.png` | Main remote, connected (green dot) |
| `screenshots/11a_device_picker_connected_badge.png` | Picker showing "Connected" while actually disconnected |
| `screenshots/13_keyboard_sheet.png` | Keyboard / search sheet |
| `screenshots/14_voice_listening.png` | Voice listening state |
| `screenshots/15_snackbar_not_connected.png` | Not-connected snackbar |
| `screenshots/16_main_dpad_colored_buttons.png` | D-pad + Colored Buttons |
| `screenshots/17_main_dpad_media_buttons.png` | D-pad + Media Buttons |
| `screenshots/18_main_dpad_no_quick_access.png` | D-pad + None |
| `screenshots/19_feedback_dialog.png` | Feedback confirmation dialog |
| `screenshots/11_device_picker.png` | TV picker sheet |
| `screenshots/12_numpad.png` | Main remote (number pad) |

## Appendix B — Data files

- [data/dependencies.txt](data/dependencies.txt): Dart/Flutter packages from NOTICES
- [data/tv-app-catalogue.txt](data/tv-app-catalogue.txt): built-in TV app catalogue
- [data/keys-events-config.txt](data/keys-events-config.txt): analytics events, storage and Remote Config keys
- [data/protocol-and-keycodes.txt](data/protocol-and-keycodes.txt): protocol messages, mDNS types, keycodes

## Appendix C — Artifact identities

| Artifact | SHA-256 |
|---|---|
| base.apk | `65d012f7aca9b2c0e8abf8d88e22623d9fcd141555497cc64b50352556f5b29a` |
| split_config.arm64_v8a.apk | `36e67b9ba316f9782e7f5803016c6878e8a29f8555f10c69bed2cba3991443b5` |
| libapp.so | `fe43c9e6d1ac7e6794697f97cfcaa93fbb3bfcd4b6317d11dee696bc395c11bd` |
| libflutter.so | `61838891a9d405d954df6a64ec5217b16ed0d6fdaafce44fe1fb0170d79b7849` |

Key REA evidence IDs: package `ev_b180d544e628…`, Dart AOT `ev_184ad66e2f7d…`, Flutter build `ev_89e9306878df…`, plugin registrant `ev_5e04a77b65e2…`, mediation adapters `ev_034b1b01a7fd…`.
