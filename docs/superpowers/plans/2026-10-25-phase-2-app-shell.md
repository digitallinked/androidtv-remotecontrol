# Phase 2 — App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the placeholder `app/` into a themed, localised, routed Flutter shell with local storage, a secure client identity and dev/prod flavors. It launches into an empty-state Discovery screen, and its golden tests pass in light and dark.

**Architecture:** Design tokens become a `ThemeExtension` plus `ThemeData`. The design-system widgets build on them. Storage is three plain-Dart classes (drift DB + `DeviceRepository`, `IdentityStore` over a secure key-value abstraction, `SettingsStore` over `SharedPreferencesWithCache`) exposed to the UI through Riverpod 3 codegen providers. go_router picks the start route once, at bootstrap, from stored state. `bootstrap(Flavor)` installs error handlers that forward to a `CrashReporter` interface (logging only until Phase 6) and runs optional startup steps, each of which may fail without stopping the app.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, flutter_riverpod 3.3.2 + riverpod_generator 4.0.4, go_router 18.1.1, drift 2.34.0 (sqlite3 3.x through build hooks), flutter_secure_storage 11.2.0, shared_preferences 2.5.6, dynamic_color 2.1.0, flutter_localizations + intl 0.20.2, very_good_analysis 10.3.0.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md` (binding). This plan expands Phase 2 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md` and keeps its interfaces except where a **Ruling** below says otherwise. Read the `flutter-app-architecture`, `remote-design-system` and `store-release` skills before starting. The `app-services` skill gives the bootstrap order that Phase 6 fills in.

## Global Constraints

- Flutter 3.44.1 / Dart 3.12.1 (decision #8). `environment.sdk: ^3.12.1`. Lints: `very_good_analysis` 10.3.0. `public_member_api_docs` is on, so every public `lib/` member gets a `///` doc. Keep pubspec dependencies sorted (`sort_pub_dependencies`).
- Pin every new app dependency to an **exact** version, the one given in its task. The versions below were checked with `flutter pub add --dry-run` against this workspace on 2026-10-25.
- Android minSdk 24, targetSdk ≥ 35. iOS deployment target 13.0.
- Application ids: prod `com.digitallinked.atvremote`, dev `com.digitallinked.atvremote.dev`. Display names: prod `Remotely for Android TV`, dev `Remotely Dev`. Never "Google" in the name or icon.
- No socket, TLS or protobuf code in `app/`. The app imports only `package:atv_remote/atv_remote.dart`.
- English strings in `app/lib/app/l10n/app_en.arb` only. No hard-coded UI text (test-only strings are fine).
- Text contrast ≥ 4.5:1. Remote keys ≥ 56 dp, all other touch targets ≥ 48 dp. Text scaling to 200% reflows without overflow.
- Firebase, AdMob and RevenueCat config files don't exist yet. Nothing in this phase may need them to build, test or run.
- Generated code (`*.g.dart`, `lib/app/l10n/app_localizations*.dart`) is committed and excluded from the analyzer. After every `build_runner` run, run `dart format lib test` from `app/` so `tool/check.ps1`'s format check passes.
- Goldens: one file per widget, named `*_golden_test.dart`, annotated `@Tags(['golden'])`, with baselines in a `goldens/` folder next to the test. Baselines are generated **on Windows** (`flutter test --update-goldens --tags golden` from `app/`). They use the test font, so text shows as boxes; they check layout and colour, not glyphs.
- `flutter`/`dart` commands in the steps run from `app/`. The `check.ps1` and `git` commands run from the repo root. Before every commit, `powershell -File tool/check.ps1` must print `All checks passed.`
- Commits end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Don't edit `docs/knowledge/*` or `CLAUDE.md`. Put knowledge updates (decisions, learnings, run commands) in your task report. The controller applies them.

## Rulings (conflicts and open questions resolved for this phase)

1. **No freezed.** freezed 3.2.5, the last stable release, can't resolve alongside drift_dev ≥ 2.32: the analyzer range is pinned by `test` through `flutter_test`. `SavedDevice` is the drift-generated data class (`@DataClassName('SavedDevice')`), which comes with `==`, `copyWith` and `toString`. `AppSettings` is hand-written.
2. **drift 2.34.0, not 2.35.x.** drift_dev ≥ 2.34.6 needs analyzer ≥ 13, which this SDK pin blocks. 2.34.0 brings sqlite3 3.x. Its build hook bundles SQLite, so `NativeDatabase.memory()` works in `flutter test` on Windows and Linux with no system `sqlite3.dll`. Verified with a spike: SQLite 3.53.4 under `flutter test` on this machine.
3. **`SavedDevice.serverKeyPin` is nullable** (`String?`). Master Task 2.3 lists it as non-null, but Task 3.3 says to "clear the pin" on a mismatch. `null` means there's no trusted key and Phase 3 routes to pairing (decision #11).
4. **First run** opens `/onboarding`, a placeholder with a single "Get started" button that marks onboarding done and goes to `/discover`. Phase 7 builds the real onboarding. The exit criterion "launches into an empty-state Discovery screen" holds on every launch once onboarding is done and no TV is saved. Start route: a saved device → `/remote`; otherwise onboarding not done → `/onboarding`; otherwise `/discover`.
5. **Routes.** `/settings` is a single route for now; Phase 5 adds child routes (`/settings/appearance`, …). `/pair/:serviceName` carries the `DiscoveredTv` as go_router `extra`, because the path only holds the name.
6. **Dynamic colour is a separate boolean** (`dynamicColor`, default off) next to `ThemePreference { system, light, dark }`. This follows the spec ("System / Light / Dark, plus Dynamic colour") rather than the skill's four-way list.
7. **Contrast fixes to the token table** (the spec's ≥ 4.5:1 overrides the skill table):
   - New token `dangerText`: light `#B83A3A` (5.29:1 on bg), dark `#FF6B6B`. It feeds `ColorScheme.error`. Light `danger` `#D64545` is only 4.08:1 on bg.
   - `onAccent`: dark `#0F1115` (6.15:1; white on `#6C8CFF` is only 3.07:1), light `#FFFFFF` (5.13:1).
   - Light success/warning/danger are below 4.5:1. They're used only for non-text indicators (≥ 3:1), never as text colour.
8. **Typography:** the system font (Roboto / SF), as the skill allows ("Inter (or the system font)"). Bundling Inter can happen in Phase 7 branding.
9. **Goldens in CI:** `tool/check.sh` (Linux CI) runs `flutter test --exclude-tags golden`. A new `goldens` job on `windows-latest` runs `flutter test --tags golden`, so baselines are always compared on the platform that made them. `tool/check.ps1` runs everything. If the Windows runner drifts from local baselines, add a tolerance comparator in `test/flutter_test_config.dart` rather than re-baselining on Linux.
10. **Flavors:**
    - Android sets the app name with `manifestPlaceholders["appName"]`. AGP 9.0.1 turns `resValues` off by default.
    - There is no `lib/main.dart`. `flutter: default-flavor: dev` lets `flutter run -t lib/main_dev.dart` work without `--flavor`.
    - iOS can't be built on Windows. It gets a structural test here plus an owner check on a Mac.
11. **Backup/restore:** flutter_secure_storage's `resetOnError: true` (its Android default) turns an undecryptable restored store into empty reads. `IdentityStore` regenerates on any empty, partial, corrupt or throwing read. `allowBackup` stays unchanged.
12. **`AppKeyButton` gets `longPressDuration`** (default `kLongPressTimeout`). Phase 4.2's power key needs 600 ms, and the widget is designed now.
13. **Settings added beyond spec goal 7:** `autoOpenKeyboard` (Task 4.6, default on), `onboardingComplete` (routing, default off) and `localeCode` (`String?`, `null` = system; only `en` is supported until Phase 8).
14. **`shortcuts` and `app_usage` are global**, not per TV. This phase creates the tables; Phase 5 adds their repositories.
15. **Out of scope here:**
    - These Phase 1 carry-over items belong to Phase 3, where the library is wired: code trim/upper-case, resume/network debounce, Reconnect → `notifyNetworkChanged()`, WoL subnet broadcast.
    - The iOS `NSLocalNetworkUsageDescription`/`NSBonjourServices` keys belong to Task 3.1.
    - This phase does take the Android permissions carry-over (Task 2.9).

## Review Focus

1. **A hold is interrupted.** The finger is cancelled by the system, or the widget is rebuilt away mid-hold (status flips, layout changes). `onLongPressEnd` must still fire exactly once so the TV never keeps a stuck `START_LONG` (Task 2.2 `long_press_end_fires_once_when_pointer_cancelled`, `dispose_during_hold_calls_end_once`).
2. **Secure storage returns garbage.** This covers a restored backup (reset to empty), only one of the two PEMs written, corrupt PEM, a read that throws, or two first-launch callers at once. The result must be one valid identity, never a crash or two identities (Task 2.5 `regenerates_when_*`, `concurrent_calls_generate_once`).
3. **Odd TV service names.** Spaces, `/`, `%`, `:`, accents. They must round-trip exactly through `/pair/:serviceName` (Task 2.7 `pair_route_round_trips_service_names`).
4. **200% text scale.** Key buttons, rocker, status pill, dialog, sheet and the Discovery empty state reflow with no overflow error (Tasks 2.2, 2.3, 2.7 `*_reflows_at_200_percent_text`).
5. **Stored settings from another app version.** Unknown enum names or wrong value types fall back to defaults, and a failing device lookup at startup still opens the app (Task 2.6 `unknown_or_mistyped_values_fall_back_to_defaults`, Task 2.7 `initial_location_falls_back_when_device_lookup_fails`).

---

## File Structure

```
app/
  pubspec.yaml               pinned deps; flutter: generate: true, default-flavor: dev
  l10n.yaml                  gen-l10n config (Task 2.3)
  analysis_options.yaml      include ../analysis_options.yaml; exclude generated (Task 2.3)
  dart_test.yaml             declares tag `golden` (Task 2.2)
  drift_schemas/drift_schema_v1.json   schema dump (Task 2.4)
  lib/
    main_dev.dart, main_prod.dart      → bootstrap(Flavor.dev/prod)            (2.8)
    bootstrap.dart           bootstrap, buildRootWidget, StartupStep, runStartupSteps (2.8)
    app/
      app.dart               App: MaterialApp.router, theme/locale from settings (2.8)
      flavor.dart            Flavor, flavorMatchesNative, flavorProvider        (2.8)
      router.dart            AppRoutes, resolveInitialLocation, providers       (2.7)
      theme/tokens.dart      AppColors (ThemeExtension), spacing/radii/sizes/motion/type, contrastRatio (2.1)
      theme/app_theme.dart   buildAppTheme                                     (2.1)
      l10n/app_en.arb        + generated app_localizations*.dart              (2.3, 2.7)
      widgets/app_key_button.dart, rocker.dart                                 (2.2)
      widgets/status_pill.dart, app_dialog.dart, app_sheet.dart                (2.3)
      widgets/placeholder_screen.dart                                          (2.7)
    core/
      crash/crash_reporter.dart, crash/error_handlers.dart                     (2.8)
      storage/app_database.dart, device_repository.dart                        (2.4)
      storage/secure_key_value_store.dart, identity_store.dart                 (2.5)
      storage/settings_store.dart                                              (2.6)
      storage/settings_controller.dart, storage_providers.dart                 (2.7)
    features/
      onboarding/presentation/onboarding_screen.dart                           (2.7)
      discovery/presentation/discovery_screen.dart, widgets/discovery_empty_state.dart (2.7)
  test/                      mirrors lib/; helpers/ for pump/golden/fakes
  android/app/build.gradle.kts, android/app/src/main/AndroidManifest.xml      (2.9)
  ios/Runner.xcodeproj/project.pbxproj, xcshareddata/xcschemes/{dev,prod}.xcscheme, ios/Runner/Info.plist (2.9)
tool/check.sh, .github/workflows/ci.yml                                        (2.2)
```

| Task | Master task | Deliverable |
|---|---|---|
| 2.1 | 2.1 | Tokens + `buildAppTheme` |
| 2.2 | 2.1 | `AppKeyButton`, `Rocker`, golden infrastructure |
| 2.3 | 2.1 (+ l10n from 2.2) | `StatusPill`, `AppDialog`, `AppSheet`, ARB + gen-l10n |
| 2.4 | 2.3 | drift `AppDatabase` + `DeviceRepository` |
| 2.5 | 2.3 | `IdentityStore` |
| 2.6 | 2.3 | `SettingsStore` + `AppSettings` |
| 2.7 | 2.2 | Providers, router, shell screens |
| 2.8 | 2.2 | `App`, bootstrap, error handling, entry points |
| 2.9 | 2.2 | Android/iOS flavors, release permissions |

Execution order is 2.1 → 2.9: storage (2.4–2.6) comes before the router (2.7) because the start route reads it.

---

### Task 2.1: Theme tokens and `buildAppTheme`

**Files:**
- Create: `app/lib/app/theme/tokens.dart`, `app/lib/app/theme/app_theme.dart`
- Test: `app/test/app/theme/tokens_test.dart`, `app/test/app/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `@immutable class AppColors extends ThemeExtension<AppColors>` with `Color` fields `bg, surface, surfaceRaised, outline, textPrimary, textSecondary, accent, onAccent, success, warning, danger, dangerText, onDanger, tvRed, tvGreen, tvYellow, tvBlue`; `static const AppColors dark`, `static const AppColors light`; `copyWith`, `lerp` (`Color.lerp` per field).
  - `extension AppThemeX on BuildContext { AppColors get appColors; }` returns `Theme.of(this).extension<AppColors>()!`.
  - `abstract final class AppSpacing { xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0 }`; `AppRadii { key = 20.0, card = 16.0, sheet = 28.0 }`; `AppSizes { keyMin = 56.0, touchMin = 48.0, keyGap = 8.0 }`; `AppMotion { fast = Duration(milliseconds: 150), standard = 200 ms, slow = 250 ms, curve = Curves.easeOut, pressScale = 0.94 }`.
  - `double contrastRatio(Color a, Color b)`: WCAG ratio from `Color.computeLuminance()`, `(lighter + 0.05) / (darker + 0.05)`.
  - `ThemeData buildAppTheme({required Brightness brightness, ColorScheme? dynamicScheme})`.

**Values (from the `remote-design-system` skill, with Ruling 7):**

| Field | Dark | Light |
|---|---|---|
| bg | `0xFF0F1115` | `0xFFF6F7F9` |
| surface | `0xFF181B21` | `0xFFFFFFFF` |
| surfaceRaised | `0xFF232731` | `0xFFECEEF2` |
| outline | `0xFF2E3340` | `0xFFD5D9E0` |
| textPrimary | `0xFFF2F4F8` | `0xFF12151B` |
| textSecondary | `0xFFA7AFBF` | `0xFF4A5263` |
| accent / onAccent | `0xFF6C8CFF` / `0xFF0F1115` | `0xFF3D5AFE` / `0xFFFFFFFF` |
| success / warning / danger | `0xFF3DDC97` / `0xFFFFC857` / `0xFFFF6B6B` | `0xFF0F9D63` / `0xFFB7791F` / `0xFFD64545` |
| dangerText / onDanger | `0xFFFF6B6B` / `0xFF0F1115` | `0xFFB83A3A` / `0xFFFFFFFF` |
| tvRed / tvGreen / tvYellow / tvBlue | `0xFFE5484D` / `0xFF30A46C` / `0xFFF5D90A` / `0xFF3E63DD` | same |

`buildAppTheme` mapping, with `t` = the brightness's `AppColors`:
- `useMaterial3: true` and `scaffoldBackgroundColor: t.bg`.
- `ColorScheme` takes:
  - `primary`/`secondary: t.accent` and `onPrimary`/`onSecondary: t.onAccent`
  - `error: t.dangerText`, `onError: t.onDanger`
  - `surface: t.surface`, `onSurface: t.textPrimary`, `onSurfaceVariant: t.textSecondary`
  - `outline`/`outlineVariant: t.outline`, `surfaceContainerHighest: t.surfaceRaised`
- `textTheme` (sizes / line height / weight):

  | Role | Size / line height / weight |
  |---|---|
  | `displaySmall` | 28 / 34 / w600 |
  | `titleLarge` | 20 / 26 / w600 |
  | `bodyLarge` | 16 / 22 / w400 |
  | `labelLarge` | 14 / 18 / w500 |
  | `bodySmall` | 12 / 16 / w400 |

  `height` is line height / size. Colours are textPrimary, except `bodySmall`, which uses textSecondary.
- `dialogTheme`: `backgroundColor: t.surface`, `RoundedRectangleBorder(radius 28)`.
- `bottomSheetTheme`: `backgroundColor: t.surface`, top radius 28, `dragHandleColor: t.outline`.
- `appBarTheme`: `backgroundColor: t.bg`, `foregroundColor: t.textPrimary`, elevation 0, `scrolledUnderElevation: 0`.
- `filledButtonTheme` and `textButtonTheme`: `minimumSize: Size(48, 48)`.
- `extensions: [t]`.

With `dynamicScheme`:
- The `ColorScheme` is `dynamicScheme` with `error`/`onError` from tokens.
- The `AppColors` extension is `t.copyWith(bg: s.surface, surface: s.surfaceContainer, surfaceRaised: s.surfaceContainerHighest, outline: s.outlineVariant, textPrimary: s.onSurface, textSecondary: s.onSurfaceVariant, accent: s.primary, onAccent: s.onPrimary)`.
- Status and TV-key colours stay from the tokens.

- [ ] **Step 1: Write the failing tests**

```dart
// tokens_test.dart
for (final (name, c) in [('dark', AppColors.dark), ('light', AppColors.light)]) {
  test('text_secondary_contrast_at_least_4_5 ($name)', () {
    for (final bg in [c.bg, c.surface, c.surfaceRaised]) {
      expect(contrastRatio(c.textSecondary, bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.textPrimary, bg), greaterThanOrEqualTo(4.5));
    }
  });
  test('accent_and_danger_text_contrast_at_least_4_5 ($name)', () {
    for (final bg in [c.bg, c.surface]) {
      expect(contrastRatio(c.accent, bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(c.dangerText, bg), greaterThanOrEqualTo(4.5));
    }
    expect(contrastRatio(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(c.onDanger, c.dangerText), greaterThanOrEqualTo(4.5));
  });
  test('status_colours_have_3_to_1_non_text_contrast ($name)', () {
    for (final s in [c.success, c.warning, c.danger]) {
      for (final bg in [c.bg, c.surface]) expect(contrastRatio(s, bg), greaterThanOrEqualTo(3));
    }
  });
}
test('token_values_match_design_system', () {
  expect(AppColors.dark.bg, const Color(0xFF0F1115));
  expect(AppColors.light.textSecondary, const Color(0xFF4A5263));
  expect(AppColors.light.dangerText, const Color(0xFFB83A3A));
  expect(AppColors.dark.onAccent, const Color(0xFF0F1115));
  expect(AppColors.light.tvYellow, const Color(0xFFF5D90A));
  expect((AppRadii.key, AppRadii.card, AppRadii.sheet), (20.0, 16.0, 28.0));
  expect((AppSizes.keyMin, AppSizes.touchMin, AppSizes.keyGap), (56.0, 48.0, 8.0));
  expect(AppMotion.pressScale, 0.94);
});
test('contrast_ratio_of_black_on_white_is_21', () =>
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01)));

// app_theme_test.dart
test('dark_theme_maps_tokens_to_color_scheme', () {
  final t = buildAppTheme(brightness: Brightness.dark);
  expect(t.colorScheme.brightness, Brightness.dark);
  expect(t.scaffoldBackgroundColor, AppColors.dark.bg);
  expect(t.colorScheme.primary, AppColors.dark.accent);
  expect(t.colorScheme.onPrimary, AppColors.dark.onAccent);
  expect(t.colorScheme.error, AppColors.dark.dangerText);
  expect(t.colorScheme.surface, AppColors.dark.surface);
  expect(t.colorScheme.onSurfaceVariant, AppColors.dark.textSecondary);
  expect(t.extension<AppColors>(), AppColors.dark);
});
// light_theme_maps_tokens_to_color_scheme: same assertions against AppColors.light.
test('type_scale_matches_tokens', () {
  final tt = buildAppTheme(brightness: Brightness.light).textTheme;
  expect((tt.displaySmall!.fontSize, tt.displaySmall!.height! * 28, tt.displaySmall!.fontWeight), (28, closeTo(34, 0.01), FontWeight.w600));
  expect((tt.titleLarge!.fontSize, tt.titleLarge!.fontWeight), (20, FontWeight.w600));
  expect((tt.bodyLarge!.fontSize, tt.bodyLarge!.height! * 16), (16, closeTo(22, 0.01)));
  expect((tt.labelLarge!.fontSize, tt.labelLarge!.fontWeight), (14, FontWeight.w500));
  expect(tt.bodySmall!.fontSize, 12);
});
test('dialog_and_sheet_use_surface_and_28dp_radius', () {
  final t = buildAppTheme(brightness: Brightness.dark);
  expect(t.dialogTheme.backgroundColor, AppColors.dark.surface);
  expect(t.bottomSheetTheme.backgroundColor, AppColors.dark.surface);
  expect((t.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)));
});
test('dynamic_scheme_replaces_accent_and_surfaces_but_keeps_status_colours', () {
  final s = ColorScheme.fromSeed(seedColor: const Color(0xFF00FF00), brightness: Brightness.dark);
  final t = buildAppTheme(brightness: Brightness.dark, dynamicScheme: s);
  final c = t.extension<AppColors>()!;
  expect(t.colorScheme.primary, s.primary);
  expect(c.accent, s.primary);
  expect(c.bg, s.surface);
  expect(c.success, AppColors.dark.success);
  expect(c.tvRed, AppColors.dark.tvRed);
  expect(t.colorScheme.error, AppColors.dark.dangerText);
});
test('dynamic_scheme_text_secondary_contrast_at_least_4_5', () {
  for (final seed in const [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFFFFFF00), Color(0xFF0000FF)]) {
    for (final b in Brightness.values) {
      final c = buildAppTheme(brightness: b, dynamicScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b)).extension<AppColors>()!;
      expect(contrastRatio(c.textSecondary, c.bg), greaterThanOrEqualTo(4.5));
    }
  }
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/theme`
Expected: FAIL. Compilation errors: `tokens.dart` and `app_theme.dart` don't exist.

- [ ] **Step 3: Implement `tokens.dart` and `app_theme.dart`** with the values and mapping above. Don't add a font package; the system font is used.

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/app/theme`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib/app/theme app/test/app/theme
git commit -m "feat(app): design tokens and app theme" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2.2: `AppKeyButton`, `Rocker`, golden test infrastructure

**Files:**
- Create: `app/lib/app/widgets/app_key_button.dart`, `app/lib/app/widgets/rocker.dart`
- Create: `app/test/helpers/pump_app.dart`, `app/test/helpers/golden.dart`, `app/dart_test.yaml`
- Modify: `tool/check.sh` (app test line), `.github/workflows/ci.yml` (add `goldens` job)
- Test: `app/test/app/widgets/app_key_button_test.dart`, `rocker_test.dart`, `app_key_button_golden_test.dart`, `rocker_golden_test.dart` (+ `goldens/`)

**Interfaces:**
- Consumes: `buildAppTheme`, `AppColors`, `AppSizes`, `AppRadii`, `AppMotion` (Task 2.1).
- Produces:
  - `class AppKeyButton extends StatefulWidget { const AppKeyButton({super.key, required String semanticLabel, required Widget icon, required VoidCallback onTap, VoidCallback? onLongPressStart, VoidCallback? onLongPressEnd, Duration longPressDuration = kLongPressTimeout, double size = AppSizes.keyMin}); }`
  - `class Rocker extends StatelessWidget { const Rocker({super.key, required String label, String? value, required String upSemanticLabel, required String downSemanticLabel, required VoidCallback onUp, required VoidCallback onDown, Widget upIcon = const Icon(Icons.add), Widget downIcon = const Icon(Icons.remove), VoidCallback? onUpLongPressStart, VoidCallback? onUpLongPressEnd, VoidCallback? onDownLongPressStart, VoidCallback? onDownLongPressEnd}); }`
  - Test helpers:
    - `Future<void> pumpApp(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light, double textScale = 1, bool disableAnimations = false, bool wrapInScaffold = true})` wraps `child` in a `MaterialApp`:
      - `theme: buildAppTheme(brightness: brightness)`
      - `builder` overrides `MediaQuery` with `textScaler: TextScaler.linear(textScale)` and `disableAnimations`
      - `home`: `Scaffold(body: Center(child: child))` when `wrapInScaffold`
    - `Future<void> pumpForGolden(WidgetTester tester, Widget child, {required Brightness brightness, required Size size})` sets `tester.view.physicalSize = size` and `devicePixelRatio = 1` (with `addTearDown(tester.view.reset)`), then calls `pumpApp`.

**Behaviour (`AppKeyButton`):**
- Size and shape: at least `size × size`, enforced with a `ConstrainedBox` min. `surfaceRaised` fill, radius `AppRadii.key`, icon in `textPrimary`, ink ripple.
- Gestures: use `RawGestureDetector` with a `TapGestureRecognizer` and a `LongPressGestureRecognizer(duration: longPressDuration)`, plus a `Listener(onPointerCancel:)`.
  - A short press calls `onTap`. A press that becomes a long press calls `onLongPressStart` and never `onTap`.
  - Track `_holding`. `onLongPressEnd` is called **exactly once** per start: from the recognizer's end, from its cancel, from pointer cancel, or from `dispose()` while holding.
  - With both long-press callbacks null, only taps are recognised.
- Press feedback: `AnimatedScale(scale: pressed ? AppMotion.pressScale : 1, duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast, curve: AppMotion.curve)`.
- Semantics: `Semantics(button: true, label: semanticLabel, onTap: onTap, onLongPress: <start then end> when onLongPressStart != null)`, with the icon excluded from semantics.

**`Rocker`:**
- A vertical pill (`surfaceRaised`, stadium shape): up `AppKeyButton`, then a centre area (min height 40) with `label` in `labelLarge` and an optional `value` in `bodySmall`, then down `AppKeyButton`.
- The centre text must wrap or scale without overflow at 200%: use `Flexible` / `FittedBox(fit: BoxFit.scaleDown)`.

- [ ] **Step 1: Write the failing tests**

```dart
// app_key_button_test.dart
Widget key({VoidCallback? onTap, VoidCallback? start, VoidCallback? end, Duration d = kLongPressTimeout}) =>
    AppKeyButton(semanticLabel: 'Volume up', icon: const Icon(Icons.add), onTap: onTap ?? () {},
        onLongPressStart: start, onLongPressEnd: end, longPressDuration: d);

testWidgets('key_button_min_size_56dp', (t) async {
  await pumpApp(t, AppKeyButton(semanticLabel: 'x', icon: const SizedBox(width: 4, height: 4), onTap: () {}));
  final s = t.getSize(find.byType(AppKeyButton));
  expect(s.width, greaterThanOrEqualTo(56)); expect(s.height, greaterThanOrEqualTo(56));
});
testWidgets('tap_calls_onTap_once', (t) async { var n = 0; await pumpApp(t, key(onTap: () => n++)); await t.tap(find.byType(AppKeyButton)); await t.pumpAndSettle(); expect(n, 1); });
testWidgets('long_press_calls_start_then_end_and_not_tap', (t) async {
  final log = <String>[];
  await pumpApp(t, key(onTap: () => log.add('tap'), start: () => log.add('start'), end: () => log.add('end')));
  await t.longPress(find.byType(AppKeyButton)); await t.pumpAndSettle();
  expect(log, ['start', 'end']);
});
testWidgets('long_press_end_fires_once_when_pointer_cancelled', (t) async {
  final log = <String>[];
  await pumpApp(t, key(start: () => log.add('start'), end: () => log.add('end')));
  final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
  await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await g.cancel(); await t.pumpAndSettle();
  expect(log, ['start', 'end']);
});
testWidgets('dispose_during_hold_calls_end_once', (t) async {
  final log = <String>[];
  await pumpApp(t, key(start: () => log.add('start'), end: () => log.add('end')));
  final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
  await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await pumpApp(t, const SizedBox()); await g.up(); await t.pumpAndSettle();
  expect(log, ['start', 'end']);
});
testWidgets('custom_long_press_duration_respected', (t) async {
  var starts = 0;
  await pumpApp(t, key(start: () => starts++, end: () {}, d: const Duration(milliseconds: 600)));
  final g = await t.startGesture(t.getCenter(find.byType(AppKeyButton)));
  await t.pump(const Duration(milliseconds: 550)); expect(starts, 0);
  await t.pump(const Duration(milliseconds: 100)); expect(starts, 1);
  await g.up();
});
testWidgets('semantics_label_and_long_press_action', (t) async {
  final h = t.ensureSemantics(); final log = <String>[];
  await pumpApp(t, key(onTap: () => log.add('tap'), start: () => log.add('start'), end: () => log.add('end')));
  expect(find.bySemanticsLabel('Volume up'), findsOneWidget);
  t.semantics.longPress(find.semantics.byLabel('Volume up')); await t.pumpAndSettle();
  expect(log, ['start', 'end']); h.dispose();
});
testWidgets('press_scale_has_no_animation_with_reduce_motion', (t) async {
  await pumpApp(t, key(), disableAnimations: true);
  expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
});

// rocker_test.dart
testWidgets('rocker_up_and_down_call_callbacks', ...)            // tap find.bySemanticsLabel('Volume up') → up == 1; 'Volume down' → down == 1
testWidgets('rocker_hold_routes_to_matching_long_press_callbacks', ...) // longPress on down key → ['downStart','downEnd'], up callbacks untouched
testWidgets('rocker_shows_label_and_value', ...)                // label 'VOL', value '12' → both find.text
testWidgets('rocker_reflows_at_200_percent_text', (t) async {
  await pumpApp(t, Rocker(label: 'VOL', value: '100', upSemanticLabel: 'Volume up', downSemanticLabel: 'Volume down', onUp: () {}, onDown: () {}), textScale: 2);
  expect(t.takeException(), isNull);
  expect(t.getSize(find.bySemanticsLabel('Volume up')).height, greaterThanOrEqualTo(56));
});

// app_key_button_golden_test.dart
@Tags(['golden'])
library;
for (final b in Brightness.values) {
  testWidgets('app_key_button_${b.name}', (t) async {
    await pumpForGolden(t, Row(mainAxisSize: MainAxisSize.min, children: [
      for (final i in [Icons.arrow_back, Icons.home_outlined, Icons.volume_off_outlined])
        Padding(padding: const EdgeInsets.all(AppSizes.keyGap / 2), child: AppKeyButton(semanticLabel: '$i', icon: Icon(i), onTap: () {})),
    ]), brightness: b, size: const Size(320, 120));
    await expectLater(find.byType(Row), matchesGoldenFile('goldens/app_key_button_${b.name}.png'));
  });
}
// rocker_golden_test.dart: same pattern, Rocker(label: 'VOL', value: '12', ...) at Size(160, 240) → goldens/rocker_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app/widgets`
Expected: FAIL. Compilation errors: the widgets don't exist.

- [ ] **Step 3: Add `app/dart_test.yaml`**

```yaml
tags:
  golden:
    description: Pixel comparisons. Baselines are generated on Windows; Linux CI excludes this tag.
```

- [ ] **Step 4: Implement `AppKeyButton` and `Rocker`** per the behaviour above.
- [ ] **Step 5: Generate the golden baselines**

Run: `flutter test --update-goldens --tags golden`
Then open the four PNGs in `test/app/widgets/goldens/`. Check that the dark keys are `#232731` on `#0F1115` and that the corners are rounded.

- [ ] **Step 6: Run all widget tests and confirm they pass**

Run: `flutter test test/app/widgets`
Expected: all PASS, goldens included.

- [ ] **Step 7: Wire the golden tag into CI**
  - In `tool/check.sh`, change the app test line to `(cd app && flutter test --exclude-tags golden)` with a comment: goldens are Windows baselines; the `goldens` CI job runs them.
  - In `.github/workflows/ci.yml`, add a job `goldens` with `runs-on: windows-latest` and `timeout-minutes: 20`. It runs the same checkout and `subosito/flutter-action@v2` steps (`flutter-version: 3.44.1`), then `flutter pub get`, then `flutter test --tags golden` with `working-directory: app`.
  - Leave `tool/check.ps1` running all tests.

- [ ] **Step 8: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib/app/widgets app/test app/dart_test.yaml tool/check.sh .github/workflows/ci.yml
git commit -m "feat(app): key button and rocker widgets with golden tests" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2.3: `StatusPill`, `AppDialog`, `AppSheet` and English localisation

**Files:**
- Modify: `app/pubspec.yaml`:
  - dependencies: `flutter_localizations: {sdk: flutter}`, `intl: 0.20.2`, `atv_remote: {path: ../packages/atv_remote}`
  - add `generate: true` under `flutter:`
- Create: `app/l10n.yaml`, `app/lib/app/l10n/app_en.arb` (+ generated `app_localizations.dart`, `app_localizations_en.dart`), `app/analysis_options.yaml`
- Create: `app/lib/app/widgets/status_pill.dart`, `app_dialog.dart`, `app_sheet.dart`
- Modify: `app/test/helpers/pump_app.dart` (add `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales`)
- Test: `app/test/app/l10n/app_localizations_test.dart`, `app/test/app/widgets/status_pill_test.dart`, `app_dialog_test.dart`, `app_sheet_test.dart`, and `status_pill_golden_test.dart`, `app_dialog_golden_test.dart`, `app_sheet_golden_test.dart`

**Interfaces:**
- Consumes: Tasks 2.1–2.2; `ConnectionStatus` from `package:atv_remote/atv_remote.dart`.
- Produces:
  - `AppLocalizations` (generated, non-nullable `AppLocalizations.of(context)`).
  - `class StatusPill extends StatelessWidget { const StatusPill({super.key, required ConnectionStatus status, VoidCallback? onReconnect}); }`
  - `class AppDialogAction<T> { const AppDialogAction({required String label, required T value, bool isPrimary = false, bool isDestructive = false}); }`
  - `Future<T?> showAppDialog<T>({required BuildContext context, required String title, required String message, required List<AppDialogAction<T>> actions})`. It shows `AppDialog<T>`, a public widget so tests can find it.
  - `Future<T?> showAppSheet<T>({required BuildContext context, required String title, required WidgetBuilder builder})`

**Config:**
- `app/l10n.yaml`: `arb-dir: lib/app/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`, `output-class: AppLocalizations`, `nullable-getter: false`.
- `app/analysis_options.yaml`: `include: ../analysis_options.yaml`, with `analyzer: exclude:` for `"**/*.g.dart"` and `lib/app/l10n/app_localizations*.dart`.

**ARB keys (exact English copy):**

| Key | Copy |
|---|---|
| `statusConnected` | `Connected` |
| `statusConnecting` | `Connecting…` |
| `statusReconnecting` | `Reconnecting…` |
| `statusOffline` | `Offline` |
| `statusNeedsPairing` | `Pair again` |
| `statusDisconnected` | `Not connected` |
| `statusReconnectAction` | `Reconnect` |
| `statusSemantics` | `Connection: {status}` (placeholder `status`, String) |
| `closeAction` | `Close` |

Each key has an `@key` description.

**Behaviour:**
- `StatusPill`:
  - A stadium-shaped pill on `surface` with an `outline` border, holding an 8 dp dot, a label (`labelLarge`, `textPrimary`; colour is never the only signal) and, only when `status == offline && onReconnect != null`, a `TextButton` labelled `statusReconnectAction` (≥ 48 dp).
  - Dot colours: connected `success`, connecting `accent`, reconnecting `warning`, offline `danger`, needsPairing `danger`, disconnected `textSecondary`.
  - Wrap it in `Semantics(container: true, liveRegion: true, label: statusSemantics(<label>))` so status changes are announced.
- `AppDialog`:
  - Themed `Dialog` with the title in `titleLarge` and the message in `bodyLarge`/`textSecondary`.
  - Actions in a `Wrap` aligned end: primary → `FilledButton`; destructive → `TextButton` with foreground `dangerText`; other → `TextButton`.
  - Tapping an action pops its `value`. Barrier dismiss returns `null`.
- `AppSheet`:
  - `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, showDragHandle: true)` with the themed shape.
  - Header row: title (`titleLarge`), then an `IconButton(icon: Icons.close, tooltip: closeAction)` that pops `null`.
  - Below the header, `builder` content in a `Flexible` + `SingleChildScrollView` so 200% text scrolls instead of overflowing.

- [ ] **Step 1: Write the failing tests**

```dart
// app_localizations_test.dart
test('english_strings_load', () async {
  expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
  final l = await AppLocalizations.delegate.load(const Locale('en'));
  expect(l.statusReconnecting, 'Reconnecting…');
  expect(l.statusSemantics('Offline'), 'Connection: Offline');
});

// status_pill_test.dart
testWidgets('shows_label_for_every_status', (t) async {
  const labels = {
    ConnectionStatus.connected: 'Connected', ConnectionStatus.connecting: 'Connecting…',
    ConnectionStatus.reconnecting: 'Reconnecting…', ConnectionStatus.offline: 'Offline',
    ConnectionStatus.needsPairing: 'Pair again', ConnectionStatus.disconnected: 'Not connected',
  };
  for (final e in labels.entries) { await pumpApp(t, StatusPill(status: e.key)); expect(find.text(e.value), findsOneWidget); }
});
testWidgets('reconnect_button_only_when_offline_and_callback_given', (t) async {
  await pumpApp(t, StatusPill(status: ConnectionStatus.offline, onReconnect: () {})); expect(find.text('Reconnect'), findsOneWidget);
  await pumpApp(t, StatusPill(status: ConnectionStatus.reconnecting, onReconnect: () {})); expect(find.text('Reconnect'), findsNothing);
  await pumpApp(t, const StatusPill(status: ConnectionStatus.offline)); expect(find.text('Reconnect'), findsNothing);
});
testWidgets('reconnect_tap_calls_callback_and_is_48dp', ...)   // tap 'Reconnect' → n == 1; getSize(find.byType(TextButton)).height >= 48
testWidgets('pill_is_live_region_with_status_label', (t) async {
  final h = t.ensureSemantics();
  await pumpApp(t, const StatusPill(status: ConnectionStatus.offline));
  expect(t.getSemantics(find.byType(StatusPill)), matchesSemantics(label: 'Connection: Offline', isLiveRegion: true));
  h.dispose();
});
testWidgets('status_pill_reflows_at_200_percent_text', ...)  // offline + onReconnect, textScale 2 → takeException() isNull

// app_dialog_test.dart
testWidgets('returns_tapped_action_value', ...)   // button opens showAppDialog<String>(actions: [Cancel→'c', Delete→'d' destructive]); tap 'Delete' → result 'd'
testWidgets('barrier_dismiss_returns_null', ...)  // tapAt(Offset(5, 5)) → result null
testWidgets('dark_dialog_uses_surface_token_not_white', (t) async {
  // open in dark theme
  final m = t.widget<Material>(find.descendant(of: find.byType(AppDialog<String>), matching: find.byType(Material)).first);
  expect(m.color, AppColors.dark.surface);
});
testWidgets('destructive_action_uses_danger_text_colour', ...) // DefaultTextStyle/foreground of 'Delete' == AppColors.light.dangerText
testWidgets('app_dialog_reflows_at_200_percent_text', ...)    // long title + message, textScale 2 → no exception

// app_sheet_test.dart
testWidgets('close_button_pops_with_null', ...)  // find.byTooltip('Close') → tap → sheet gone, result null; its size >= 48x48
testWidgets('swipe_down_dismisses', ...)         // fling(find.text(title), Offset(0, 600), 2000) → pumpAndSettle → findsNothing
testWidgets('sheet_has_28dp_top_radius_and_surface_colour', ...) // BottomSheet's resolved shape/colour from theme == tokens
testWidgets('app_sheet_reflows_at_200_percent_text', ...)        // 40 lines of content, textScale 2 → no exception

// goldens (each file @Tags(['golden'])):
//   status_pill_all_states_{light,dark}: Column of the 6 statuses + offline with onReconnect, Size(360, 480)
//   app_dialog_{light,dark}: open dialog (Cancel + primary 'Pair'), golden of find.byType(AppDialog<String>), Size(400, 400)
//   app_sheet_{light,dark}: open sheet with two lines of text, golden of find.byType(BottomSheet), Size(400, 500)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app`
Expected: FAIL. Compilation errors: no `AppLocalizations`, `StatusPill`, `AppDialog` or `AppSheet`.

- [ ] **Step 3: Add the dependencies, config and ARB**

Run: `flutter pub add flutter_localizations --sdk=flutter`, then `flutter pub add intl:0.20.2 "atv_remote:{\"path\":\"../packages/atv_remote\"}"`. Edit the pubspec so `atv_remote` is a path dependency with no version.

Create the config and ARB above, then run `flutter pub get`.
Expected: `lib/app/l10n/app_localizations.dart` and `app_localizations_en.dart` are generated.

- [ ] **Step 4: Implement `StatusPill`, `AppDialog`/`showAppDialog`, `AppSheet`/`showAppSheet`** and update `pump_app.dart` with the localization delegates.
- [ ] **Step 5: Generate and check the golden baselines**

Run: `flutter test --update-goldens --tags golden`
Then inspect the six new PNGs.

- [ ] **Step 6: Run the app tests and confirm they pass**

Run: `flutter test test/app`
Expected: all PASS.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml app/l10n.yaml app/analysis_options.yaml app/lib/app app/test pubspec.lock
git commit -m "feat(app): status pill, dialog, sheet and English strings" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Commit commands run from the repo root; the workspace lockfile is the root `pubspec.lock`.)

---

### Task 2.4: Local database and `DeviceRepository`

**Files:**
- Modify: `app/pubspec.yaml`: deps `drift: 2.34.0`, `drift_flutter: 0.3.1`; dev deps `build_runner: 2.15.1`, `drift_dev: 2.34.0`
- Create: `app/lib/core/storage/app_database.dart` (+ `app_database.g.dart`), `app/lib/core/storage/device_repository.dart`, `app/drift_schemas/drift_schema_v1.json`
- Test: `app/test/core/storage/app_database_test.dart`, `app/test/core/storage/device_repository_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - Tables:
    - `@DataClassName('SavedDevice') class Devices extends Table`: `serviceName` text PK, `displayName` text, `lastHost` text, `port` int, `nickname` text nullable, `wolMac` text nullable, `serverKeyPin` text nullable (hex SHA-256, Ruling 3), `lastConnectedAt` dateTime.
    - `@DataClassName('ShortcutRow') class Shortcuts extends Table`: `id` int autoIncrement, `package` text, `name` text, `launchLink` text, `iconUrl` text nullable, `isCustom` bool default false, `customColor` int nullable (ARGB), `customIcon` text nullable, `position` int.
    - `@DataClassName('AppUsageRow') class AppUsage extends Table`: `package` text PK, `seenCount` int default 0, `lastSeenAt` dateTime.
    - SQL table names: `devices`, `shortcuts`, `app_usage`.
  - `@DriftDatabase(tables: [Devices, Shortcuts, AppUsage]) class AppDatabase extends _$AppDatabase { AppDatabase(super.e); factory AppDatabase.open() /* driftDatabase(name: 'remotely') */; int get schemaVersion => 1; }`
  - `abstract interface class DeviceRepository { Stream<List<SavedDevice>> watchAll(); Future<void> upsert(SavedDevice device); Future<void> delete(String serviceName); Future<SavedDevice?> lastUsed(); }`
  - `class DriftDeviceRepository implements DeviceRepository { DriftDeviceRepository(AppDatabase db); }`. `watchAll` and `lastUsed` order by `lastConnectedAt` descending. `upsert` uses `insertOnConflictUpdate`. Deleting an unknown name is a no-op.
- `SavedDevice` (generated) has the constructor `SavedDevice({required String serviceName, required String displayName, required String lastHost, required int port, String? nickname, String? wolMac, String? serverKeyPin, required DateTime lastConnectedAt})` and `copyWith(nickname: Value<String?>(...))`.
- Note for Phase 5: drift stores `DateTime` as unix **seconds** (the default), so sub-second precision is dropped. Bumping `schemaVersion` needs a step-by-step migration and a new schema dump.

- [ ] **Step 1: Write the failing tests** (`setUp`: `db = AppDatabase(NativeDatabase.memory())`; `tearDown`: `db.close()`; `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` in `setUpAll`)

```dart
SavedDevice dev(String name, {int minute = 0, String? pin}) => SavedDevice(serviceName: name, displayName: 'TV $name',
    lastHost: '192.168.0.10', port: 6466, serverKeyPin: pin, lastConnectedAt: DateTime.utc(2026, 10, 25, 12, minute));

test('database_creates_devices_shortcuts_and_app_usage_tables', () async {
  expect(db.allTables.map((t) => t.actualTableName), containsAll(['devices', 'shortcuts', 'app_usage']));
  await db.into(db.shortcuts).insert(ShortcutsCompanion.insert(package: 'com.netflix.ninja', name: 'Netflix', launchLink: 'market://launch?id=com.netflix.ninja', position: 0));
  await db.into(db.appUsage).insert(AppUsageCompanion.insert(package: 'com.netflix.ninja', lastSeenAt: DateTime.utc(2026)));
  expect((await db.select(db.shortcuts).getSingle()).isCustom, isFalse);
  expect((await db.select(db.appUsage).getSingle()).seenCount, 0);
  expect(db.schemaVersion, 1);
});
// device_repository_test.dart
test('device_upsert_and_watch', () async {
  final repo = DriftDeviceRepository(db);
  final seen = expectLater(repo.watchAll(), emitsInOrder([isEmpty, [dev('a')]]));
  await repo.upsert(dev('a')); await seen;
});
test('upsert_replaces_device_with_same_service_name', () async {
  final repo = DriftDeviceRepository(db);
  await repo.upsert(dev('a')); await repo.upsert(dev('a').copyWith(nickname: const Value('Bedroom')));
  final all = await repo.watchAll().first;
  expect(all, hasLength(1)); expect(all.single.nickname, 'Bedroom');
});
test('watch_all_orders_by_last_connected_desc', ...)   // upsert a(min 1), b(min 3), c(min 2) → names [b, c, a]
test('last_used_returns_most_recent_or_null', ...)      // empty → null; after a(1), b(3) → b
test('delete_removes_device_and_ignores_unknown', ...)  // delete('a') → empty; delete('zzz') completes without error
test('nullable_fields_round_trip', ...)                 // pin 'ab12…', wolMac 'AA:BB:CC:DD:EE:FF', nickname set → read back equal; all null → null
test('last_connected_at_round_trips_to_the_second', () async {
  final repo = DriftDeviceRepository(db); await repo.upsert(dev('a', minute: 7));
  expect((await repo.lastUsed())!.lastConnectedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 25, 12, 7)), isTrue);
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/storage`
Expected: FAIL. Compilation errors: `AppDatabase` doesn't exist.

- [ ] **Step 3: Add the dependencies**

Run: `flutter pub add drift:2.34.0 drift_flutter:0.3.1 dev:build_runner:2.15.1 dev:drift_dev:2.34.0`

- [ ] **Step 4: Implement the tables, `AppDatabase` and `DriftDeviceRepository`, then generate**

Run: `dart run build_runner build --delete-conflicting-outputs`, then `dart format lib test`.
If `dart run` can't resolve the workspace, use `flutter pub run build_runner build --delete-conflicting-outputs`, and report that as a learning.

- [ ] **Step 5: Dump the v1 schema**

Run: `dart run drift_dev schema dump lib/core/storage/app_database.dart drift_schemas/drift_schema_v1.json`
Expected: the file exists and lists the 3 tables.

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `flutter test test/core/storage`
Expected: all PASS.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml app/lib/core/storage app/test/core/storage app/drift_schemas pubspec.lock
git commit -m "feat(app): local database and device repository" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2.5: Secure client identity store

**Files:**
- Modify: `app/pubspec.yaml`: dep `flutter_secure_storage: 11.2.0`
- Create: `app/lib/core/storage/secure_key_value_store.dart`, `app/lib/core/storage/identity_store.dart`, `app/test/helpers/in_memory_secure_store.dart`
- Test: `app/test/core/storage/identity_store_test.dart`

**Interfaces:**
- Consumes: `ClientIdentity` (`generate`, `fromPem`, `certificatePem`, `privateKeyPem`) from `package:atv_remote/atv_remote.dart`.
- Produces:
  - `abstract interface class SecureKeyValueStore { Future<String?> read(String key); Future<void> write(String key, String value); Future<void> delete(String key); }`
  - `class FlutterSecureKeyValueStore implements SecureKeyValueStore { FlutterSecureKeyValueStore([FlutterSecureStorage storage = defaultStorage]); static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(aOptions: AndroidOptions(), iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)); }`. The key never leaves the device, and the Android defaults include `resetOnError: true` (Ruling 11).
  - `class IdentityStoreException implements Exception { const IdentityStoreException(this.message); final String message; }`. The message never contains PEM text.
  - `class IdentityStore { IdentityStore(SecureKeyValueStore storage, {Future<ClientIdentity> Function()? generate}); static const certificateKey = 'client_identity.certificate_pem'; static const privateKeyKey = 'client_identity.private_key_pem'; Future<ClientIdentity> loadOrCreate(); }`. The default `generate` is `() => Isolate.run(ClientIdentity.generate)`, because RSA-2048 key generation must stay off the UI isolate.
- Test fake `InMemorySecureKeyValueStore implements SecureKeyValueStore` has a public `Map<String, String> values`, plus `Object? throwOnRead` and `Object? throwOnWrite` that, when set, are thrown by the matching method.

**`loadOrCreate` algorithm:**
1. Memoise the in-flight/completed `Future`. Concurrent callers share one generation. A call that failed is not memoised, so the next call retries.
2. Read both keys. A throwing read counts as missing.
3. If both are present, `ClientIdentity.fromPem`. If that throws (`ArgumentError`/`FormatException`), treat the identity as missing.
4. If it's missing: try to delete both keys, ignoring errors. Then generate, write `privateKeyKey` and then `certificateKey`, and return the new identity.
5. If a write throws, throw `IdentityStoreException('Could not save the client identity')`. Never hand out an identity that wasn't persisted: the TV would pin a certificate the next launch can't present.

- [ ] **Step 1: Write the failing tests** (`setUpAll`: one real `fixture = ClientIdentity.generate()`. The `generate:` stubs return `fixture` or a second real identity `fixture2` and count calls.)

```dart
test('identity_is_created_once_and_reused', () async {
  final storage = InMemorySecureKeyValueStore(); var n = 0;
  final a = await IdentityStore(storage, generate: () async { n++; return fixture; }).loadOrCreate();
  final b = await IdentityStore(storage, generate: () async { n++; return fixture2; }).loadOrCreate();
  expect(n, 1); expect(b.certificatePem, a.certificatePem);
  expect(storage.values.keys, containsAll([IdentityStore.certificateKey, IdentityStore.privateKeyKey]));
});
test('concurrent_calls_generate_once', () async {
  var n = 0; final s = IdentityStore(InMemorySecureKeyValueStore(), generate: () async { n++; await Future<void>.delayed(const Duration(milliseconds: 10)); return fixture; });
  final r = await Future.wait([s.loadOrCreate(), s.loadOrCreate()]);
  expect(n, 1); expect(identical(r[0], r[1]), isTrue);
});
test('regenerates_when_stored_pem_is_corrupt', () async {
  final storage = InMemorySecureKeyValueStore()..values.addAll({IdentityStore.certificateKey: 'garbage', IdentityStore.privateKeyKey: 'garbage'});
  final id = await IdentityStore(storage, generate: () async => fixture).loadOrCreate();
  expect(id.certificatePem, fixture.certificatePem);
  expect(storage.values[IdentityStore.certificateKey], fixture.certificatePem);
});
test('regenerates_when_only_one_half_is_stored', ...)   // only privateKeyKey present → generate called, both keys written
test('regenerates_when_storage_read_throws', ...)       // throwOnRead = PlatformException(code: 'x') → returns fixture; then clear throwOnRead → both keys present
test('write_failure_throws_and_next_call_retries', () async {
  final storage = InMemorySecureKeyValueStore()..throwOnWrite = PlatformException(code: 'x');
  final s = IdentityStore(storage, generate: () async => fixture);
  await expectLater(s.loadOrCreate(), throwsA(isA<IdentityStoreException>().having((e) => e.message, 'message', isNot(contains('BEGIN')))));
  storage.throwOnWrite = null;
  expect((await s.loadOrCreate()).certificatePem, fixture.certificatePem);
});
test('secure_storage_keeps_keys_on_this_device', () =>
    expect(FlutterSecureKeyValueStore.defaultStorage.iOptions.accessibility, KeychainAccessibility.first_unlock_this_device));
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/core/storage/identity_store_test.dart`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Add the dependency**

Run: `flutter pub add flutter_secure_storage:11.2.0`

- [ ] **Step 4: Implement** `SecureKeyValueStore`, `FlutterSecureKeyValueStore`, `IdentityStore` and the test fake.
- [ ] **Step 5: Run the test and confirm it passes**

Run: `flutter test test/core/storage/identity_store_test.dart`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml app/lib/core/storage app/test pubspec.lock
git commit -m "feat(app): secure client identity store" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2.6: Settings store

**Files:**
- Modify: `app/pubspec.yaml`: dep `shared_preferences: 2.5.6`; dev dep `shared_preferences_platform_interface: 2.4.2`
- Create: `app/lib/core/storage/settings_store.dart`
- Test: `app/test/core/storage/settings_store_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum NavigationStyle { touchpad, dpad }`, `enum QuickAccessRow { apps, colourKeys, mediaKeys, none }`, `enum ThemePreference { system, light, dark }`
  - `@immutable class AppSettings`:
    - Fields: `navigationStyle`, `quickAccessRow`, `hapticsEnabled`, `smoothPressEnabled`, `keepScreenAwake`, `theaterMode`, `themePreference`, `dynamicColor`, `localeCode` (`String?`), `autoOpenKeyboard`, `onboardingComplete`.
    - `const AppSettings({...all required})`, `static const AppSettings defaults`, and value `==`/`hashCode`.
  - `class SettingsStore`:
    - Constructors: `SettingsStore(SharedPreferencesWithCache prefs)` and `static Future<SettingsStore> open()`. `open` creates the prefs with `SharedPreferencesWithCacheOptions(allowList: SettingsStore.keys)`.
    - `static const Set<String> keys`.
    - One typed getter and `Future<void>` setter per field: `navigationStyle`/`setNavigationStyle`, `quickAccessRow`, `hapticsEnabled`, `smoothPressEnabled`, `keepScreenAwake`, `theaterMode`, `themePreference`, `dynamicColor`, `localeCode`/`setLocaleCode(String?)` (null removes the key), `autoOpenKeyboard`, `onboardingComplete`.
    - `AppSettings snapshot()`.
- Defaults (spec goal 7 + master Task 2.3 + Ruling 13): touchpad, apps row, haptics on, smooth press on, keep awake on, theater off, theme system, dynamic colour off, locale `null`, auto-open keyboard on, onboarding not complete.
- Keys: `settings.navigation_style`, `settings.quick_access_row`, `settings.haptics`, `settings.smooth_press`, `settings.keep_screen_awake`, `settings.theater_mode`, `settings.theme`, `settings.dynamic_color`, `settings.locale`, `settings.auto_open_keyboard`, `settings.onboarding_complete`. Enums are stored by `.name`.
- Reading: every getter reads `prefs.get(key)` (`Object?`) and type-checks it. A missing key, the wrong type or an unknown enum name returns the default and never throws.

- [ ] **Step 1: Write the failing tests** (`setUp`: `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()`)

```dart
test('settings_defaults_match_spec', () async {
  final s = (await SettingsStore.open()).snapshot();
  expect(s, AppSettings.defaults);
  expect(s.navigationStyle, NavigationStyle.touchpad); expect(s.quickAccessRow, QuickAccessRow.apps);
  expect((s.hapticsEnabled, s.smoothPressEnabled, s.keepScreenAwake, s.theaterMode), (true, true, true, false));
  expect((s.themePreference, s.dynamicColor, s.localeCode), (ThemePreference.system, false, null));
  expect((s.autoOpenKeyboard, s.onboardingComplete), (true, false));
});
test('setters_persist_across_instances', () async {
  final a = await SettingsStore.open();
  await a.setThemePreference(ThemePreference.dark); await a.setQuickAccessRow(QuickAccessRow.mediaKeys);
  await a.setHapticsEnabled(false); await a.setLocaleCode('en'); await a.setOnboardingComplete(true);
  final b = (await SettingsStore.open()).snapshot();
  expect((b.themePreference, b.quickAccessRow, b.hapticsEnabled, b.localeCode, b.onboardingComplete),
      (ThemePreference.dark, QuickAccessRow.mediaKeys, false, 'en', true));
});
test('set_locale_null_returns_to_system', ...)   // setLocaleCode('en') then setLocaleCode(null) → localeCode null
test('unknown_or_mistyped_values_fall_back_to_defaults', () async {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData({
    'settings.theme': 'purple', 'settings.haptics': 'yes', 'settings.quick_access_row': 3, 'settings.locale': true,
  });
  final s = (await SettingsStore.open()).snapshot();
  expect((s.themePreference, s.hapticsEnabled, s.quickAccessRow, s.localeCode), (ThemePreference.system, true, QuickAccessRow.apps, null));
});
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/core/storage/settings_store_test.dart`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Add the dependencies**

Run: `flutter pub add shared_preferences:2.5.6 dev:shared_preferences_platform_interface:2.4.2`

- [ ] **Step 4: Implement `settings_store.dart`.**
- [ ] **Step 5: Run the test and confirm it passes**

Run: `flutter test test/core/storage/settings_store_test.dart`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml app/lib/core/storage/settings_store.dart app/test/core/storage/settings_store_test.dart pubspec.lock
git commit -m "feat(app): typed settings store" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2.7: Providers, router and shell screens

**Files:**
- Modify: `app/pubspec.yaml`: deps `flutter_riverpod: 3.3.2`, `riverpod_annotation: 4.0.3`, `go_router: 18.1.1`; dev dep `riverpod_generator: 4.0.4`
- Create: `app/lib/core/storage/storage_providers.dart`, `app/lib/core/storage/settings_controller.dart`, `app/lib/app/router.dart` (each with a `.g.dart`)
- Create: `app/lib/app/widgets/placeholder_screen.dart`, `app/lib/features/onboarding/presentation/onboarding_screen.dart`, `app/lib/features/discovery/presentation/discovery_screen.dart`, `app/lib/features/discovery/presentation/widgets/discovery_empty_state.dart`
- Modify: `app/lib/app/l10n/app_en.arb` (keys below)
- Test: `app/test/app/router_test.dart`, `app/test/app/initial_location_test.dart`, `app/test/core/storage/settings_controller_test.dart`, `app/test/features/discovery/discovery_screen_test.dart`, `app/test/features/discovery/discovery_screen_golden_test.dart`, `app/test/helpers/pump_router_app.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `DeviceRepository`, `DriftDeviceRepository` (2.4); `IdentityStore`, `FlutterSecureKeyValueStore` (2.5); `SettingsStore`, `AppSettings` (2.6); `buildAppTheme`, `AppLocalizations` (2.1, 2.3).
- Produces (all `@Riverpod(keepAlive: true)`):
  - In `storage_providers.dart`:
    - `appDatabaseProvider` (`AppDatabase.open()`, `ref.onDispose(db.close)`)
    - `deviceRepositoryProvider` (`DriftDeviceRepository(ref.watch(appDatabaseProvider))`)
    - `settingsStoreProvider` (throws `UnimplementedError('settingsStoreProvider must be overridden at bootstrap')`)
    - `identityStoreProvider` (`IdentityStore(FlutterSecureKeyValueStore())`)
  - `class SettingsController extends _$SettingsController { AppSettings build(); Future<void> update(Future<void> Function(SettingsStore store) change); }` → `settingsControllerProvider`. `build` returns `ref.watch(settingsStoreProvider).snapshot()`. `update` awaits `change`, then sets `state = store.snapshot()`.
  - In `router.dart`:
    - `abstract final class AppRoutes { static const onboarding = '/onboarding', discover = '/discover', remote = '/remote', apps = '/apps', devices = '/devices', settings = '/settings', paywallPath = '/paywall'; static String pair(String serviceName) => '/pair/${Uri.encodeComponent(serviceName)}'; static String paywall({required String source}) => Uri(path: paywallPath, queryParameters: {'source': source}).toString(); }`
    - `Future<String> resolveInitialLocation({required SettingsStore settings, required DeviceRepository devices, void Function(Object error, StackTrace stack)? onError})`, using Ruling 4's order. If `devices.lastUsed()` throws, it calls `onError` and continues as if no device is saved.
    - `initialLocationProvider` (`String`, must be overridden; throws `UnimplementedError` otherwise).
    - `appRouterProvider` (`GoRouter(initialLocation: ref.watch(initialLocationProvider), routes: ..., errorBuilder: ...)`, with `ref.onDispose(router.dispose)`).
  - `class PlaceholderScreen extends StatelessWidget { const PlaceholderScreen({super.key, required String title, Map<String, String> params = const {}, Object? extra, String? actionLabel, VoidCallback? onAction}); }`. It shows an `AppBar(title)` and the `placeholderBody` text, plus an optional `FilledButton`.
  - `OnboardingScreen` (ConsumerWidget). `DiscoveryScreen` (StatelessWidget for now; Phase 3.1 makes it a ConsumerWidget with results, manual IP, demo and troubleshooting). `DiscoveryEmptyState`.
- Routes:

  | Path | Builds |
  |---|---|
  | `/onboarding` | `OnboardingScreen` |
  | `/discover` | `DiscoveryScreen` |
  | `/pair/:serviceName` | `PlaceholderScreen(title: pageTitlePair, params: {'serviceName': state.pathParameters['serviceName']!}, extra: state.extra)`. Phase 3 passes the `DiscoveredTv` as `extra`. |
  | `/remote` | `PlaceholderScreen(title: pageTitleRemote)` |
  | `/apps` | `PlaceholderScreen(title: pageTitleApps)` |
  | `/devices` | `PlaceholderScreen(title: pageTitleDevices)` |
  | `/settings` | `PlaceholderScreen(title: pageTitleSettings)` |
  | `/paywall` | `PlaceholderScreen(title: pageTitlePaywall, params: {if (source != null) 'source': source})`, with `source` taken from `state.uri.queryParameters['source']` |

  `errorBuilder` → `PlaceholderScreen(title: routeNotFoundTitle, actionLabel: routeNotFoundAction, onAction: () => context.go(AppRoutes.discover))`.
- New ARB keys (exact copy):

  | Key | Copy |
  |---|---|
  | `onboardingTitle` | `Control your TV from your phone` |
  | `onboardingBody` | `Find your Android TV on this Wi-Fi network and pair it in a few seconds.` |
  | `onboardingGetStarted` | `Get started` |
  | `discoverTitle` | `Choose your TV` |
  | `discoverEmptyTitle` | `No TVs found yet` |
  | `discoverEmptyBody` | `Make sure your phone and TV are on the same Wi-Fi network and the TV is turned on.` |
  | `pageTitlePair` | `Pair your TV` |
  | `pageTitleRemote` | `Remote` |
  | `pageTitleApps` | `Apps` |
  | `pageTitleDevices` | `Devices` |
  | `pageTitleSettings` | `Settings` |
  | `pageTitlePaywall` | `Premium` |
  | `placeholderBody` | `This screen is coming soon.` |
  | `routeNotFoundTitle` | `Page not found` |
  | `routeNotFoundAction` | `Back to TVs` |
- Onboarding "Get started": `await ref.read(settingsControllerProvider.notifier).update((s) => s.setOnboardingComplete(true));` then `context.go(AppRoutes.discover)`.
- Discovery empty state: centred, scrollable column with `Icons.tv_outlined` (48 dp, `textSecondary`, excluded from semantics), `discoverEmptyTitle` in `titleLarge` and `discoverEmptyBody` in `bodyLarge`/`textSecondary`, with `AppSpacing.xl` padding.
- Test helper `pumpRouterApp(WidgetTester t, {required String initialLocation, List<Override> overrides = const [], Brightness brightness = Brightness.light, double textScale = 1})` builds `ProviderScope(key: UniqueKey(), overrides: [settingsStoreProvider.overrideWithValue(store), initialLocationProvider.overrideWithValue(initialLocation), ...overrides], child: Consumer(builder: (_, ref, _) => MaterialApp.router(theme: buildAppTheme(brightness: brightness), localizationsDelegates: ..., supportedLocales: ..., routerConfig: ref.watch(appRouterProvider))))`. It applies the `textScale` override through `builder:`, creates `store` with an in-memory prefs platform and returns it. The `UniqueKey` gives every call a fresh container, so tests that pump several locations in a loop never reuse a router.

- [ ] **Step 1: Write the failing tests**

```dart
// initial_location_test.dart (in-memory prefs + AppDatabase(NativeDatabase.memory()) + DriftDeviceRepository)
test('router_starts_at_onboarding_on_first_run', () async =>
    expect(await resolveInitialLocation(settings: settings, devices: devices), AppRoutes.onboarding));
test('router_starts_at_remote_when_device_saved', () async {
  await devices.upsert(SavedDevice(serviceName: 'Living Room TV 3', displayName: 'Living Room TV 3', lastHost: '192.168.0.20', port: 6466, lastConnectedAt: DateTime.utc(2026, 10, 25)));
  expect(await resolveInitialLocation(settings: settings, devices: devices), AppRoutes.remote);
});
test('router_starts_at_discover_after_onboarding_without_devices', ...) // setOnboardingComplete(true) → '/discover'
test('initial_location_falls_back_when_device_lookup_fails', () async {
  await settings.setOnboardingComplete(true); Object? reported;
  expect(await resolveInitialLocation(settings: settings, devices: _ThrowingDevices(), onError: (e, _) => reported = e), AppRoutes.discover);
  expect(reported, isNotNull);
});

// router_test.dart
testWidgets('first_run_shows_onboarding_and_get_started_opens_discover', (t) async {
  final store = await pumpRouterApp(t, initialLocation: AppRoutes.onboarding);
  await t.tap(find.text('Get started')); await t.pumpAndSettle();
  expect(find.text('Choose your TV'), findsOneWidget); expect(find.text('No TVs found yet'), findsOneWidget);
  expect(store.onboardingComplete, isTrue);
});
testWidgets('every_route_renders_its_titled_screen', (t) async {
  const titles = {AppRoutes.remote: 'Remote', AppRoutes.apps: 'Apps', AppRoutes.devices: 'Devices', AppRoutes.settings: 'Settings', '/paywall': 'Premium'};
  for (final e in titles.entries) { await pumpRouterApp(t, initialLocation: e.key); expect(find.text(e.value), findsOneWidget); }
});
testWidgets('pair_route_round_trips_service_names', (t) async {
  for (final name in ['Living Room TV 3', 'Bravia/4K', '100% TV', 'Télé du salon', 'manual:192.168.0.5']) {
    await pumpRouterApp(t, initialLocation: AppRoutes.pair(name));
    expect(t.widget<PlaceholderScreen>(find.byType(PlaceholderScreen)).params['serviceName'], name);
  }
});
testWidgets('paywall_route_passes_source', ...)  // AppRoutes.paywall(source: 'apps') → params['source'] == 'apps'
testWidgets('unknown_route_offers_way_back_to_discover', ...)  // '/nope' → 'Page not found'; tap 'Back to TVs' → 'Choose your TV'

// settings_controller_test.dart (ProviderContainer.test(overrides: [settingsStoreProvider.overrideWithValue(store)]))
test('update_writes_through_and_emits_new_snapshot', ...) // update((s) => s.setThemePreference(ThemePreference.dark)) → state.themePreference dark AND store.themePreference dark

// discovery_screen_test.dart
testWidgets('discovery_empty_state_reflows_at_200_percent_text', ...) // pumpRouterApp('/discover', textScale: 2) → takeException() isNull; both texts found
// discovery_screen_golden_test.dart (@Tags(['golden'])): pumpRouterApp('/discover') at Size(390, 844), light + dark → goldens/discovery_empty_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/app test/core test/features`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Add the dependencies**

Run: `flutter pub add flutter_riverpod:3.3.2 riverpod_annotation:4.0.3 go_router:18.1.1 dev:riverpod_generator:4.0.4`

- [ ] **Step 4: Implement the providers, controller, router, screens and ARB keys, then generate**

Run: `dart run build_runner build --delete-conflicting-outputs`, then `flutter pub get` (regenerates l10n), then `dart format lib test`.

- [ ] **Step 5: Generate and check the Discovery golden baselines**

Run: `flutter test --update-goldens --tags golden test/features`
Then inspect the PNGs.

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `flutter test test/app test/core test/features`
Expected: all PASS.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml app/lib app/test pubspec.lock
git commit -m "feat(app): router, providers and shell screens" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2.8: App root, bootstrap, error handling, entry points

**Files:**
- Modify: `app/pubspec.yaml`: dep `dynamic_color: 2.1.0`
- Create: `app/lib/app/flavor.dart` (+ `.g.dart`), `app/lib/app/app.dart`, `app/lib/core/crash/crash_reporter.dart` (+ `.g.dart`), `app/lib/core/crash/error_handlers.dart`, `app/lib/bootstrap.dart`, `app/lib/main_dev.dart`, `app/lib/main_prod.dart`
- Delete: `app/lib/main.dart`, `app/test/smoke_test.dart` (replaced by `app_test.dart`)
- Test: `app/test/app/flavor_test.dart`, `app/test/app/app_test.dart`, `app/test/core/crash/error_handlers_test.dart`, `app/test/bootstrap_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2.1–2.7.
- Produces:
  - `enum Flavor { dev, prod; String get displayName; String get applicationId; }`. dev: `'Remotely Dev'` / `'com.digitallinked.atvremote.dev'`. prod: `'Remotely for Android TV'` / `'com.digitallinked.atvremote'`.
  - `bool flavorMatchesNative(Flavor flavor, String? nativeFlavor)`. True when `nativeFlavor` is null or equals `flavor.name`.
  - `flavorProvider` (keepAlive, must be overridden).
  - `abstract interface class CrashReporter { Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false, String? reason}); Future<void> recordFlutterError(FlutterErrorDetails details, {bool fatal = false}); }` and `class LoggingCrashReporter implements CrashReporter`. `LoggingCrashReporter` writes to `dart:developer` `log` only, with no network; Phase 6 adds Crashlytics. `crashReporterProvider` (keepAlive) defaults to `LoggingCrashReporter()`.
  - `void installErrorHandlers(CrashReporter reporter)`:
    - `FlutterError.onError` calls `FlutterError.presentError(details)`, then `recordFlutterError(details, fatal: true)`.
    - `PlatformDispatcher.instance.onError` calls `recordError(e, s, fatal: true)` and returns `true`.
    - Calls into the reporter are wrapped so a throwing or rejecting reporter is swallowed.
  - `typedef StartupStep = Future<void> Function();`
  - `Future<void> runStartupSteps(List<StartupStep> steps, {required CrashReporter reporter, Duration timeout = const Duration(seconds: 5)})`. Steps run in order. A step that throws or exceeds `timeout` is reported (`fatal: false`, `reason: 'startup step N'`) and skipped. This is where Phase 6 puts Firebase, consent, ads and RevenueCat init, in the `app-services` order.
  - `Future<Widget> buildRootWidget({required Flavor flavor, required CrashReporter crashReporter, List<StartupStep> startupSteps = const [], Future<SettingsStore> Function() openSettings = SettingsStore.open, AppDatabase Function() openDatabase = AppDatabase.open})`:
    - Runs the steps, opens settings and the database, and resolves the initial location (passing `onError` → `crashReporter.recordError`).
    - Returns `ProviderScope(overrides: [flavorProvider, crashReporterProvider, settingsStoreProvider, appDatabaseProvider (overrideWith + onDispose close), initialLocationProvider], child: const App())`.
  - `Future<void> bootstrap(Flavor flavor)`:
    - Calls `WidgetsFlutterBinding.ensureInitialized()`.
    - Asserts `flavorMatchesNative(flavor, appFlavor)` (from `package:flutter/services.dart`) with a message naming both.
    - `installErrorHandlers(const LoggingCrashReporter())`, then `runApp(await buildRootWidget(...))`.
  - `class App extends ConsumerWidget`:
    - Wraps everything in `DynamicColorBuilder`, then builds `MaterialApp.router`:
      - `theme`/`darkTheme: buildAppTheme(brightness: …, dynamicScheme: settings.dynamicColor ? lightDynamic/darkDynamic : null)`
      - `themeMode`, mapped from `ThemePreference`
      - `locale: settings.localeCode == null ? null : Locale(settings.localeCode!)`
      - AppLocalizations delegates and supported locales
      - `onGenerateTitle: (_) => ref.watch(flavorProvider).displayName`
      - `routerConfig: ref.watch(appRouterProvider)`
    - Settings come from `ref.watch(settingsControllerProvider)`.
  - `main_dev.dart`: `Future<void> main() => bootstrap(Flavor.dev);`. `main_prod.dart` is the same with `Flavor.prod`.

- [ ] **Step 1: Write the failing tests**

```dart
// flavor_test.dart
test('flavor_names_and_ids_match_store_config', () {
  expect((Flavor.dev.displayName, Flavor.dev.applicationId), ('Remotely Dev', 'com.digitallinked.atvremote.dev'));
  expect((Flavor.prod.displayName, Flavor.prod.applicationId), ('Remotely for Android TV', 'com.digitallinked.atvremote'));
});
test('flavor_mismatch_is_detected', () {
  expect(flavorMatchesNative(Flavor.dev, null), isTrue); expect(flavorMatchesNative(Flavor.dev, 'dev'), isTrue);
  expect(flavorMatchesNative(Flavor.dev, 'prod'), isFalse);
});

// error_handlers_test.dart (plain test(); save FlutterError.onError and PlatformDispatcher.instance.onError first and restore both in addTearDown)
test('flutter_error_is_forwarded_as_fatal', ...)       // FlutterError.onError!(FlutterErrorDetails(exception: StateError('x'))) → recorder.flutterErrors.single.fatal isTrue
test('platform_error_is_forwarded_and_marked_handled', ...) // PlatformDispatcher.instance.onError!(StateError('y'), StackTrace.empty) returns true; recorder.errors.single.error is StateError
test('reporter_failure_is_swallowed', ...)             // reporter whose methods throw → calling both handlers throws nothing

// bootstrap_test.dart
testWidgets('failing_step_is_reported_and_later_steps_run', ...) // steps [throws, sets ran=true] → ran isTrue; recorder.errors.single.fatal isFalse
testWidgets('hanging_step_times_out_after_5s', (t) async {
  var done = false; final r = RecordingCrashReporter();
  unawaited(runStartupSteps([() => Completer<void>().future], reporter: r).then((_) => done = true));
  await t.pump(const Duration(seconds: 4)); expect(done, isFalse);
  await t.pump(const Duration(seconds: 2)); expect(done, isTrue); expect(r.errors, hasLength(1));
});

// app_test.dart (in-memory prefs; openDatabase: () => AppDatabase(NativeDatabase.memory()))
testWidgets('app_opens_onboarding_on_first_run_without_any_service_config', (t) async {
  await t.pumpWidget(await buildRootWidget(flavor: Flavor.dev, crashReporter: RecordingCrashReporter(),
      startupSteps: [() async => throw StateError('no google-services.json')], openDatabase: () => AppDatabase(NativeDatabase.memory())));
  await t.pumpAndSettle();
  expect(find.text('Get started'), findsOneWidget);
});
testWidgets('app_opens_discover_after_onboarding', ...)  // prefs withData({'settings.onboarding_complete': true}) → 'No TVs found yet'
testWidgets('app_follows_dark_theme_preference', ...)    // prefs withData({'settings.theme': 'dark'}) → Theme.of(ctx of 'Get started').brightness == dark and scaffold bg == AppColors.dark.bg
testWidgets('dynamic_colour_off_uses_tokens', ...)       // default settings → Theme.of(...).colorScheme.primary == AppColors.light.accent
```

`RecordingCrashReporter` lives in `test/helpers/recording_crash_reporter.dart`. It records `errors` (error, fatal, reason) and `flutterErrors` (details, fatal), and has a `throwOnRecord` flag.

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Add the dependency**

Run: `flutter pub add dynamic_color:2.1.0`

- [ ] **Step 4: Implement** `flavor.dart`, `crash_reporter.dart`, `error_handlers.dart`, `bootstrap.dart`, `app.dart`, `main_dev.dart` and `main_prod.dart`. Delete `lib/main.dart` and `test/smoke_test.dart`. Run `dart run build_runner build --delete-conflicting-outputs`, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add -A app/lib app/test app/pubspec.yaml pubspec.lock
git commit -m "feat(app): app root, bootstrap and error handling" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report to the controller: the run command is now `flutter run --flavor dev -t lib/main_dev.dart` (for CLAUDE.md), and `lib/main.dart` no longer exists.

---

### Task 2.9: Native flavors and release permissions

**Files:**
- Modify: `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, `app/pubspec.yaml` (`flutter: default-flavor: dev`)
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj`, `app/ios/Runner/Info.plist`
- Create: `app/ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme`, `prod.xcscheme`
- Delete: `app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- Test: `app/test/platform/flavor_config_test.dart`

**Interfaces:**
- Consumes: `Flavor.displayName` and `Flavor.applicationId` (Task 2.8), so the native config is checked against the Dart values.
- Produces: `flutter run|build --flavor dev|prod -t lib/main_<flavor>.dart` on Android and iOS. Each flavor installs side by side under its own id and name.

**Android:**
- In `android { }`: `flavorDimensions += "env"`, then `productFlavors { create("dev") { dimension = "env"; applicationIdSuffix = ".dev"; manifestPlaceholders["appName"] = "Remotely Dev" }; create("prod") { dimension = "env"; manifestPlaceholders["appName"] = "Remotely for Android TV" } }`.
- Keep `applicationId = "com.digitallinked.atvremote"` and `namespace` unchanged, and remove the template's `TODO` comment on `applicationId`.
- Main manifest: `android:label="${appName}"`. Add these `<uses-permission>` elements before `<application>`: `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE`, `android.permission.ACCESS_WIFI_STATE`, `android.permission.CHANGE_WIFI_MULTICAST_STATE`.

**iOS:**
- Configurations: in each of the three `XCConfigurationList`s (project, Runner, RunnerTests), add `Debug-dev`, `Release-dev`, `Profile-dev`, `Debug-prod`, `Release-prod`, `Profile-prod`.
  - Make each one a copy of its Debug / Release / Profile sibling, with new unique 24-hex object ids.
  - Debug-* use `baseConfigurationReference` → `Debug.xcconfig`. Release-* and Profile-* use `Release.xcconfig`.
  - Keep the original three configurations.
- Runner target settings:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.digitallinked.atvremote.dev` and `APP_DISPLAY_NAME = "Remotely Dev"` for `*-dev`.
  - `com.digitallinked.atvremote` and `"Remotely for Android TV"` for `*-prod`.
- `Info.plist`: `CFBundleDisplayName` = `$(APP_DISPLAY_NAME)`.
- Schemes: `dev.xcscheme` and `prod.xcscheme` are copies of `Runner.xcscheme` with every `buildConfiguration` set to `Debug-<f>` (Test, Launch, Analyze), `Profile-<f>` (Profile) or `Release-<f>` (Archive). Then delete `Runner.xcscheme`.
- If a `Podfile` appears later, it must map the six configurations (`'Debug-dev' => :debug`, others `:release`). Note that in the task report.

- [ ] **Step 1: Write the failing test** (`flutter test` runs with cwd `app/`)

```dart
String read(String p) => File(p).readAsStringSync();
test('android_flavors_match_dart_flavors', () {
  final g = read('android/app/build.gradle.kts');
  expect(g, contains('applicationId = "${Flavor.prod.applicationId}"'));
  expect(g, contains('applicationIdSuffix = ".dev"'));
  expect(g, contains('manifestPlaceholders["appName"] = "${Flavor.dev.displayName}"'));
  expect(g, contains('manifestPlaceholders["appName"] = "${Flavor.prod.displayName}"'));
});
test('release_manifest_declares_network_permissions_and_flavor_label', () {
  final m = read('android/app/src/main/AndroidManifest.xml');
  for (final p in ['INTERNET', 'ACCESS_NETWORK_STATE', 'ACCESS_WIFI_STATE', 'CHANGE_WIFI_MULTICAST_STATE']) {
    expect(m, contains('<uses-permission android:name="android.permission.$p"'));
  }
  expect(m, contains(r'android:label="${appName}"'));
});
test('ios_has_six_flavor_configs_with_ids_and_names', () {
  final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
  for (final f in Flavor.values) {
    for (final c in ['Debug', 'Release', 'Profile']) expect(RegExp('name = "?$c-${f.name}"?;').allMatches(pbx).length, 3); // project, Runner, RunnerTests
    expect(pbx, contains('PRODUCT_BUNDLE_IDENTIFIER = ${f.applicationId};'));
    expect(pbx, contains('APP_DISPLAY_NAME = "${f.displayName}";'));
  }
  expect(read('ios/Runner/Info.plist'), contains(r'<string>$(APP_DISPLAY_NAME)</string>'));
});
test('ios_schemes_use_their_flavor_configs', () {
  for (final f in Flavor.values) {
    final s = read('ios/Runner.xcodeproj/xcshareddata/xcschemes/${f.name}.xcscheme');
    for (final c in ['Debug', 'Release', 'Profile']) expect(s, contains('buildConfiguration = "$c-${f.name}"'));
    expect(s, isNot(contains('buildConfiguration = "Debug"')));
  }
});
test('default_flavor_is_dev', () => expect(read('pubspec.yaml'), contains('default-flavor: dev')));
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/platform/flavor_config_test.dart`
Expected: FAIL on every test.

- [ ] **Step 3: Implement the Android flavors, manifest permissions and label, and `default-flavor`.**
- [ ] **Step 4: Implement the iOS configurations, `Info.plist` and schemes.**
- [ ] **Step 5: Run the test and confirm it passes**

Run: `flutter test test/platform/flavor_config_test.dart`
Expected: all PASS.

- [ ] **Step 6: Build the dev debug APK and check its badging**

Run `flutter build apk --debug --flavor dev -t lib/main_dev.dart`. Then run `aapt2 dump badging build/app/outputs/flutter-apk/app-dev-debug.apk`, using `aapt2.exe` from `%LOCALAPPDATA%\Android\Sdk\build-tools\<newest>\`.
Expected: `package: name='com.digitallinked.atvremote.dev'` and `application-label:'Remotely Dev'`.

- [ ] **Step 7: Build the prod release APK and check its permissions**

Run `flutter build apk --release --flavor prod -t lib/main_prod.dart`, then `aapt2 dump permissions build/app/outputs/flutter-apk/app-prod-release.apk`.
Expected: the four permissions are listed. Badging shows `com.digitallinked.atvremote` and `application-label:'Remotely for Android TV'`.

- [ ] **Step 8: Check on a device or emulator (phase exit check)**

Run: `flutter run --flavor dev -t lib/main_dev.dart`
Expected: the onboarding placeholder appears. Tap "Get started" to reach "Choose your TV" / "No TVs found yet" in the system theme. Relaunch: it opens straight to Discovery.
If neither the owner's phone (ADB Wi-Fi) nor an emulator is available, say so in the report; don't claim the check passed.

- [ ] **Step 9: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add -A app/android app/ios app/pubspec.yaml app/test/platform
git commit -m "build(app): dev and prod flavors with network permissions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report to the controller under "needs the owner": on a Mac, run `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` and the same for prod. Both should succeed with the bundle ids above.

---

## Phase exit checklist

- [ ] `powershell -File tool/check.ps1` → `All checks passed.` (goldens included); `tool/check.sh` passes with goldens excluded.
- [ ] 12 golden PNGs exist: app_key_button, rocker, status_pill_all_states, app_dialog, app_sheet and discovery_empty, each in light and dark.
- [ ] The dev flavor launches to onboarding → Discovery empty state (Task 2.9 Step 8). Prod and dev install side by side.
- [ ] The task reports collectively carry these knowledge updates:
  - decisions: Rulings 1, 2, 7, 9 and 10 as new entries, plus the pinned package versions
  - learnings: freezed/drift analyzer conflict; AGP 9 `resValues` off; sqlite3 3.x hooks under `flutter test`
  - the CLAUDE.md run command
