> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# App Review notes (App Store Connect)

App Store Connect → the app → the version → App Review Information. The `store-release` skill: "the reviewer has no Android TV"; Apple 2.1 ("couldn't test") is the rejection this prevents. Fill the tokens first (`dart tool/fill_release_docs.dart` from `app/`) and paste from `build/release-docs/review/apple-review-notes.md`.

## Fields

| Field | Value |
|---|---|
| Sign-in required | **No** (the app has no accounts) |
| Contact information | **[owner]** your name, phone and `{{SUPPORT_EMAIL}}` |
| Attachment | Optional: the demo video file itself, if you'd rather not use a link **[owner]** |
| Notes | The block below (Apple's limit is 4,000 characters; the block is about 3,750 before the tokens are filled; `store_forms_test.dart` keeps the filled block at 4,000 or fewer, so keep additions short) |

## Notes (paste this block)

```text
WHAT THE APP NEEDS
This app is a remote control for TVs and streaming boxes that run Android TV or Google TV. It talks directly to the TV over the local Wi-Fi network (no server of ours), so every control needs such a TV on the same Wi-Fi as the iPhone or iPad. We understand you may not have one, so the app has a demo mode, and there is a video of it working with a real TV.

DEMO VIDEO (real TV)
{{DEMO_VIDEO_URL}}
It shows a fresh install, the Local Network prompt, discovery, pairing with the code shown on the TV, the touchpad, D-pad, volume and keyboard controlling the TV, the Apps screen, Settings > Privacy choices, and the Premium page with Restore purchases.

TRY IT WITHOUT A TV: DEMO MODE
1. Install and open the app. The first screen shows three introduction cards.
2. Tap "Try demo" at the bottom of the cards. (If the introduction was already finished, the app opens on "Choose your TV"; tap "Try demo" at the bottom of that screen.)
3. The remote opens on "Demo TV" with a "Demo mode" strip at the top. Try the touchpad (swipe and tap), the D-pad, volume, the keys row, the app shortcuts and the Keyboard key. A card under the status line shows what the simulated TV just did. Nothing is sent over the network in demo mode.
4. Tap the Settings button (top left of the remote) to reach Settings, Premium and Privacy choices. To leave demo mode, tap "Leave" in the demo strip, then confirm with "Leave demo" (or "Stay" to keep going).

LOCAL NETWORK PERMISSION
The app asks for Local Network access only to find and control the user's TV on their own Wi-Fi (Bonjour services _androidtvremote2._tcp and _androidtvremote._tcp; the TV's remote service on ports 6466 and 6467 over TLS). Before iOS asks, the app explains why ("Allow local network access"); this happens when the user taps "Get started" or "Skip" on the introduction. Demo mode never browses the network, so "Try demo" shows no Local Network prompt.

APP TRACKING TRANSPARENCY
The free version shows a banner ad at the bottom of the Apps and Settings screens (Google AdMob). The first time one of those screens opens, the app explains how ads work ("About ads in this app"), then shows Apple's tracking question. The ads SDK isn't started until the user has answered, and the IDFA is used only if the user allows tracking. The app shows the same number of ads either way. The current answer is shown in Settings > Privacy choices > Ad tracking. Full-screen ads are off; if we switch them on later, an occasional one may appear when leaving Settings, never while pairing a TV. Where the law requires consent (for example the EEA and the UK), Google's consent form appears first, on the remote screen.

IN-APP PURCHASES
Premium removes ads and adds three colour styles. Every TV and every remote feature stays free.
- premium_monthly (auto-renewable subscription, monthly)
- premium_yearly (auto-renewable subscription, yearly)
- premium_lifetime (non-consumable, one payment)
Open Settings > Premium. The page shows each price and period, the auto-renewal terms, and links to the Terms of use and the Privacy policy.

RESTORE PURCHASES
Settings > Premium > "Restore purchases" (at the bottom of the Premium page, below Continue). It is also on the Premium page after a purchase.

NOT AFFILIATED WITH GOOGLE
This app is not made, endorsed or sponsored by Google. Android TV and Google TV are trademarks of Google LLC and are named only to say which TVs the app works with. The app uses Android TV's own remote protocol, which the TV's Android TV Remote Service provides to phone apps.

OTHER NOTES
- No account or sign-in.
- Turning a TV on over the network (Wake-on-LAN) is Android only; on iPhone the power key works while the TV is connected.
- Contact: {{SUPPORT_EMAIL}}
```

## Before you paste

- [ ] The video is uploaded (unlisted, no sign-in needed to watch) and `DEMO_VIDEO_URL` is filled in `docs/release/placeholders.json`. Script: `demo-video-script.md`. **[owner]**
- [ ] The three product ids exist in App Store Connect, are "Ready to Submit" and are attached to this version (first-time IAPs are reviewed with the binary). **[owner]**
- [ ] `SUPPORT_EMAIL` is filled (the release check refuses the example address). **[owner]**
- [ ] The steps above still match the build you submit: run them once on a device in demo mode. **[device]** **[owner]**
- [ ] If the app name still contains "Android TV" (`Remotely for Android TV`), expect questions under Guideline 2.3.10 / 5.2 (third-party trademarks in metadata); the trademark paragraph above is the answer, but a name without it is safer (owner list). **[owner]**
