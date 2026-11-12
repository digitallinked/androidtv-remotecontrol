# Legal texts: what was settled and what still needs checking

The privacy policy and terms (`privacy-policy.md`, `terms.md`, and the Malay `*.ms.md`) were made final on 2026-11-12 at the owner's request: the draft line and the "Owner to confirm" lists were removed, and each open point was settled in the text as below. They were written from the code and the project's decisions, **not reviewed by a lawyer**. A lawyer's review is still recommended before the paid launch.

When the English text changes, change the Malay text in the same commit (`legal_docs_test.dart` checks both carry the same placeholders).

## Settled in the text (2026-11-12)

| Old item | How the text handles it |
|---|---|
| Privacy 1, iPhone preferences in backups | Stated plainly: preferences (theme, layout, Privacy choices) may be in the user's iPhone backup; no TV data. |
| Privacy 2, Remote Config fields | Described as app id and version, platform and system version, language, country and time zone, with the Installation ID. |
| Privacy 3, iOS Analytics without the ad id | Worded as "the app is built so that…". **Still verify DM-106 / DM-112 on the Mac before the first iOS upload.** |
| Privacy 4, retention | Analytics 14 months (owner), Crashlytics up to 90 days, RevenueCat while the service is used, feedback e-mails 24 months after the last reply; a retention table (section 6). |
| Privacy 5, selling and sharing (US) | Section 10 "United States": no sale for money; personalised ads may be "sharing"; opt out via Ad privacy choices, phone ad settings or Premium. |
| Privacy 6, transfers | Section 9: SCCs or the EU–US Data Privacy Framework as the providers describe; PDPA transfer conditions. |
| Privacy 7, rights requests | Section 11 "How to make a request": what we can and can't look up, order number for purchases, same address for e-mails. |
| Privacy 8, GDPR legal bases and controller | Section 10 GDPR list; the publisher is named as controller in the intro. |
| Privacy 9, children | Kept: 18+ target audience, not directed at under-13s. |
| Privacy 10, full-screen ads | Disclosure kept (tests pin it). |
| Privacy 11, pairing certificate on iPhone | Sentence kept (tests pin it). **Still verify DM-108 (3) before any iOS build reaches people outside the team.** |
| Privacy 12, consent regions | Worded as examples, including US states, "depends on the messages we publish in AdMob". |
| Privacy 13, Privacy Sandbox and SKAdNetwork | Kept as "may"; matches the store forms. |
| Privacy 14, PDPA in Malay | Malay version written (`privacy-policy.ms.md`, hosted at `/privacy/ms`); section 10 "Malaysia" is the s.7 notice (21-day answer to access requests). |
| Privacy 15, "anonymous" | Already fixed 2026-11-07. |
| Privacy 16, IP addresses and location | Section 3 intro: every service sees the IP address and may derive approximate location. |
| Terms 1, liability cap | Greater of 12 months' payments and RM 50; carve-outs for death or injury by negligence, fraud and the Consumer Protection Act 1999. |
| Terms 2, governing law and courts | Malaysia (owner); courts of Malaysia, without removing the user's local courts or the Tribunal for Consumer Claims. |
| Terms 3, cancel paths | Play: Payments & subscriptions → Subscriptions; iPhone: Settings → your name → Subscriptions. |
| Terms 4, Apple's EULA | Apple's standard EULA, with Apple's required third-party-beneficiary and no-support wording. |
| Terms 5, Wake-on-LAN | "available only where the app says so". |

## Still to do outside the text

1. **AdMob → Privacy & messaging:** besides the GDPR message (runbook step 4), publish the **US states regulations** message, so "Ad privacy choices" appears for US users as the policy says.
2. **The publisher on the stores must match:** the Play and App Store developer name and address should be Newy Enterprise, Selangor, Malaysia. If the app is first published from the Digital Linked account (decision #61), either name Digital Linked in `placeholders.json` until the transfer, or publish from a Newy Enterprise account.
3. **GDPR representative (Art. 27):** a business outside the EU that offers an app to people in the EU may need an EU (and a UK) representative. Ask a lawyer, or leave the EU and UK out of the app's availability until it's settled.
4. **US state laws** apply only above their size thresholds; the section is written so it is accurate either way.
5. **Malaysia PDPA 2024 amendments:** breach notification (section 7 says we notify as the law requires) and the data protection officer duty apply by size; check the Commissioner's current thresholds as the app grows.
6. **Native Malay review** of `privacy-policy.ms.md` and `terms.ms.md` together with DM-068/DM-113. The translator's uncertain terms: "Seting" (iPhone) versus "Tetapan" (app and Android), "pengawal data", "ID tika apl", "pengecam untuk vendor", "kebolehasingan", "Pelan Seumur Hidup".
7. **iOS checks before any iOS release:** DM-106, DM-112 (Analytics without the ad id), DM-108 (3) (reinstall makes the TV ask for a new code).
