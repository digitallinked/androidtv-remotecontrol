@Tags(['integration'])
library;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_supervisor.dart';
import 'package:tv_remote/core/session/tv_remote_session.dart';

import '../helpers/in_memory_device_repository.dart';
import '../helpers/manual_session_signals.dart';
import '../helpers/paired_fake_tv.dart';
import '../helpers/test_identity.dart';
import '../helpers/wait_for.dart';

const int _cycles = 50;

/// A real [RemoteClient] that reports when it is closed.
class _CountedClient extends RemoteClient {
  _CountedClient(
    this._onClose, {
    required super.host,
    required super.port,
    required super.identity,
    required super.deviceInfo,
  });

  final void Function(RemoteClient client) _onClose;

  @override
  Future<void> close() {
    _onClose(this);
    return super.close();
  }
}

/// The app's real remote clients, counted.
class _CountingClients {
  final List<RemoteClient> created = [];
  final Set<RemoteClient> closed = {};

  RemoteClient create({
    required String host,
    required int port,
    required ClientIdentity identity,
  }) {
    final client = _CountedClient(
      closed.add,
      host: host,
      port: port,
      identity: identity,
      deviceInfo: deviceInfoFor(Flavor.dev),
    );
    created.add(client);
    return client;
  }
}

void main() {
  test(
    'no_leak_after_50_resume_cycles',
    () async {
      final (:tv, :device) = await startPairedFakeTv();
      final clients = _CountingClients();
      final signals = ManualSessionSignals();
      var now = DateTime.utc(2026, 10, 30, 12);

      final session = TvRemoteSession(
        device: device,
        identity: testIdentity(),
        devices: InMemoryDeviceRepository([device]),
        clientFactory: clients.create,
        resolveHost: (_) async => null,
      );
      final supervisor = SessionSupervisor(
        session: session,
        signals: signals,
        backgroundGrace: Duration.zero,
        now: () => now,
      );
      var disposed = false;
      addTearDown(() async {
        if (disposed) return;
        supervisor.dispose();
        await session.dispose();
      });

      bool hasStatus(ConnectionStatus status) =>
          session.current.status == status;

      await session.connect();
      await waitFor(
        () => hasStatus(ConnectionStatus.connected),
        reason: 'the first connection',
      );

      for (var cycle = 1; cycle <= _cycles; cycle++) {
        signals.background();
        // Away for longer than the production grace, by the wall clock too.
        now = now.add(const Duration(seconds: 61));
        await waitFor(
          () => hasStatus(ConnectionStatus.disconnected),
          reason: 'the grace disconnect of cycle $cycle',
        );
        signals.foreground();
        await waitFor(
          () => hasStatus(ConnectionStatus.connected),
          reason: 'the reconnect of cycle $cycle',
        );
      }

      await waitFor(
        () => tv.openRemoteConnections == 1 && clients.closed.length == _cycles,
        reason: 'every earlier connection to be closed on both ends',
      );
      expect(tv.acceptedRemoteConnections, _cycles + 1);
      expect(clients.created, hasLength(_cycles + 1));
      expect(clients.closed, hasLength(_cycles));
      expect(clients.closed, isNot(contains(clients.created.last)));
      // Only the supervisor listens to the signals: one listener each.
      expect(signals.visibilityListeners, 1);
      expect(signals.networkListeners, 1);

      disposed = true;
      supervisor.dispose();
      await session.dispose();
      await waitFor(
        () => tv.openRemoteConnections == 0,
        reason: 'the TV to see the last connection closed',
      );
      expect(clients.closed, hasLength(_cycles + 1));
      expect(signals.visibilityListeners, 0);
      expect(signals.networkListeners, 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
