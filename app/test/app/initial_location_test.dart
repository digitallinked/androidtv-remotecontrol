import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

class _ThrowingDevices implements DeviceRepository {
  @override
  Stream<List<SavedDevice>> watchAll() => const Stream.empty();

  @override
  Future<void> upsert(SavedDevice device) async {}

  @override
  Future<void> delete(String serviceName) async {}

  @override
  Future<SavedDevice?> lastUsed() => Future.error(StateError('db is broken'));

  @override
  Future<SavedDevice?> find(String serviceName) async => null;

  @override
  Future<void> markConnected(
    String serviceName, {
    required String host,
    required DateTime at,
  }) async {}

  @override
  Future<void> setWolMac(String serviceName, String? mac) async {}

  @override
  Future<void> clearServerKeyPin(
    String serviceName, {
    required String distrustedPin,
  }) async {}
}

void main() {
  late SettingsStore settings;
  late AppDatabase db;
  late DriftDeviceRepository devices;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = await SettingsStore.open();
    db = AppDatabase(NativeDatabase.memory());
    devices = DriftDeviceRepository(db);
  });
  tearDown(() => db.close());

  test(
    'router_starts_at_onboarding_on_first_run',
    () async => expect(
      await resolveInitialLocation(settings: settings, devices: devices),
      AppRoutes.onboarding,
    ),
  );

  test('router_starts_at_remote_when_device_saved', () async {
    await devices.upsert(
      SavedDevice(
        serviceName: 'Living Room TV 3',
        displayName: 'Living Room TV 3',
        lastHost: '192.168.0.20',
        port: 6466,
        lastConnectedAt: DateTime.utc(2026, 10, 25),
      ),
    );
    expect(
      await resolveInitialLocation(settings: settings, devices: devices),
      AppRoutes.remote,
    );
  });

  test('router_starts_at_discover_after_onboarding_without_devices', () async {
    await settings.setOnboardingComplete(true);
    expect(
      await resolveInitialLocation(settings: settings, devices: devices),
      AppRoutes.discover,
    );
  });

  test('initial_location_falls_back_when_device_lookup_fails', () async {
    await settings.setOnboardingComplete(true);
    Object? reported;
    expect(
      await resolveInitialLocation(
        settings: settings,
        devices: _ThrowingDevices(),
        onError: (e, _) => reported = e,
      ),
      AppRoutes.discover,
    );
    expect(reported, isNotNull);
  });

  test('initial_location_without_onError_still_falls_back', () async {
    expect(
      await resolveInitialLocation(
        settings: settings,
        devices: _ThrowingDevices(),
      ),
      AppRoutes.onboarding,
    );
  });
}
