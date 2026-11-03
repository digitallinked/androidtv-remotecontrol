> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# App Store App Privacy ("nutrition label")

App Store Connect → the app → App Privacy → Get Started / Edit. Ruling P9-R15, the `store-release` skill's App Store checklist, and `docs/release/legal/privacy-policy.md`, which these answers must agree with. Every **[owner]** line needs your check against the console and the vendor pages linked below.

## What the app links (prod iOS build)

| SDK | Used for |
|---|---|
| Firebase Analytics | Usage statistics, only while "Share usage statistics" is on (decision #39). Built without the advertising identifier: `FIREBASE_ANALYTICS_WITHOUT_ADID=true` under Swift Package Manager (`tool/release.sh` sets it), `$FirebaseAnalyticsWithoutAdIdSupport` under CocoaPods (P9-R5, P9-C4). IDFV collection is off (`GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED=false`). **(unverified, Mac: DM-106)** |
| Firebase Crashlytics | Crash reports, scrubbed, only while "Share crash reports" is on. |
| Firebase Remote Config + Installations | Feature switches and the minimum version, fetched on every start whatever the choices. |
| Google AdMob + User Messaging Platform | Ads in the free version, after the consent step and the App Tracking Transparency question; the IDFA only if the user allows tracking. |
| RevenueCat | Confirms Premium purchases. |

**Ads, as the privacy policy says them:** the free version shows a banner ad at the bottom of the Apps and Settings screens. Full-screen ads are off by default; if they are switched on through Remote Config, the free version may also show an occasional full-screen ad when you leave Settings, never while you pair a TV or straight after connection trouble. Premium shows no ads.

## Data collection

**Do you or your third-party partners collect data from this app?** **Yes.**

For each type below, App Store Connect asks three things: the purposes, whether it is linked to the user's identity, and whether it is used for tracking.

- **Linked to the user: No** for every type (Ruling P9-R15). The app has no accounts, no name or e-mail, and every identifier is random per installation. **[owner]** confirm: Apple counts data as linked if *any* partner links it; read AdMob's page below.
- **Tracking: Yes** where marked (the IDFA after the user allows tracking, and what AdMob uses with it).

| Category → data type | Collected by | Purposes | Linked | Used for tracking |
|---|---|---|---|---|
| Identifiers → **Device ID** | AdMob (the IDFA, only if tracking is allowed); Firebase Analytics (app instance ID); Firebase Installations (Firebase Installation ID, for Remote Config); Crashlytics (installation ID); RevenueCat (anonymous app user ID) | Third-Party Advertising; Analytics; App Functionality | No | **Yes** (the IDFA, by AdMob) |
| Usage Data → **Product Interaction** | Firebase Analytics (the event catalogue: screens, onboarding, pairing and connection outcomes, sampled key names, app launches by catalogue package or "custom", layout changes, paywall and purchase events, the review prompt); AdMob (ad views and taps) | Analytics; Third-Party Advertising | No | **Yes** (AdMob) **[owner]** confirm |
| Usage Data → **Advertising Data** | AdMob (the ads shown and how they performed) | Third-Party Advertising | No | **Yes** |
| Diagnostics → **Crash Data** | Crashlytics (scrubbed of TV names, addresses and codes); AdMob (SDK crashes) | App Functionality; Analytics | No | No |
| Diagnostics → **Performance Data** | AdMob (ad SDK performance, such as load times); Crashlytics (device state with a crash, such as free memory) | App Functionality; Analytics; Third-Party Advertising | No | No **[owner]** confirm on AdMob's page |
| Purchases → **Purchase History** | RevenueCat (this app's App Store transactions: product, date, transaction id); Firebase Analytics (`purchase_success` with the product id, only while usage statistics are on) | App Functionality; Analytics | No | No |
| Location → **Coarse Location** | AdMob (from the IP address); Firebase Analytics (city/region/country from the IP address) | Third-Party Advertising; Analytics | No | **Yes** (AdMob) **[owner]** confirm |

**Tracking: Yes.** The app shows the App Tracking Transparency question (after its own explanation) before the ads SDK starts, and AdMob receives the IDFA only if the user allows tracking. Declare "Used to track you" for the data types marked **Yes** above. Without tracking permission the app still shows ads, which are less tailored.

**Possibly also declare** (AdMob's page lists it for some SDK versions): Diagnostics → **Other Diagnostic Data**. **[owner]** add it if Google's page for the linked SDK version lists it.

**Not collected** (leave unchecked): Contact Info, Health and Fitness, Financial Info, Precise Location, Sensitive Info, Contacts, User Content (typed text goes only to the user's own TV; feedback is sent by the user's own Mail app, outside the app), Browsing History, Search History, Other Data. TV names, IP addresses, MAC addresses and the pairing certificate stay on the iPhone and are excluded from backups (decision #49).

## Privacy policy URL

App Store Connect → App Privacy → Privacy Policy URL: `{{PRIVACY_POLICY_URL}}` (the hosted `privacy-policy.md`). **[owner]** host it first.

## Vendor disclosures to check (open each before you answer)

- Firebase: https://firebase.google.com/docs/ios/app-store-data-collection **[owner]**
- Google Mobile Ads SDK (AdMob) and UMP: https://developers.google.com/admob/ios/privacy/data-disclosure **[owner]**
- RevenueCat: https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy **[owner]** (if the URL moved, search RevenueCat's docs for "App Privacy")
- Apple, "App privacy details on the App Store": https://developer.apple.com/app-store/app-privacy-details/

## Privacy manifests

Apple also reads each SDK's `PrivacyInfo.xcprivacy` (required-reason APIs and declared data). Firebase, Google Mobile Ads and RevenueCat ship their own. After the first archive, Xcode's Organizer → the archive → Generate Privacy Report shows the combined manifest: check it against the table above. **(unverified, Mac)** **[owner]**

## Owner to confirm

- [ ] "Linked: No" for every type, against AdMob's and RevenueCat's pages. **[owner]**
- [ ] The "used for tracking" marks against AdMob's page. **[owner]**
- [ ] Whether to add Other Diagnostic Data. **[owner]**
- [ ] The Xcode privacy report agrees with this table. **(unverified, Mac)** **[owner]**
- [ ] The answers agree with the hosted privacy policy, including the occasional full-screen ad when you leave Settings (policy owner item 10). **[owner]**
