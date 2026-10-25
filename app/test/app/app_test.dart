import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/storage/app_database.dart';

import '../helpers/recording_crash_reporter.dart';

void _prefs([Map<String, Object> data = const {}]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(data);
}

Future<Widget> _root({
  List<StartupStep> steps = const [],
  void Function()? onOpenDatabase,
}) => buildRootWidget(
  flavor: Flavor.dev,
  crashReporter: RecordingCrashReporter(),
  startupSteps: steps,
  openDatabase: () {
    onOpenDatabase?.call();
    return AppDatabase(NativeDatabase.memory());
  },
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

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

    expect(find.text('No TVs found yet'), findsOneWidget);
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

  test('locale_from_code_maps_unsupported_values_to_null', () {
    expect(localeFromCode(null), isNull);
    expect(localeFromCode(''), isNull);
    expect(localeFromCode('xx'), isNull);
    expect(localeFromCode('en'), const Locale('en'));
  });
}
