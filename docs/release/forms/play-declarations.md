> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Google Play: App content declarations

Play Console → Policy and programs → App content. Ruling P9-R15. Data safety and the content rating have their own drafts (`play-data-safety.md`, `content-rating.md`).

| Section | Answer | Why / source |
|---|---|---|
| **Privacy policy** | `{{PRIVACY_POLICY_URL}}` | The hosted `docs/release/legal/privacy-policy.md`. **[owner]** host it first. |
| **Ads** — does your app contain ads? | **Yes** | AdMob banners at the bottom of the Apps and Settings screens in the free version; an occasional full-screen ad when you leave Settings may be switched on through Remote Config (off by default, decision #41). Premium shows none. |
| **App access** | **All or some functionality is restricted** | Every feature needs an Android TV or Google TV on the same Wi-Fi network; reviewers won't have one. Paste the instructions below. |
| **Target audience and content** | Ages **18 and over** only | Keeps the app out of the Families policy (Ruling P9-R15; privacy policy section 6). |
| — Could the store listing unintentionally appeal to children? | **No** | Plain utility listing; no characters or games. |
| **Content rating** | See `content-rating.md` | Expected Everyone / PEGI 3. |
| **Data safety** | See `play-data-safety.md` | |
| **Advertising ID** — does your app use an advertising ID? | **Yes** | The manifest declares `com.google.android.gms.permission.AD_ID` (`permissions.md`). |
| — Purposes | **Advertising or marketing**; **Fraud prevention, security and compliance** (AdMob uses it to stop invalid traffic) | Only AdMob reads it. Firebase Analytics doesn't (`google_analytics_adid_collection_enabled=false`), so don't tick Analytics. **[owner]** confirm against AdMob's Play disclosure. |
| **Government apps** | **No** | |
| **Financial features** | **None** of the listed features | Premium is an in-app purchase, not a financial service. |
| **Health apps** | **No** health features | |
| **News apps** | **No** | |
| **Photo and video permissions** | Not shown / **No** | The app asks for no media permission. |
| **Foreground service permissions** | Not shown expected; if asked, **no foreground service types** | The merged manifest has `FOREGROUND_SERVICE` from WorkManager but no typed foreground service (`permissions.md`). **[owner]** confirm. |
| **Full-screen intent**, **Exact alarms**, **Accessibility API**, **VPN service** | **No** / not shown | The app uses none. |

## App access: instructions for the reviewer

Choose "All or some functionality is restricted", add one set of instructions, and paste:

```text
Name: Demo mode (no TV needed)

Every feature controls an Android TV or Google TV on the same Wi-Fi network, so the app can't be fully used without one. It needs no account, username or password.

To try the app without a TV, use demo mode, which shows a simulated TV:
1. Open the app. On the first screen (the introduction cards), tap "Try demo" at the bottom.
   (If the introduction was already finished: on "Choose your TV", tap "Try demo" at the bottom.)
2. The remote opens on "Demo TV" with a "Demo mode" strip at the top. Use the touchpad, D-pad, volume and the other keys, the app shortcuts and the keyboard: a card under the status line shows what the simulated TV just did. Nothing is sent over the network.
3. Tap the Settings button (top left) for Settings, Premium and Privacy choices. Tap "Leave" in the demo strip to leave demo mode.

A video of the app controlling a real TV (discovery, pairing with the code on the TV, and control): {{DEMO_VIDEO_URL}}
```

## Owner to confirm

- [ ] Each answer against the console's current questions (sections are added and renamed often). **[owner]**
- [ ] The Advertising ID purposes against AdMob's Play disclosure page. **[owner]**
- [ ] The demo video is uploaded (unlisted) and `DEMO_VIDEO_URL` is filled before pasting. **[owner]**
