import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show StreamProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/database_location.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/secure_key_value_store.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

part 'storage_providers.g.dart';

/// The local database, opened on first use and closed with its container.
/// On iOS it lives in the backup-excluded directory (Ruling P8-R1).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open(
    databaseDirectory: databaseDirectoryFor(defaultTargetPlatform),
  );
  ref.onDispose(db.close);
  return db;
}

/// Saved TVs, stored in [appDatabaseProvider].
@Riverpod(keepAlive: true)
DeviceRepository deviceRepository(Ref ref) =>
    DriftDeviceRepository(ref.watch(appDatabaseProvider));

/// The opened settings store. Bootstrap must override it, because opening
/// the store is asynchronous.
@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) => throw UnimplementedError(
  'settingsStoreProvider must be overridden at bootstrap',
);

/// The phone's client identity. This is the only provider of it, because the
/// store memoises the identity per instance.
@Riverpod(keepAlive: true)
IdentityStore identityStore(Ref ref) =>
    IdentityStore(const FlutterSecureKeyValueStore());

/// The saved TVs, most recently connected first, kept up to date.
///
/// Written by hand: `riverpod_generator` can't name [SavedDevice], because
/// drift generates that class in the same build (`InvalidTypeException`).
final StreamProvider<List<SavedDevice>> savedDevicesProvider =
    StreamProvider.autoDispose<List<SavedDevice>>(
      (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
      name: 'savedDevicesProvider',
    );
