import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

void main() {
  late SettingsStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
  });

  ProviderContainer container() => ProviderContainer.test(
    overrides: [settingsStoreProvider.overrideWithValue(store)],
  );

  test('build_reads_the_current_snapshot', () async {
    await store.setHapticsEnabled(false);
    expect(container().read(settingsControllerProvider).hapticsEnabled, false);
  });

  test('update_writes_through_and_emits_new_snapshot', () async {
    final c = container();
    expect(
      c.read(settingsControllerProvider).themePreference,
      ThemePreference.system,
    );
    await c
        .read(settingsControllerProvider.notifier)
        .update((s) => s.setThemePreference(ThemePreference.dark));
    expect(
      c.read(settingsControllerProvider).themePreference,
      ThemePreference.dark,
    );
    expect(store.themePreference, ThemePreference.dark);
  });

  test('settings_store_provider_must_be_overridden', () {
    final c = ProviderContainer.test();
    expect(
      () => c.read(settingsStoreProvider),
      throwsA(
        anyOf(
          isA<UnimplementedError>(),
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      ),
    );
  });

  test('identity_store_provider_returns_one_instance', () {
    final c = ProviderContainer.test();
    expect(
      identical(c.read(identityStoreProvider), c.read(identityStoreProvider)),
      isTrue,
    );
  });
}
