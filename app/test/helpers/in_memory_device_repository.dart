import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show Value;
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';

/// A [DeviceRepository] in memory, for widget tests: drift's own `watch()`
/// leaves a timer behind when it is disposed, which fails the test.
///
/// Mirrors [DriftDeviceRepository]: `watchAll` replays the current list
/// (newest first) and then every change, and every write emits.
class InMemoryDeviceRepository implements DeviceRepository {
  /// Creates a repository holding [initial].
  InMemoryDeviceRepository([Iterable<SavedDevice> initial = const []]) {
    for (final device in initial) {
      saved[device.serviceName] = device;
    }
  }

  /// The saved TVs by service name.
  final Map<String, SavedDevice> saved = {};

  final StreamController<List<SavedDevice>> _changes =
      StreamController<List<SavedDevice>>.broadcast();

  /// How many write calls were made, failed ones included.
  int writes = 0;

  /// When set, the next write throws it and clears it.
  Object? failNextWrite;

  List<SavedDevice> get _newestFirst =>
      saved.values.toList()
        ..sort((a, b) => b.lastConnectedAt.compareTo(a.lastConnectedAt));

  /// Counts the write, throws [failNextWrite] once, and returns normally
  /// otherwise.
  void _beginWrite() {
    writes++;
    final failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      // The test chose what to throw, an Error or not.
      // ignore: only_throw_errors
      throw failure;
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(_newestFirst);
  }

  /// When set, `watchAll` fails with it (the list can't be read).
  Object? watchError;

  @override
  Stream<List<SavedDevice>> watchAll() {
    final error = watchError;
    if (error != null) return Stream<List<SavedDevice>>.error(error);
    return Stream.multi((controller) {
      controller.add(_newestFirst);
      final sub = _changes.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> upsert(SavedDevice device) async {
    _beginWrite();
    saved[device.serviceName] = device;
    _emit();
  }

  @override
  Future<void> delete(String serviceName) async {
    _beginWrite();
    saved.remove(serviceName);
    _emit();
  }

  @override
  Future<SavedDevice?> lastUsed() async {
    final all = _newestFirst;
    return all.isEmpty ? null : all.first;
  }

  @override
  Future<SavedDevice?> find(String serviceName) async => saved[serviceName];

  @override
  Future<void> markConnected(
    String serviceName, {
    required String host,
    required DateTime at,
  }) async {
    _beginWrite();
    _update(
      serviceName,
      (d) => d.copyWith(lastHost: host, lastConnectedAt: at),
    );
  }

  @override
  Future<void> setLastHost(String serviceName, String host) async {
    _beginWrite();
    _update(serviceName, (d) => d.copyWith(lastHost: host));
  }

  @override
  Future<void> setNickname(String serviceName, String? nickname) async {
    _beginWrite();
    _update(serviceName, (d) => d.copyWith(nickname: Value(nickname)));
  }

  @override
  Future<void> setWolMac(String serviceName, String? mac) async {
    _beginWrite();
    _update(serviceName, (d) => d.copyWith(wolMac: Value(mac)));
  }

  @override
  Future<void> clearServerKeyPin(
    String serviceName, {
    required String distrustedPin,
  }) async {
    _beginWrite();
    _update(
      serviceName,
      (d) => d.serverKeyPin == distrustedPin
          ? d.copyWith(serverKeyPin: const Value(null))
          : d,
    );
  }

  @override
  Future<bool> adoptManualDevice({
    required String manualServiceName,
    required DiscoveredTv tv,
  }) async {
    _beginWrite();
    final manual = saved[manualServiceName];
    if (manual == null || saved.containsKey(tv.serviceName)) return false;
    saved
      ..remove(manualServiceName)
      ..[tv.serviceName] = SavedDevice(
        serviceName: tv.serviceName,
        displayName: tv.displayName,
        lastHost: tv.host,
        port: tv.port,
        nickname: manual.nickname,
        wolMac: manual.wolMac,
        serverKeyPin: manual.serverKeyPin,
        lastConnectedAt: manual.lastConnectedAt,
      );
    _emit();
    return true;
  }

  void _update(String serviceName, SavedDevice Function(SavedDevice) change) {
    final current = saved[serviceName];
    if (current == null) return;
    saved[serviceName] = change(current);
    _emit();
  }
}
