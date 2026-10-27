import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../helpers/fake_ads_overrides.dart';
import '../helpers/fake_consent_service.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/recording_crash_reporter.dart';
import '../helpers/test_premium.dart';

void _prefs([Map<String, Object> data = const {}]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(data);
}

Future<Widget> _root({
  List<StartupStep> steps = const [],
  void Function()? onOpenDatabase,
  FakeConsentService? consent,
  List<Override> extraOverrides = const [],
}) => buildRootWidget(
  flavor: Flavor.dev,
  crashReporter: RecordingCrashReporter(),
  startupSteps: steps,
  overrides: [
    ...fakeAdsOverrides(consent: consent),
    ...extraOverrides,
    tvDiscoveryFactoryProvider.overrideWithValue(FakeTvDiscoveries().create),
    // The database's own stream leaves a timer behind when it is disposed.
    savedDevicesProvider.overrideWith(
      (ref) => Stream.value(const <SavedDevice>[]),
    ),
  ],
  openDatabase: () {
    onOpenDatabase?.call();
    return AppDatabase(NativeDatabase.memory());
  },
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('the_silent_consent_update_starts_with_the_app', (t) async {
    _prefs();
    final consent = FakeConsentService();
    await t.pumpWidget(await _root(consent: consent));
    await t.pumpAndSettle();

    // Onboarding is on screen: the update ran, the form did not.
    expect(find.text('Get started'), findsOneWidget);
    expect(consent.requestUpdateCalls, 1);
    expect(consent.showFormCalls, 0);
  });

  testWidgets('app_opens_onboarding_on_first_run_without_any_service_config', (
    t,
  ) async {
    _prefs();
    await t.pumpWidget(
      await _root(steps: [() async => throw StateError('no services')]),
    );
    await t.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('app_opens_discover_after_onboarding', (t) async {
    _prefs({'settings.onboarding_complete': true});
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();

    expect(find.text('Choose your TV'), findsOneWidget);
  });

  testWidgets('app_follows_dark_theme_preference', (t) async {
    _prefs({'settings.theme': 'dark'});
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();

    final context = t.element(find.text('Get started'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.dark.bg);
  });

  testWidgets('dynamic_colour_off_uses_tokens', (t) async {
    _prefs();
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();

    final context = t.element(find.text('Get started'));
    expect(Theme.of(context).colorScheme.primary, AppColors.light.accent);
  });

  testWidgets('app_title_is_the_flavor_display_name', (t) async {
    _prefs();
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();

    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Remotely Dev');
  });

  testWidgets('startup_opens_exactly_one_database', (t) async {
    _prefs({'settings.onboarding_complete': true});
    var opened = 0;
    await t.pumpWidget(await _root(onOpenDatabase: () => opened++));
    await t.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('empty_stored_locale_follows_the_system_locale', (t) async {
    _prefs({'settings.locale': ''});
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();

    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);
  });

  testWidgets('supported_stored_locale_is_used', (t) async {
    _prefs({'settings.locale': 'en'});
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();

    expect(
      t.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
  });

  testWidgets('theme_switch_applies_immediately', (t) async {
    _prefs({'settings.onboarding_complete': true});
    await t.pumpWidget(await _root());
    await t.pumpAndSettle();
    unawaited(
      ProviderScope.containerOf(
        t.element(find.byType(Scaffold).first),
      ).read(appRouterProvider).push(AppRoutes.settingsAppearance),
    );
    await t.pumpAndSettle();

    ThemeData theme() => Theme.of(t.element(find.text('Appearance').first));

    await t.tap(find.text('Dark'));
    await t.pump();
    expect(theme().brightness, Brightness.dark);
    expect(theme().scaffoldBackgroundColor, AppColors.dark.bg);

    await t.tap(find.text('Light'));
    await t.pump();
    expect(theme().brightness, Brightness.light);
    expect(theme().scaffoldBackgroundColor, AppColors.light.bg);
  });

  // The real `App` wiring (stored style + Premium -> theme), not the copy in
  // `pumpRouterApp`: dropping the style or the Premium flag from `app.dart`
  // must turn these red.
  for (final style in [ColourStyle.ember, ColourStyle.midnight]) {
    testWidgets(
      'premium_user_gets_the_stored_style_${style.name}_in_both_themes',
      (
        t,
      ) async {
        _prefs({'settings.colour_style': style.name});
        await t.pumpWidget(
          await _root(
            extraOverrides: [
              premiumProvider.overrideWith(
                () => TestPremium(
                  const PremiumState(isPremium: true, known: true),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        final app = t.widget<MaterialApp>(find.byType(MaterialApp));
        expect(
          app.theme!.extension<AppColors>(),
          colourStyleColors(style, Brightness.light),
        );
        expect(
          app.darkTheme!.extension<AppColors>(),
          colourStyleColors(style, Brightness.dark),
        );
      },
    );

    testWidgets('free_user_with_a_stored_style_${style.name}_gets_standard', (
      t,
    ) async {
      _prefs({'settings.colour_style': style.name});
      await t.pumpWidget(
        await _root(
          extraOverrides: [
            premiumProvider.overrideWith(() => TestPremium(PremiumState.free)),
          ],
        ),
      );
      await t.pumpAndSettle();

      final app = t.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.extension<AppColors>(), AppColors.light);
      expect(app.darkTheme!.extension<AppColors>(), AppColors.dark);
    });
  }

  test('locale_from_code_maps_unsupported_values_to_null', () {
    expect(localeFromCode(null), isNull);
    expect(localeFromCode(''), isNull);
    expect(localeFromCode('xx'), isNull);
    expect(localeFromCode('en'), const Locale('en'));
  });
}
