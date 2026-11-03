> DRAFT — not legal advice. The owner (and, if they choose, a lawyer) reviews this before it is hosted.

# {{APP_NAME}} privacy policy

Effective date: {{EFFECTIVE_DATE}}

This policy explains what the {{APP_NAME}} app ("the app") does with information about you. The app is published by {{DEVELOPER_NAME}} ("we", "us"), {{DEVELOPER_ADDRESS}}. It applies to the app on Android (Google Play package `{{PLAY_PACKAGE}}`) and on iPhone and iPad (App Store). Where this policy says "iPhone", it means iPad too.

The short version:

- The app has no accounts and no server of its own, so there's nothing to sign in to.
- Everything about your TVs stays on your phone.
- Usage statistics and crash reports are sent to Firebase only if you allow it (or, where the law doesn't require asking first, until you turn them off).
- The free app shows banner ads from Google AdMob. If we turn them on, the free version may also show an occasional full-screen ad when you leave Settings. Premium has no ads.
- We don't sell your information.

## 1. What stays on your phone

The app keeps the following on your phone only. None of it is sent to us, to Firebase, to AdMob, to RevenueCat or to anyone else:

- your TVs' names and the nicknames you give them;
- their network addresses (IP addresses and local host names) and MAC addresses;
- the pairing certificate the app creates for your phone, and the TV key pins it uses to recognise each TV again;
- your app shortcuts, and the counts of which TV apps you use (kept on the phone to suggest shortcuts; the counts themselves never leave it, but see section 3 for the event sent when you start an app from the app's list);
- your settings, including your Privacy choices;
- anything you type with the keyboard feature, which goes straight to the TV.

**Backup and moving to a new phone.** On Android, the app turns off Android backup and device transfer for all its data, so none of the above goes into a Google backup or onto a new phone. On iPhone, the database that holds your TVs is excluded from iCloud and computer backups, and the pairing certificate is kept in the iPhone keychain as a this-device-only item, so neither moves to another iPhone. After you move to a new phone, you pair your TVs again. On iPhone, the app's simple preferences (such as theme and layout, which contain nothing about your TVs) are stored like other apps' preferences and may be included in your own iPhone backup. [owner to confirm]

When you delete the app, this data is deleted with it. On iPhone, iOS may keep the app's pairing certificate in the keychain after you delete the app; the app replaces it with a new one when you install it again. You can also remove a TV in the app at any time.

## 2. How the app talks to your TV

The app talks to your TV directly over your local network, without going through the internet or any server of ours:

- it finds TVs with local network discovery (mDNS / Bonjour);
- it connects to the TV's remote service over an encrypted (TLS) connection on ports 6466 and 6467;
- on Android it can send a Wake-on-LAN packet on your local network to wake a TV, using the MAC address saved on your phone.

On iPhone, iOS asks you to allow local network access before the app can find TVs.

## 3. Services we use, and what they receive

The app uses the services below. Each receives only what is described here. Information sent to them travels encrypted over HTTPS. Like any internet service, each of them also sees your phone's IP address when the app contacts it.

### Firebase Analytics (usage statistics, by Google)

If usage statistics are on, the app sends Firebase Analytics a fixed list of events about how the app is used:

- which screens you open (by screen name only);
- that onboarding was finished, and how many TVs were found when discovery found its first TVs;
- when pairing starts, succeeds or fails, and the kind of failure (for example, a wrong code);
- when a connection to a TV succeeds or is lost, and the kind of reason;
- the name of a remote key you press (such as "home" or "volume up"), for about one press in ten;
- which app you start from the app's list, by its package name when it is in the app's built-in catalogue, or only as "custom" when it is a shortcut you added yourself;
- when you change the layout of the remote;
- when you open the Premium page, from where, and which version of the Premium page was shown (we may test different versions); when a purchase or restore unlocks Premium, and which product was bought;
- when the app asks you for a store review.

Firebase Analytics also records its own standard events, such as the first time the app is opened, app sessions and app updates [owner to confirm the list in the Firebase console], an app instance ID (a random identifier for this installation of the app), basic device and app information (such as the phone model, system version, app version and language), and the approximate location (such as city, region or country) that Google works out from your IP address.

It never receives your TVs' names, network addresses or MAC addresses, pairing codes, anything you type, the names of apps you added yourself, or the paths of screens about a particular TV. The app does not give Firebase Analytics the advertising ID, and Google's ad-related consent signals for Analytics are always set to "denied".

**Your control.** In the app, open Settings → **Privacy choices** → **Share usage statistics**. Turning it off stops collection. Until you choose, the app decides as follows: where the law requires asking first (for example the European Economic Area, the United Kingdom and Switzerland, as reported by Google's User Messaging Platform), usage statistics stay off; elsewhere they are on until you turn them off. While the app can't yet tell which applies, events wait on the phone and are deleted if the answer is "off".

Analytics data is kept for {{ANALYTICS_RETENTION}}.

### Firebase Crashlytics (crash reports, by Google)

If crash reports are on, the app sends a report to Firebase Crashlytics when it crashes or hits a serious error. A report contains the error and the code location where it happened, device and app information (such as the phone model, system version, app version and free memory), and a crash installation identifier. When usage statistics are also on, Crashlytics may attach the app's most recent analytics events (the events listed above) to the report, to show what led up to the crash.

Before a report leaves the phone, the app removes anything that could identify your TVs, your network or you: TV names, network addresses, MAC addresses, pairing codes, e-mail addresses, certificates and similar values. If the app doesn't yet know your saved TVs' names, it holds the report back rather than send it unscrubbed. Development builds of the app never send crash reports.

**Your control.** Settings → **Privacy choices** → **Share crash reports**. The default works the same way as for usage statistics. When you turn it off, reports waiting on the phone are deleted.

Crash reports are kept for 90 days.

### Firebase Remote Config and Firebase Installations (by Google)

The app asks Firebase Remote Config for its settings each time it starts, whatever your Privacy choices are. These settings let us switch features on or off remotely (for example, banner ads and the occasional full-screen ad described below) and tell you when your version of the app is too old to work. The request is identified by a Firebase Installation ID, a random identifier for this installation of the app, and includes basic app information such as the app version and platform. [owner to confirm the exact fields]

### Google AdMob (ads) and the User Messaging Platform

The free version of the app shows a banner ad at the bottom of the Apps and Settings screens. Full-screen ads are off by default; if we turn them on through Remote Config, the free version may also show an occasional full-screen ad when you leave Settings, never while you pair a TV or straight after connection trouble. Premium shows no ads, and the app doesn't load ads for Premium users.

To show and measure ads, Google AdMob receives your device's advertising identifier (on Android, the advertising ID; on iPhone, the advertising identifier only if you allow tracking, see below), your IP address (from which Google works out an approximate location), and device and app information. On iPhone, Google's ads SDK may also use the identifier for vendors (a random identifier that iOS gives to all apps from the same developer on your device) whatever you answer about tracking. [owner to confirm] In regions where consent is required, ads are personalised only if you agree to that through the consent form. Elsewhere, ads may be personalised by default; you can limit this with your phone's ad settings and, on iPhone, by not allowing tracking. On Android, Google's ads SDK may also use the Android Privacy Sandbox (such as Topics and ad measurement), which you control in your phone's settings; on iPhone, Apple's SKAdNetwork may report, without identifying you, that an ad led to an app install. [owner to confirm] Google uses this information as described in its own privacy policy, at https://policies.google.com/privacy.

Google's **User Messaging Platform** decides whether your region requires a consent form (for example the European Economic Area, the United Kingdom and Switzerland; the exact list depends on the consent messages we publish in AdMob). Where it does, the app shows Google's consent form before any ad is loaded, and stores your answer on your phone. You can change your answer at any time in Settings → **Privacy choices** → **Ad privacy choices** (shown wherever the form is required, also with Premium).

### App Tracking Transparency (iPhone)

On iPhone, the app explains why it asks, then shows Apple's **App Tracking Transparency** question before it first shows an ad. The ads SDK isn't started until you have answered. If you don't allow tracking, AdMob doesn't receive the advertising identifier and you still see ads, which are then less tailored. The answer is shown in Settings → **Privacy choices** → **Ad tracking**, and you can change it in the iPhone's Settings.

### RevenueCat (Premium purchases)

Premium is sold through Google Play and the App Store, and the app uses RevenueCat to confirm your purchase. RevenueCat receives an anonymous app user ID (a random identifier, not your name or e-mail address), your store purchase records for this app (such as the product, the purchase date and the transaction ID), and basic device and app information. Payments are handled by Google Play or the App Store; we and RevenueCat never see your card details. RevenueCat's privacy policy is at https://www.revenuecat.com/privacy. [owner to confirm the retention RevenueCat applies]

### Google Play and the App Store

When you download the app, buy Premium or leave a review, Google Play or the App Store processes that under their own privacy policies. The app can ask the store to show its review prompt; the store decides whether it appears, and we don't learn whether you were shown it or what you wrote unless you post a public review.

## 4. Feedback e-mails

If you choose to send feedback, the app opens your own e-mail app with a message to {{SUPPORT_EMAIL}}. The message includes the app's version and your phone's system version, and nothing about your TVs. If you send it, we receive your e-mail address, your name if your e-mail app adds it, and whatever you write. You can read and change it before you send it. We use what you send only to answer you and improve the app, and keep it no longer than we need for that. [owner to confirm]

## 5. What we don't do

- We don't have accounts, so there's nothing to sign up for and no account to delete.
- We don't sell your personal information.
- We don't use your information to build a profile of you ourselves.

## 6. Children

The app is meant for adults; on the stores, its target audience is 18 and over. It is not directed at children under 13, and we don't knowingly collect personal information from children. If you believe a child has used the app and sent us information, contact us and we will delete what we can.

## 7. Where information is processed

Google (Firebase and AdMob) and RevenueCat may process information in countries other than yours, including the United States, under their own safeguards. [owner to confirm]

## 8. Why we use information (legal bases)

This section is a draft for places, such as the European Economic Area and the United Kingdom, whose law asks us to name a legal basis. [owner to confirm]

- **Usage statistics, crash reports and personalised ads:** your consent where the law requires it, otherwise our legitimate interest in improving the app and funding it with ads. Where it rests on consent, you can withdraw it at any time in Settings → **Privacy choices**.
- **Non-personalised ads:** our legitimate interest in offering a free version.
- **Remote Config:** our legitimate interest in keeping the app working and safe (switching features on or off, and telling you when an update is needed).
- **Premium purchases:** to provide what you bought (performance of a contract).
- **Feedback e-mails:** our legitimate interest in answering you.

## 9. Your choices and rights

- Turn usage statistics and crash reports on or off in Settings → **Privacy choices**.
- Change your ad consent in Settings → **Privacy choices** → **Ad privacy choices**, and ad tracking in the iPhone's Settings.
- Buy Premium to remove ads.
- Delete the app to delete what it keeps on your phone; a new installation gets new random identifiers. On iPhone, iOS may keep the app's pairing certificate in the keychain after you delete the app; the app replaces it with a new one when you install it again.

Depending on where you live, you may have the right to ask for access to, correction of, deletion of, or a portable copy of information about you, to restrict or object to its use, or to withdraw consent. Because the app has no accounts, we can't look you up by name or e-mail address; the services above hold only random identifiers. Contact us and we will help as far as we can. You can also complain to your local data protection authority.

## 10. Changes to this policy

If we change this policy, we will publish the new version at {{PRIVACY_POLICY_URL}} with a new effective date. If a change is significant, we will also say so in the app or on its store page.

## 11. Contact

{{DEVELOPER_NAME}}
{{DEVELOPER_ADDRESS}}
E-mail: {{SUPPORT_EMAIL}}
Website: {{SUPPORT_URL}}

---

## Owner to confirm (remove this section before hosting)

These points are written from the code and the project's decisions, but someone has to check them against the live services and the law that applies to you:

1. **iPhone preferences in backups:** the app's simple preferences (theme, layout, Privacy choices) live in the standard iOS preferences store, which iOS includes in backups. They hold no TV data (pinned by a test), but confirm you're comfortable with the wording in section 1.
2. **Remote Config fields:** the exact device and app fields a Remote Config fetch sends with the Firebase Installation ID.
3. **iOS Analytics without the advertising identifier:** the release build must resolve Swift packages with `FIREBASE_ANALYTICS_WITHOUT_ADID=true` (`tool/release.sh` sets it; device-matrix DM-106 checks it on a Mac). Section 3 depends on it. **(unverified, Mac)**
4. **Retention:** set `ANALYTICS_RETENTION` to what the Firebase console says; confirm Crashlytics' 90 days and RevenueCat's retention; decide how long feedback e-mails are kept.
5. **Selling and sharing:** "we don't sell" is true of us; whether AdMob's personalised ads count as "sharing" under laws such as California's (CCPA/CPRA) needs a legal view, and may need a "Do not sell or share" statement.
6. **International transfers:** the transfer safeguards Google and RevenueCat use, if your law requires you to name them.
7. **Rights requests:** how you will handle access or deletion requests, given that the app never shows its random identifiers.
8. **Legal basis (EEA/UK):** if the GDPR applies to you, the legal basis for each use (consent for analytics, crash reports and personalised ads; legitimate interest or contract for Remote Config and purchases) and the name of the data controller.
9. **Children:** that the store target audience is set to 18+ on Google Play. The App Store age rating (4+) reflects content; the audience is adults. Cap AdMob's ad content at G so the ads suit that rating (`docs/release/forms/content-rating.md`).
10. **Full-screen ads:** the app ships an interstitial that Remote Config can turn on (`ads_interstitial_enabled`, off by default; shown when leaving Settings, paced by `ads_interstitial_min_interval_s`). Keep the disclosure in the summary and section 3 as long as that code path ships, and keep the store forms consistent with it.
11. **Pairing certificate on iPhone:** the wording in sections 1 and 9 relies on the code change that replaces the stored certificate when the app is installed again (ruling P9-C8, Task 9.13). Confirm it shipped before hosting.
12. **Consent regions:** the regions named in section 3 are examples; the real list is whatever consent messages you publish in AdMob (UMP then reports consent as required there).
13. **Privacy Sandbox and SKAdNetwork:** confirm what the merged Android manifest keeps (`ACCESS_ADSERVICES_*`, see the store forms) and the iOS `SKAdNetworkItems`, and that section 3's sentence matches.
14. **Malaysia (PDPA):** if Malaysia's Personal Data Protection Act applies to you, it requires the notice in both Malay and English; this draft is English only.
15. **"Anonymous" in the app:** the Privacy choices page says "Anonymous counts…" (`privacyUsageSubtitle`), but the app instance ID makes the data pseudonymous. Fix the in-app copy after v1 (the strings are frozen for this release), or accept the wording.
16. **Location detail and IP addresses:** Google may derive city-level location from the IP address, and every service the app contacts sees the IP address. Confirm the store forms say the same.
