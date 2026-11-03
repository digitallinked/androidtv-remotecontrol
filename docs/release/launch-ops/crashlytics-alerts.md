# Crash alerts and rollout gates

What to switch on in Firebase Crashlytics and the store consoles before the first production release, and the numbers that decide whether a staged rollout goes on, waits or stops. The owner sets all of it up in the consoles; Claude changes nothing there (Ruling P9-R1). Console menus move; where a name below doesn't match, search the console's help for the alert's name.

## What the app sends

- **Crash reports** go to Crashlytics only from release and profile builds, only while Firebase is running, and only while the user's crash-report choice is on (Settings → Privacy choices; decision #39). Debug builds never send.
- **Every report is scrubbed** before it leaves the phone: no TV names, addresses, MACs or pairing codes (decision #39). An issue that seems to show one is a privacy bug: treat it like a fatal in the connect path below.
- **Non-fatal reports with a reason** come from places that catch their own errors. Their reasons, to recognise them in the console: `startup step <n>`, `initial route`, `fresh database`, `launch count`, `onboarding write`, `review prompt flag`, `premium unreadable`, `banner load`, `merge follow-up`, `crash reporter setup`, and `test crash` (dev builds only, from Settings → About → "Send a test crash report").
- **Stack traces are readable** without uploads for Dart code (no obfuscation in v1, Ruling P9-R2). Native frames need the Android mapping file and the iOS dSYMs, which the builds upload (device-matrix DM-107).

## Alerts to switch on (prod project)

In the [Firebase console](https://console.firebase.google.com/), prod project → **Crashlytics** → the alert settings (Google currently reaches them through the bell icon or **Project settings → Alerts**). Switch on, for both the Android and the iOS app:

| Alert | Why | Who gets it |
|---|---|---|
| **New fatal issue** | Any crash nobody has seen before. In launch week, every one is read the same day. | The owner (e-mail and the Firebase mobile app, if installed) |
| **New non-fatal issue** | Our caught errors above; a new reason or a new stack in one is an early warning. Switch it off again after launch week if it is noisy. | The owner |
| **Regressed issue** | An issue that was closed comes back in a newer version. | The owner |
| **Velocity alert** | One issue suddenly affects many users. Set the threshold to **1 %** of users in an hour during the rollout (the console's own default may differ; lower is earlier). | The owner |
| **New ANR issue** (Android) | The app froze for 5 seconds or more. | The owner |
| **Trending stability digest** | A daily e-mail of the issues that grew. | The owner |

- **Who:** alerts go to project members who opted in. Add every person who must react (today: the owner) under **Project settings → Users and permissions**, then each of them switches on the alerts for themselves. A Slack or Jira integration can come later.
- **Play Console:** prod app → **Monitor and improve → Android vitals**, and switch on vitals e-mail notifications under the account's notification settings. Vitals see crashes even from users who turned crash reports off.
- **App Store Connect / Xcode:** crash reports from TestFlight and the App Store appear in Xcode → Window → Organizer → Crashes (opted-in users only). Check them during the TestFlight phase and in launch week.
- **Prove it works** with device-matrix row **DM-110**: a test crash from a dev build reaches Crashlytics and the alert e-mail arrives.

## Rollout gates

**Discover, pair or connect** means an issue whose top frames are in `app/lib/features/discovery/`, `app/lib/features/pairing/`, `app/lib/core/session/`, `app/lib/core/tv/` or `packages/atv_remote/` (in Crashlytics: `package:tv_remote/features/discovery/…`, `package:tv_remote/features/pairing/…`, `package:tv_remote/core/session/…`, `package:tv_remote/core/tv/…`, `package:atv_remote/…`). These are the paths a user can't work around: the app is useless without them.

**Halt** (and don't advance) when any of these is true at any stage:

- **crash-free users below 99.5 %** in Crashlytics (prod project, the new version only, last 24 hours or since the stage began, whichever is shorter);
- **a new fatal issue in discover, pair or connect**, even one user;
- a report that shows TV data (a name, address, MAC or code) despite the scrubber;
- Play's **user-perceived crash rate above 1.09 %** or **user-perceived ANR rate above 0.47 %** (Android vitals). These are Google's bad-behaviour thresholds as this page was written; the owner checks the current numbers in **Android vitals → Overview** before the first rollout and updates this line;
- a kill switch that doesn't apply (`kill-switch-checklist.md`), or an ad-policy warning from AdMob or a store;
- the same new complaint in three or more reviews in a day (`review-response-plan.md`).

**Advance** only when none of the halt conditions has held for the whole minimum time:

| Stage | Who gets it | Minimum time | Advance when |
|---|---|---|---|
| Internal testing (Play) / TestFlight internal | The owner and up to 100 testers | 1 day, and every device row the runbook names for this stage passed | No fatal issue at all; the build was installed from the store, not side-loaded. |
| Closed testing (Play) / TestFlight external | At least **12 testers opted in for 14 days** in a row (a new personal Play account must do this before production) | 14 days | Crash-free users ≥ 99.5 %; no open fatal in discover, pair or connect; testers' feedback triaged. |
| Production, staged **10 %** | 10 % of new and updating users | 48 hours, and at least 100 users on the new version if the stage has that many | All gates green. |
| Production, staged **50 %** | 50 % | 48 hours | All gates green. |
| Production, **100 %** | Everyone | — | Keep watching daily for the first week (`review-response-plan.md`). |

**How to act:**

- **Halt on Play:** Play Console → prod app → **Test and release → Production → Releases** → the release → **Halt rollout**. Users who already have the version keep it; new installs get the previous one.
- **Contain:** if the problem is the ads (a banner over a control, an SDK crash in `banner load`), flip `ads_banner_enabled` to `false` first (`kill-switch-checklist.md`); it reaches active users within a few launches.
- **Fix:** a new build with a higher build number (`pubspec.yaml` `version: X.Y.Z+<build>`), through `tool/release.ps1` again, into internal testing, then **resume** at the stage you halted, not at 100 %.
- **iOS:** the first App Store release (1.0.0) goes to everyone at once. For later versions, choose **Phased release for automatic updates** in App Store Connect (7 days) and use **Pause phased release** as the halt. The gates above apply to TestFlight for 1.0.0 and to each phased release after it.
- **Record** every halt, with the issue link and the fix, in `docs/knowledge/status.md`.
