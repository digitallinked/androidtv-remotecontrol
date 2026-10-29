import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

void main() {
  test('share_defaults_follow_the_consent_region', () {
    expect(effectiveShare(null, ConsentRegion.unknown), isFalse);
    expect(effectiveShare(null, ConsentRegion.required), isFalse);
    expect(effectiveShare(null, ConsentRegion.notRequired), isTrue);
    expect(effectiveShare(true, ConsentRegion.required), isTrue);
    expect(effectiveShare(false, ConsentRegion.notRequired), isFalse);
  });

  test('privacy_choices_follow_settings_and_region', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = await SettingsStore.open();
    final container = ProviderContainer.test(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    final seen = <PrivacyChoices>[];
    container.listen(privacyChoicesProvider, (_, next) => seen.add(next));

    var choices = container.read(privacyChoicesProvider);
    expect(choices.region, ConsentRegion.unknown);
    expect(
      (choices.shareUsage, choices.shareCrashReports),
      (false, false),
    );
    expect((choices.usageDecided, choices.crashDecided), (false, false));

    await container
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.notRequired);
    choices = container.read(privacyChoicesProvider);
    expect(store.consentRegion, ConsentRegion.notRequired);
    expect(choices.region, ConsentRegion.notRequired);
    expect((choices.shareUsage, choices.shareCrashReports), (true, true));
    expect((choices.usageDecided, choices.crashDecided), (true, true));

    await container
        .read(settingsControllerProvider.notifier)
        .update((s) => s.setShareUsageStats(false));
    choices = container.read(privacyChoicesProvider);
    expect(choices.shareUsage, isFalse);
    expect(choices.shareCrashReports, isTrue);

    await container
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.required);
    choices = container.read(privacyChoicesProvider);
    expect(choices.shareUsage, isFalse);
    expect(choices.shareCrashReports, isFalse);
    expect(choices.usageDecided, isTrue, reason: 'explicit choice');
    expect(choices.crashDecided, isTrue, reason: 'region known');

    await container
        .read(settingsControllerProvider.notifier)
        .update((s) => s.setShareCrashReports(true));
    expect(container.read(privacyChoicesProvider).shareCrashReports, isTrue);
    expect(seen, isNotEmpty);
  });

  test('a_choice_decides_even_while_the_region_is_unknown', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = await SettingsStore.open();
    await store.setShareUsageStats(true);
    final container = ProviderContainer.test(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    final choices = container.read(privacyChoicesProvider);
    expect(choices.region, ConsentRegion.unknown);
    expect((choices.shareUsage, choices.usageDecided), (true, true));
    expect((choices.shareCrashReports, choices.crashDecided), (false, false));
  });
}
