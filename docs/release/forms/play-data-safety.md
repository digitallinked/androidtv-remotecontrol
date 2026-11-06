> DRAFT for the owner to paste. Confirm every answer against the console's current wording.

# Google Play Data safety

Play Console → Policy and programs → App content → Data safety. Ruling P9-R15, the `store-release` skill's Data safety list, and `docs/release/legal/privacy-policy.md`, which this form must agree with. Every **[owner]** line needs your check against the console and the vendor pages linked below; vendor disclosures change with SDK versions.

## What the app links (prod Android build)

| SDK | Version (pubspec / merged manifest) | Used for |
|---|---|---|
| Firebase Analytics | `firebase_analytics` 13.0.1 (`play-services-measurement` 24.0.0) | Usage statistics, only while "Share usage statistics" is on (decision #39). Never the advertising ID (`google_analytics_adid_collection_enabled=false`). |
| Firebase Crashlytics | `firebase_crashlytics` 6.0.1 (`firebase-crashlytics` 21.0.1, `firebase-sessions` 4.0.1) | Crash reports, scrubbed, only while "Share crash reports" is on. |
| Firebase Remote Config + Installations | `firebase_remote_config` 7.0.1 (`firebase-config` 24.0.1, `firebase-installations` 20.0.0) | Feature switches and the minimum version, fetched on every start whatever the choices (decision #39). |
| Google AdMob + User Messaging Platform | `google_mobile_ads` 9.2.0 (`play-services-ads` 25.5.0, `user-messaging-platform` 4.0.0) | Ads in the free version; the consent form where required. |
| RevenueCat | `purchases_flutter` 10.18.1 (`purchases` 10.29.0, Play Billing 8.3.0) | Confirms Premium purchases. |

**Ads, as the privacy policy says them:** the free version shows a banner ad at the bottom of the Apps and Settings screens. Full-screen ads are off by default; if they are switched on through Remote Config, the free version may also show an occasional full-screen ad when you leave Settings, never while you pair a TV or straight after connection trouble. Premium shows no ads.

## Overview questions

| Question | Answer | Source |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | The table below. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Every SDK uses HTTPS; the TV connection is TLS and its data never leaves the phone. Policy section 3. |
| Which account creation methods does your app support? | **None** (the app has no accounts) | Policy section 5. |
| Account deletion URL | **Not applicable**: no accounts. | Policy section 5. |
| Do you provide a way for users to request that their data is deleted? | **Yes**: by e-mail to `{{SUPPORT_EMAIL}}`. Explain that the app has no accounts; you delete what you can find from what the user gives you. | Ruling P9-R15; policy section 9. **[owner]** confirm how you will handle requests (policy owner item 7). |
| Has your app been independently security-reviewed (MASA)? | **No** (optional) | |
| Is your app's data collection compliant with the Families policy? | Not shown: the target audience is 18+ (`play-declarations.md`). | Ruling P9-R15. |

## Data types

"Collected" means it leaves the phone; "shared" means it goes to a third party for that party's own use. Data sent to a service provider that processes it for us (Firebase, RevenueCat) is collected, not shared. Where the same data type comes from several SDKs, Play wants one answer: it is **required** if any SDK collects it without a user choice.

| Play category → data type | Collected | Shared | SDK | Required or optional | Purposes |
|---|---|---|---|---|---|
| Location → **Approximate location** | Yes | **Yes** for AdMob (advertising) **[owner]** confirm on AdMob's page | AdMob (from the IP address); Firebase Analytics (city/region/country from the IP address) | Required (AdMob, free version) | Advertising or marketing; Analytics; Fraud prevention, security and compliance |
| App activity → **App interactions** | Yes | **Yes** for AdMob (ad views and taps) **[owner]** confirm | Firebase Analytics (the event catalogue: screens, onboarding, pairing and connection outcomes, sampled key names, app launches by catalogue package or "custom", layout changes, paywall and purchase events, the review prompt); AdMob (ad interactions) | Analytics: optional (Privacy choices). AdMob: required in the free version. So **Required**. | Analytics; Advertising or marketing; Fraud prevention, security and compliance |
| App info and performance → **Crash logs** | Yes | **Yes** for AdMob (SDK crash data) **[owner]** confirm on AdMob's page | Firebase Crashlytics (scrubbed of TV names, addresses, codes); AdMob (crashes in the ads SDK, collected automatically in the free version) | Crashlytics: optional (Privacy choices → Share crash reports). AdMob: required in the free version. So **Required**. | App functionality; Analytics; Advertising or marketing; Fraud prevention, security and compliance (the AdMob purposes as Google's page lists them: **[owner]** confirm and copy its exact purposes) |
| App info and performance → **Diagnostics** | Yes | **Yes** for AdMob (SDK performance) **[owner]** confirm | Firebase Crashlytics (device state with a crash; Firebase Sessions); Firebase Analytics (app version, OS); AdMob (ad SDK performance) | Required (AdMob) | App functionality; Analytics; Advertising or marketing |
| Device or other IDs: **Advertising ID**, **Firebase Installation ID**, **App set ID** (and the Analytics app instance ID, the Crashlytics installation ID and RevenueCat's anonymous app user ID) | Yes | **Yes** for AdMob (the Advertising ID and App set ID, for advertising) **[owner]** confirm | AdMob (Advertising ID, App set ID); Firebase Remote Config, Installations, Analytics, Crashlytics (Firebase Installation ID, app instance ID, App set ID); RevenueCat (anonymous app user ID) | Required (Remote Config fetches on every start; AdMob in the free version) | App functionality; Analytics; Advertising or marketing; Fraud prevention, security and compliance |
| Financial info → **Purchase history** | Yes | No | RevenueCat (store transactions for this app: product, date, transaction id); Firebase Analytics (`purchase_success` with the product id, only while usage statistics are on) | Required for anyone who buys Premium | App functionality (unlock Premium); Analytics |

**Not collected** (answer "No" to every other type):

- **Personal info** (name, e-mail, address, phone, IDs): no accounts. Feedback is sent by the user's own e-mail app, outside the app: it isn't used for tracking or advertising, it is infrequent, optional and started by the user, and the user's own address is shown as the sender. Apple's App Privacy guidance lists these as the criteria for optional disclosure ("Optional disclosure" on https://developer.apple.com/app-store/app-privacy-details/); Play's Data safety help treats data the user sends through another app as handled by that app. **[owner]** confirm you're comfortable not declaring it.
- **Location → Precise location:** the app never reads location and declares no location permission.
- **Messages, Photos and videos, Audio, Files and docs, Calendar, Contacts, Health and fitness, Web browsing:** none.
- **App activity → Installed apps, In-app search history, Other user-generated content:** none. Text typed with the keyboard feature goes only to the user's own TV. The TV-app usage counts and the app shortcuts stay on the phone; the analytics `app_launch` event (declared under App interactions) names a TV app only when it is in the app's built-in catalogue, otherwise "custom".
- **TV names, IP addresses, MAC addresses, the pairing certificate and key pins:** stored on the phone only, never transmitted; Android backup and device transfer are off (decision #49). Not collected.

Processed ephemerally: **No** for every row.

**In-app review prompt (`in_app_review`, Play In-App Review API):** collects nothing for us. Google Play shows the prompt and handles any rating or review under its own policy; the app never learns whether the prompt appeared or what was written. Nothing to declare.

## Vendor disclosures to check (open each before you paste)

- Firebase (Analytics, Crashlytics, Remote Config, Installations): https://firebase.google.com/docs/android/play-data-disclosure **[owner]**
- Google Mobile Ads SDK (AdMob) and UMP: https://developers.google.com/admob/android/privacy/play-data-disclosure **[owner]**
- RevenueCat: https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety **[owner]** (if the URL moved, search RevenueCat's docs for "Data safety")
- Play Console Help, "Provide information for Google Play's Data safety section": https://support.google.com/googleplay/android-developer/answer/10787469

## Owner to confirm

- [ ] Each "Shared" answer for AdMob against Google's disclosure page for SDK 25.5.0. **[owner]**
- [ ] Required vs optional for each row (Play's definitions change). **[owner]**
- [ ] Crash logs: AdMob is listed (Required, Shared) because Google's GMA SDK disclosure lists crash logs among what it collects; confirm and copy its purposes (Ruling P9-C12). **[owner]**
- [ ] The answers agree with the hosted privacy policy, including the occasional full-screen ad when you leave Settings (policy owner item 10). **[owner]**
- [ ] If you remove the AdServices permissions (`adservices-permissions.md`), nothing here changes; if you add ad mediation, add each network's data. **[owner]**
