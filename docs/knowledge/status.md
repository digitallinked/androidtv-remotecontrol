# Project status

_Last updated: 2026-11-12 by Claude (publisher Newy Enterprise, Selangor, Malaysia; before that: website live on Coolify, decision #62; support address `support@newy.my`; the site shows the real app, decision #63)._

## Current phase

**Phase 9 (release preparation) and the design pass are merged to `main`** at the owner's request on 2026-11-06. Nothing was signed, uploaded or hosted (P9-R1).

**On the phone (2026-11-11):** only the renamed dev build `my.newy.remotely.dev` (decision #61), paired and connected to Living Room TV 3; the old `com.digitallinked.atvremote.dev` is uninstalled. Proved on the earlier build: YouTube and Netflix tiles open their apps; Channel 4 opens its Play Store page without dropping the connection (decision #60).

What remains is the **owner's release work**, in the order of `docs/release/runbook.md`, and the **real-device run** (`docs/knowledge/device-matrix.md`, rows DM-001…DM-113, results empty). The device run gates every upload (runbook step 9).

## Done

- **Website live at https://remotely.newy.my on Coolify (2026-11-12, decision #62):** Coolify app `newy-remotely` (`dfxb7lvq0um2lt8xebxnxjfy`) in project Newy on the shared CargoLinked droplet, image `cargolinked/newy:remotely-latest`, one proxied DNS record `remotely` in Newy's Cloudflare zone. `.github/workflows/deploy-web.yml` tests, builds, pushes and deploys on every push to `main` that touches `web/` (`WEB_AUTODEPLOY=on`). Verified live: `/api/health` `{"ok":true}`, every page 200, 404 for unknown paths, sitemap and robots on `https://remotely.newy.my` only, `running:healthy`. Everything is in `docs/hosting.md`. The privacy, terms and support links in the app now work.
- **Website shows the real app (2026-11-12, decision #63):** the hero, the "How it works" steps, a new five-screen row and the share image use screens rendered from the app (`tool/web_screens.ps1` → `web/public/screens/*.webp`); the interactive demo moved to "Try the controls here". The support FAQ matches the in-app FAQ (Play Store page then Open, decision #60; "My TV isn't in the list"). `npm test` (27), typecheck, `next build` (standalone) and `flutter analyze` pass; checked in Chrome at 1440 and 390 px with no sideways scroll. Merged to `main` and pushed at the owner's request, which deploys it. Regenerate the screens after any visible change to those app screens.
- **Support address `support@newy.my` (2026-11-12):** owner's choice; in `docs/release/placeholders.json`, `AppLinks.supportEmail` (feedback mail) and the site's `/support` page.
- **App id, domain and knowledge sharing (2026-11-11, decision #61):**
  - App id `my.newy.remotely` (dev `.dev`) everywhere, with the Kotlin namespace, channel names and `DeviceInfo` vendor `newy` (`86643e3`). Analyze clean; the full suite passed except three load timeouts that pass alone.
  - Privacy, terms and support links point at `https://remotely.newy.my`; `web/content` synced.
  - **Knowledge sharing between agents:** `docs/knowledge/activity-log.md` (who did what, newest first); a SessionStart hook (`.claude/settings.json` → `tool/session_brief.sh`) that shows every new session the branch, last commits, the head of this file and the newest log entries; the `project-knowledge` skill now covers hand-offs, subagents and sharing a checkout; new skills `device-testing` and `marketing-site`.
  - Runbook: the Digital Linked account plan (step 2), the RevenueCat service account (step 5), and "Moving the app to another Play account".
- **Production pass (2026-11-07, decisions #57–#58):**
  - **The iOS app was built for the first time,** with no Mac of ours: the Device builds workflow (`.github/workflows/device-builds.yml`) builds both flavors with Xcode 26.6, inspects `Runner.app` and runs both flows on a simulator. On API 26 and 35 emulators it runs the flows and a **prod release build** from a clean install. All green in run 42334046970. Manual only (Actions tab or a `diag/**` push); the repo is public, so it costs nothing.
  - **Default apps follow the phone's country** (SIM, then network; iOS Region), not the language (decision #57). Proved on an API 35 R8 build: British language, US SIM, US row.
  - **Catalogue:** Disney+ Hotstar (retired 2025-10-09, no Play listing) replaced by Disney+ in the MY and ID rows; Astro GO, sooka and Tonton added for MY (ids from their Play listings, V11-12 done). All 58 ids checked against Google Play; 54 found, the other four look like TV-only listings the website doesn't show (`uk.co.bbc.iplayer`, `deezer.android.tv`, `com.google.android.youtube.tvkids`) plus the retired Hotstar id.
  - **iOS privacy manifest:** `PrivacyInfo.xcprivacy` declares file timestamps (C617.1) and disk space (E174.1), because `sqlite3.framework` from the build hook references `stat` and `statfs` and has no manifest. With `FIREBASE_ANALYTICS_WITHOUT_ADID=true`, `GoogleAppMeasurementIdentitySupport` is absent; without it, it ships.
  - **Privacy wording:** usage data is "tied to a random ID and not to your name", no longer "anonymous" (V11-17 done; Malay through DM-068).
  - **Store rules checked** (runbook "Store rules checked on 2026-11-07"): target API 36, Billing Library 8.3.0 and 16 KB pages all hold. Added: EU DSA trader status, the D-U-N-S exemption, the newer Apple age-rating questions.
  - **Device rows recorded:** DM-056 Pass (backup not allowed), DM-058, DM-062, DM-063, DM-117 Pass; DM-116 step 1 passed (the `→` draws); partial notes on DM-038, DM-066, DM-103, DM-104, DM-106, DM-112.
  - **Release dry run:** refuses five owner-config items per platform and nothing else (DM-104 notes).
- **Marketing site, live on Vercel (2026-11-07, decision #59):** public at https://remotely-woad.vercel.app, deployed from this PC with the CLI (Vercel project `remotely`, team Newy's projects). Later `vercel deploy` runs from `web/` are previews unless given `--prod`, and pushes don't deploy because the repo isn't connected. `web/` holds the home page with a working remote demo, `/support`, `/privacy`, `/terms`, the share image, sitemap and robots.
  - **Verified 2026-11-07:** 27 unit tests, the typecheck and a production build pass. Chrome checks passed 27 of 27 against a production build: mouse, touch, keyboard, widths 320, 390 and 1440, no console errors, no owner notes on the legal pages. The script is throwaway and isn't in the repo.
  - **Live site, 2026-11-07:** the same 27 Chrome checks passed against the deployed address. Every route answers as expected, and an unknown path gives 404.
  - **Not verified:** Safari, and a real phone (including whether iOS shows its keyboard on OK).
  - **Waiting on the owner:** the domain. See "Blocked / needs the owner".
- **CI, app links and release script (2026-11-06):**
  - **CI is green on `main`, the first time on record** (`b6acba6`, run 42225620223): goldens 61, app 2337 with 5 skipped, Gradle 7, atv_remote 208. Three bugs were stacked, each hiding the next (learnings):
    - `real_fonts.dart` hardcoded the lower-case font names that only Windows has. `materialFontFile` now matches without case, with a test that catches this on Windows too.
    - The Gradle tests ran `sh gradlew`, and Ubuntu's `sh` can't run it. They use bash now, and the workflow warms Gradle first.
    - The test's `_Peer` had no `socket.done` handler. The real clients do, so users were never exposed.
  - **App buttons (decision #56):** six apps send a published deep link, resolved at launch by `AppCatalogue.launchLinkFor`, so saved shortcuts need no migration. The demo follows.
  - **Release wrappers:** `tool/release.ps1` and `.sh` run `flutter clean` before they build, and a failed clean stops the build.
  - **Verified 2026-11-06, under load from another job (CPU at 100 %):** format and analyze clean; app 2402 passed, 1 skipped, 0 failed. In that run the first two Gradle tests hit the 2-minute limit on a cold Gradle straight after `flutter clean`, which stopped the script before atv_remote. Rerun on the same code: Gradle 7 of 7, atv_remote 208 of 208. So every step has passed on this code, but not in one `tool/check.ps1` run.
- **Design pass (decision #54, 2026-11-06):**
  - **Identity:** a brand-hue ink palette, Atkinson Hyperlegible Next and Mono bundled, and `Relief` / `KeySurface` deriving moulded keys from any palette. The icon and store art are unchanged; the native splash follows the new `bg`.
  - **Remote:** the D-pad is the app's mark as a control (backlit ring, lit arc, accent OK key with a real label); a recessed touchpad with a dot matrix that lights under the thumb; `PadTabs` replaces the `SegmentedButton`; the cluster runs out to the pad's edges; the status lamp is calm while connected, in a strip that never changes height; the quick row lines up with the pad and fades where it scrolls.
  - **Everywhere else:** `AppPanel` on Settings, Your TVs and discovery; complete component themes (fields, snack bars, buttons, list rows); a backlit badge on onboarding; logo tiles get an edge; sheet rows line up with their titles; the paywall's benefit hierarchy; the error log's empty state.
  - **Copy:** "Swipe to move, tap to select" (en, ms). Other wording untouched.
  - **Verified 2026-11-06:** format and analyze clean; app 2389 passed, with two failures in the full run while `ffmpeg` and headless Chrome from another job held the CPU at 94 %. Both are the known load flakes. The latency test then passed 3 of 3 alone (p95 10 to 20 ms). `discover_pair_press_key_flow` passed 8 of 8 alternating with a pristine `HEAD` checkout, which also passed 8 of 8, under the same load. Gradle +7, atv_remote +208 twice, 52 goldens regenerated. No complete green `tool/check.ps1` yet.
- **Owner's real-device requests (decision #53):**
  - **Finding the TV:** fixed and proven on the real TV (448961e). Pairing and connecting work.
  - **Task 9.14, error recording and the error log:** approved. Every failure the user sees is recorded, and Settings → Help → Error log keeps the last 50 errors on the phone.
  - **Task 9.15, real logos:** approved. 27 of 55 apps show a logo. Seen on the phone in a release build on 2026-11-06; DM-115 still to be worked through.
- **Phase 9 (release preparation, decisions #51–#52):**
  - **Release checker:** `app/tool/release_check.dart` with the `tool/release.{ps1,sh}` wrappers. It refuses an incomplete prod build, listing every problem at once. Stages: pre, manifest and post.
  - **Android:** `key.properties` signing; the prod bundle refuses the test or malformed AdMob id and debug signing (`taskGraph` backstop); `localeConfig`; R8 with the Crashlytics mapping upload.
  - **iOS scaffolding (unverified, Mac):** Podfile at 15.0, per-flavor xcconfigs, the "Check AdMob app id" phase, the Crashlytics dSYM upload (Pods or SPM), and Ad-ID-free Analytics under SPM.
  - **App:**
    - a fresh database resets the onboarding, ATT pre-prompt and seeded flags, and deletes the stored pairing identity, so a reinstalled iPhone gets a new certificate;
    - `defaultTargetPlatform` replaces `dart:io` Platform;
    - every page and error state passes the no-cut text sweep;
    - ads are capped at G (fail closed, reported);
    - the label "Natural hold" replaces the competitor's "Smooth Press" (P9-C10).
  - **CLI:** atomic identity write; `hold` releases on Ctrl+C and reports a dropped connection.
  - **Docs (`docs/release/`):**
    - `placeholders.json` and `fill_release_docs.dart`;
    - DRAFT privacy policy and terms;
    - English and Malay store copy (Malay UNREVIEWED);
    - the feature graphic and the screenshot generator (`tool/store_screenshots.*`);
    - nine store-form drafts;
    - Apple review notes and the demo-video script;
    - the rename checklist;
    - **the release runbook** and its owner-decision list;
    - launch-ops docs and the v1.1 backlog.
  - **Tests:** app +2261, gradle-tagged +7, atv_remote +208, before the owner's requests; final counts come with the next full check.
- **Phase 8 (quality and hardening):**
  - **Release blocker closed in code** (decision #49): Android backup and device transfer off (`allowBackup`, `fullBackupContent`, `data_extraction_rules.xml`; verified in the devDebug and prodRelease merged manifests). iOS DB in a backup-excluded `Application Support/Database` via a small Swift channel; keychain this-device-only; a fresh DB re-seeds the Apps row. New-phone FAQ.
  - **Tests:** the fake TV is a test library (`package:atv_remote/testing.dart`); discover → pair → key and demo flows run on the host and on a device; key-press latency (p95 < 30 ms, host) and a 50-cycle resume leak test; `tool/measure_android.{ps1,sh}` for cold start, trace and battery (device numbers not yet measured).
  - **Accessibility:** every screen, sheet and state meets the four guidelines in light and dark, at 320 dp / 200 % and the non-linear scaler; reduce motion closed for Radio, Switch and the decorator.
  - **Hardening:** `noRetry` storage errors, MAC cleared with a distrusted pin, usage pruning, NSD stop/cancel, narrowed catches, RTL split layout, one `connectionTroubleProvider`, crash reports held until saved TV names are known.
  - **Malay:** complete `app_ms.arb` (strict parity), Malay iOS purpose strings, pseudo-locale and Malay overflow sweeps. Decisions #49–#50.
- **Phase 7 (polish):** onboarding (3 cards, Try demo, iOS Local Network explainer); page transitions and a full reduce-motion mode (decision #47); original icon and splash (decision #48); Settings reachable before pairing; Apps search polish; large-text layouts. Decisions #46–#48.
- **Phase 6 (services & monetisation):** Firebase Analytics, Crashlytics and Remote Config behind config checks (startup order, decision #38); scrubbing reporter and analytics guard; UMP consent, Privacy and Ad privacy choices; iOS ATT pre-prompt; AdMob banner on `/apps` and the `/settings` hub only; interstitials off by default; RevenueCat Premium with offline cache and paywall; review prompt. Decisions #38–#45.
- **Phase 5 (apps, devices, settings, help):** bundled app catalogue and region default rows; Apps screen, Edit apps, custom shortcuts, recommendations; Your TVs and Edit TV; Settings hub, Appearance, Remote layout, Remote behaviour; Help and About. Decisions #27–#37.
- **Phase 4 (remote experience):** the input path (`RemoteActions`: refusals, Natural hold, repeat, stuck-key guard, haptics); touchpad, D-pad and numbers pager; quick-access row; bottom cluster; keyboard sheet; Power, Wake-on-LAN and the MAC sheet; Keep Screen Awake; Theater Mode. Decisions #20–#26.
- **Phase 3 (connect flow):** discovery (NSD and manual IP), the pairing wizard with a TOFU pin, `RemoteSession` and `SessionSupervisor`, the remote screen shell, demo mode, `WakeOnLanService`. Decisions #13–#19.
- **Phase 2 (app shell):** tokens and theme, base components with goldens, ARB l10n, drift DB and `DeviceRepository`, secure `IdentityStore`, `SettingsStore`, go_router, `bootstrap`, dev/prod flavors.
- **Phase 1 (protocol library):** protobufs, framing, client identity, pairing secret, `FakeTvServer`, `PairingClient`, `RemoteClient`, `TvConnection`, Wake-on-LAN, discovery model, CLI.
- **Phase 0:** monorepo scaffold, lints, `tool/check.ps1`/`.sh`, CI.

## In progress

Nothing. **App buttons fixed and proved on Living Room TV 3 on 2026-11-11** (decision #60, DM-029 Pass): real taps on the YouTube and Netflix tiles open the apps and read "now on TV"; tiles without a deep link open the app's Play Store page (press Open), and the remote stays connected. `market://launch` had been rejected with an error and a dropped connection. Still unproved: Prime Video's link (lands on Android's chooser).

## Next up

**First:** DM-116 steps 2–6 in a dim room, and the rest of the device run with Claude (the phone and TV are available on request).

**Before any store upload:** run a **prod** release build on a real phone. It runs on API 26 and 35 emulators (DM-117), not yet on the Note10+.

Then:

1. **The owner works through `docs/release/runbook.md`**, in order:
   - **Lead-time items first:** recruit the 12 closed-test testers (the 14-day test starts once a build is uploaded) and request the Apple multicast entitlement.
   - **Step 1:** the final app name and ids (`docs/release/rename-checklist.md`). The Play package name is permanent.
   - **Step 2:** accounts.
   - **Step 3:** Firebase.
   - **Step 4:** AdMob. Publish the UMP GDPR message and set the **G** content cap in the console.
   - **Step 5:** RevenueCat.
   - **Step 6:** the legal pages, `placeholders.json` and `dart tool/fill_release_docs.dart` (from `app/`).
   - **Step 7:** the upload keystore and `key.properties`, then DM-105.
2. **The device-matrix run with Claude** (runbook step 9): DM-001…DM-113, with the Android gates DM-056/057 before the first upload. The iOS restore and Quick Start gates DM-060/061 come before TestFlight external, and so does DM-108 (3): a reinstall must ask for a code again. **Ask before any Power or Wake-on-LAN step.**
3. **The Malay sign-off** (runbook step 8, DM-068), including "Tahan semula jadi", before any Malay listing.
4. **The Mac** (runbook step 12): signing, the archive, DM-059/066/106/107/112 (DM-058 passed in CI), `tool/release.sh --platform ios`, TestFlight. The Device builds workflow covers compiling, not signing.
5. **Release:**
   - `tool/release.ps1 -Platform android` (step 10);
   - internal → closed → staged production (step 11);
   - App Review with the review notes (step 12);
   - launch week (step 13).
6. **CI:** green. The workflow warms Gradle before `tool/check.sh`; if the dry runs ever time out on a cold runner, warm more there and never loosen the test.

After launch: `docs/release/launch-ops/v1.1-backlog.md` holds the post-launch backlog. It includes:
- the CLI minors;
- the in-app/system language sync;
- real logos for the 30 apps that still show a letter;
- the store-art list.

## Known flakes and residuals

- **Design pass residuals:**
  - Only DM-116 can judge the ring, dots, key travel and glare in a real dim room. On the phone so far: launch, the remote screen and the live connection, looked at with no taps.
  - The `→` in 28 strings has no glyph in the bundled face and relies on system font fallback (DM-116 step 1). `flutter test` draws a box for it.
  - Store screenshots are git-ignored: run `tool/store_screenshots.ps1` to see the new look in them.
  - The Malay layout is covered by the sweeps, but nobody has judged the new face in Malay (DM-113).

- **Under heavy machine load:** `discover_pair_press_key_flow` (a 20 s wait) and the atv_remote latency p95 (30 ms) can fail. Both pass alone. Run the final full check on a quiet machine, and keep the thresholds.
- **Fresh-database residuals:**
  - A preference reset that fails or times out leaves the old values for that launch.
  - An identity delete that **fails** keeps the old pairing certificate until the next reinstall. One that only times out usually completes later, and `loadOrCreate` waits up to 5 s for it.
  - Both failures go to the crash reporter. It is still in its hold phase then, so they are only logged on the device and never reach Crashlytics (decision #50).
- **Error log residuals:**
  - `AppDatabase.filePath()` is proven on Windows only; if it answers empty on a phone, the log stays in memory (DM-114 step 5 catches it).
  - An error naming a TV the phone has never seen keeps that name.
  - The typed paths were traced on 2026-11-05 and found clean; the keyboard path is safe by construction, not by scrubbing.
- **Logo residuals:** the release compile path is proven by a desktop AOT stand-in only (DM-115 runs it on a phone); HBO Max reads "max"; "First letter" in the shortcut editor shows the logo on a mapped package; a failed logo load leaves no trace.

## Blocked / needs the owner



**The marketing site (decision #59)** needs, from the owner:
- done 2026-11-12: the site is live on `https://remotely.newy.my`, hosted on Coolify (decision #62, `docs/hosting.md`). The old Vercel project `remotely` still exists, unused; delete it when the owner agrees;
- done 2026-11-12: `SUPPORT_EMAIL` is `support@newy.my` (owner's choice) in `placeholders.json`, `AppLinks.supportEmail` and `web/content`; `/support` now shows it. Whether the mailbox receives mail is unverified;
- done 2026-11-12: publisher `DEVELOPER_NAME` = Newy Enterprise, `DEVELOPER_ADDRESS` = Selangor, Malaysia (owner's values) in `placeholders.json` and `web/content`. The legal pages stay labelled Draft until `EFFECTIVE_DATE`, `ANALYTICS_RETENTION` and `GOVERNING_LAW` are set too;
- done 2026-11-11: `PRIVACY_POLICY_URL`, `TERMS_URL` and `SUPPORT_URL` (`/support`) in `placeholders.json` and `AppLinks` point at `remotely.newy.my`, and `web/content` is synced. They work since 2026-11-12;
- `web/public/app-ads.txt` once the AdMob publisher id exists (`docs/release/forms/app-ads-txt.md`);
- `site.stores` in `web/lib/site.ts` at launch.

Everything else is a step of `docs/release/runbook.md`; its end has the owner-decision list. In short:

- **Accounts:** Play Console and Apple Developer. Recruit the 12 closed-test testers now.
- **Final name** before the first upload. The ids are final: `my.newy.remotely` and `.dev` (decision #61). The placeholder name is `Remotely for Android TV`, and that App Store name carries a 2.3.10 risk.
- **Play account:** publish first from the existing Digital Linked account, then transfer the app to the new company account once its D-U-N-S number arrives (decision #61). Check whether Digital Linked is an organisation account or a personal one made before 13 November 2023; if so, it skips the 12-tester closed test.
- **Real config:**
  - Firebase dev/prod and the four config files;
  - AdMob apps and units, the UMP GDPR message, `app-ads.txt`, the **G** cap, and the AdServices permissions (default keep);
  - RevenueCat and the store products. Confirm the prices, the style names Ocean, Ember and Midnight, and that interstitials stay off.
- **The upload keystore:** made by the owner outside the repo, then `key.properties` and Play App Signing.
- **Legal:**
  - review and host the policy and terms;
  - fill `placeholders.json` and update `AppLinks`;
  - `GOVERNING_LAW`;
  - `APP_STORE_ID` once the App Store record exists.
- **Export compliance:** `ITSAppUsesNonExemptEncryption` and the France declaration.
- **Malay sign-off** (DM-068).
- **The device matrix and the Mac rows.**
- **The real Malaysian app ids** (from the TV).
- **Logos:** on by the owner's decision of 2026-11-05 (runbook item 10). The brands have given no licence, so the risk stands.
- **Privacy policy:** the crash-report sentence was narrowed on 2026-11-05 so it promises only what the scrubber does; review it with the rest of the draft.
- **Apple multicast entitlement** for Wake-on-LAN on iOS.
- **Optional:** delete the stale git-ignored golden `failures/` folders under `app/test/`.

## Test hardware

- Phone: Samsung Galaxy Note10+ (SM-N975F, Android 12), reachable over ADB Wi-Fi when the owner enables it.
- TV: MediaTek-based Android TV "Living Room TV 3" on the home LAN (192.168.0.x).

## How to run things

- iOS build and emulator checks: Actions tab → Device builds → Run workflow, or push a `diag/**` branch (decision #58).

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`. It must print "All checks passed."
- App: `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` from `app/`. Without the define file, every service stays off.
- Release: `tool/release.ps1 -Platform android [-DryRun]` / `tool/release.sh --platform ios [--dry-run]` (runbook steps 10 and 12).
- Store screenshots: `tool/store_screenshots.ps1` / `.sh` → `build/store-screenshots/`.
- Release docs with values filled: `dart tool/fill_release_docs.dart` from `app/` → `build/release-docs/`.
- Package tests: from `packages/atv_remote`, run `flutter test`, not `dart test` (see learnings).
- Marketing site: from `web/`, `npm run dev`, `npm test`, `npm run typecheck`, `npm run build`. After a change in `docs/release/legal/` or `placeholders.json`, run `npm run sync:release`.
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch|text|hold> <host> ...`.
