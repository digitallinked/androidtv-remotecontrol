# Remote Config kill-switch checklist

The owner uses this page in two ways: to prove the switches work before launch (device-matrix row DM-109), and to flip one for real when something goes wrong after launch. Claude never changes a console setting (Ruling P9-R1).

## How a change reaches a phone

The rules come from the code (`app/lib/core/config/app_config.dart`) and decision #40 (Ruling P6-R7). Learn them before you flip anything.

- **Values fetched in one launch apply from the next launch.** At startup the app activates the values it fetched last time, then starts a download for the launch after this one. Nothing changes mid-session.
- **The fetch is rate-limited.** The prod flavor fetches at most once an hour, and the dev flavor once every 5 minutes. A launch within that window reuses the last download.
- **So a phone needs two launches after you publish, with the first one at least an hour after its previous fetch (prod).** A user who opens the app once a week sees your change about a week later. A kill switch is fast for active users and slow for everyone else. It isn't instant.
- **"Launch" means a cold start.** Swipe the app away from the recent-apps list, then open it again. Returning from the background is not a launch.
- **A value of the wrong type falls back to the code default for that key alone.** A boolean published as the text `"no"` therefore behaves as if you never set it. Publish booleans as the **Boolean** type, and versions as **String**.
- **Without Firebase** (a build with `FIREBASE_ENABLED` false, or Firebase failing at startup) the app uses the code defaults below and no switch reaches it.
- **One prod project serves both platforms.** A parameter applies to the Android and the iOS app at once, unless you add a condition such as "Platform = iOS" to its value.

## The code's defaults

What the app uses until a configuration is activated, by key:

| Key | Type to publish | Code default | What it does |
|---|---|---|---|
| `ads_banner_enabled` | Boolean | `true` | The banner kill switch: `false` removes the banner from Apps and the Settings hub. |
| `ads_interstitial_enabled` | Boolean | `false` | Interstitials are off unless this is `true` (decision #41). |
| `ads_interstitial_min_interval_s` | Number | `600` | The least time between two interstitials, 60 s to 7 days. |
| `review_prompt_min_key_presses` | Number | `150` | Key presses before the review prompt, 1 to 10000. |
| `paywall_variant` | String | `a` | Which paywall variant to show. |
| `min_supported_version` | String | `1.0.0` | Versions below it get the "Update required" screen. |
| `catalogue_version` | Number | `1` | The app catalogue version the config asks for. |

An excerpt of `app/lib/core/config/app_config.dart`: the key constants, then `defaultsMap` (a test keeps the `defaultsMap` block equal to the code; the constants are copied for reading):

```dart
  static const _adsBanner = 'ads_banner_enabled';
  static const _adsInterstitial = 'ads_interstitial_enabled';
  static const _interstitialInterval = 'ads_interstitial_min_interval_s';
  static const _reviewKeyPresses = 'review_prompt_min_key_presses';
  static const _paywallVariant = 'paywall_variant';
  static const _minSupportedVersion = 'min_supported_version';
  static const _catalogueVersion = 'catalogue_version';

  static const Map<String, Object> defaultsMap = {
    _adsBanner: true,
    _adsInterstitial: false,
    _interstitialInterval: 600,
    _reviewKeyPresses: 150,
    _paywallVariant: 'a',
    _minSupportedVersion: '1.0.0',
    _catalogueVersion: 1,
  };
```

**Before the first production rollout,** create all seven parameters in the prod project's Remote Config with exactly these defaults and types, and publish. Then the switches already exist on the day you need one, and the console shows what is live.

## The console steps (every key)

1. Open the [Firebase console](https://console.firebase.google.com/), choose the project (dev for a test, prod for real), then **Remote Config** in the left menu. Google moves this menu between groups such as "Run" and "Engage"; search for "Remote Config" if it isn't where you expect.
2. On the **Parameters** tab, open the parameter (pencil icon). If it doesn't exist yet, use **Add parameter** with the exact key, the type from the table and the code default.
3. Change the **Default value** (or the value of one condition), then **Save**.
4. Select **Publish changes** and confirm. Nothing reaches a phone until you publish.
5. Note the time and the new version number from the **Version history** tab. To undo a bad publish, pick the earlier version there and roll back to it, then wait for two launches again.

## `ads_banner_enabled`

Code default: `true`. Turning it to `false` is the banner kill switch: use it when a banner misbehaves (covers a control, an ad-policy warning, a crash in the ads SDK).

| Step | What to do | Expected |
|---|---|---|
| Test target | Dev project with a dev build (5-minute fetch), then once more on the prod project with the internal-track build (1-hour fetch). For the dev build, `app/env/dev.json` needs `FIREBASE_ENABLED: true` and the dev Firebase files (store-release skill). | |
| Before | As a free user (not Premium), with ads allowed by consent, open Apps and then the Settings hub. | Each shows the "Advertisement" band with a test banner (dev) or a live banner (prod). |
| Change | Console steps 1–4: set `ads_banner_enabled` to `false`, publish. | |
| Launch once (fetch) | Wait out the fetch window (dev 5 minutes, prod 1 hour since the last launch), cold-start the app, open Apps. | The banner is **still there**: this launch only downloads the new value. |
| Launch again (applied) | Cold-start again, open Apps and the Settings hub. | No banner and no "Advertisement" band on either screen; the space collapses. Nothing else changes: the remote, Premium and the interstitial switch behave as before. |
| Restore | Set `ads_banner_enabled` back to `true`, publish, then launch twice the same way. | The banner is back on the second launch. |

## `ads_interstitial_enabled`

Code default: `false`. Interstitials ship switched off (decision #41). Setting this to `false` is the kill switch if they were ever turned on; the test below turns them on in the dev project to prove the switch both ways.

When on, an interstitial can show only when **all** of these hold (`app/lib/core/ads/interstitials.dart`): the build has an interstitial unit id (dev builds always use Google's test unit; a **prod** build needs `ADMOB_INTERSTITIAL_ANDROID`/`_IOS` in `app/env/prod.json` at build time, so switching this on for a build without ids does nothing), the app has launched at least twice, the user isn't Premium and isn't in the demo, consent allows ads, on iOS the tracking question has been answered, the user is leaving the Settings hub that was opened from the remote (not from setup), no connection trouble just happened, and at least `ads_interstitial_min_interval_s` (default `600` s) has passed since the last one. Never during pairing.

| Step | What to do | Expected |
|---|---|---|
| Test target | Dev project and a dev build only. Turning interstitials on in prod is a product decision for the owner, and the privacy policy and store forms must keep disclosing them (owner item 10 of the privacy policy). | |
| Before | Needs a paired TV: Settings opened from the no-TV remote or from discovery counts as setup and never shows one. Launch the dev build at least twice. As a free user, connect to the TV, stay on the remote for about 10 seconds (the app keeps one ad loaded in advance and never waits for a load), open Settings, then go back. | No full-screen ad. |
| Change | Set `ads_interstitial_enabled` to `true`, publish. | |
| Launch once (fetch) | After the 5-minute window, cold-start, open Settings from the remote, go back. | Still no full-screen ad: the value is only downloaded. |
| Launch again (applied) | Cold-start again, connect to the TV, wait about 10 seconds on the remote, open Settings, go back. **Verify the screen before each tap; never tap the ad itself.** | A Google **test** interstitial shows once as you leave Settings. Leaving Settings again within 10 minutes shows none. |
| Kill | Set it back to `false`, publish, launch twice. | On the second launch, leaving Settings never shows a full-screen ad. This is the state to keep for v1 unless the owner decides otherwise. |
| Restore | Leave it at `false` (the code default). | |

## `min_supported_version`

Code default: `1.0.0`. Any app version below the published value gets the full-screen "Update required" screen with an **Update** button that opens the store listing; the remote isn't reachable until the user updates. A value that isn't a version (for example `v2`, or empty) never blocks anyone.

**Danger:** never publish a version higher than the newest version that is live, at 100 %, on **both** stores. Users would be told to update to a version they can't get. If Android and iOS releases are out of step, give the parameter a "Platform" condition per platform.

| Step | What to do | Expected |
|---|---|---|
| Test target | Dev project and a dev build only. Never test this on the prod project. | |
| Before | Note the installed version in Settings → About (for example `1.0.0`). | |
| Change | Set `min_supported_version` to `99.0.0` in the **dev** project, publish. | |
| Launch once (fetch) | After the 5-minute window, cold-start. | The app opens normally: the value is only downloaded. |
| Launch again (applied) | Cold-start again. | The "Update required" screen shows on the first frame (no flash of the remote). **Update** opens the store page (the dev package may have no listing; then the app shows its "Couldn't open the store" message, which is also a pass). |
| Restore | Set it back to `1.0.0`, publish, cold-start twice. | The first launch still shows "Update required" (the app fetches the restored value behind it); the second launch opens normally. |

**Real use after launch:** raise it only to retire a version that is broken beyond a fix (for example a protocol change on the TV side), to the oldest version that works, and only once that version is fully rolled out on both stores.

## Record

Write each result in device-matrix row DM-109 (Result, Device, Date, Notes), with the console version numbers you published. A switch that doesn't apply on the second launch is a Fail: stop the rollout (`crashlytics-alerts.md`) and record it in `status.md`.
