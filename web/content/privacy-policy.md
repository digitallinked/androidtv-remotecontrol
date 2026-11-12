# {{APP_NAME}} privacy policy

Effective date: {{EFFECTIVE_DATE}}

This policy explains what the {{APP_NAME}} app ("the app") does with information about you. The app is published by {{DEVELOPER_NAME}} ("we", "us"), {{DEVELOPER_ADDRESS}}. We are responsible for the information the app handles (the "data controller" or "data user" under data protection laws). It applies to the app on Android (Google Play package `{{PLAY_PACKAGE}}`) and on iPhone and iPad (App Store), and to our website at {{SUPPORT_URL}}. Where this policy says "iPhone", it means iPad too.

A Malay version of this policy is available on our website. Versi Bahasa Melayu dasar ini boleh didapati di laman web kami. If the two versions differ, the English version applies, unless the law where you live says otherwise.

The short version:

- The app has no accounts and no server of its own, so there's nothing to sign in to.
- Everything about your TVs stays on your phone.
- Usage statistics and crash reports are sent to Firebase only if you allow it (or, where the law doesn't require asking first, until you turn them off).
- The free app shows banner ads from Google AdMob. If we turn them on, the free version may also show an occasional full-screen ad when you leave Settings. Premium has no ads.
- We don't sell your information for money. Where a law counts personalised ads as "sharing" or "selling", you can opt out (section 10).

## 1. What stays on your phone

The app keeps the following on your phone only. None of it is sent to us, to Firebase, to AdMob, to RevenueCat or to anyone else; only your own TV takes part in the connection (section 2), and the pairing certificate goes only to that TV:

- your TVs' names and the nicknames you give them;
- their network addresses (IP addresses and local host names) and MAC addresses;
- the pairing certificate the app creates for your phone, and the TV key pins it uses to recognise each TV again;
- your app shortcuts, and the counts of which TV apps you use (kept on the phone to suggest shortcuts; the counts themselves never leave it, but see section 3 for the event sent when you start an app from the app's list);
- your settings, including your Privacy choices;
- your country, which the app reads each time it starts (from the SIM or mobile network on Android, from the Region setting on iPhone) to choose which TV apps to suggest, and doesn't store;
- anything you type with the keyboard feature, which goes straight to the TV;
- a short error log (Settings → Help → Error log) with TV names and addresses removed, which leaves your phone only if you copy it yourself.

**Backup and moving to a new phone.** On Android, the app turns off Android backup and device transfer for all its data, so none of the above goes into a Google backup or onto a new phone. On iPhone, the database that holds your TVs is excluded from iCloud and computer backups, and the pairing certificate is kept in the iPhone keychain as a this-device-only item, so neither moves to another iPhone. After you move to a new phone, you pair your TVs again. On iPhone, the app's simple preferences (such as theme, layout and your Privacy choices, which contain nothing about your TVs) are stored like other apps' preferences and may be included in your own iPhone backup.

When you delete the app, this data is deleted with it. On iPhone, iOS may keep the app's pairing certificate in the keychain after you delete the app; the app replaces it with a new one when you install it again. You can also remove a TV in the app at any time.

## 2. How the app talks to your TV

The app talks to your TV directly over your local network, without going through the internet or any server of ours:

- it finds TVs with local network discovery (mDNS / Bonjour);
- it connects to the TV's remote service over an encrypted (TLS) connection on ports 6466 and 6467;
- on Android it can send a Wake-on-LAN packet on your local network to wake a TV, using the MAC address saved on your phone.

**Permissions.** On Android, the app uses network permissions (internet access, network and Wi-Fi state, and multicast for discovery) and the advertising ID permission used by AdMob. On iPhone, iOS asks you to allow local network access before the app can find TVs, and asks about tracking as described in section 3. The app doesn't ask for your location, contacts, camera, microphone, photos or files.

## 3. Services we use, and what they receive

The app uses the services below. Each receives only what is described here. Information sent to them travels encrypted over HTTPS. Like any internet service, each of them also sees your phone's IP address when the app contacts it, and may work out an approximate location (such as city, region or country) from it.

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

Firebase Analytics also records its own standard events, such as the first time the app is opened, app sessions, app updates and in-app purchases, together with an app instance ID (a random identifier for this installation of the app), basic device and app information (such as the phone model, system version, app version and language), and the approximate location that Google works out from your IP address.

It never receives your TVs' names, network addresses or MAC addresses, pairing codes, anything you type, the names of apps you added yourself, or the paths of screens about a particular TV. The app is built so that Firebase Analytics doesn't collect the advertising ID, and Google's ad-related consent signals for Analytics are always set to "denied".

**Your control.** In the app, open Settings → **Privacy choices** → **Share usage statistics**. Turning it off stops collection. Until you choose, the app decides as follows: where the law requires asking first (for example the European Economic Area, the United Kingdom and Switzerland, as reported by Google's User Messaging Platform), usage statistics stay off; elsewhere they are on until you turn them off. While the app can't yet tell which applies, events wait on the phone and are deleted if the answer is "off".

Analytics data is kept for {{ANALYTICS_RETENTION}}, then deleted by Google.

### Firebase Crashlytics (crash reports, by Google)

If crash reports are on, the app sends a report to Firebase Crashlytics when it crashes or hits a serious error. A report contains the error and the code location where it happened, device and app information (such as the phone model, system version, app version and free memory), and a crash installation identifier. When usage statistics are also on, Crashlytics may attach the app's most recent analytics events (the events listed above) to the report, to show what led up to the crash.

Before a report leaves the phone, the app removes the names of the TVs it knows, network addresses, MAC addresses, pairing codes, e-mail addresses, certificates, database text and similar values. If the app doesn't yet know your saved TVs' names, it holds the report back rather than send it unscrubbed. Debug builds of the app never send crash reports.

**Your control.** Settings → **Privacy choices** → **Share crash reports**. The default works the same way as for usage statistics. When you turn it off, reports waiting on the phone are deleted.

Crash reports are kept for up to 90 days, under Google's standard Crashlytics retention.

### Firebase Remote Config and Firebase Installations (by Google)

The app asks Firebase Remote Config for its settings each time it starts, whatever your Privacy choices are. These settings let us switch features on or off remotely (for example, banner ads and the occasional full-screen ad described below) and tell you when your version of the app is too old to work. The request is identified by a Firebase Installation ID, a random identifier for this installation of the app, and includes basic app and device information that Firebase uses to choose the right settings, such as the app's id and version, the platform and system version, and the language, country and time zone settings of your phone. Remote Config doesn't receive anything about your TVs.

### Google AdMob (ads) and the User Messaging Platform

The free version of the app shows a banner ad at the bottom of the Apps and Settings screens. Full-screen ads are off by default; if we turn them on through Remote Config, the free version may also show an occasional full-screen ad when you leave Settings, never while you pair a TV or straight after connection trouble. Premium shows no ads, and the app doesn't load ads for Premium users. The ads are limited to content suitable for general audiences.

To show and measure ads and to prevent fraud, Google AdMob receives your device's advertising identifier (on Android, the advertising ID; on iPhone, the advertising identifier only if you allow tracking, see below), your IP address (from which Google works out an approximate location), and device and app information, and it may collect diagnostic and crash information about its own ads code. On iPhone, Google's ads code may also use the identifier for vendors (a random identifier that iOS gives to all apps from the same developer on your device) whatever you answer about tracking. In regions where consent is required, ads are personalised only if you agree to that through the consent form; otherwise you see non-personalised or limited ads. Elsewhere, ads may be personalised by default; you can limit this with your phone's ad settings, through Settings → **Privacy choices** → **Ad privacy choices** where it is shown, and, on iPhone, by not allowing tracking. On Android, Google's ads code may also use the Android Privacy Sandbox (such as Topics and ad measurement), which you control in your phone's settings; on iPhone, Apple's SKAdNetwork may report, without identifying you, that an ad led to an app install. Google uses this information as described in its own privacy policy, at https://policies.google.com/privacy, and explains how it uses information from apps that use its services at https://policies.google.com/technologies/partner-sites.

Google's **User Messaging Platform** decides whether your region requires a consent form or privacy message (for example the European Economic Area, the United Kingdom and Switzerland, and US states with privacy laws; the exact list depends on the messages we publish in AdMob). Where it does, the app shows Google's form before any ad is loaded, and stores your answer on your phone. You can change your answer at any time in Settings → **Privacy choices** → **Ad privacy choices** (shown wherever such a message applies, also with Premium).

### App Tracking Transparency (iPhone)

On iPhone, the app explains why it asks, then shows Apple's **App Tracking Transparency** question before it first shows an ad. The ads code isn't started until you have answered. If you don't allow tracking, AdMob doesn't receive the advertising identifier and you still see ads, which are then less tailored. The answer is shown in Settings → **Privacy choices** → **Ad tracking**, and you can change it in the iPhone's Settings.

### RevenueCat (Premium purchases)

Premium is sold through Google Play and the App Store, and the app uses RevenueCat to confirm your purchase. RevenueCat receives an anonymous app user ID (a random identifier, not your name or e-mail address), your store purchase records for this app (such as the product, the purchase date and the transaction ID), and basic device and app information. Payments are handled by Google Play or the App Store; we and RevenueCat never see your card details. RevenueCat keeps purchase records for as long as we use its service, so that Premium can be restored, and handles them under its privacy policy at https://www.revenuecat.com/privacy.

### Google Play and the App Store

When you download the app, buy Premium or leave a review, Google Play or the App Store processes that under their own privacy policies. The app can ask the store to show its review prompt; the store decides whether it appears, and we don't learn whether you were shown it or what you wrote unless you post a public review. The stores also give us statistics about installs, purchases and crashes that don't identify you.

### Our website

Our website is served through Cloudflare, which processes visitors' IP addresses and technical request data to deliver the pages and protect them from attacks. The website sets no advertising or analytics cookies.

## 4. Feedback e-mails

If you choose to send feedback, the app opens your own e-mail app with a message to {{SUPPORT_EMAIL}}. The message includes the app's version and your phone's system version, and nothing about your TVs. If you send it, we receive your e-mail address, your name if your e-mail app adds it, and whatever you write. You can read and change it before you send it. We use what you send only to answer you and improve the app. We delete feedback e-mails within 24 months of our last reply, unless we need to keep one longer to deal with a legal claim.

## 5. What we don't do

- We don't have accounts, so there's nothing to sign up for and no account to delete.
- We don't sell your personal information for money.
- We don't use your information to build a profile of you ourselves, and we don't make decisions about you by automated means that have legal or similarly significant effects.
- We don't collect sensitive information, such as health, financial, religious or biometric information.

## 6. How long information is kept

| Information | Where | How long |
|---|---|---|
| Your TVs, pairing certificate, shortcuts, settings | Your phone | Until you remove the TV or delete the app |
| Usage statistics | Firebase Analytics | {{ANALYTICS_RETENTION}} |
| Crash reports | Firebase Crashlytics | Up to 90 days |
| Remote Config and installation identifiers | Firebase | While the app is installed; Google deletes inactive installation data on its own schedule |
| Ad data | Google AdMob | Under Google's own retention policies |
| Purchase records | RevenueCat, Google Play, App Store | As long as needed to provide Premium and meet tax and accounting law |
| Feedback e-mails | Our mailbox | Up to 24 months after our last reply |

## 7. Security

The connection to your TV is encrypted with TLS and protected by the pairing code your TV shows. Information sent to the services in section 3 travels over HTTPS. On your phone, the pairing certificate is kept in the system's secure storage (encrypted with a key held by the Android Keystore, or the iPhone keychain). Crash reports are scrubbed before they leave the phone (section 3). No method of storage or transmission is perfectly secure, but we and the services we use take reasonable steps to protect information. If a data breach affecting you happens, we will notify you and the authorities as the law requires.

## 8. Children

The app is meant for adults; on the stores, its target audience is 18 and over. It is not directed at children under 13, and we don't knowingly collect personal information from children. If you believe a child has used the app and sent us information, contact us and we will delete what we can.

## 9. Where information is processed

We are based in Malaysia. Google (Firebase and AdMob), RevenueCat and Cloudflare may process information in countries other than yours, including the United States. Where the law requires it, they protect transfers with recognised safeguards such as the European Commission's standard contractual clauses or the EU–US Data Privacy Framework, as described in their own terms. Transfers of personal data out of Malaysia are made under the conditions allowed by the Personal Data Protection Act 2010.

## 10. Privacy laws where you live

### Malaysia (Personal Data Protection Act 2010)

This section is our notice under section 7 of the Act.

- **What we process and why:** the information in sections 3 and 4, to provide the app and Premium, keep it working, fix crashes, show ads that fund the free version, and answer you.
- **Where it comes from:** from you and from the app on your phone, and from the stores when you buy Premium.
- **Who receives it:** the service providers in section 3 (Google, RevenueCat, Google Play and the App Store, Cloudflare), and authorities when the law requires it.
- **Is it required?** Usage statistics and crash reports are optional, and you can turn them off at any time. Ads come with the free version; Premium removes them. Purchase information is needed to provide Premium. Feedback is up to you. The app works fully without anything optional.
- **Your rights:** you may ask for access to and correction of your personal data, withdraw consent, ask us to stop processing that is likely to cause damage or distress, and stop direct marketing (we don't send any). Send requests to {{SUPPORT_EMAIL}}. We answer within 21 days, as the Act requires.

### European Economic Area, United Kingdom and Switzerland (GDPR)

The legal bases we rely on:

- **Usage statistics, crash reports, personalised ads, and storing or reading information on your device for ads:** your consent. You can withdraw it at any time in Settings → **Privacy choices**, without affecting what happened before.
- **Non-personalised or limited ads:** our legitimate interest in funding a free version of the app, together with your consent where the law requires it for device storage.
- **Remote Config:** our legitimate interest in keeping the app working and safe (switching features on or off, and telling you when an update is needed).
- **Premium purchases:** to provide what you bought (performance of a contract) and to meet our legal obligations, such as tax records.
- **Feedback e-mails:** our legitimate interest in answering you.

You have the right to access, correct, delete or receive a portable copy of your personal data, to restrict or object to its use (including use based on legitimate interests), and to withdraw consent. You can also complain to the data protection authority where you live or work.

### United States (state privacy laws)

Some US state laws, such as California's, give you rights over personal information: to know what is collected, to access, correct or delete it, and to opt out of its "sale", its "sharing" for cross-context behavioural advertising, or targeted advertising. We don't sell personal information for money. Showing personalised ads through AdMob may count as "sharing" or targeted advertising under those laws. To opt out, use Settings → **Privacy choices** → **Ad privacy choices** where it is shown, turn off ad personalisation in your phone's settings (Android: Settings → Google → Ads, or Settings → Privacy → Ads; iPhone: don't allow tracking), or buy Premium. The categories involved are identifiers (the advertising and app identifiers), internet and app activity (the events in section 3), approximate location and purchase information, used for the purposes in section 3. We don't collect sensitive personal information, and we won't treat you differently for using your rights.

## 11. Your choices and rights

- Turn usage statistics and crash reports on or off in Settings → **Privacy choices**.
- Change your ad consent in Settings → **Privacy choices** → **Ad privacy choices**, and ad tracking in the iPhone's Settings.
- Buy Premium to remove ads.
- Delete the app to delete what it keeps on your phone; a new installation gets new random identifiers for analytics and crash reports. On iPhone, iOS may keep the app's pairing certificate in the keychain after you delete the app; the app replaces it with a new one when you install it again.

**How to make a request.** Write to {{SUPPORT_EMAIL}} and say what you want. Because the app has no accounts, we can't look you up by name or e-mail address: the services in section 3 hold only random identifiers, which the app doesn't show. Turning off sharing in Settings → **Privacy choices** and deleting the app stops further collection; Google then deletes the data under the retention periods in section 6. For a request about your purchases, include the store order number. For a feedback e-mail, write from the same address. We may ask for information to confirm a request is yours, and we answer within the time the law where you live sets.

## 12. Changes to this policy

If we change this policy, we will publish the new version at {{PRIVACY_POLICY_URL}} with a new effective date. If a change is significant, we will also say so in the app or on its store page.

## 13. Contact

{{DEVELOPER_NAME}}
{{DEVELOPER_ADDRESS}}
E-mail: {{SUPPORT_EMAIL}}
Website: {{SUPPORT_URL}}
