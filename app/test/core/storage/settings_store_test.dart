import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
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

  test('phase_6_values_default_and_round_trip', () async {
    final a = await SettingsStore.open();
    expect(a.snapshot(), AppSettings.defaults);
    expect(
      (a.colourStyle, a.shareUsageStats, a.shareCrashReports),
      (ColourStyle.standard, null, null),
    );
    expect(
      (a.consentRegion, a.trackingPrepromptShown, a.reviewPromptShown),
      (ConsentRegion.unknown, false, false),
    );
    expect(a.cachedPremium, (active: false, expiresAt: null));
    expect(a.interstitialLastShownAt, isNull);
    expect((a.reviewKeyPresses, a.launchCount), (0, 0));

    final expiry = DateTime.utc(2027, 3, 4, 5, 6, 7);
    final shown = DateTime.utc(2026, 10, 27, 8);
    await a.setColourStyle(ColourStyle.ember);
    await a.setShareUsageStats(true);
    await a.setShareCrashReports(false);
    await a.setConsentRegion(ConsentRegion.required);
    await a.setTrackingPrepromptShown(true);
    await a.setCachedPremium((active: true, expiresAt: expiry));
    await a.setInterstitialLastShownAt(shown);
    await a.setReviewKeyPresses(42);
    await a.setLaunchCount(3);
    await a.setReviewPromptShown(true);

    final b = await SettingsStore.open();
    expect(
      (b.colourStyle, b.shareUsageStats, b.shareCrashReports),
      (ColourStyle.ember, true, false),
    );
    expect(
      (b.consentRegion, b.trackingPrepromptShown, b.reviewPromptShown),
      (ConsentRegion.required, true, true),
    );
    final cached = b.cachedPremium;
    expect(cached.active, isTrue);
    expect(cached.expiresAt!.isUtc, isTrue);
    expect(
      cached.expiresAt!.millisecondsSinceEpoch,
      expiry.millisecondsSinceEpoch,
    );
    expect(
      b.interstitialLastShownAt!.millisecondsSinceEpoch,
      shown.millisecondsSinceEpoch,
    );
    expect((b.reviewKeyPresses, b.launchCount), (42, 3));
    // Choices are settings; the rest is app state the snapshot ignores.
    final snapshot = b.snapshot();
    expect(
      (
        snapshot.colourStyle,
        snapshot.shareUsageStats,
        snapshot.shareCrashReports,
      ),
      (ColourStyle.ember, true, false),
    );
    expect(snapshot, isNot(AppSettings.defaults));

    await b.setShareUsageStats(null);
    await b.setShareCrashReports(null);
    await b.setCachedPremium((active: false, expiresAt: null));
    await b.setInterstitialLastShownAt(null);
    final c = await SettingsStore.open();
    expect((c.shareUsageStats, c.shareCrashReports), (null, null));
    expect(c.cachedPremium, (active: false, expiresAt: null));
    expect(c.interstitialLastShownAt, isNull);
  });

  test('unknown_phase_6_enum_names_fall_back', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'settings.colour_style': 'neon',
          'privacy.consent_region': 'mars',
          'privacy.share_usage': 'yes',
          'review.launch_count': 'many',
          'premium.expires_at': 'soon',
        });
    final s = await SettingsStore.open();
    expect(s.colourStyle, ColourStyle.standard);
    expect(s.consentRegion, ConsentRegion.unknown);
    expect(s.shareUsageStats, isNull);
    expect(s.launchCount, 0);
    expect(s.cachedPremium.expiresAt, isNull);
  });

  test('every_phase_6_key_is_in_the_allow_list', () {
    expect(
      SettingsStore.keys,
      containsAll(const [
        'settings.colour_style',
        'privacy.share_usage',
        'privacy.share_crashes',
        'privacy.consent_region',
        'privacy.att_preprompt_shown',
        'premium.active',
        'premium.expires_at',
        'ads.interstitial_last_shown_at',
        'review.key_presses',
        'review.launch_count',
        'review.prompt_shown',
      ]),
    );
  });
}
