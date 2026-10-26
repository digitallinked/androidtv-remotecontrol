import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/remote/application/power_controller.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../../../helpers/fake_remote_session.dart';
import '../../../helpers/fake_wake_on_lan.dart';
import '../../../helpers/recording_haptics.dart';
import '../../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

/// A repository whose MAC writes fail.
class _FailingWrites extends DriftDeviceRepository {
  _FailingWrites(super._db);

  @override
  Future<void> setWolMac(String serviceName, String? mac) =>
      Future<void>.error(Exception('disk full'));
}

void main() {
  late AppDatabase db;
  late DeviceRepository repo;
  late FakeRemoteSession fake;
  late FakeWakeOnLan wol;
  late RecordingHaptics haptics;
  late int refused;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    repo = DriftDeviceRepository(db);
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
    wol = FakeWakeOnLan();
    haptics = RecordingHaptics();
    refused = 0;
    await repo.upsert(savedTv());
  });

  PowerController controller({
    bool noSession = false,
    bool available = true,
    bool hapticsEnabled = true,
    DeviceRepository? devices,
    FakeRemoteSession? session,
  }) {
    final s = session ?? fake;
    return PowerController(
      session: noSession ? null : s,
      actions: RemoteActions(
        session: noSession ? null : s,
        smoothPress: true,
        hapticsEnabled: hapticsEnabled,
        haptics: haptics,
        onRefused: () => refused++,
      ),
      devices: devices ?? repo,
      wakeOnLan: wol,
      wakeOnLanAvailable: available,
      haptics: haptics,
      hapticsEnabled: hapticsEnabled,
      onRefused: () => refused++,
    );
  }

  test('connected_sends_the_power_key', () async {
    expect(await controller().press(), PowerOutcome.sentPowerKey);
    expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
    expect(haptics.events, ['heavy']);
    expect(wol.wakes, isEmpty);
    expect(refused, 0);
  });

  test('standby_tv_still_connected_gets_power_key_not_wol', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    fake.push(const PowerStateChanged(false));
    expect(await controller().press(), PowerOutcome.sentPowerKey);
    expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
    expect(wol.wakes, isEmpty);
    expect(fake.reconnectCalls, 0);
  });

  test('connected_but_socket_gone_is_not_connected', () async {
    fake.failNextSends = 1;
    expect(await controller().press(), PowerOutcome.notConnected);
    expect(refused, 1, reason: 'one notice, not two');
    expect(haptics.events, isEmpty);
    expect(wol.wakes, isEmpty);
  });

  test('wol_sent_when_tv_off_and_mac_known', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    fake.emit(_offline);
    expect(await controller().press(), PowerOutcome.waking);
    expect(wol.wakes, [('AA:BB:CC:DD:EE:F0', '192.168.0.20')]);
    expect(fake.reconnectCalls, 1);
    expect(haptics.events, ['heavy']);
    expect(fake.sentPresses, isEmpty);
    expect(refused, 0);
  });

  test('wol_path_respects_the_haptics_setting', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    fake.emit(_offline);
    expect(
      await controller(hapticsEnabled: false).press(),
      PowerOutcome.waking,
    );
    expect(haptics.events, isEmpty);
  });

  test('offline_without_mac_needs_mac', () async {
    fake.emit(_offline);
    expect(await controller().press(), PowerOutcome.needsMac);
    expect(wol.wakes, isEmpty);
    expect(fake.reconnectCalls, 0);
    expect(haptics.events, ['heavy']);
  });

  test('save_mac_and_wake_stores_then_wakes_once_with_one_haptic', () async {
    fake.emit(_offline);
    final c = controller();
    expect(await c.press(), PowerOutcome.needsMac);
    expect(await c.saveMacAndWake('AA:BB:CC:DD:EE:F0'), PowerOutcome.waking);
    expect((await repo.find('Living Room TV 3'))!.wolMac, 'AA:BB:CC:DD:EE:F0');
    expect(wol.wakes, [('AA:BB:CC:DD:EE:F0', '192.168.0.20')]);
    expect(fake.reconnectCalls, 1);
    expect(haptics.events, ['heavy'], reason: 'press() fired it, not save');
  });

  test('save_failure_is_rethrown_and_nothing_is_sent', () async {
    fake.emit(_offline);
    final c = controller(devices: _FailingWrites(db));
    await expectLater(c.saveMacAndWake('AA:BB:CC:DD:EE:F0'), throwsException);
    expect(wol.wakes, isEmpty);
    expect(fake.reconnectCalls, 0);
  });

  test('wake_failure_reports_wake_failed_and_does_not_reconnect', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    fake.emit(_offline);
    wol.result = false;
    expect(await controller().press(), PowerOutcome.wakeFailed);
    expect(wol.wakes, hasLength(1));
    expect(fake.reconnectCalls, 0);
  });

  test('needs_pairing_is_refused', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    fake.emit(const TvConnectionState(status: ConnectionStatus.needsPairing));
    expect(await controller().press(), PowerOutcome.notConnected);
    expect(refused, 1);
    expect(wol.wakes, isEmpty);
    expect(fake.sentPresses, isEmpty);
    expect(haptics.events, isEmpty);
  });

  test('demo_offline_is_refused', () async {
    final demo = FakeRemoteSession(isDemo: true, initial: _offline);
    expect(await controller(session: demo).press(), PowerOutcome.notConnected);
    expect(refused, 1);
    expect(wol.wakes, isEmpty);
    expect(haptics.events, isEmpty);
  });

  test('no_session_is_refused', () async {
    expect(
      await controller(noSession: true).press(),
      PowerOutcome.notConnected,
    );
    expect(refused, 1);
    expect(haptics.events, isEmpty);
  });

  test('unavailable_wol_reports_cannot_wake', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    fake.emit(_offline);
    expect(await controller(available: false).press(), PowerOutcome.cannotWake);
    expect(wol.wakes, isEmpty);
    expect(fake.reconnectCalls, 0);
    expect(refused, 0);
  });

  test('every_status_that_is_not_connected_wakes', () async {
    await repo.upsert(savedTv(wolMac: 'AA:BB:CC:DD:EE:F0'));
    for (final status in [
      ConnectionStatus.offline,
      ConnectionStatus.reconnecting,
      ConnectionStatus.connecting,
      ConnectionStatus.disconnected,
    ]) {
      wol.wakes.clear();
      fake.emit(TvConnectionState(status: status));
      expect(
        await controller().press(),
        PowerOutcome.waking,
        reason: '$status',
      );
      expect(wol.wakes, hasLength(1), reason: '$status');
    }
  });
}
