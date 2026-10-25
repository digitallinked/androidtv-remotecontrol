import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'settings_controller.g.dart';

/// Holds the current [AppSettings] and writes changes through to the
/// [SettingsStore].
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).snapshot();

  /// Runs [change] against the store, then publishes the stored settings.
  Future<void> update(Future<void> Function(SettingsStore store) change) async {
    final store = ref.read(settingsStoreProvider);
    await change(store);
    state = store.snapshot();
  }
}
