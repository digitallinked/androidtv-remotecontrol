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

Choose "All or some functionality is restricted" and add one set of instructions. Name it `Demo mode (no TV needed)`; leave username and password empty. Paste the block below into the instructions field (`store_forms_test.dart` keeps it at 500 characters or fewer after filling; **[owner]** confirm the field's current limit in the console and shorten further if needed):

```text
No account needed. Every feature controls an Android TV or Google TV on the same Wi-Fi, so please use demo mode (a simulated TV):
1. Open the app and tap "Try demo" at the bottom of the intro cards (or of "Choose your TV").
2. Use the remote on "Demo TV"; a card shows what the TV did.
3. Settings: top-left button. To exit: "Leave" in the Demo mode strip, then confirm "Leave demo".
Real-TV video: {{DEMO_VIDEO_URL}}
```

## Owner to confirm

- [ ] Each answer against the console's current questions (sections are added and renamed often). **[owner]**
- [ ] The Advertising ID purposes against AdMob's Play disclosure page. **[owner]**
- [ ] The demo video is uploaded (unlisted) and `DEMO_VIDEO_URL` is filled before pasting. **[owner]**
