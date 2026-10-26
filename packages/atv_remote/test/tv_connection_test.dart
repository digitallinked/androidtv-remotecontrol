import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/backoff.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/key_codes.dart';
import 'package:atv_remote/src/pairing_client.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:atv_remote/src/remote_client.dart';
import 'package:atv_remote/src/remote_events.dart';
import 'package:atv_remote/src/socket_connector.dart';
import 'package:atv_remote/src/tv_connection.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;
import 'package:test/test.dart';

import 'fake_tv/fake_tv_identity.dart';
import 'fake_tv/fake_tv_server.dart';

const Duration _wait = Duration(seconds: 5);

/// Short enough to see several attempts within a test, long enough to matter.
Backoff _fastBackoff() => Backoff(
  initial: const Duration(milliseconds: 10),
  max: const Duration(milliseconds: 40),
);

const DeviceInfo _deviceInfo = DeviceInfo(
  model: 'Test Phone',
  vendor: 'Test Vendor',
  packageName: 'com.example.remote',
  appVersion: '1.2.3',
);

// RSA keygen is slow: generate each identity once per test run.
late ClientIdentity _paired;
late ClientIdentity _trustedButUnpaired;

/// A [Backoff] that counts how often it was used.
class _CountingBackoff extends Backoff {
  _CountingBackoff({super.initial});

  int nextCalls = 0;
  int resetCalls = 0;

  @override
  Duration? next() {
    nextCalls++;
    return super.next();
  }

  @override
  void reset() {
    resetCalls++;
    super.reset();
  }
}

/// A fake TV, a [TvConnection] to it and a record of what the factory did.
class _Rig {
  _Rig._(this.tv, this.port, this.hosts, this.clients, this.connection);

  FakeTvServer tv;

  /// The control port the factory points new clients at.
  int port;

  /// Makes new connections fail at once, like a refused connection.
  ///
  /// Connecting to a closed port can take seconds on Windows, which would
  /// make the retry tests slow.
  bool unreachable = false;

  /// While set, new connections hang until it completes (a dead network);
  /// afterwards [unreachable] decides.
  Completer<void>? hold;

  /// The host passed to the client factory, one entry per client created.
  final List<String> hosts;

  /// Every client the factory created, in order.
  final List<RemoteClient> clients;
  final TvConnection connection;

  int get clientsCreated => hosts.length;
}

Future<void> _pair(FakeTvServer tv, ClientIdentity identity) async {
  final pairing = PairingClient(
    host: InternetAddress.loopbackIPv4.address,
    port: tv.pairingPort,
    identity: identity,
    timeout: _wait,
  );
  addTearDown(pairing.close);
  await pairing.start(clientName: 'test phone');
  await pairing.submitCode(tv.displayedCode!);
}

Future<_Rig> _rig({
  Backoff? backoff,
  Future<String?> Function()? reResolveHost,
  Duration reResolveTimeout = const Duration(seconds: 5),
  ClientIdentity? identity,
  bool pair = true,
  bool sendPings = true,
  Duration idleTimeout = const Duration(seconds: 5),
  bool Function(Uint8List serverKeySha256)? verifyServerKey,
  List<RemoteMessage> initialPushes = const [],
}) async {
  final tv = await FakeTvServer.start(
    sendPings: sendPings,
    initialPushes: initialPushes,
  );
  addTearDown(tv.close);
  final who = identity ?? _paired;
  if (pair) await _pair(tv, who);
  late final _Rig rig;
  final hosts = <String>[];
  final clients = <RemoteClient>[];
  final connection = TvConnection(
    host: '127.0.0.1',
    clientFactory: (host) {
      hosts.add(host);
      final client = RemoteClient(
        host: host,
        port: rig.port,
        identity: who,
        deviceInfo: _deviceInfo,
        idleTimeout: idleTimeout,
        connectTimeout: const Duration(seconds: 2),
        connector: (host, port, context) async {
          await rig.hold?.future;
          if (rig.unreachable) throw const SocketException('refused');
          return socketConnectorWithTimeout(const Duration(seconds: 2))(
            host,
            port,
            context,
          );
        },
      );
      clients.add(client);
      return client;
    },
    backoff: backoff ?? _fastBackoff(),
    reResolveHost: reResolveHost,
    reResolveTimeout: reResolveTimeout,
    verifyServerKey: verifyServerKey,
  );
  addTearDown(connection.dispose);
  return rig = _Rig._(tv, tv.remotePort, hosts, clients, connection);
}

/// Resolves with the first state (current or future) matching [test].
Future<TvConnectionState> _until(
  TvConnection connection,
  bool Function(TvConnectionState state) test, {
  Duration timeout = _wait,
}) {
  if (test(connection.current)) return Future.value(connection.current);
  return connection.states.firstWhere(test).timeout(timeout);
}

Future<TvConnectionState> _untilStatus(
  TvConnection connection,
  ConnectionStatus status, {
  Duration timeout = _wait,
}) => _until(connection, (s) => s.status == status, timeout: timeout);

/// Lets queued microtasks and zero-delay events run.
Future<void> _pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(_wait);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $_wait');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Switches the TV off: it stops listening and new connections are refused.
Future<void> _takeDown(_Rig rig) async {
  rig.unreachable = true;
  await rig.tv.close();
}

/// Connects [rig] and waits until the TV considers the client active.
Future<void> _connected(_Rig rig) async {
  await rig.connection.connect().timeout(_wait);
  await rig.tv.waitForActiveClient();
}

/// Waits for a drop to be noticed and for the following reconnect to finish.
Future<void> _lostAndBack(_Rig rig) async {
  await _untilStatus(rig.connection, ConnectionStatus.reconnecting);
  await _untilStatus(rig.connection, ConnectionStatus.connected);
  await rig.tv.waitForActiveClient();
}

void main() {
  setUpAll(() {
    _paired = ClientIdentity.generate(commonName: 'phone-paired');
    _trustedButUnpaired = ClientIdentity.generate(commonName: 'phone-unpaired');
    FakeTvServer.trustClient(_paired);
    FakeTvServer.trustClient(_trustedButUnpaired);
  });

  group('connecting', () {
    test('connects_and_emits_connecting_then_connected', () async {
      final rig = await _rig();
      final conn = rig.connection;
      expect(conn.current.status, ConnectionStatus.disconnected);
      final seen = <TvConnectionState>[];
      final sub = conn.states.listen(seen.add);
      addTearDown(sub.cancel);

      await conn.connect().timeout(_wait);
      await _pump();

      expect(seen, const [
        TvConnectionState(status: ConnectionStatus.connecting),
        TvConnectionState(status: ConnectionStatus.connected),
      ]);
      expect(conn.current.attempt, 0);
      expect(conn.current.lastError, isNull);
    });

    test('connect_is_a_no_op_while_connected', () async {
      final rig = await _rig();
      await rig.connection.connect().timeout(_wait);
      await rig.connection.connect().timeout(_wait);
      expect(rig.clientsCreated, 1);
      expect(rig.connection.current.status, ConnectionStatus.connected);
    });

    test('unpaired_client_routes_to_pairing_on_first_connect', () async {
      final rig = await _rig(identity: _trustedButUnpaired, pair: false);
      await rig.connection.connect().timeout(_wait);
      expect(rig.connection.current.status, ConnectionStatus.needsPairing);
      expect(
        rig.connection.current.lastError,
        RemoteCloseReason.certificateRejected,
      );
      expect(rig.clientsCreated, 1);
    });

    test('unreachable_tv_on_first_connect_enters_the_backoff_loop', () async {
      final rig = await _rig();
      await _takeDown(rig);
      final conn = rig.connection;

      await conn.connect().timeout(_wait);
      expect(conn.current.status, ConnectionStatus.reconnecting);
      expect(conn.current.attempt, 1);
      expect(conn.current.lastError, RemoteCloseReason.networkError);

      final offline = await _untilStatus(conn, ConnectionStatus.offline);
      expect(offline.attempt, 6);
      expect(rig.clientsCreated, 7, reason: '1 connect + 6 retries');
    });

    test('a_failure_triggers_exactly_one_backoff_step', () async {
      final backoff = _CountingBackoff(initial: const Duration(seconds: 30));
      final rig = await _rig(backoff: backoff);
      await _takeDown(rig);

      // connect() throws inside the client AND the client emits RemoteClosed:
      // that must still count as a single failure.
      await rig.connection.connect().timeout(_wait);
      await _pump();

      expect(rig.connection.current.status, ConnectionStatus.reconnecting);
      expect(rig.connection.current.attempt, 1);
      expect(backoff.nextCalls, 1);
      expect(rig.clientsCreated, 1);
    });

    test('a_lost_connection_triggers_exactly_one_backoff_step', () async {
      final backoff = _CountingBackoff(initial: const Duration(seconds: 30));
      final rig = await _rig(backoff: backoff);
      await _connected(rig);

      await rig.tv.dropConnections();
      await _untilStatus(rig.connection, ConnectionStatus.reconnecting);
      await _pump();

      expect(rig.connection.current.attempt, 1);
      expect(backoff.nextCalls, 1);
      expect(rig.clientsCreated, 1);
    });

    test('successful_connect_resets_the_backoff', () async {
      final backoff = _CountingBackoff(
        initial: const Duration(milliseconds: 10),
      );
      final rig = await _rig(backoff: backoff);
      await _connected(rig);
      final resets = backoff.resetCalls;

      await rig.tv.dropConnections();
      await _lostAndBack(rig);

      expect(backoff.resetCalls, greaterThan(resets));
      expect(rig.connection.current.attempt, 0);
    });
  });

  group('reconnecting', () {
    test('marks_lost_when_socket_closes', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);

      await rig.tv.dropConnections();
      final lost = await _untilStatus(
        conn,
        ConnectionStatus.reconnecting,
        timeout: const Duration(milliseconds: 100),
      );
      expect(lost.attempt, 1);
      expect(lost.lastError, RemoteCloseReason.remoteClosed);

      final back = await _untilStatus(conn, ConnectionStatus.connected);
      expect(back.attempt, 0);
      expect(back.lastError, isNull);
      expect(rig.clientsCreated, 2, reason: 'a new client per attempt');
    });

    test('marks_lost_on_ping_timeout', () async {
      // The TV never pings, so the client declares the connection dead.
      final rig = await _rig(
        sendPings: false,
        idleTimeout: const Duration(milliseconds: 150),
      );
      await rig.connection.connect().timeout(_wait);
      final lost = await _untilStatus(
        rig.connection,
        ConnectionStatus.reconnecting,
      );
      expect(lost.lastError, RemoteCloseReason.pingTimeout);
    });

    test('goes_offline_after_max_attempts', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);

      await _takeDown(rig);
      final offline = await _untilStatus(conn, ConnectionStatus.offline);

      expect(offline.attempt, 6);
      expect(offline.lastError, RemoteCloseReason.networkError);
      expect(rig.clientsCreated, 7, reason: '1 session + 6 reconnects');
    });

    test('connect_leaves_offline_once_the_tv_is_back', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);
      await _takeDown(rig);
      await _untilStatus(conn, ConnectionStatus.offline);

      final tv2 = await FakeTvServer.start();
      addTearDown(tv2.close);
      await _pair(tv2, _paired);
      rig
        ..port = tv2.remotePort
        ..unreachable = false;
      await conn.connect().timeout(_wait);

      expect(conn.current.status, ConnectionStatus.connected);
      expect(conn.current.attempt, 0);
      expect(conn.current.lastError, isNull);
    });

    test('routes_to_pairing_on_cert_rejection', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);

      rig.tv.forgetClients();
      await rig.tv.dropConnections();
      final state = await _untilStatus(conn, ConnectionStatus.needsPairing);

      expect(state.lastError, RemoteCloseReason.certificateRejected);
      final created = rig.clientsCreated;
      // Negative assertion, so a wait is unavoidable: several backoff
      // periods (10 + 20 + 40 ms ...) must pass without another attempt.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(rig.clientsCreated, created);
      expect(conn.current.status, ConnectionStatus.needsPairing);
    });

    test('needs_pairing_ignores_resume_and_network_changes', () async {
      final rig = await _rig(identity: _trustedButUnpaired, pair: false);
      final conn = rig.connection;
      await conn.connect().timeout(_wait);
      expect(conn.current.status, ConnectionStatus.needsPairing);

      conn
        ..notifyAppResumed()
        ..notifyNetworkChanged();
      await _pump();

      expect(conn.current.status, ConnectionStatus.needsPairing);
      expect(rig.clientsCreated, 1);
    });

    test('connect_after_pairing_leaves_needs_pairing', () async {
      final rig = await _rig(identity: _trustedButUnpaired, pair: false);
      final conn = rig.connection;
      await conn.connect().timeout(_wait);
      expect(conn.current.status, ConnectionStatus.needsPairing);

      await _pair(rig.tv, _trustedButUnpaired);
      await conn.connect().timeout(_wait);

      expect(conn.current.status, ConnectionStatus.connected);
      expect(conn.current.lastError, isNull);
    });

    test('reconnects_after_resume', () async {
      // A 10 s backoff: only notifyAppResumed() can reconnect in time.
      final rig = await _rig(
        backoff: Backoff(initial: const Duration(seconds: 10)),
      );
      final conn = rig.connection;
      await _connected(rig);

      await rig.tv.dropConnections();
      await _untilStatus(conn, ConnectionStatus.reconnecting);
      expect(rig.clientsCreated, 1, reason: 'still waiting for the 10 s timer');

      conn.notifyAppResumed();
      final state = await _untilStatus(conn, ConnectionStatus.connected);
      expect(state.attempt, 0);
      expect(rig.clientsCreated, 2);
    });

    test('network_change_reconnects_from_offline', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);
      await _takeDown(rig);
      await _untilStatus(conn, ConnectionStatus.offline);

      // The "network" comes back: a TV answers on a new port.
      final tv2 = await FakeTvServer.start();
      addTearDown(tv2.close);
      await _pair(tv2, _paired);
      rig
        ..port = tv2.remotePort
        ..unreachable = false;
      conn.notifyNetworkChanged();

      final state = await _untilStatus(conn, ConnectionStatus.connected);
      expect(state.attempt, 0);
    });

    test('resume_while_connected_does_nothing', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await conn.connect().timeout(_wait);
      final seen = <TvConnectionState>[];
      final sub = conn.states.listen(seen.add);
      addTearDown(sub.cancel);

      conn
        ..notifyAppResumed()
        ..notifyNetworkChanged();
      await _pump();

      expect(seen, isEmpty);
      expect(rig.clientsCreated, 1);
    });

    for (final (name, notify) in <(String, void Function(TvConnection))>[
      ('app_resume', (c) => c.notifyAppResumed()),
      ('network_change', (c) => c.notifyNetworkChanged()),
    ]) {
      test('${name}_during_an_in_flight_attempt_retries_immediately', () async {
        final backoff = _CountingBackoff(initial: const Duration(seconds: 30));
        final rig = await _rig(backoff: backoff);
        final conn = rig.connection;
        await _connected(rig);

        // A dead network: attempts hang instead of failing fast.
        final hold = rig.hold = Completer<void>();
        addTearDown(() {
          if (!hold.isCompleted) hold.complete();
        });
        rig.unreachable = true;
        await rig.tv.dropConnections();
        await _untilStatus(conn, ConnectionStatus.reconnecting);
        expect(backoff.nextCalls, 1);

        notify(conn); // starts attempt 2, which hangs
        await _eventually(() => rig.clientsCreated == 2);
        final resets = backoff.resetCalls;

        notify(conn); // mid-attempt: abandon it and start over now
        await _eventually(() => rig.clientsCreated == 3);
        expect(backoff.resetCalls, greaterThan(resets));
        expect(conn.current.status, ConnectionStatus.reconnecting);
        expect(conn.current.attempt, 1);

        // The network answers (with a failure): only the fresh attempt
        // counts, and the backoff is back at its first step.
        hold.complete();
        final state = await _until(
          conn,
          (s) => s.status == ConnectionStatus.reconnecting && s.attempt == 2,
        );
        expect(state.lastError, RemoteCloseReason.networkError);
        expect(backoff.nextCalls, 2, reason: 'one step after the restart');
        await _pump();
        expect(rig.clientsCreated, 3, reason: 'the abandoned attempt is inert');
      });
    }

    test('a_hanging_re_resolve_times_out_and_keeps_the_old_host', () async {
      final rig = await _rig(
        reResolveHost: () => Completer<String?>().future,
        reResolveTimeout: const Duration(milliseconds: 50),
      );
      await _connected(rig);

      await rig.tv.dropConnections();
      await _lostAndBack(rig);

      expect(rig.hosts, ['127.0.0.1', '127.0.0.1']);
    });

    test('reconnect_uses_the_re_resolved_host', () async {
      final rig = await _rig(reResolveHost: () async => 'localhost');
      await _connected(rig);

      await rig.tv.dropConnections();
      await _lostAndBack(rig);

      expect(rig.hosts, ['127.0.0.1', 'localhost']);
    });

    test('re_resolve_is_skipped_on_the_first_connect', () async {
      var calls = 0;
      final rig = await _rig(
        reResolveHost: () async {
          calls++;
          return 'localhost';
        },
      );
      await rig.connection.connect().timeout(_wait);
      expect(calls, 0);
      expect(rig.hosts, ['127.0.0.1']);
    });

    test('re_resolve_errors_and_null_keep_the_old_host', () async {
      var calls = 0;
      final rig = await _rig(
        reResolveHost: () async {
          calls++;
          if (calls == 1) throw StateError('mdns failed');
          return null;
        },
      );
      await _connected(rig);

      await rig.tv.dropConnections();
      await _lostAndBack(rig);
      await rig.tv.dropConnections();
      await _lostAndBack(rig);

      expect(calls, 2);
      expect(rig.hosts, ['127.0.0.1', '127.0.0.1', '127.0.0.1']);
    });
  });

  group('commands and events', () {
    test('commands_throw_when_not_connected', () async {
      final rig = await _rig();
      final conn = rig.connection;
      Matcher notConnected() => throwsA(isA<NotConnectedException>());

      expect(() => conn.sendKey(KeyCodes.home), notConnected());
      expect(() => conn.launchAppLink('market://x'), notConnected());
      expect(() => conn.sendText('hi'), notConnected());

      await _connected(rig);
      await rig.tv.dropConnections();
      await _untilStatus(conn, ConnectionStatus.reconnecting);
      expect(() => conn.sendKey(KeyCodes.home), notConnected());
    });

    test('commands_reach_the_tv_when_connected', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);

      conn
        ..sendKey(KeyCodes.home)
        ..launchAppLink('market://launch?id=com.example')
        ..sendText('hello');

      await _eventually(
        () =>
            rig.tv.receivedKeyCodes.isNotEmpty &&
            rig.tv.receivedAppLinks.isNotEmpty &&
            rig.tv.receivedText.isNotEmpty,
      );
      expect(rig.tv.receivedKeyCodes, [KeyCodes.home]);
      expect(rig.tv.receivedAppLinks, ['market://launch?id=com.example']);
      expect(rig.tv.receivedText, 'hello');
    });

    test('forwards_tv_events_but_not_ready_or_closed', () async {
      final rig = await _rig();
      final conn = rig.connection;
      final events = <RemoteEvent>[];
      final sub = conn.events.listen(events.add);
      addTearDown(sub.cancel);

      await _connected(rig);
      rig.tv.sendVolume(level: 7, max: 100, muted: false);
      await _eventually(() => events.isNotEmpty);
      await rig.tv.dropConnections();
      await _lostAndBack(rig);
      rig.tv.setPowerOn(false);
      await _eventually(() => events.length >= 2);

      expect(events, const [
        VolumeChanged(7, 100, false),
        PowerStateChanged(false),
      ]);
    });
  });

  group('server key pinning', () {
    final parts = fakeTvIdentity.publicParts;
    Uint8List fakeTvKey() => SHA256Digest().process(
      Uint8List.fromList([...parts.modulus, ...parts.exponent]),
    );
    final pushes = [
      RemoteMessage(
        remoteSetVolumeLevel: RemoteSetVolumeLevel(
          volumeLevel: 3,
          volumeMax: 10,
        ),
      ),
    ];

    test('a_rejected_key_routes_to_pairing_and_never_connects', () async {
      final keys = <Uint8List>[];
      final rig = await _rig(
        initialPushes: pushes,
        verifyServerKey: (key) {
          keys.add(key);
          return false;
        },
      );
      final conn = rig.connection;
      final seen = <TvConnectionState>[];
      final events = <RemoteEvent>[];
      final stateSub = conn.states.listen(seen.add);
      final eventSub = conn.events.listen(events.add);
      addTearDown(stateSub.cancel);
      addTearDown(eventSub.cancel);

      await conn.connect().timeout(_wait);

      expect(conn.current.status, ConnectionStatus.needsPairing);
      expect(conn.current.lastError, RemoteCloseReason.serverKeyChanged);
      expect(keys.single, orderedEquals(fakeTvKey()));
      expect(
        () => conn.sendKey(KeyCodes.home),
        throwsA(isA<NotConnectedException>()),
      );
      // The rejected client is closed, and nothing more is tried.
      await _eventually(() => !rig.clients.single.isReady);
      conn
        ..notifyAppResumed()
        ..notifyNetworkChanged();
      await _pump();
      expect(rig.clientsCreated, 1);
      expect(seen, const [
        TvConnectionState(status: ConnectionStatus.connecting),
        TvConnectionState(
          status: ConnectionStatus.needsPairing,
          lastError: RemoteCloseReason.serverKeyChanged,
        ),
      ]);
      expect(events, isEmpty, reason: 'pushes of an unverified TV are dropped');
      expect(rig.tv.receivedKeyCodes, isEmpty);
      expect(rig.tv.receivedAppLinks, isEmpty);
      expect(rig.tv.receivedText, isEmpty);
    });

    test('dispose_inside_verify_server_key_never_reports_connected', () async {
      late TvConnection c;
      final seen = <ConnectionStatus>[];
      final rig = await _rig(
        verifyServerKey: (_) {
          unawaited(c.dispose());
          return true;
        },
      );
      c = rig.connection;
      c.states.listen((s) => seen.add(s.status));
      await c.connect();
      await pumpEventQueue();

      expect(seen, isNot(contains(ConnectionStatus.connected)));
      expect(c.current.status, ConnectionStatus.disconnected);
    });

    test('disconnect_from_verify_server_key_ends_disconnected', () async {
      late TvConnection c;
      final rig = await _rig(
        initialPushes: pushes,
        verifyServerKey: (_) {
          unawaited(c.disconnect());
          return true;
        },
      );
      c = rig.connection;
      final seen = <ConnectionStatus>[];
      final events = <RemoteEvent>[];
      final stateSub = c.states.listen((s) => seen.add(s.status));
      final eventSub = c.events.listen(events.add);
      addTearDown(stateSub.cancel);
      addTearDown(eventSub.cancel);

      await c.connect();
      await pumpEventQueue();

      expect(seen, isNot(contains(ConnectionStatus.connected)));
      expect(c.current.status, ConnectionStatus.disconnected);
      expect(events, isEmpty);
    });

    test('an_accepted_key_connects_as_before', () async {
      final keys = <Uint8List>[];
      final rig = await _rig(
        initialPushes: pushes,
        verifyServerKey: (key) {
          keys.add(key);
          return true;
        },
      );
      final conn = rig.connection;
      final seen = <TvConnectionState>[];
      final events = <RemoteEvent>[];
      final stateSub = conn.states.listen(seen.add);
      final eventSub = conn.events.listen(events.add);
      addTearDown(stateSub.cancel);
      addTearDown(eventSub.cancel);

      await _connected(rig);
      conn.sendKey(KeyCodes.home);

      await _eventually(() => rig.tv.receivedKeyCodes.isNotEmpty);
      expect(keys.single, orderedEquals(fakeTvKey()));
      expect(seen, const [
        TvConnectionState(status: ConnectionStatus.connecting),
        TvConnectionState(status: ConnectionStatus.connected),
      ]);
      await _eventually(() => events.isNotEmpty);
      expect(events, const [VolumeChanged(3, 10, false)]);
    });
  });

  group('disconnect', () {
    test('disconnect_closes_the_client_and_emits_disconnected', () async {
      final rig = await _rig();
      await _connected(rig);

      await rig.connection.disconnect();

      expect(rig.connection.current.status, ConnectionStatus.disconnected);
      expect(
        () => rig.connection.sendKey(KeyCodes.home),
        throwsA(isA<NotConnectedException>()),
      );
      await _eventually(() => !rig.clients.single.isReady);
    });

    test('connect_after_disconnect_connects_again', () async {
      final rig = await _rig();
      await _connected(rig);

      await rig.connection.disconnect();
      await rig.connection.connect().timeout(_wait);

      expect(rig.connection.current.status, ConnectionStatus.connected);
      expect(rig.connection.current.attempt, 0);
      expect(rig.clients.length, 2);
    });

    test('disconnect_is_idempotent', () async {
      final rig = await _rig();
      await _connected(rig);
      final seen = <ConnectionStatus>[];
      final sub = rig.connection.states.listen((s) => seen.add(s.status));
      addTearDown(sub.cancel);

      await rig.connection.disconnect();
      await rig.connection.disconnect();
      await _pump();

      expect(seen, [ConnectionStatus.disconnected]);
    });

    test('disconnect_is_a_no_op_after_dispose', () async {
      final rig = await _rig();
      await rig.connection.dispose();
      await rig.connection.disconnect();
      expect(rig.connection.current.status, ConnectionStatus.disconnected);
    });

    test('disconnect_cancels_a_scheduled_retry', () async {
      final rig = await _rig();
      await _connected(rig);

      rig.unreachable = true;
      await rig.tv.dropConnections();
      await _untilStatus(rig.connection, ConnectionStatus.reconnecting);
      await rig.connection.disconnect();
      final created = rig.clientsCreated;

      // Three times the fast backoff's cap: a retry would have fired.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(rig.connection.current.status, ConnectionStatus.disconnected);
      expect(rig.clientsCreated, created);
    });

    test('disconnect_abandons_an_attempt_in_flight', () async {
      final rig = await _rig();
      await _connected(rig);
      final hold = rig.hold = Completer<void>();
      addTearDown(() {
        if (!hold.isCompleted) hold.complete();
      });

      await rig.tv.dropConnections();
      await _untilStatus(rig.connection, ConnectionStatus.reconnecting);
      await _eventually(() => rig.clientsCreated == 2);

      await rig.connection.disconnect();
      hold.complete();
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(rig.connection.current.status, ConnectionStatus.disconnected);
      expect(rig.clientsCreated, 2);
      expect(rig.clients.last.isReady, isFalse);
    });

    test('resume_and_network_change_do_nothing_after_disconnect', () async {
      final rig = await _rig();
      await _connected(rig);
      await rig.connection.disconnect();
      final created = rig.clientsCreated;

      rig.connection
        ..notifyAppResumed()
        ..notifyNetworkChanged();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(rig.clientsCreated, created);
      expect(rig.connection.current.status, ConnectionStatus.disconnected);
    });

    test('disconnect_during_re_resolve_discards_the_late_host', () async {
      final resolving = Completer<String?>();
      var started = false;
      final rig = await _rig(
        reResolveHost: () {
          started = true;
          return resolving.future;
        },
      );
      await _connected(rig);
      await rig.tv.dropConnections();
      await _eventually(() => started);

      await rig.connection.disconnect();
      resolving.complete('localhost');
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(rig.connection.host, '127.0.0.1');
      expect(rig.clientsCreated, 1);
      expect(rig.connection.current.status, ConnectionStatus.disconnected);
    });

    test('host_reports_the_re_resolved_address', () async {
      final rig = await _rig(reResolveHost: () async => 'localhost');
      expect(rig.connection.host, '127.0.0.1');
      await _connected(rig);
      expect(rig.connection.host, '127.0.0.1');

      await rig.tv.dropConnections();
      await _lostAndBack(rig);

      expect(rig.connection.host, 'localhost');
    });
  });

  group('dispose', () {
    test('dispose_emits_disconnected_and_stops_reconnecting', () async {
      final rig = await _rig(
        backoff: Backoff(initial: const Duration(milliseconds: 50)),
      );
      final conn = rig.connection;
      await _connected(rig);
      await rig.tv.dropConnections();
      await _untilStatus(conn, ConnectionStatus.reconnecting);

      final seen = <TvConnectionState>[];
      final done = Completer<void>();
      conn.states.listen(seen.add, onDone: done.complete);
      await conn.dispose();
      await done.future.timeout(_wait);

      expect(seen.last.status, ConnectionStatus.disconnected);
      expect(conn.current.status, ConnectionStatus.disconnected);
      final created = rig.clientsCreated;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(rig.clientsCreated, created);
    });

    test('dispose_while_connected_closes_the_client', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await _connected(rig);

      await conn.dispose();

      expect(conn.current.status, ConnectionStatus.disconnected);
      expect(
        () => conn.sendKey(KeyCodes.home),
        throwsA(isA<NotConnectedException>()),
      );
    });

    test('dispose_during_connect_ends_disconnected', () async {
      final rig = await _rig();
      final conn = rig.connection;
      final connecting = conn.connect();
      await conn.dispose();
      await connecting.timeout(_wait);
      expect(conn.current.status, ConnectionStatus.disconnected);
      expect(rig.clientsCreated, lessThanOrEqualTo(1));
    });

    test('dispose_is_idempotent_and_connect_afterwards_throws', () async {
      final rig = await _rig();
      final conn = rig.connection;
      await conn.dispose();
      await conn.dispose();
      await expectLater(conn.connect(), throwsStateError);
    });
  });
}
