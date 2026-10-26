import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('settings_defaults_match_spec', () async {
    final s = (await SettingsStore.open()).snapshot();
    expect(s, AppSettings.defaults);
    expect(s.navigationStyle, NavigationStyle.touchpad);
    expect(s.quickAccessRow, QuickAccessRow.apps);
    expect(
      (
        s.hapticsEnabled,
        s.smoothPressEnabled,
        s.keepScreenAwake,
        s.theaterMode,
      ),
      (true, true, true, false),
    );
    expect(
      (s.themePreference, s.dynamicColor, s.localeCode),
      (ThemePreference.system, false, null),
    );
    expect((s.autoOpenKeyboard, s.onboardingComplete), (true, false));
  });

  test('setters_persist_across_instances', () async {
    final a = await SettingsStore.open();
    await a.setThemePreference(ThemePreference.dark);
    await a.setQuickAccessRow(QuickAccessRow.mediaKeys);
    await a.setHapticsEnabled(false);
    await a.setLocaleCode('en');
    await a.setOnboardingComplete(true);
    final b = (await SettingsStore.open()).snapshot();
    expect(
      (
        b.themePreference,
        b.quickAccessRow,
        b.hapticsEnabled,
        b.localeCode,
        b.onboardingComplete,
      ),
      (ThemePreference.dark, QuickAccessRow.mediaKeys, false, 'en', true),
    );
  });

  test('set_locale_null_returns_to_system', () async {
    final a = await SettingsStore.open();
    await a.setLocaleCode('en');
    expect(a.localeCode, 'en');
    await a.setLocaleCode(null);
    expect(a.localeCode, isNull);
    expect((await SettingsStore.open()).localeCode, isNull);
  });

  test('unknown_or_mistyped_values_fall_back_to_defaults', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'settings.theme': 'purple',
          'settings.haptics': 'yes',
          'settings.quick_access_row': 3,
          'settings.locale': true,
        });
    final s = (await SettingsStore.open()).snapshot();
    expect(
      (s.themePreference, s.hapticsEnabled, s.quickAccessRow, s.localeCode),
      (ThemePreference.system, true, QuickAccessRow.apps, null),
    );
  });

  test('shortcuts_seeded_flag_round_trips_and_is_allow_listed', () async {
    final a = await SettingsStore.open();
    expect(a.shortcutsSeeded, isFalse);
    expect(SettingsStore.keys, contains('apps.shortcuts_seeded'));
    await a.setShortcutsSeeded(true);
    expect((await SettingsStore.open()).shortcutsSeeded, isTrue);
    await a.setShortcutsSeeded(false);
    expect((await SettingsStore.open()).shortcutsSeeded, isFalse);
    // It is app state, not a setting: the snapshot ignores it.
    expect(a.snapshot(), AppSettings.defaults);
  });
}
