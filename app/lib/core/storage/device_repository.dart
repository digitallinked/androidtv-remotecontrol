import 'package:drift/drift.dart';
import 'package:tv_remote/core/storage/app_database.dart';

/// Storage for the TVs the user has paired with.
abstract interface class DeviceRepository {
  /// Emits all saved TVs, most recently connected first.
  Stream<List<SavedDevice>> watchAll();

  /// Inserts [device], or replaces the one with the same service name.
  Future<void> upsert(SavedDevice device);

  /// Removes the TV named [serviceName]; does nothing if there is none.
  Future<void> delete(String serviceName);

  /// The most recently connected TV, or `null` when none is saved.
  Future<SavedDevice?> lastUsed();
}

/// [DeviceRepository] backed by the drift [AppDatabase].
class DriftDeviceRepository implements DeviceRepository {
  /// Creates a repository over the given database.
  DriftDeviceRepository(this._db);

  final AppDatabase _db;

  // Drift reads `DateTime` back in local time; normalise to UTC so equal
  // instants compare equal and callers get one consistent representation.
  static SavedDevice _toUtc(SavedDevice d) =>
      d.copyWith(lastConnectedAt: d.lastConnectedAt.toUtc());

  SimpleSelectStatement<$DevicesTable, SavedDevice> _newestFirst() =>
      _db.select(_db.devices)
        ..orderBy([(t) => OrderingTerm.desc(t.lastConnectedAt)]);

  @override
  Stream<List<SavedDevice>> watchAll() =>
      _newestFirst().watch().map((rows) => rows.map(_toUtc).toList());

  @override
  Future<void> upsert(SavedDevice device) =>
      // `toCompanion(false)` keeps null fields as explicit nulls, so
      // upserting a device with no pin clears a previously stored pin instead
      // of leaving it untouched.
      _db.into(_db.devices).insertOnConflictUpdate(device.toCompanion(false));

  @override
  Future<void> delete(String serviceName) => (_db.delete(
    _db.devices,
  )..where((t) => t.serviceName.equals(serviceName))).go();

  @override
  Future<SavedDevice?> lastUsed() async {
    final row = await (_newestFirst()..limit(1)).getSingleOrNull();
    return row == null ? null : _toUtc(row);
  }
}
