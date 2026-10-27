import 'package:atv_remote/atv_remote.dart';
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

  /// The TV named [serviceName], or `null` when it isn't saved.
  Future<SavedDevice?> find(String serviceName);

  /// Records a successful connection to [serviceName] at [host] and time
  /// [at], leaving every other field alone. Does nothing for an unknown TV.
  Future<void> markConnected(
    String serviceName, {
    required String host,
    required DateTime at,
  });

  /// Records [host] as where [serviceName] was last seen, leaving every other
  /// field alone. A no-op for unknown TVs.
  Future<void> setLastHost(String serviceName, String host);

  /// Moves the saved TV [manualServiceName] (a `manual:<ip>` entry) to [tv]'s
  /// mDNS identity in one transaction (Ruling P5-R10 d): a row named
  /// `tv.serviceName` takes the discovered name, host and port, and the manual
  /// row's nickname, Wake-on-LAN MAC, trusted key pin and last connection;
  /// then the manual row is deleted. The pin moves unchanged, so a different
  /// TV at that address still fails the key check on connect.
  ///
  /// Returns `false`, and changes nothing, when the manual row is missing or
  /// a row named `tv.serviceName` already exists.
  Future<bool> adoptManualDevice({
    required String manualServiceName,
    required DiscoveredTv tv,
  });

  /// Sets the nickname of [serviceName] to [nickname] (`null` shows the TV's
  /// own name again), leaving every other field alone. Does nothing for an
  /// unknown TV.
  Future<void> setNickname(String serviceName, String? nickname);

  /// Sets the Wake-on-LAN MAC address of [serviceName] to [mac] (`null`
  /// clears it), leaving every other field alone. Does nothing for an unknown
  /// TV.
  Future<void> setWolMac(String serviceName, String? mac);

  /// Forgets the trusted key of [serviceName] (it must be paired again),
  /// leaving every other field alone, but only while the stored pin is still
  /// [distrustedPin]: a newer pairing's pin is kept. Does nothing for an
  /// unknown TV.
  Future<void> clearServerKeyPin(
    String serviceName, {
    required String distrustedPin,
  });
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

  @override
  Future<SavedDevice?> find(String serviceName) async {
    final row = await (_db.select(
      _db.devices,
    )..where((t) => t.serviceName.equals(serviceName))).getSingleOrNull();
    return row == null ? null : _toUtc(row);
  }

  // Targeted updates: only the named columns are written, so a concurrent
  // rename or re-pairing is never overwritten with stale values.
  UpdateStatement<$DevicesTable, SavedDevice> _updateOne(String serviceName) =>
      _db.update(_db.devices)..where((t) => t.serviceName.equals(serviceName));

  @override
  Future<void> markConnected(
    String serviceName, {
    required String host,
    required DateTime at,
  }) async {
    await _updateOne(serviceName).write(
      DevicesCompanion(lastHost: Value(host), lastConnectedAt: Value(at)),
    );
  }

  @override
  Future<void> setLastHost(String serviceName, String host) async {
    await _updateOne(
      serviceName,
    ).write(DevicesCompanion(lastHost: Value(host)));
  }

  @override
  Future<bool> adoptManualDevice({
    required String manualServiceName,
    required DiscoveredTv tv,
  }) => _db.transaction(() async {
    final manual = await find(manualServiceName);
    if (manual == null || await find(tv.serviceName) != null) return false;
    await _db
        .into(_db.devices)
        .insert(
          SavedDevice(
            serviceName: tv.serviceName,
            displayName: tv.displayName,
            lastHost: tv.host,
            port: tv.port,
            nickname: manual.nickname,
            wolMac: manual.wolMac,
            serverKeyPin: manual.serverKeyPin,
            lastConnectedAt: manual.lastConnectedAt,
          ),
        );
    await delete(manualServiceName);
    return true;
  });

  @override
  Future<void> setNickname(String serviceName, String? nickname) async {
    await _updateOne(
      serviceName,
    ).write(DevicesCompanion(nickname: Value(nickname)));
  }

  @override
  Future<void> setWolMac(String serviceName, String? mac) async {
    await _updateOne(
      serviceName,
    ).write(DevicesCompanion(wolMac: Value(mac)));
  }

  @override
  Future<void> clearServerKeyPin(
    String serviceName, {
    required String distrustedPin,
  }) async {
    await (_updateOne(serviceName)
          ..where((t) => t.serverKeyPin.equals(distrustedPin)))
        .write(const DevicesCompanion(serverKeyPin: Value(null)));
  }
}
