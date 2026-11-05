# Project status

_Last updated: 2026-11-05 by Claude (controller, owner's first real-device run)._

## Current phase

**Phase 9 (release preparation) is on `feat/phase-9-release-prep`, not yet merged; `main` is at Phase 8.** The owner has started testing on the real phone and TV, and the merge waits for the app-button fix and a quiet full check. Nothing was signed, uploaded or hosted (P9-R1).

What remains is the **owner's release work**, in the order of `docs/release/runbook.md`, and the **real-device run** (`docs/knowledge/device-matrix.md`, rows DM-001…DM-113, results empty). The device run gates every upload (runbook step 9).

## Done

- **Owner's real-device requests (decision #53):**
  - **Finding the TV:** fixed and proven on the real TV (448961e). Pairing and connecting work.
  - **Task 9.14, error recording and the error log:** approved. Every failure the user sees is recorded, and Settings → Help → Error log keeps the last 50 errors on the phone.
  - **Task 9.15, real logos:** approved. 27 of 55 apps show a logo. **Not installed on the phone yet.**
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

**App buttons do nothing on the real TV.** Likely the `market://launch?id=` break (learnings; unverified on this TV). Every app sends that link today (`app_entry.dart:20`), `shortcut_repository.dart` stores it in the DB, and `demo_remote_session.dart` parses it.
- **Waiting on the owner:** the code on the TV, to pair a test tool. The link test is written but not in the repo: a throwaway `link_test.dart` and `links.txt` in the session's scratchpad.
- **Then:** per-app deep links in the catalogue, stored rows remapped or resolved from the catalogue at launch, the demo and catalogue validation updated, tests, a decision, and DM-029.

## Next up

**First:** the app-button fix, then `tool/check.ps1` on a quiet machine, a new build on the phone, merge `--no-ff` to `main`, full check on `main`, push, and watch the first CI run.

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
4. **The Mac** (runbook step 12): `pod install`, DM-058/059/066/106/107/112, `tool/release.sh --platform ios`, TestFlight.
5. **Release:**
   - `tool/release.ps1 -Platform android` (step 10);
   - internal → closed → staged production (step 11);
   - App Review with the review notes (step 12);
   - launch week (step 13).
6. **CI:** the first Linux `check` job run is unverified. If the Gradle dry runs time out on a cold runner, warm Gradle in the CI step; never loosen the test.

After launch: `docs/release/launch-ops/v1.1-backlog.md` holds the post-launch backlog. It includes:
- the CLI minors;
- the in-app/system language sync;
- real logos for the 28 apps that still show a letter;
- the store-art list;
- "Anonymous" → "pseudonymous" in `privacyUsageSubtitle`.

## Known flakes and residuals

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

**The code on the TV** blocks the app-button fix.

Everything is a step of `docs/release/runbook.md`; its end has the owner-decision list. In short:

- **Accounts:** Play Console and Apple Developer. Recruit the 12 closed-test testers now.
- **Final name and ids** before the first upload. The placeholders are `Remotely for Android TV` and `com.digitallinked.atvremote`, and that App Store name carries a 2.3.10 risk.
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

- All checks: `powershell -File tool/check.ps1` (Windows) or `tool/check.sh`. It must print "All checks passed."
- App: `flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json` from `app/`. Without the define file, every service stays off.
- Release: `tool/release.ps1 -Platform android [-DryRun]` / `tool/release.sh --platform ios [--dry-run]` (runbook steps 10 and 12).
- Store screenshots: `tool/store_screenshots.ps1` / `.sh` → `build/store-screenshots/`.
- Release docs with values filled: `dart tool/fill_release_docs.dart` from `app/` → `build/release-docs/`.
- Package tests: from `packages/atv_remote`, run `flutter test`, not `dart test` (see learnings).
- CLI: from `packages/atv_remote`, `dart run bin/atv_cli.dart <pair|key|watch|text|hold> <host> ...`.
