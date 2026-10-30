# Phase 7 — Polish and Differentiators Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The v1.0 app looks and feels finished. That means:
- **First run:** an onboarding of three cards (connect, control, apps), with "Try demo" and an honest explanation of the permissions.
- **Motion:** quiet, quick motion that switches off completely with reduce motion.
- **Identity:** an original app icon and splash screen of our own, with no Google or Android TV marks.
- **Carry-overs:** every Phase 7 carry-over in `status.md` closes:
  - Settings can be reached before pairing.
  - The update gate no longer flashes the remote.
  - The consent form is skipped for Premium users.
  - Apps search and the large-text layouts are fixed.
  - The About page is fixed.
  - Remote-feel bugs are fixed.
  - The onboarding storage error no longer leaves its buttons dead.

**Architecture:**
- **No new services and no protocol changes.** `packages/atv_remote` is untouched.
- **Onboarding** stays in `features/onboarding/`. It becomes a three-card `PageView`. Finishing it (Skip, Get started or Try demo) never waits on storage succeeding.
- **Motion:** every animation goes through one helper, `AppMotion.durationOf(context, d)`, which is zero under reduce motion. Page, sheet and dialog transitions follow the same flag through the theme and the two show helpers.
- **The icon is drawn by our own code.**
  - A Dart painter under `app/test/branding/` holds the geometry.
  - Golden tests render it to the master PNGs in `app/assets/branding/`, and an SVG export of the same geometry is checked against the committed file.
  - `flutter_launcher_icons` and `flutter_native_splash` turn the masters into the native resources. One script reruns the whole chain.
- **The carry-overs are fixed in the files that own them.**

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2 (riverpod_generator 4.0.4), go_router 18.1.1, drift 2.34.0, AGP 9.0.1, Kotlin 2.3.20. The only new packages are two **dev_dependencies**, pinned exactly. They were resolved against this workspace with `flutter pub add --dry-run` on 2026-10-30, and both are the newest versions that resolve:
- `flutter_launcher_icons` 0.14.4
- `flutter_native_splash` 2.4.8

They also pull in `image` 4.12.0, `html` 0.15.7, `csslib` 1.0.2, `ansicolor` 2.0.3 and `universal_io` 2.3.1.

Both are code generators: they write PNGs and XML or plist files and don't run inside Gradle. A few things about them are **(unverified)**; Task 7.3 proves them or reports a workaround:
- that what they generate builds with AGP 9.0.1;
- that the generators run in this pub workspace through `flutter pub run`;
- that 0.14.4 supports `adaptive_icon_monochrome`.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md`.
- **Binding parts:**
  - goal 10 (demo mode from onboarding);
  - goal 11 (accessibility, 200% text);
  - goal 12 (layouts);
  - the anti-goal "using 'Google' in the name or icon";
  - the `remote-design-system` screens list (Onboarding: 3 cards + permission explainers) and its motion rules (150–250 ms ease-out, scale 0.94, respect reduce motion).
- **Relation to the master plan:** this plan expands Phase 7 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md`. It keeps that plan's test names (`onboarding_shown_once`, `skip_goes_to_discover`, `reduce_motion_disables_animations`) and its "no Google/Android TV marks" check.
- **Before starting, read:**
  - the `remote-design-system` skill (primary), plus `flutter-app-architecture`, `app-services` (for 7.4) and `store-release` (for 7.3);
  - in `docs/knowledge/decisions.md`: #6, #12, #18, #21, #22, #24, #28, #29, #34, #38, #41 and #42;
  - `learnings.md`, especially the Phase 4–6 gotchas.

## Global Constraints

- **Toolchain:**
  - Flutter 3.44.1 / Dart 3.12.1, `environment.sdk: ^3.12.1`.
  - Lints are `very_good_analysis` 10.3.0 with `public_member_api_docs`, so every public `lib/` member gets a `///` doc.
  - Keep pubspec dependencies sorted.
- **Dependencies:** the only new ones are `flutter_launcher_icons: 0.14.4` and `flutter_native_splash: 2.4.8`, both under `dev_dependencies`, pinned exactly and added by Task 7.3 (`flutter pub add dev:flutter_launcher_icons:0.14.4 dev:flutter_native_splash:2.4.8`). `git add` includes the root `pubspec.lock` (pub workspace). No runtime dependency is added: we never call `FlutterNativeSplash.preserve()`.
- **Branding (CLAUDE.md, spec anti-goals, `store-release`):**
  - **No copied artwork:** never copy code, assets, text or branding from competitor apps (including `docs/competitor-analysis/`).
  - **No third-party marks:** no Google logo, "G" mark, Google four-colour palette, Android robot or Android TV logo or glyph, in the icon, the splash or any name.
  - **The app name:** it never contains "Google". "Android TV" may appear in a name only as the suffix ` for Android TV`.
  - **The placeholder names stay:** `Remotely for Android TV` (prod) and `Remotely Dev` (dev). The owner decides the final name.
  - **Every branding pixel comes from our own painter** (Ruling P7-R6).
- **No secrets:** nothing in this phase touches config files or IDs. `secrets_are_git_ignored` keeps passing.
- **Strings (Ruling P7-R1):** every new Phase 7 string is added to `app/lib/app/l10n/app_en.arb` in **Task 7.1**, each with an `@key` description taken from the "Used for" column. Later tasks reuse existing keys and don't edit the ARB file. If a later task finds it needs a string, it stops and reports the key and the copy to the controller. No hard-coded UI text.
- **Navigation model:**
  - Pushed pages have a back arrow and a title that names the page.
  - Dialogs use `showAppDialog`, sheets use `showAppSheet`, never a stock `AlertDialog`.
  - No ad on onboarding, discovery, pairing or the remote (decision #6). A hub opened before pairing never shows an interstitial (Ruling P7-R7).
- **Accessibility:**
  - Touch targets are ≥ 48 dp (≥ 56 dp for remote keys) and ≥ 8 dp apart.
  - Every new or changed screen, sheet and dialog is tested in four ways: at **320 dp width and 200% text** (no exception thrown and nothing that carries meaning clipped), with a **non-linear** text scaler (`test/helpers/nonlinear_text_scaler.dart`), in light and in dark.
  - Colour is never the only signal.
  - Headers carry `Semantics(header: true)`.
- **Layout:** use `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional` in new or touched layout code.
- **Platform branches** use `defaultTargetPlatform`. Tests use `testWidgetsOn(...)` from `test/helpers/platform_override.dart`. Never `dart:io Platform`.
- **Riverpod 3:**
  - `Override` and `ProviderException` come from `package:flutter_riverpod/misc.dart`.
  - Check `ref.mounted` after every `await` in a notifier.
  - Use `retry: noRetry` on providers whose errors the UI shows.
  - Hold a `container.listen` across an await on an autoDispose `.future`.
  - Auto-dispose actions take their dependencies in the constructor (learnings).
- **Time:** production code uses `clock`. Tests use `fakeAsync` or `tester.pump(duration)`, with no real waits over 100 ms.
- **drift:** widget tests never subscribe to a drift `.watch()` stream. Use the in-memory repositories.
- **Code generation:** `flutter pub run build_runner build --delete-conflicting-outputs`, then `dart format lib test`, both from `app/`. On Windows, revert unrelated `.g.dart` files that changed only in line endings.
- **Goldens:**
  - One `*_golden_test.dart` per subject, `@Tags(['golden'])`, baselines in `goldens/` next to the test, generated on Windows with `flutter test --update-goldens --tags golden <path>`.
  - Branding masters are the one exception: their baselines live in `app/assets/branding/` (Ruling P7-R6).
  - Inspect every new or changed PNG. A golden that changes outside the "expected re-baselines" list of its task is a defect, not a re-baseline. Never commit `failures/` folders.
- **Where commands run:** `flutter` and `dart` from `app/`; `check.ps1` and `git` from the repo root.
- **Before every commit:** `powershell -File tool/check.ps1` must print `All checks passed.`
- **Commits** end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Knowledge files:** don't edit `docs/knowledge/*`, `CLAUDE.md` or `.claude/skills/*`. Put knowledge and skill updates in your task report; the controller applies them.

## Rulings (conflicts and open questions resolved for this phase)

1. **P7-R1 — Strings land with onboarding.**
   - Only onboarding needs new copy, so Task 7.1 adds every Phase 7 key (the table in Task 7.1). The Settings buttons reuse `pageTitleSettings` as their tooltip.
   - `onboardingTitle` and `onboardingBody` are removed. They are used only by the old screen, and no other ARB file exists yet (Malay arrives in Phase 8).
2. **P7-R2 — Onboarding** (amends decision #12's "onboarding placeholder").
   - **Cards:** `/onboarding` is a `PageView` of three cards, in this order: **connect**, **control**, **apps**. Each card has:
     - an illustration: a Material icon in a 96 dp accent-tinted circle, our own and never a logo;
     - a title (`Semantics(header: true)`);
     - a body.

     The connect card adds a network note.
   - **Controls on every card:**
     - **Skip** at the top end. It's hidden on the last card.
     - A page indicator: three dots, the current one wider, and one semantics node "Card N of 3".
     - The primary button: **Next** on cards 1–2, **Get started** on card 3.
     - **Try demo**, a `TextButton` under the primary button.
   - **Paging:**
     - Swiping pages too.
     - System Back on cards 2–3 goes to the previous card; on card 1 it leaves the app as before.
     - Next moves with `animateToPage` (`AppMotion.standard`), or with `jumpToPage` under reduce motion.
   - **Finishing:** Skip and Get started go to `/discover`. Try demo starts the demo and goes to `/remote`.
     - Each finish writes `onboardingComplete = true`, then logs `onboarding_complete` once, then navigates.
     - **A storage write that throws is reported to `crashReporterProvider` and never stops the navigation** (the Phase 6 carry-over). The cost is that onboarding shows again on the next launch.
     - A second tap while finishing does nothing.
   - **Shown once:** after any finish, `resolveInitialLocation` gives `/discover` (or `/remote` once a TV is saved). The route itself stays reachable by URL; nothing links to it.
3. **P7-R3 — Permission explainers.**
   - **Android:** the app needs no runtime permission to find TVs. `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE` and `INTERNET` are install-time permissions; `NEARBY_WIFI_DEVICES` and location are not declared, and `android_queries_test` keeps the five-permission list exact.
     - So Android shows no permission dialog.
     - The connect card's note (`onboardingConnectNote`) says the app only looks on the Wi-Fi network and never asks for location.
   - **iOS:** the system Local Network prompt fires when discovery first browses.
     - So on iOS, **Skip and Get started** first show a themed `showAppDialog`: title `onboardingLocalNetworkTitle`, body `onboardingLocalNetworkBody`, and **one** action, "Continue" (`onboardingContinue`). It is not dismissible by the barrier or Back, the same pattern as the ATT pre-prompt (decision #41). Then the app goes to `/discover`.
     - Try demo doesn't show it, because the demo never browses.
     - It is shown once per onboarding finish. It isn't persisted separately: onboarding itself is shown once.
   - The troubleshooting sheet's existing `troubleshootLocalNetwork` line covers a user who chose "Don't Allow".
4. **P7-R4 — Reduce motion means none.**
   - **The helper:** `AppMotion.durationOf(BuildContext context, Duration d)` returns `Duration.zero` when `MediaQuery.disableAnimationsOf(context)`, else `d`. Every new or touched implicit animation uses it.
   - **Transitions:** under reduce motion, page transitions, `showAppSheet` and `showAppDialog` don't animate:
     - `AppPageTransitionsBuilder` wraps the platform default and returns the child unchanged when the flag is set. It is set in `pageTransitionsTheme` for every `TargetPlatform` in `app_theme.dart`.
     - The sheet and dialog helpers pass `AnimationStyle.noAnimation`.
   - **Exempt** (not motion for this rule): progress spinners, and the system's own UI.
   - **Already compliant, unchanged:** the theme switch is instant (decision #34). The pad pager, the key press scale and the touchpad trail already check the flag.
5. **P7-R5 — Motion vocabulary** (`remote-design-system`: 150–250 ms ease-out):

   | Element | Motion | Duration / curve | Under reduce motion |
   |---|---|---|---|
   | `AppKeyButton` (existing) | scale 0.94 while pressed | `AppMotion.fast`, `AppMotion.curve` | the scale applies in the same frame |
   | `Rocker` halves | the pressed half's icon scales to 0.94 | `fast` | the same frame |
   | `AppTile` and `QuickAppTile` | the square scales to 0.94 while pressed | `fast` | the same frame |
   | `StatusPill` | the dot colour tweens; the label and the action button cross-fade with a size change | `AppMotion.standard` | the new state in one frame |
   | Touchpad trail and edge glow (existing) | fading trail of the first finger; edge glow per step | unchanged | not painted |
   | Touchpad **tap pulse** (new) | a ring at the touch point: radius 0 → 24 dp, accent alpha 0.35 → 0, on a centre tap and on a two-finger back | `standard` | not painted |
   | Onboarding Next | `animateToPage` | `standard` | `jumpToPage` |

   - Nothing loops or repeats.
   - No motion carries meaning on its own: the pill's label and its live region still announce the state.
6. **P7-R6 — Icon, splash and the branding pipeline.**
   - **Concept** (our own): a white D-pad mark. It's a ring with a centre dot and four small outward triangles, on the light accent `#3D5AFE`. It's generic remote-control imagery: no TV outline, no antenna, no robot, no letters, no multi-colour palette.
   - **Geometry** (units on a 108 × 108 canvas, centre (54, 54), which is the adaptive-icon canvas):
     - **ring:** centre radius 22.5, stroke 7 (outer radius 26, inner 19), round;
     - **centre dot:** radius 7;
     - **triangles:** four isosceles triangles, up, right, down and left. Each has an 8-unit base centred 10.5 from the centre and its apex 15.5 from the centre.

     The outer radius 26 sits well inside the adaptive safe zone (radius 33).
   - **Source of truth:**
     - `BrandMarkGeometry` and `BrandMarkPainter({required Color color, Color? background, double zoom = 1})` in `app/test/branding/brand_mark.dart`. They are test code, so nothing ships that the app doesn't use.
     - The painter scales the 108-unit space to `size.shortestSide / 108 × zoom` around the centre. It fills `background` edge to edge when it's given.
     - `BrandMarkGeometry.svg({required String color, String? background, double zoom = 1})` emits the same shapes as SVG (`viewBox="0 0 108 108"`). The test `brand_svg_matches_the_painter_geometry` keeps `app/assets/branding/brand_icon.svg` in sync. It writes the file when `autoUpdateGoldenFiles` is true and compares it otherwise.
   - **Masters:** golden files in `app/assets/branding/`, written by `--update-goldens`. They aren't app assets (not listed under `flutter: assets:`).

     | File | Size px | Content |
     |---|---|---|
     | `icon_full.png` | 1024 | background `#3D5AFE`, mark white, zoom 1.3 (legacy Android ≤ API 25 and iOS) |
     | `icon_foreground.png` | 1024 | mark white on transparent, zoom 1 (adaptive foreground; also the monochrome layer) |
     | `play_store_icon_512.png` | 512 | like `icon_full` (Phase 9 listing) |
     | `splash_light.png` | 768 | mark `#3D5AFE` on transparent, zoom 1.3 (shown at 192 dp; the generator treats it as 4×) |
     | `splash_dark.png` | 768 | mark `#6C8CFF` on transparent, zoom 1.3 |
     | `splash_android12_light.png` | 1152 | mark `#3D5AFE` on transparent, zoom 1 (inside the 768 px circle) |
     | `splash_android12_dark.png` | 1152 | mark `#6C8CFF` on transparent, zoom 1 |

   - **`app/flutter_launcher_icons.yaml`:**
     - `android: true`, `ios: true`;
     - `image_path: assets/branding/icon_full.png`;
     - `adaptive_icon_background: "#3D5AFE"`, `adaptive_icon_foreground: assets/branding/icon_foreground.png`, `adaptive_icon_monochrome: assets/branding/icon_foreground.png`;
     - `min_sdk_android: 24` (the generator can't parse `build.gradle.kts`);
     - `remove_alpha_ios: true`, `background_color_ios: "#3D5AFE"`.

     There is **one icon for both flavors**: the label already tells dev from prod, and per-flavor iOS icon sets would mean editing `project.pbxproj`.
   - **`app/flutter_native_splash.yaml`:**
     - `color: "#F6F7F9"`, `color_dark: "#0F1115"` (the `bg` tokens, so the first Flutter frame doesn't flash);
     - `image: assets/branding/splash_light.png`, `image_dark: assets/branding/splash_dark.png`;
     - `android_12:` with `image`, `image_dark`, `color` and `color_dark` (the Android 12 masters, the same colours);
     - `fullscreen: false`, `web: false`.
   - **The pipeline:** `tool/brand.ps1` and `tool/brand.sh`, run from the repo root. Each runs, in `app/`:
     1. `flutter test --update-goldens --tags golden test/branding`
     2. `flutter pub run flutter_launcher_icons -f flutter_launcher_icons.yaml`
     3. `flutter pub run flutter_native_splash:create --path=flutter_native_splash.yaml`

     The generated native files are committed. Rerun the script whenever the painter changes.
   - **The marks check** has two parts:
     - Automated: `test/platform/branding_test.dart` scans names, labels and the branding folder (Task 7.3).
     - Human: the review checklist item in the Phase exit checklist.
7. **P7-R7 — Settings before pairing** (closes P6-R15's carry-over).
   - **Where:** discovery's app bar and the remote's "No TV selected" app bar each get an `IconButton(Icons.settings_outlined, tooltip: pageTitleSettings)`. It is 48 dp and pushes `AppRoutes.settingsFromSetup` (`'/settings?from=setup'`).
   - **The route:** the `/settings` route builds `SettingsScreen(fromSetup: state.uri.queryParameters['from'] == 'setup')`. The route name stays `settings`, so analytics doesn't change.
   - **Interstitials:** a hub with `fromSetup` never calls `Interstitials.maybeShow`, so no interstitial lands on discovery (decision #6).
   - **Banner:** the hub's banner rules are unchanged. Before pairing, consent hasn't been gathered (only `/remote` starts it), so no banner loads anyway.
   - Every hub row works without a TV: Remote layout's preview has no session (decision #34), and Edit apps works offline.
8. **P7-R8 — The update gate decides on the first frame.**
   - `updateRequiredProvider` compares the compile-time `kAppVersion` with `min_supported_version`. It no longer reads `appInfoProvider`, so there is no loading window in which the remote shows.
   - `kAppVersion` moves from `core/session/remote_client_factory.dart` to `core/config/app_version.dart`, and the factory imports it. The existing test that `kAppVersion` equals the pubspec version keeps it honest (decision #18).
9. **P7-R9 — No UMP form for a Premium user.** This amends P6-R8 and decision #41.
   - **Why we can skip it:** the UMP form asks for consent for Google's ad purposes. A Premium user is shown no ads (decision #42), so asking is noise. Our analytics consent is separate (Privacy choices, decision #39) and unchanged.
   - **The rule:** in `ConsentController._gatherOnce`, after `refresh()`, if `premiumProvider` reports `isPremium` (the cached entitlement counts; `known` doesn't need to be true), the form step is skipped. The result is then:
     - `gathered: true`, `formShown: false`;
     - `canRequestAds` and `privacyOptionsRequired` read from the service as usual.
   - **Ad privacy choices stays reachable:** the silent update still runs every launch, and the Privacy choices row still shows whenever `privacyOptionsRequired` is true.
   - **A cache that was wrong** (for example, a refund):
     - That launch has no banner unless an earlier consent already allows ads. Banner eligibility also needs "Premium known and false" (P6-R9), and `canRequestAds` reflects only an earlier consent.
     - The next launch caches "free" and shows the form.
     - Ads never load without consent.
   - The review prompt treats a skipped form like a form that wasn't required (`formShown: false`).
   - **(unverified)** whether UMP reports the privacy options as required in the EEA before any form was ever shown. If it doesn't, the row stays hidden for that Premium user, who has no ad choice to make; it appears once they are free. The device run checks this with `UMP_DEBUG_GEOGRAPHY=eea`.
10. **P7-R10 — Name-prefix-first search.**
    - `nameMatchRank(String name, String needle)` lives in `features/apps/domain/name_search.dart`. The needle is lower-cased and trimmed. The ranks are:

      | Rank | When |
      |---|---|
      | 0 | the name starts with the needle |
      | 1 | a later word of the name starts with it (words split on whitespace and `-+:&.`) |
      | 2 | the name contains it |
      | 3 | no name match |

    - `AppCatalogue.search` keeps its matches (name or package contains). It orders them by rank, then region-available first, then catalogue order.
    - The Apps screen's "Your apps" filter uses the same rank, keeping list order within a rank.
11. **P7-R11 — Large text.**
    - **Edit apps rows** stack when the name column would be narrower than 160 dp: the icon and the name/package column on the first line, then the three controls (edit, remove, drag handle) on a second line, aligned to the end. The 56 dp minimum row height stays.
    - **Quick-app tiles:** at a text scale whose scaled `labelSmall` size is over 1.3 × its base size, the name takes up to **2** lines and the tile grows to `QuickAppTile.widthOf(context)`. That is `clamp(72 × scaledFont / (1.3 × baseFont), 72, 112)` dp. `heightOf` counts the lines.
    - **About:**
      - It makes a single `ref.watch(appInfoProvider)`.
      - The app name is a header.
      - The version line keeps its height while loading: an `ExcludeSemantics` placeholder `Text(' ', style: secondary)`. So nothing below it moves when the version arrives.
    - **Apps empty state:**
      - The `BannerSlot.clearance` spacer moves inside the empty state's `SliverFillRemaining`, so a list that fits doesn't scroll.
      - The scroll view gets `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`.
    - **Now-on-TV dot:**
      - It gets a 2 dp ring in the square's ink colour: `colourKeyLabelColor(customColor)` on a custom colour, `textPrimary` on the default fill. The total diameter is 12 dp.
      - One `NowOnTvDot` widget serves both tiles.
12. **P7-R12 — Remote feel.**
    - **Power haptic:** exactly one heavy haptic per power action, and only when something is sent: the power key (through `RemoteActions`), or a Wake-on-LAN send attempt after a MAC was found. `needsMac`, `cannotWake` and `notConnected` give **no** heavy haptic. `saveMacAndWake` fires the one heavy haptic, just before its send. This amends decision #22's "exactly one heavy haptic per power action".
    - **Touchpad reach:** the touchpad updates `reach` from the **up** event's position before it decides on a tap. A finger that flicks past the slop between its last move and lifting off is not a tap.
13. **P7-R13 — Out of scope.**
    - **v1.1:** widgets, the notification remote, voice, App Intents/Siri, watch apps.
    - **Phase 8:**
      - `allowBackup`;
      - `InfoPlist.strings` (Malay purpose strings);
      - the update-gate live-region announcement;
      - the pre-prompt insets;
      - the other Phase 8 carry-overs in `status.md`.
    - **Phase 9:**
      - store screenshots and the feature graphic (the 512 icon master is made here only because it costs nothing);
      - the final app name and bundle id;
      - listing copy.

## Review Focus

1. **A first run whose storage write fails, or whose app is killed mid-onboarding, still reaches discovery or the demo.** Onboarding shows again next time, never as a dead button. Test: Task 7.1 `get_started_still_navigates_when_the_write_fails`.
2. **On iOS, the Local Network prompt never appears without context, on the Skip path too.** Tests: Task 7.1 `ios_skip_explains_local_network_before_discovery`, `ios_try_demo_shows_no_permission_dialog`.
3. **A reduce-motion user sees no animation anywhere:** keys, pill, touchpad, onboarding paging, pushed pages, sheets and dialogs. Tests: Task 7.2 `reduce_motion_disables_animations`; Task 7.6 `no_animation_runs_anywhere_with_reduce_motion`.
4. **At 320 dp and 200% text (and a non-linear scaler), the new and changed layouts don't clip or overflow:**
   - onboarding;
   - discovery with its extra app-bar action;
   - the no-TV remote;
   - Edit apps rows;
   - quick tiles;
   - About.

   Tests: Task 7.1 `onboarding_fits_320dp_at_200_percent_text_*`; Task 7.4 `discovery_app_bar_keeps_its_title_at_200_percent_text`; Task 7.5 `edit_apps_rows_stack_at_200_percent_text_on_320dp`; Task 7.6 `every_phase7_screen_fits_320dp_at_200_percent_text`.
5. **The icon and names are ours and store-safe:** no "Google" in any name, an opaque iOS 1024 icon, an adaptive monochrome layer, and a dev APK that still builds after the generators touched the native files. Tests: Task 7.3 `app_names_never_mention_google`, `ios_marketing_icon_has_no_alpha`, `android_adaptive_icon_has_a_monochrome_layer`; Task 7.6 dev APK build.

---

## File Structure

```
tool/brand.ps1, tool/brand.sh                          branding pipeline                                  (7.3)
app/
  pubspec.yaml                                         dev: flutter_launcher_icons, flutter_native_splash (7.3)
  flutter_launcher_icons.yaml, flutter_native_splash.yaml                                                (7.3)
  assets/branding/                                     masters (goldens) + brand_icon.svg                 (7.3)
  android/app/src/main/res/**                          generated icons, adaptive XML, splash styles       (7.3)
  ios/Runner/Assets.xcassets/{AppIcon.appiconset,LaunchImage.imageset,LaunchBackground.imageset}/**,
    ios/Runner/Base.lproj/LaunchScreen.storyboard      generated                                          (7.3)
  lib/
    app/l10n/app_en.arb                                every Phase 7 string                               (7.1)
    app/theme/tokens.dart                              AppMotion.durationOf                               (7.2)
    app/theme/app_theme.dart, app/theme/page_transitions.dart   reduce-motion page transitions            (7.2)
    app/widgets/app_sheet.dart, app_dialog.dart        no animation under reduce motion                   (7.2)
    app/widgets/status_pill.dart, rocker.dart, app_key_button.dart   motion                               (7.2)
    app/router.dart                                    AppRoutes.settingsFromSetup, SettingsScreen(fromSetup) (7.4)
    core/config/app_version.dart                       kAppVersion moved here                             (7.4)
    core/config/update_gate.dart                       uses kAppVersion                                   (7.4)
    core/session/remote_client_factory.dart            imports kAppVersion                                (7.4)
    core/ads/consent_controller.dart                   Premium skips the form                             (7.4)
    features/onboarding/presentation/onboarding_screen.dart   three cards                                 (7.1)
    features/onboarding/presentation/onboarding_card.dart, onboarding_dots.dart,
      local_network_explainer.dart                                                                       (7.1)
    features/remote/presentation/widgets/touchpad.dart tap pulse (7.2); reach from the up position (7.2)
    features/remote/application/power_controller.dart  haptic order                                       (7.2)
    features/remote/presentation/remote_screen.dart    Settings on the no-TV screen                       (7.4)
    features/discovery/presentation/discovery_screen.dart   Settings button                               (7.4)
    features/settings/presentation/settings_screen.dart    fromSetup                                      (7.4)
    features/settings/presentation/about_page.dart     single watch, header, no pop-in                    (7.4)
    features/apps/domain/name_search.dart              nameMatchRank                                      (7.5)
    features/apps/domain/app_catalogue.dart            ranked search                                      (7.5)
    features/apps/presentation/apps_screen.dart        ranked filter, empty state, keyboard dismiss       (7.5)
    features/apps/presentation/widgets/app_tile.dart   NowOnTvDot, press scale (7.5 / 7.2)
    features/remote/presentation/widgets/quick_app_tile.dart, quick_access_row.dart   2 lines, widthOf (7.5); press scale (7.2)
    features/apps/presentation/manage_apps_screen.dart stacked rows                                       (7.5)
  test/
    helpers/failing_preferences.dart                                                                     (7.1)
    helpers/pump_router_app.dart                       disableAnimations parameter                        (7.2)
    branding/brand_mark.dart, branding/brand_assets_golden_test.dart                                     (7.3)
    platform/branding_test.dart                                                                          (7.3)
    features/onboarding/onboarding_screen_test.dart, onboarding_golden_test.dart                         (7.1)
    app/reduce_motion_test.dart                                                                          (7.2)
    app/phase7_flow_test.dart, app/phase7_accessibility_test.dart                                        (7.6)
```

| Task | Master task | Deliverable |
|---|---|---|
| 7.1 | 7.1 | Three-card onboarding, permission explainers, Try demo, the write-error fix, every Phase 7 string |
| 7.2 | 7.2 | Reduce-motion helper and transitions, the motion vocabulary, the tap pulse, touchpad reach, power haptic order |
| 7.3 | 7.3 | Brand painter and masters, launcher icons, splash, the branding scan |
| 7.4 | carry-overs | Settings before pairing, an update gate with no flash, Premium skips UMP, About |
| 7.5 | carry-overs | Prefix search, the dot ring, the Apps empty state, Edit apps stacking, quick tiles at 200% |
| 7.6 | exit | Seams, the reduce-motion sweep, accessibility, goldens, the dev APK |

**Order and parallelism** (one implementer at a time in the shared tree):
- **7.1 first:** it adds the strings.
- **Then 7.2, 7.3, 7.4 and 7.5** in that order. They don't share files except as follows:
  - `pump_router_app.dart` (7.2 adds a parameter);
  - `app_tile.dart` and `quick_app_tile.dart` (7.2 adds the press scale, 7.5 the ring and the width), so run 7.5 after 7.2;
  - `pubspec.yaml`/`pubspec.lock` (7.3 only).
- **7.6 last.**

---

### Task 7.1: Onboarding — three cards, permission explainers and Try demo

**Files:**
- Modify:
  - `app/lib/app/l10n/app_en.arb`
  - `app/lib/features/onboarding/presentation/onboarding_screen.dart`
- Create:
  - `app/lib/features/onboarding/presentation/onboarding_card.dart`
  - `app/lib/features/onboarding/presentation/onboarding_dots.dart`
  - `app/lib/features/onboarding/presentation/local_network_explainer.dart`
  - `app/test/helpers/failing_preferences.dart`
  - `app/test/features/onboarding/onboarding_golden_test.dart` (+ `goldens/`)
- Test: `app/test/features/onboarding/onboarding_screen_test.dart` (rewrite; keep `onboarding_complete_logged_by_both_buttons`, extended to all three exits and renamed `onboarding_complete_logged_by_every_exit`), `app/test/app/l10n/app_localizations_test.dart`

**Interfaces:**
- Consumes:
  - `settingsControllerProvider.notifier.update`
  - `appAnalyticsProvider.notifier.log(AnalyticsEvent.onboardingComplete())`
  - `activeTargetProvider.notifier.startDemo()`
  - `crashReporterProvider` (`recordError(error, stack, reason: 'onboarding write')`)
  - `showAppDialog`, `AppRoutes`, `resolveInitialLocation`
- Produces:
  - `enum OnboardingCardKind { connect, control, apps }`.
  - `class OnboardingCard extends StatelessWidget { const OnboardingCard({required this.kind}); }`. Its content scrolls inside the page.
  - `class OnboardingDots extends StatelessWidget { const OnboardingDots({required this.count, required this.index}); }`: one semantics node, `onboardingProgress(index + 1, count)`.
  - `Future<void> showLocalNetworkExplainer(BuildContext context)` completes when "Continue" is tapped. It isn't dismissible.
  - `OnboardingScreen` becomes a `ConsumerStatefulWidget` (same constructor) with:
    - `Future<void> _finish(_Exit exit)`, where `enum _Exit { skip, getStarted, demo }`;
    - the order: guard → (iOS and not the demo) explainer → write (caught) → log → navigate.
  - Test helper `FailingSharedPreferencesAsync` (extends `InMemorySharedPreferencesAsync`, or implements `SharedPreferencesAsyncPlatform` by delegating reads to one if the class can't be extended) throws `StateError('write failed')` from every `set*`. Install it with `SharedPreferencesAsyncPlatform.instance = FailingSharedPreferencesAsync()` **after** `pumpRouterApp` has opened the store.
- **ARB keys** (exact copy; `{current}` and `{total}` are `int`). Write each `@key` description from "Used for":

  | Key | Copy | Used for |
  |---|---|---|
  | `onboardingSkip` | `Skip` | top-end button on cards 1–2 |
  | `onboardingNext` | `Next` | primary button on cards 1–2 |
  | `onboardingProgress` | `Card {current} of {total}` | spoken page indicator |
  | `onboardingConnectTitle` | `Find your TV` | card 1 title |
  | `onboardingConnectBody` | `Your phone finds your Android TV on the same Wi-Fi network. Pair once with the code your TV shows.` | card 1 body |
  | `onboardingConnectNote` | `The app only looks on your Wi-Fi network. It never asks for your location.` | card 1 note |
  | `onboardingControlTitle` | `Control it from your phone` | card 2 title |
  | `onboardingControlBody` | `Swipe the touchpad or use the D-pad, change the volume and type with your phone's keyboard.` | card 2 body |
  | `onboardingAppsTitle` | `Open apps in one tap` | card 3 title |
  | `onboardingAppsBody` | `Keep your favourite TV apps in a row on the remote and open them without searching.` | card 3 body |
  | `onboardingLocalNetworkTitle` | `Allow local network access` | iOS explainer title |
  | `onboardingLocalNetworkBody` | `Next, your iPhone asks to let this app find devices on your local network. Choose Allow so the app can find your TV. You can change this later in Settings → Privacy & Security → Local Network.` | iOS explainer body |
  | `onboardingContinue` | `Continue` | the explainer's only action |

  Keep `onboardingGetStarted` and `onboardingTryDemo`. Remove `onboardingTitle` and `onboardingBody`.
- Card icons: connect `Icons.wifi_find_outlined`, control `Icons.touch_app_outlined`, apps `Icons.apps_outlined`.

- [ ] **Step 1: Write the failing tests**

```dart
// onboarding_screen_test.dart (pumpRouterApp at AppRoutes.onboarding; analytics as today)
testWidgets('onboarding_shows_three_cards_in_order', ...)
    // 'Find your TV' + 'Card 1 of 3' semantics; Next → 'Control it from your phone'; Next → 'Open apps in one tap',
    // the primary button reads 'Get started' and 'Skip' is gone
testWidgets('swiping_pages_and_back_returns_a_card', ...)  // fling left → card 2; t.pageBack via handlePopRoute → card 1
testWidgets('onboarding_shown_once', ...)                  // master name
    // Get started → store.onboardingComplete true; resolveInitialLocation(settings: store, devices: InMemoryDeviceRepository())
    // == AppRoutes.discover (and AppRoutes.remote once the repository holds a TV)
testWidgets('skip_goes_to_discover', ...)                  // master name: card 1 Skip → DiscoveryScreen, onboardingComplete true
testWidgets('try_demo_opens_the_demo_remote', ...)         // card 2 'Try demo' → RemoteScreen, activeTarget is DemoTarget
testWidgets('onboarding_complete_logged_by_every_exit', ...) // Skip, Get started, Try demo → exactly one 'onboarding_complete' each, no params
testWidgets('get_started_still_navigates_when_the_write_fails', ...)
    // FailingSharedPreferencesAsync installed after pump → Get started → DiscoveryScreen shown;
    // RecordingCrashReporter.errors.single.reason == 'onboarding write'; analytics logged once; no FlutterError
testWidgets('a_double_tap_finishes_once', ...)             // two taps on Get started in one frame → one event, one navigation
testWidgets('connect_card_says_no_location_is_needed', ...) // 'The app only looks on your Wi-Fi network. It never asks for your location.'
testWidgetsOn(TargetPlatform.iOS, 'ios_get_started_explains_local_network_before_discovery', ...)
    // Get started → dialog 'Allow local network access' with exactly one button 'Continue'; tapping the barrier and
    // handlePopRoute leave it open; DiscoveryScreen absent until 'Continue' → DiscoveryScreen
testWidgetsOn(TargetPlatform.iOS, 'ios_skip_explains_local_network_before_discovery', ...)
testWidgetsOn(TargetPlatform.iOS, 'ios_try_demo_shows_no_permission_dialog', ...)
testWidgets('android_shows_no_permission_dialog', ...)     // default platform: Get started → no AppDialog ever, straight to discovery
testWidgets('reduce_motion_jumps_between_cards', ...)      // pumpApp-level MediaQuery disableAnimations: tap Next, one pump() → card 2, !t.hasRunningAnimations
for (final b in Brightness.values) {
  testWidgets('onboarding_fits_320dp_at_200_percent_text_${b.name}', ...) // each card: no exception, buttons ≥ 48 dp, Skip/Next/Try demo hit-testable
}
testWidgets('onboarding_fits_a_non_linear_text_scaler', ...)
testWidgets('onboarding_meets_tap_target_and_contrast_guidelines', ...)  // android/iOS/labeled tap targets + textContrastGuideline, both themes

// onboarding_golden_test.dart  @Tags(['golden'])  pumpForGolden 360x760
testWidgets('onboarding_connect_light', ...); testWidgets('onboarding_connect_dark', ...); testWidgets('onboarding_apps_dark', ...)

// app_localizations_test.dart
test('phase_7_strings_load', ...)  // l.onboardingProgress(2, 3) == 'Card 2 of 3'; l.onboardingContinue == 'Continue'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/onboarding test/app/l10n`
Expected: FAIL (missing keys, widgets and helpers).

- [ ] **Step 3: Implement.**
  1. Add the ARB keys, then run `flutter pub get` (it regenerates l10n).
  2. Write the card, the dots and the explainer.
  3. Rewrite `OnboardingScreen` with the `_finish` order from Interfaces. Keep its constructor, its route and its `AppRouteNames.onboarding`.
  4. Write `FailingSharedPreferencesAsync`.
  5. Run `dart format lib test`.
- [ ] **Step 4: Generate the goldens and inspect them**

Run: `flutter test --update-goldens --tags golden test/features/onboarding/onboarding_golden_test.dart`

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): three-card onboarding with permission explainers and a write-safe finish" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decisions for P7-R1, P7-R2 and P7-R3 (no Android runtime permission, the iOS explainer pattern), and the closed carry-over (the dead "Get started").

---

### Task 7.2: Motion, micro-interactions and remote feel

**Files:**
- Modify:
  - `app/lib/app/theme/tokens.dart` (`AppMotion.durationOf`)
  - `app/lib/app/theme/app_theme.dart` (`pageTransitionsTheme`)
  - `app/lib/app/widgets/{app_key_button,status_pill,rocker,app_sheet,app_dialog}.dart`
  - `app/lib/features/apps/presentation/widgets/app_tile.dart` (press scale only)
  - `app/lib/features/remote/presentation/widgets/{quick_app_tile,touchpad}.dart`
  - `app/lib/features/remote/application/power_controller.dart`
  - `app/test/helpers/pump_router_app.dart` (adds `bool disableAnimations = false`, applied to the same `MediaQuery` as `textScale`)
- Create:
  - `app/lib/app/theme/page_transitions.dart`
  - `app/test/app/reduce_motion_test.dart`
- Test:
  - `app/test/app/widgets/{status_pill,rocker,app_sheet,app_dialog}_test.dart`
  - `app/test/features/remote/widgets/touchpad_test.dart`
  - `app/test/features/remote/power_test.dart`
  - `app/test/features/apps/app_tile_test.dart`
  - `app/test/features/remote/widgets/quick_access_row_test.dart`
  - `app/test/app/theme/app_theme_test.dart` (or the existing theme test file)

**Interfaces:**
- Consumes: `AppMotion`, `MediaQuery.disableAnimationsOf`, `RecordingHaptics`, `FakeWakeOnLan`.
- Produces:
  - `static Duration AppMotion.durationOf(BuildContext context, Duration d)`.
  - `class AppPageTransitionsBuilder extends PageTransitionsBuilder { const AppPageTransitionsBuilder(this.inner); final PageTransitionsBuilder inner; }`. It returns `child` when `MediaQuery.disableAnimationsOf(context)`, else delegates.
    - `appPageTransitionsTheme`: Android `AppPageTransitionsBuilder(PredictiveBackPageTransitionsBuilder())`, iOS and macOS `AppPageTransitionsBuilder(CupertinoPageTransitionsBuilder())`, every other platform `AppPageTransitionsBuilder(FadeForwardsPageTransitionsBuilder())`. If a named builder doesn't exist in Flutter 3.44.1, use that platform's current default and say which in the report.
  - `showAppSheet` and `showAppDialog` pass `sheetAnimationStyle:` / `animationStyle: AnimationStyle.noAnimation` under reduce motion. **(unverified)** that `showDialog(animationStyle:)` exists in 3.44.1. If not, `showAppDialog` uses `showGeneralDialog` with `transitionDuration: Duration.zero` under reduce motion.
  - `StatusPill`: same constructor. The dot uses `TweenAnimationBuilder<Color?>`. The label and the action use `AnimatedSwitcher` inside `AnimatedSize`, all with `AppMotion.durationOf(context, AppMotion.standard)`. **One** live-region node, as now: the outgoing child stays inside the existing `ExcludeSemantics`.
  - `Rocker`: each half's icon in an `AnimatedScale(scale: pressed ? AppMotion.pressScale : 1)`. The pressed state is tracked per half from pointer down/up/cancel, and doesn't affect the hold callbacks.
  - `AppTile` and `QuickAppTile`: the square in an `AnimatedScale`, pressed from `InkWell.onHighlightChanged`.
  - Touchpad:
    - `_PadGestures` gets `onTap: void Function(Offset localPosition)`, called for a centre tap and a two-finger back.
    - `_Feedback.pulse(Offset)` paints the P7-R5 ring; `_TrailPainter` paints pulses (none under reduce motion).
    - `up(int pointer, Offset position)` calls `touch.moveTo(position)` first (P7-R12).
  - `PowerController.press()`: the heavy haptic moves into `_wake` and fires only right before `wakeOnLan.wake(...)` (P7-R12). `saveMacAndWake` reaches the same point, so it fires exactly one.

- [ ] **Step 1: Write the failing tests**

```dart
// reduce_motion_test.dart (pumpRouterApp(disableAnimations: true) at /remote with remoteSessionProvider → a connected
// FakeRemoteSession from test/helpers/fake_remote_session.dart, so the test can push status changes)
testWidgets('reduce_motion_disables_animations', (t) async {   // master name
  // 1. press Volume up: after one pump() the key is at AppMotion.pressScale, !t.hasRunningAnimations
  // 2. the fake session goes to reconnecting: one pump() shows 'Reconnecting…' only (one Text), !hasRunningAnimations
  // 3. touchpad tap: Touchpad.trailKey painter paints nothing (RecordingCanvas / find.byKey + paints..everything)
  // 4. tap Settings: after one pump() SettingsScreen's Scaffold is at Offset.zero and fully opaque, !hasRunningAnimations
  // 5. open the TV switcher sheet / an AppDialog: one pump() → fully shown, !hasRunningAnimations
});
testWidgets('with_motion_the_same_steps_animate', ...)  // same script without the flag: each step hasRunningAnimations after one pump()

// app_theme_test.dart
test('every_platform_uses_the_reduce_motion_page_builder', ...) // buildTheme(...).pageTransitionsTheme.builders: all AppPageTransitionsBuilder

// status_pill_test.dart
testWidgets('status_change_cross_fades_in_200ms', ...)   // connected → offline: at 100 ms both labels present (Opacity between 0 and 1); at 200 ms only 'Offline'
testWidgets('status_pill_stays_one_live_region_while_animating', ...) // mid-transition: exactly one liveRegion node, label of the new status
testWidgets('dot_colour_tweens_to_the_new_status', ...)  // at 100 ms dot colour strictly between success and danger; at 200 ms == danger

// rocker_test.dart
testWidgets('pressed_half_scales_its_icon', ...)          // press up half: its AnimatedScale.scale == 0.94, the other half's 1.0; release → 1.0
// app_tile_test.dart / quick_access_row_test.dart
testWidgets('pressing_a_tile_scales_its_square', ...)

// touchpad_test.dart
testWidgets('tap_paints_a_pulse_that_fades_in_200ms', ...)
testWidgets('reduce_motion_paints_no_pulse', ...)
testWidgets('a_flick_past_the_slop_between_move_and_up_is_not_a_tap', (t) async {
  // down at (100,100); move to (102,100); up event at (100 + kTouchSlop + 4, 100) with no move in between → no dpadCenter tap
});

// power_test.dart
test('heavy_haptic_only_when_a_wake_is_sent', ...)        // disconnected + MAC → one heavy, FakeWakeOnLan.calls == 1
test('no_heavy_haptic_for_needs_mac', ...)                // disconnected, no MAC → PowerOutcome.needsMac, haptics.heavy == 0
test('no_heavy_haptic_when_it_cannot_wake', ...)          // wakeOnLanAvailable false → cannotWake, heavy == 0
test('save_mac_and_wake_fires_one_heavy_haptic', ...)     // press → needsMac (0) → saveMacAndWake → exactly 1
test('power_key_still_gets_one_heavy_haptic', ...)        // connected → RemoteActions heavy once (existing behaviour kept)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app test/features/remote test/features/apps/app_tile_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.** Refactor `AppKeyButton` to `AppMotion.durationOf`; its behaviour is unchanged. Then run `dart format lib test`.
- [ ] **Step 4: Run every test and the goldens**

Run: `flutter test`
Expected: all PASS, with **no golden changes**. Every animation settles to the same final frame. A changed golden is a defect.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): motion vocabulary with reduce-motion transitions, touchpad tap pulse and remote-feel fixes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- decisions for P7-R4, P7-R5 and P7-R12, including the amendment to decision #22;
- the page-transition builders actually used;
- whether `showDialog(animationStyle:)` existed;
- the two closed carry-overs.

---

### Task 7.3: App icon, splash and branding

**Files:**
- Modify: `app/pubspec.yaml` (two dev_dependencies), `pubspec.lock`
- Create:
  - `app/flutter_launcher_icons.yaml`, `app/flutter_native_splash.yaml`
  - `tool/brand.ps1`, `tool/brand.sh`
  - `app/test/branding/brand_mark.dart`, `app/test/branding/brand_assets_golden_test.dart`
  - `app/assets/branding/{icon_full,icon_foreground,play_store_icon_512,splash_light,splash_dark,splash_android12_light,splash_android12_dark}.png`, `app/assets/branding/brand_icon.svg`
  - `app/test/platform/branding_test.dart`
- Generated (committed after inspecting the diff):
  - **Android:** `app/android/app/src/main/res/mipmap-*/ic_launcher.png`, `mipmap-anydpi-v26/ic_launcher.xml`, `drawable-*/ic_launcher_foreground.png` and the monochrome drawables, `values/colors.xml`.
  - **Android splash:** `drawable*/launch_background.xml`, `drawable*/splash.png`, `values*/styles.xml` (incl. `values-v31`, `values-night-v31`).
  - **iOS:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`, the `LaunchImage.imageset` / `LaunchBackground.imageset` files and `Base.lproj/LaunchScreen.storyboard`.
  - The generators may also touch `ios/Runner/Info.plist`. Commit only what they changed and list each file in the report.

**Interfaces:**
- Consumes: Ruling P7-R6 (geometry, colours, sizes, configs).
- Produces:
  - `abstract final class BrandMarkGeometry { static const double canvas = 108; static Path path(double scale, Offset centre); static String svg({required String color, String? background, double zoom = 1}); }`. The ring is drawn as an even-odd annulus path, so the PNG and the SVG use one fill rule.
  - `class BrandMarkPainter extends CustomPainter { const BrandMarkPainter({required this.color, this.background, this.zoom = 1}); }`.
  - The masters (the P7-R6 table) and `brand_icon.svg` (white on `#3D5AFE`, zoom 1.3).
  - `tool/brand.ps1` and `tool/brand.sh` (the P7-R6 pipeline). Each stops at the first failing step.

- [ ] **Step 1: Write the failing tests**

```dart
// brand_assets_golden_test.dart  @Tags(['golden'])
// Each master: tester.view.physicalSize = Size.square(px), devicePixelRatio 1; pump the bare
// RepaintBoundary(key: k, child: CustomPaint(size: Size.square(px), painter: BrandMarkPainter(...)))
// with tester.pumpWidget (no MaterialApp, so transparent stays transparent);
// expectLater(find.byKey(k), matchesGoldenFile('../../assets/branding/<name>.png')).
testWidgets('icon_full_1024', ...); testWidgets('icon_foreground_1024', ...); testWidgets('play_store_icon_512', ...);
testWidgets('splash_light_768', ...); testWidgets('splash_dark_768', ...);
testWidgets('splash_android12_light_1152', ...); testWidgets('splash_android12_dark_1152', ...);
test('brand_svg_matches_the_painter_geometry', ...)
    // autoUpdateGoldenFiles ? write brand_icon.svg : expect(File(...).readAsStringSync(), BrandMarkGeometry.svg(color: '#FFFFFF', background: '#3D5AFE', zoom: 1.3))
test('the_mark_stays_inside_the_adaptive_safe_zone', ...)
    // BrandMarkGeometry.path(1, const Offset(54, 54)).getBounds(): every corner within 33 of (54, 54)

// branding_test.dart (reads files relative to app/)
test('app_names_never_mention_google', ...)
    // Flavor.values displayName; android/app/build.gradle.kts manifestPlaceholders["appName"]; every APP_DISPLAY_NAME in
    // ios/Runner.xcodeproj/project.pbxproj; Info.plist CFBundleName; NSLocalNetworkUsageDescription and NSUserTrackingUsageDescription:
    // none matches /google/i; any 'Android TV' in a name appears only as the suffix ' for Android TV';
    // dev names == 'Remotely Dev', prod names == 'Remotely for Android TV' on all three sources
test('branding_folder_holds_only_generated_files', ...)
    // Directory('assets/branding').listSync() names == the 7 PNGs + brand_icon.svg; no name matches /google|android/i
test('icon_and_splash_configs_use_only_our_masters', ...)
    // every path value in flutter_launcher_icons.yaml and flutter_native_splash.yaml starts with 'assets/branding/'
test('ios_marketing_icon_has_no_alpha', ...)
    // ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png: PNG IHDR width == height == 1024
    // (bytes 16–23 big-endian), colour type byte 25 == 2 (RGB, no alpha)
test('android_adaptive_icon_has_a_monochrome_layer', ...)
    // mipmap-anydpi-v26/ic_launcher.xml contains <background, <foreground and <monochrome; mipmap-xxxhdpi/ic_launcher.png is 192x192;
    // colors.xml ic_launcher_background == #3D5AFE (case-insensitive)
test('splash_background_matches_the_bg_tokens', ...)
    // values/styles.xml + values-v31 reference the light bg #F6F7F9; values-night(-v31) the dark bg #0F1115
    // (assert on whatever colour resource the generator writes; name it in the report)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/branding test/platform/branding_test.dart`
Expected: FAIL (no painter, masters, configs or generated resources).

- [ ] **Step 3: Add the dev dependencies:** `flutter pub add dev:flutter_launcher_icons:0.14.4 dev:flutter_native_splash:2.4.8`
- [ ] **Step 4: Implement** `brand_mark.dart`, the two YAML configs and the two scripts.
- [ ] **Step 5: Run the pipeline and inspect everything**

Run: `powershell -File tool/brand.ps1`
Expected:
- the 7 masters and the SVG are written;
- the launcher-icon and splash generators finish without errors.

Then open every master PNG and check it against the review checklist item (Phase exit). Inspect `git diff --stat` for the native files.

If either generator fails here (in a pub workspace, on `adaptive_icon_monochrome`, or on the `.kts` build file), try the first fix below that works and report it as a learning:
1. Run it with `dart run` from `app/`.
2. Add the missing value to its YAML.
3. As a last resort, hand-write `mipmap-anydpi-v26/ic_launcher.xml` with `<monochrome android:drawable="@drawable/ic_launcher_foreground"/>`.
- [ ] **Step 6: Build the dev APK** (proves the generated resources compile with AGP 9.0.1)

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds.

Then run the app on an emulator or device if one is available: the splash shows the mark on the `bg` colour and the launcher shows the adaptive icon. If none is available, say so; don't claim it.

- [ ] **Step 7: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 8: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add tool/brand.ps1 tool/brand.sh app/pubspec.yaml pubspec.lock app/flutter_launcher_icons.yaml app/flutter_native_splash.yaml app/assets/branding app/test/branding app/test/platform/branding_test.dart app/android/app/src/main/res app/ios/Runner
git commit -m "feat(app): original app icon, adaptive and themed icon, and splash from our own painter" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- the decision for P7-R6;
- the pins `flutter_launcher_icons` 0.14.4 and `flutter_native_splash` 2.4.8, and whether each worked with AGP 9.0.1 and the workspace (the (unverified) items, now answered);
- every generated file;
- the store-release skill note: the 512 icon master and `tool/brand.ps1`.

---

### Task 7.4: Settings before pairing, an update gate with no flash, the Premium consent rule and About

**Files:**
- Modify:
  - `app/lib/app/router.dart` (`AppRoutes.settingsFromSetup`, `SettingsScreen(fromSetup:)`)
  - `app/lib/features/settings/presentation/settings_screen.dart`
  - `app/lib/features/discovery/presentation/discovery_screen.dart`
  - `app/lib/features/remote/presentation/remote_screen.dart` (the no-TV `Scaffold` only)
  - `app/lib/core/config/{app_version,update_gate}.dart`
  - `app/lib/core/session/remote_client_factory.dart`
  - `app/lib/core/ads/consent_controller.dart`
  - `app/lib/features/settings/presentation/about_page.dart`
- Test:
  - `app/test/features/discovery/discovery_screen_test.dart`
  - `app/test/features/remote/remote_screen_test.dart`
  - `app/test/features/settings/settings_screen_test.dart`
  - `app/test/core/config/update_gate_test.dart`
  - `app/test/core/ads/consent_controller_test.dart`
  - `app/test/features/settings/about_page_test.dart`
  - `app/test/core/session/remote_client_factory_test.dart` (import path only)
  - re-baseline `app/test/features/discovery/goldens/*` (the new action)

**Interfaces:**
- Consumes: `premiumProvider` / `TestPremium`, `FakeConsentService`, `interstitialsProvider`, `FakeAdsSdk`, `appInfoProvider`, `FakeConfigSource`, `RecordingLinkOpener`.
- Produces:
  - `AppRoutes.settingsFromSetup = '/settings?from=setup'`.
  - `SettingsScreen({bool fromSetup = false, super.key})`. When `fromSetup` is true, its `PopScope` never calls `maybeShow`.
  - `const String kAppVersion = '1.0.0';` in `core/config/app_version.dart`. Its doc says it must equal the pubspec version.
  - `updateRequired(Ref ref) => isBelowMinimum(kAppVersion, ref.watch(appConfigProvider).minSupportedVersion)`.
  - `ConsentController._gatherOnce` implements Ruling P7-R9. The public API is unchanged.
  - `AboutPage` implements P7-R11's About rules.

- [ ] **Step 1: Write the failing tests**

```dart
// discovery_screen_test.dart
testWidgets('discovery_has_a_settings_button', ...)
    // IconButton tooltip 'Settings', ≥ 48 dp → tap → SettingsScreen with fromSetup true; back → DiscoveryScreen
testWidgets('discovery_app_bar_keeps_its_title_at_200_percent_text', ...)  // 320 dp, 200% and non-linear: no exception, 'Choose your TV' found

// remote_screen_test.dart
testWidgets('no_tv_screen_has_a_settings_button', ...)  // no session → 'No TV selected' + Settings IconButton → hub (fromSetup)

// settings_screen_test.dart
testWidgets('leaving_a_hub_opened_before_pairing_never_shows_an_interstitial', ...)
    // interstitials eligible (config on, launchCount 2, consent canRequestAds, FakeAdsSdk loaded interstitial, free) →
    // open via settingsFromSetup, pop → FakeAdsSdk.interstitialShows == 0; same setup via AppRoutes.settings from /remote → 1
testWidgets('help_privacy_and_feedback_are_reachable_before_pairing', ...)
    // /discover → Settings → Help (FAQ visible) → back → Privacy choices → back → the feedback row exists in Help

// update_gate_test.dart
testWidgets('the_gate_decides_before_app_info_loads', ...)
    // appInfoProvider overridden with a never-completing future; min 9.0.0 → the very first frame shows 'Update required',
    // RemoteBody never built (replaces app_info_still_loading_never_blocks)
testWidgets('the_gate_does_not_depend_on_app_info', ...)  // appInfo throws; min 9.0.0 → blocked; min 1.0.0 → remote (replaces app_info_failure_never_blocks)
test('app_version_constant_lives_in_config', ...)       // kAppVersion imported from core/config/app_version.dart == pubspec version

// consent_controller_test.dart
test('a_premium_user_never_sees_the_consent_form', ...)
    // TestPremium(isPremium: true, known: false) (cached) + FakeConsentService(formRequired: true) → ensureGathered:
    // service.formShows == 0; result.gathered true, formShown false
test('a_premium_user_keeps_ad_privacy_choices', ...)    // privacyOptionsRequired true from the silent update → result and state say true
test('a_free_user_still_gets_the_form', ...)            // PremiumState.free → formShows == 1, formShown true
test('the_skip_reads_ads_permission_from_the_service', ...) // canRequestAds true/false passes through unchanged
// privacy_choices_page_test.dart (or settings flow)
testWidgets('premium_user_sees_ad_privacy_choices_when_required', ...)

// about_page_test.dart
test('about_watches_app_info_once', ...)                // source scan: about_page.dart has exactly one 'ref.watch(appInfoProvider'
testWidgets('about_app_name_is_a_header', ...)          // semantics node with label 'Remotely Dev' has isHeader
testWidgets('about_version_line_keeps_its_height_while_loading', ...)
    // Completer-backed appInfo: Licences row's top offset before completion == after completion
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/discovery test/features/remote/remote_screen_test.dart test/features/settings test/core/config test/core/ads/consent_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement.**
  - Move `kAppVersion` to `core/config/app_version.dart` and update its importers.
  - Make the router and screen changes.
  - Add the consent skip.
  - Rewrite About's header block.
  - Then run build_runner (`update_gate.g.dart` changes), then `dart format lib test`.
- [ ] **Step 4: Re-baseline the discovery goldens and inspect them**

Run: `flutter test --update-goldens --tags golden test/features/discovery`
Expected: only the app-bar action changed.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): settings before pairing, a flash-free update gate, no consent form for premium, about polish" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- decisions for P7-R7, P7-R8 and P7-R9 (amends decision #41 and P6-R8);
- the `app-services` skill note: consent is skipped for Premium;
- the closed carry-overs: Settings reachability, the UpdateGate flash, the UMP ruling, About.

---

### Task 7.5: Apps polish — prefix search, the dot ring, the empty state and large text

**Files:**
- Create: `app/lib/features/apps/domain/name_search.dart`
- Modify:
  - `app/lib/features/apps/domain/app_catalogue.dart`
  - `app/lib/features/apps/presentation/apps_screen.dart`
  - `app/lib/features/apps/presentation/widgets/app_tile.dart`
  - `app/lib/features/remote/presentation/widgets/{quick_app_tile,quick_access_row}.dart`
  - `app/lib/features/apps/presentation/manage_apps_screen.dart`
- Test:
  - create `app/test/features/apps/name_search_test.dart`
  - modify `app_catalogue_test.dart`, `apps_screen_test.dart`, `app_tile_test.dart`, `manage_apps_screen_test.dart`, `test/features/remote/widgets/quick_access_row_test.dart`
- **Expected re-baselines:**
  - goldens that show a now-on-TV dot (the ring): `apps_screen_*` and `quick_access_row_*` where `isCurrent`;
  - any `manage_apps_*` golden taken at 200%;
  - any quick row golden taken at > 130% text.

  Every other golden must stay unchanged.

**Interfaces:**
- Consumes: `colourKeyLabelColor`, `kShortcutColors`, `AppColors`, `contrastRatio`, `BannerSlot.clearance`.
- Produces:
  - `int nameMatchRank(String name, String needle)` (P7-R10).
  - `AppCatalogue.search(String query, {String? region})`, ranked.
  - `class NowOnTvDot extends StatelessWidget { const NowOnTvDot({required this.ringColor, super.key}); static const double size = 12; }` (in `app_tile.dart`). The dot keys `app_tile_current_dot` and `quick_app_current_dot` stay on the inner dot.
  - `static double QuickAppTile.widthOf(BuildContext context)`. `QuickAppTile.width` (72) stays as the minimum. `QuickAppTile.nameLinesOf(BuildContext context) → 1 | 2`.
  - `_AppRowItem` stacks with a `LayoutBuilder` (P7-R11); its semantics are unchanged (the list's Move actions).

- [ ] **Step 1: Write the failing tests**

```dart
// name_search_test.dart
test('name_match_rank_orders_prefix_word_contains', () {
  expect(nameMatchRank('Prime Video', 'pr'), 0);
  expect(nameMatchRank('Amazon Prime Video', 'pr'), 1);
  expect(nameMatchRank('Disney+ Hotstar', 'hot'), 1);   // '+' splits words
  expect(nameMatchRank('Spotify', 'pot'), 2);
  expect(nameMatchRank('Netflix', 'ninja'), 3);
  expect(nameMatchRank('YouTube', '  YOU '), 0);
});
// app_catalogue_test.dart (bundled catalogue)
test('search_ranks_name_prefix_first', ...)
    // for q in ['pr', 'tv', 'you', 'net', 'a']: ranks of c.search(q) are non-decreasing
test('search_lists_region_available_apps_first', ...)   // updated: region order holds within each rank
// apps_screen_test.dart
testWidgets('your_apps_filter_ranks_prefix_first', ...) // shortcuts ['Amazon Prime Video', 'Prime Video'] + query 'pr' → 'Prime Video' first
testWidgets('empty_list_fits_without_scrolling', ...)   // no shortcuts, 800 dp tall: Scrollable position.maxScrollExtent == 0
testWidgets('dragging_the_list_closes_the_keyboard', ...) // CustomScrollView.keyboardDismissBehavior == onDrag
// app_tile_test.dart
testWidgets('now_on_tv_dot_has_a_contrasting_ring', ...)
    // for every kShortcutColors fill and the default fill, light and dark: the ring colour has contrastRatio ≥ 4.5 with the fill;
    // NowOnTvDot is 12x12 and the inner dot is 8x8 and accent-coloured
// quick_access_row_test.dart
testWidgets('quick_tile_names_take_two_lines_at_200_percent', ...)
    // textScale 2.0: Text(name).maxLines == 2; tile width == QuickAppTile.widthOf(...) > 72 and ≤ 112;
    // row height == QuickAppTile.heightOf(context); no overflow
testWidgets('quick_tiles_are_unchanged_at_100_percent', ...)  // width 72, maxLines 1
testWidgets('quick_tiles_fit_a_non_linear_text_scaler', ...)
// manage_apps_screen_test.dart
testWidgets('edit_apps_rows_stack_at_200_percent_text_on_320dp', ...)
    // the name Text is ≥ 160 dp wide; the edit/remove/drag controls are below the name (top > name bottom); each ≥ 48 dp
testWidgets('edit_apps_rows_stay_on_one_line_at_100_percent', ...)
testWidgets('stacked_rows_keep_the_move_actions', ...)  // semantics: Move up/down actions still present, labels unchanged
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/apps test/features/remote/widgets/quick_access_row_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**, then run `dart format lib test`.
- [ ] **Step 4: Re-baseline only the expected goldens and inspect them**

Run: `flutter test --update-goldens --tags golden test/features/apps test/features/remote/widgets/quick_access_row_golden_test.dart`
Expected: only the files in "Expected re-baselines" changed (`git status`).

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): prefix-first app search, ringed now-on-TV dot, and apps layouts at large text" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decisions for P7-R10 and P7-R11, the re-baselined goldens, and the closed carry-overs.

---

### Task 7.6: Seams, the reduce-motion sweep, accessibility, goldens and the phase exit

**Files:**
- Create (tests): `app/test/app/phase7_flow_test.dart`, `app/test/app/phase7_accessibility_test.dart`
- Modify: production files only to fix defects these tests reveal (name each one in the report)

**Interfaces:**
- Consumes: everything above, plus the Phase 6 fakes (`FakeConsentService`, `FakePurchaseService`, `FakeAdsSdk`, `FakeConfigSource`, `RecordingAnalyticsSink`, `RecordingCrashReporter`).
- Produces: no new production API.

- [ ] **Step 1: Write the tests**

```dart
// phase7_flow_test.dart
testWidgets('first_run_skip_then_settings_then_back_to_discovery', ...)
    // fresh store at the resolved initial location (onboarding) → Skip → discovery → Settings → Help → back ×2 → discovery;
    // no interstitial, no banner, analytics: onboarding_complete once, screen names only from AppRouteNames.all
testWidgets('first_run_try_demo_reaches_a_working_remote', ...)  // onboarding → Try demo → remote; Volume up reaches the demo preview
testWidgets('a_storage_failure_never_traps_the_user', ...)  // failing prefs from the start: onboarding → Get started → discovery → Settings opens
testWidgets('premium_in_the_eea_gets_no_consent_form_and_no_ads', ...)
    // region required, cached premium, form required → /remote: no form; /settings: no banner; Privacy choices shows Ad privacy choices
testWidgets('forced_update_still_blocks_onboarding_and_discovery', ...) // min 9.0.0 → 'Update required' on /onboarding and /discover, first frame
testWidgets('no_animation_runs_anywhere_with_reduce_motion', ...)
    // disableAnimations: onboarding Next, Skip, discovery → Settings push, a sheet (manual IP), a dialog, demo remote key press,
    // touchpad tap, status change: after each, one pump() and !t.hasRunningAnimations
test('branding_checks_still_pass', ...)  // re-runs the branding_test expectations (listed here for the exit)

// phase7_accessibility_test.dart: onboarding (each card), the iOS local-network dialog, discovery (with Settings),
// the no-TV remote, About (loading and loaded), Edit apps, the quick row, in light and dark:
testWidgets('${screen}_meets_text_contrast_${b.name}', ...)
testWidgets('${screen}_meets_tap_target_guidelines_${b.name}', ...)
testWidgets('every_phase7_screen_fits_320dp_at_200_percent_text', ...)
testWidgets('every_phase7_screen_fits_a_non_linear_text_scaler', ...)
testWidgets('onboarding_reads_in_order_with_a_screen_reader', ...)  // semantics traversal: Skip?, title (header), body, note, dots, primary, Try demo
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/app/phase7_flow_test.dart test/app/phase7_accessibility_test.dart`
Expected: they may fail. A failure here is a real defect: fix it in the owning file, name the fix in the report, and don't weaken the test.

- [ ] **Step 3: Fix** what the tests revealed.
- [ ] **Step 4: Run every test and the goldens**

Run: `flutter test`
Expected: all PASS. `git status` shows no golden changes beyond those already committed by 7.1–7.5.

- [ ] **Step 5: Build the dev APK with no config**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart` on a tree with no `google-services.json`, no `env/*.json` and no `secrets.properties`.
Expected: build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "test(app): phase 7 seams, reduce-motion sweep and accessibility" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: every defect the tests found, with its fix.

---

## Phase exit checklist

- [ ] **Checks:**
  - `powershell -File tool/check.ps1` → `All checks passed.`, goldens included.
  - `tool/check.sh` passes with goldens excluded.
  - A clean clone with no config builds the dev APK.
- [ ] **Golden PNGs:**
  - **new:**
    - `onboarding_connect_{light,dark}`, `onboarding_apps_dark`;
    - the 7 branding masters in `app/assets/branding/`.
  - **re-baselined:**
    - discovery (7.4);
    - the now-on-TV dot and large-text quick-row/Edit-apps goldens (7.5).
  - **unchanged:** every other golden. 7.2 changed none.
- [ ] **Carry-overs:** every Phase 7 carry-over in `status.md` is closed by a task report:

  | Carry-over | Task |
  |---|---|
  | UpdateGate flash | 7.4 |
  | UMP and Premium ruling | 7.4 |
  | Settings before pairing | 7.4 |
  | Prefix search | 7.5 |
  | Dot ring | 7.5 |
  | Apps empty state | 7.5 |
  | Edit apps at 200% | 7.5 |
  | About | 7.4 |
  | Heavy haptic | 7.2 |
  | Quick tiles at 200% | 7.5 |
  | Touchpad reach | 7.2 |
  | Onboarding write error | 7.1 |
- [ ] **Branding review (human, the "no Google/Android TV marks" check).** The reviewer opens every master PNG and the generated launcher icons and confirms:
  - no Google "G" or logo;
  - no Google four-colour palette;
  - no Android robot, antenna or Android TV logo or TV glyph;
  - no letters;
  - nothing traced from or resembling the competitor's icon (`docs/competitor-analysis/remote-atv/`).

  `branding_test.dart` passes.
- [ ] **Device checks.** Record the results in `learnings.md`. If a device isn't available, say so; don't claim the check passed.
  - **Note10+ (Android 12):** the splash shows the mark on `#F6F7F9`/`#0F1115` with no white flash before the first frame, and the launcher icon is round-masked correctly. Onboarding, then Skip, reaches discovery with no permission prompt. The Settings button works from discovery.
  - **Android 13+ (emulator acceptable):** with themed icons on, the monochrome icon shows.
  - **iPhone, on a Mac:**
    - the icon has no black corners (the alpha was removed);
    - the LaunchScreen shows the mark;
    - the onboarding explainer appears before the Local Network prompt on both Skip and Get started;
    - with `UMP_DEBUG_GEOGRAPHY=eea` and a cached-Premium sandbox user, there is no form and Ad privacy choices is present (the (unverified) item in P7-R9).
  - **Reduce motion on (Android "Remove animations", iOS "Reduce Motion"):** pages, sheets and the pill switch without animation.
  - Follow the live-testing rules: verify the screen before each tap, never press Power without the owner's agreement, restore settings.
- [ ] **Knowledge updates.** The task reports collectively carry these:
  - **decisions:**
    - Rulings P7-R1 to P7-R12, grouped as onboarding (R1–R3), motion (R4–R5), branding (R6), navigation and startup (R7–R8), consent (R9, amends #41), apps and large text (R10–R11), and remote feel (R12, amends #22);
    - the pins `flutter_launcher_icons` 0.14.4 and `flutter_native_splash` 2.4.8.
  - **skills (controller edits):**
    - `remote-design-system`: the motion vocabulary table, reduce motion meaning none, the onboarding structure, the brand mark and its colours.
    - `store-release`: `tool/brand.ps1`, the 512 icon master, the iOS no-alpha check.
    - `app-services`: no UMP form for Premium.
  - **learnings:**
    - how the generators behave with AGP 9 and pub workspaces;
    - whether `showDialog(animationStyle:)` exists;
    - golden files as asset masters;
    - the device-check answers.
  - **status:**
    - Phase 7 done; its carry-overs closed.
    - Carry-overs to Phase 8 as listed under P7-R13, plus anything the tasks deferred.

## Needs the owner

1. **Approve the icon.** The D-pad mark on `#3D5AFE` (P7-R6) is Claude's call.
   - A different artwork or colour means changing only `brand_mark.dart` and rerunning `tool/brand.ps1`.
   - If a designer supplies artwork, it must be original, and it replaces the painter as the source. Commit its vector under `app/assets/branding/` and update the golden tests to compare against it.
2. **The final app name.** The placeholders stay: `Remotely for Android TV` and `Remotely Dev`.
   - There is a conflict to settle: CLAUDE.md says "for Android TV" belongs in descriptive text only, but the placeholder store name contains it. Play's metadata policy is usually read as allowing "for Android TV" as a compatibility statement, but that is (unverified) for a title.
   - Decide this before the first Play closed-test upload, since the package name can never change after it.
3. **An Android 13+ device or emulator** for the themed-icon check, and **a Mac** for the iOS icon, LaunchScreen and Local Network checks (`flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign`).
4. **Questions (defaults in brackets):**
   - Should the dev flavor get its own icon variant? [no: the label differs]
   - Keep the Premium consent-form skip (P7-R9)? [yes]
   - Should onboarding mention Premium? [no: it shows only connect, control and apps, so nothing is sold during onboarding]
