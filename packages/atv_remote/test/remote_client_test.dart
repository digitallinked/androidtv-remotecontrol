import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/key_codes.dart';
import 'package:atv_remote/src/pairing_client.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:atv_remote/src/remote_client.dart';
import 'package:atv_remote/src/remote_events.dart';
import 'package:atv_remote/src/socket_connector.dart';
import 'package:atv_remote/src/testing/fake_tv_identity.dart';
import 'package:atv_remote/testing.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;
import 'package:test/test.dart';

import 'support/unloadable_identity.dart';

const Duration _wait = Duration(seconds: 5);

/// The budget for setup that is not under test (pairing, connecting and the
/// handshake with the in-process fake TV). A loaded machine can stall these
/// for seconds; tests of timing use their own explicit durations.
const Duration _setup = Duration(seconds: 20);

const DeviceInfo _deviceInfo = DeviceInfo(
  model: 'Test Phone',
  vendor: 'Test Vendor',
  packageName: 'com.example.remote',
  appVersion: '1.2.3',
);

// RSA keygen is slow: generate each identity once per test run.
late ClientIdentity _paired;
late ClientIdentity _trustedButUnpaired;
late ClientIdentity _untrusted;

Future<FakeTvServer> _startTv({
  bool sendPings = false,
  Duration pingInterval = const Duration(milliseconds: 200),
  bool setActiveFirst = false,
  List<RemoteMessage> initialPushes = const [],
}) async {
  final tv = await FakeTvServer.start(
    sendPings: sendPings,
    pingInterval: pingInterval,
    setActiveFirst: setActiveFirst,
    initialPushes: initialPushes,
  );
  addTearDown(tv.close);
  return tv;
}

Future<void> _pair(FakeTvServer tv, ClientIdentity identity) async {
  final pairing = PairingClient(
    host: InternetAddress.loopbackIPv4.address,
    port: tv.pairingPort,
    identity: identity,
    timeout: _setup,
  );
  addTearDown(pairing.close);
  await pairing.start(clientName: 'test phone');
  await pairing.submitCode(tv.displayedCode!);
}

RemoteClient _client(
  FakeTvServer tv, {
  ClientIdentity? identity,
  int? port,
  Duration idleTimeout = const Duration(seconds: 15),
  Duration connectTimeout = _setup,
  SocketConnector? connector,
}) {
  final client = RemoteClient(
    host: InternetAddress.loopbackIPv4.address,
    port: port ?? tv.remotePort,
    identity: identity ?? _paired,
    deviceInfo: _deviceInfo,
    idleTimeout: idleTimeout,
    connectTimeout: connectTimeout,
    connector: connector,
  );
  addTearDown(client.close);
  return client;
}

/// A TV with [_paired] paired and a client that is connected and active on
/// the TV side too.
Future<(FakeTvServer, RemoteClient)> _ready({
  bool sendPings = false,
  Duration pingInterval = const Duration(milliseconds: 200),
}) async {
  final tv = await _startTv(sendPings: sendPings, pingInterval: pingInterval);
  await _pair(tv, _paired);
  final client = _client(tv);
  await client.connect().timeout(_setup);
  await tv.waitForActiveClient(timeout: _setup);
  return (tv, client);
}

/// Completes with the first event of type [T]; subscribe before the cause.
Future<T> _first<T extends RemoteEvent>(RemoteClient client) =>
    client.events.firstWhere((e) => e is T).then((e) => e as T).timeout(_wait);

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(_wait);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $_wait');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Matcher _connectFailure(RemoteCloseReason reason) =>
    isA<RemoteConnectException>().having((e) => e.reason, 'reason', reason);

void main() {
  setUpAll(() {
    _paired = ClientIdentity.generate(commonName: 'phone-paired');
    _trustedButUnpaired = ClientIdentity.generate(commonName: 'phone-unpaired');
    _untrusted = ClientIdentity.generate(commonName: 'phone-untrusted');
    FakeTvServer.trustClient(_paired);
    FakeTvServer.trustClient(_trustedButUnpaired);
  });

  group('handshake', () {
    test('becomes_ready_after_configure_and_set_active', () async {
      final tv = await _startTv();
      await _pair(tv, _paired);
      final client = _client(tv);
      final seen = <RemoteEvent>[];
      client.events.listen(seen.add);
      expect(client.isReady, isFalse);

      await client.connect().timeout(_setup);

      expect(client.isReady, isTrue);
      await _eventually(() => seen.isNotEmpty);
      expect(seen, [const RemoteReady()]);
      await tv.waitForActiveClient(timeout: _setup);
      final configure = tv.receivedConfigure!;
      expect(configure.code1, 622);
      expect(configure.deviceInfo.model, 'Test Phone');
      expect(configure.deviceInfo.vendor, 'Test Vendor');
      expect(configure.deviceInfo.unknown1, 1);
      expect(configure.deviceInfo.unknown2, '1');
      expect(configure.deviceInfo.packageName, 'com.example.remote');
      expect(configure.deviceInfo.appVersion, '1.2.3');
      expect(tv.receivedActiveCode, 622);
    });

    test('becomes_ready_when_set_active_comes_before_configure', () async {
      final tv = await _startTv(setActiveFirst: true);
      await _pair(tv, _paired);
      final client = _client(tv);
      final seen = <RemoteEvent>[];
      client.events.listen(seen.add);

      await client.connect().timeout(_setup);

      expect(client.isReady, isTrue);
      await tv.waitForActiveClient(timeout: _setup);
      // The Configure that followed SetActive is answered too.
      await _eventually(() => tv.configureReplyCount == 1);
      expect(tv.setActiveReplyCount, 1);
      expect(tv.receivedConfigure!.code1, 622);
      expect(tv.receivedActiveCode, 622);
      expect(seen, [const RemoteReady()]);
    });

    test('answers_every_configure_and_set_active_after_ready', () async {
      final (tv, client) = await _ready();
      final seen = <RemoteEvent>[];
      client.events.listen(seen.add);
      expect(tv.configureReplyCount, 1);
      expect(tv.setActiveReplyCount, 1);

      tv
        ..resendSetActive()
        ..resendConfigure()
        ..resendSetActive();

      await _eventually(
        () => tv.setActiveReplyCount == 3 && tv.configureReplyCount == 2,
      );
      expect(tv.receivedConfigure!.deviceInfo.model, 'Test Phone');
      expect(tv.receivedActiveCode, 622);
      expect(client.isReady, isTrue);
      expect(seen, isEmpty, reason: 'no second RemoteReady');
    });

    test('pushes_before_set_active_are_emitted_after_ready', () async {
      final tv = await _startTv(
        initialPushes: [
          RemoteMessage(remoteStart: RemoteStart(started: true)),
          RemoteMessage(
            remoteSetVolumeLevel: RemoteSetVolumeLevel(
              volumeLevel: 9,
              volumeMax: 100,
            ),
          ),
          RemoteMessage(
            remoteImeKeyInject: RemoteImeKeyInject(
              appInfo: RemoteAppInfo(
                appPackage: 'com.google.android.tvlauncher',
              ),
            ),
          ),
        ],
      );
      await _pair(tv, _paired);
      final client = _client(tv);
      final first4 = client.events.take(4).toList();

      await client.connect().timeout(_setup);

      expect(await first4.timeout(_wait), [
        const RemoteReady(),
        const PowerStateChanged(true),
        const VolumeChanged(9, 100, false),
        const CurrentAppChanged('com.google.android.tvlauncher'),
      ]);
    });

    test('connect_twice_throws_StateError', () async {
      final (_, client) = await _ready();

      await expectLater(client.connect, throwsStateError);
    });

    test('serverPublicKeySha256_matches_the_tv_certificate_key', () async {
      final tv = await _startTv();
      await _pair(tv, _paired);
      final client = _client(tv);
      expect(client.serverPublicKeySha256, isNull);

      await client.connect().timeout(_setup);

      final parts = fakeTvIdentity.publicParts;
      final expected = SHA256Digest().process(
        Uint8List.fromList([...parts.modulus, ...parts.exponent]),
      );
      expect(client.serverPublicKeySha256, orderedEquals(expected));
      expect(client.serverPublicKeySha256, hasLength(32));
    });

    test('certificate_rejected_for_unpaired_identity', () async {
      final tv = await _startTv();
      final client = _client(tv, identity: _trustedButUnpaired);

      await expectLater(
        client.connect().timeout(_setup),
        throwsA(_connectFailure(RemoteCloseReason.certificateRejected)),
      );
      expect(client.isReady, isFalse);
    });

    test('certificate_rejected_for_untrusted_identity', () async {
      final tv = await _startTv();
      final client = _client(tv, identity: _untrusted);

      await expectLater(
        client.connect().timeout(_setup),
        throwsA(_connectFailure(RemoteCloseReason.certificateRejected)),
      );
    });

    test(
      'connect_failure_also_ends_the_event_stream_with_RemoteClosed',
      () async {
        final tv = await _startTv();
        final client = _client(tv, identity: _trustedButUnpaired);
        final all = client.events.toList();

        await expectLater(
          client.connect().timeout(_setup),
          throwsA(isA<RemoteConnectException>()),
        );

        expect(await all.timeout(_wait), [
          const RemoteClosed(RemoteCloseReason.certificateRejected),
        ]);
      },
    );

    test('connection_refused_is_a_network_error', () async {
      final tv = await _startTv();
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final freePort = probe.port;
      await probe.close();
      final client = _client(tv, port: freePort);

      await expectLater(
        client.connect().timeout(_setup),
        throwsA(_connectFailure(RemoteCloseReason.networkError)),
      );
    });

    test('connect_timeout_is_a_network_error', () async {
      final tv = await _startTv();
      final never = Completer<SecureSocket>();
      final client = _client(
        tv,
        connectTimeout: const Duration(milliseconds: 100),
        connector: (host, port, context) => never.future,
      );

      await expectLater(
        client.connect().timeout(_wait),
        throwsA(_connectFailure(RemoteCloseReason.networkError)),
      );
    });

    test('a_socket_arriving_after_the_timeout_is_destroyed', () async {
      final tv = await _startTv();
      await _pair(tv, _paired);
      final lateSocket = Completer<SecureSocket>();
      final client = _client(
        tv,
        connectTimeout: const Duration(milliseconds: 100),
        connector: (host, port, context) => lateSocket.future,
      );
      await expectLater(
        client.connect().timeout(_wait),
        throwsA(_connectFailure(RemoteCloseReason.networkError)),
      );

      final socket = await defaultSocketConnector(
        InternetAddress.loopbackIPv4.address,
        tv.remotePort,
        SecurityContext()
          ..useCertificateChainBytes(utf8.encode(_paired.certificatePem))
          ..usePrivateKeyBytes(utf8.encode(_paired.privateKeyPem)),
      );
      var closed = false;
      socket.listen((_) {}, onDone: () => closed = true, onError: (_) {});
      lateSocket.complete(socket);

      await _eventually(() => closed);
    });

    test('an_unloadable_identity_is_a_network_error_and_ends_events', () async {
      final tv = await _startTv();
      final client = _client(tv, identity: UnloadableIdentity(_paired));
      final all = client.events.toList();

      await expectLater(
        client.connect().timeout(_setup),
        throwsA(_connectFailure(RemoteCloseReason.networkError)),
      );

      expect(await all.timeout(_wait), [
        const RemoteClosed(RemoteCloseReason.networkError),
      ]);
      expect(client.isReady, isFalse);
      await expectLater(client.connect, throwsStateError);
    });

    test('close_during_connect_fails_connect_with_closedByClient', () async {
      final tv = await _startTv();
      final never = Completer<SecureSocket>();
      final client = _client(
        tv,
        connector: (host, port, context) => never.future,
      );
      final failure = expectLater(
        client.connect(),
        throwsA(_connectFailure(RemoteCloseReason.closedByClient)),
      );

      await client.close();

      await failure.timeout(_wait);
    });
  });

  group('keep-alive', () {
    test('answers_pings', () async {
      // The plan's 200 ms ping interval (the _ready default).
      final (tv, client) = await _ready(sendPings: true);
      final seen = <RemoteEvent>[];
      client.events.listen(seen.add);

      // The fake hangs up on a client that ignores three pings in a row, so
      // six answers prove the client keeps replying.
      await _eventually(() => tv.answeredPingCount >= 6);

      expect(tv.clientAnsweredLastPing, isTrue);
      expect(client.isReady, isTrue);
      expect(seen.whereType<RemoteClosed>(), isEmpty);
    });

    test('closes_with_pingTimeout_when_the_tv_goes_silent', () async {
      final tv = await _startTv();
      await _pair(tv, _paired);
      final client = _client(
        tv,
        idleTimeout: const Duration(milliseconds: 300),
      );
      await client.connect().timeout(_setup);
      final closed = _first<RemoteClosed>(client);

      expect((await closed).reason, RemoteCloseReason.pingTimeout);
      expect(client.isReady, isFalse);
    });

    test('traffic_keeps_the_idle_timer_from_firing', () async {
      // 200 ms pings against a 1 s idle timeout: a ping can be 800 ms late
      // (a loaded CI runner) before the timer could fire.
      final tv = await _startTv(sendPings: true);
      await _pair(tv, _paired);
      final client = _client(tv, idleTimeout: const Duration(seconds: 1));
      await client.connect().timeout(_setup);
      final seen = <RemoteEvent>[];
      client.events.listen(seen.add);

      // Twice the idle timeout in ping time (about 10 pings, 2 s).
      await _eventually(() => tv.answeredPingCount >= 10);

      expect(client.isReady, isTrue);
      expect(seen.whereType<RemoteClosed>(), isEmpty);
    });
  });

  group('sending', () {
    test('sends_short_key', () async {
      final (tv, client) = await _ready();

      client.sendKey(KeyCodes.dpadUp);

      await _eventually(() => tv.receivedKeyCodes.isNotEmpty);
      expect(tv.receivedKeyCodes, contains(19));
      expect(tv.receivedKeyDirections, [RemoteDirection.SHORT]);
    });

    test('sends_long_press_pair', () async {
      final (tv, client) = await _ready();

      client
        ..sendKey(KeyCodes.volumeUp, direction: KeyDirection.startLong)
        ..sendKey(KeyCodes.volumeUp, direction: KeyDirection.endLong);

      await _eventually(() => tv.receivedKeyCodes.length == 2);
      expect(tv.receivedKeyCodes, [24, 24]);
      expect(tv.receivedKeyDirections, [
        RemoteDirection.START_LONG,
        RemoteDirection.END_LONG,
      ]);
    });

    test('sends_digit_keys', () async {
      final (tv, client) = await _ready();

      client
        ..sendKey(KeyCodes.digit(0))
        ..sendKey(KeyCodes.digit(9));

      await _eventually(() => tv.receivedKeyCodes.length == 2);
      expect(tv.receivedKeyCodes, [7, 16]);
    });

    test('launches_app_link', () async {
      final (tv, client) = await _ready();

      client.launchAppLink('market://launch?id=com.netflix.ninja');

      await _eventually(() => tv.receivedAppLinks.isNotEmpty);
      expect(tv.receivedAppLinks, ['market://launch?id=com.netflix.ninja']);
    });

    test('sends_text', () async {
      final (tv, client) = await _ready();

      client.sendText('hello');

      await _eventually(() => tv.receivedText.isNotEmpty);
      expect(tv.receivedText, 'hello');
      final edit = tv.receivedImeBatchEdit!;
      expect(edit.imeCounter, 0);
      expect(edit.fieldCounter, 0);
      expect(edit.editInfo.single.insert, 1);
      expect(edit.editInfo.single.textFieldStatus.value, 'hello');
      expect(edit.editInfo.single.textFieldStatus.start, 4);
      expect(edit.editInfo.single.textFieldStatus.end, 4);
    });

    test('sendText_uses_the_counters_of_the_latest_tv_ime_message', () async {
      final (tv, client) = await _ready();
      final shown = _first<ImeShowRequested>(client);
      tv.sendMessages([
        RemoteMessage(
          remoteImeBatchEdit: RemoteImeBatchEdit(
            imeCounter: 3,
            fieldCounter: 4,
          ),
        ),
        RemoteMessage(remoteImeShowRequest: RemoteImeShowRequest()),
      ]);
      await shown;

      client.sendText('x');

      await _eventually(() => tv.receivedText.isNotEmpty);
      expect(tv.receivedImeBatchEdit!.imeCounter, 3);
      expect(tv.receivedImeBatchEdit!.fieldCounter, 4);
    });

    test('sends_enter_and_delete', () async {
      final (tv, client) = await _ready();

      client
        ..sendKey(KeyCodes.enter)
        ..sendKey(KeyCodes.delete);

      await _eventually(() => tv.receivedKeyCodes.length == 2);
      expect(tv.receivedKeyCodes, [66, 67]);
    });

    test('empty_text_clears_the_field', () async {
      final (tv, client) = await _ready();
      client.sendText('abc');
      await _eventually(() => tv.receivedText == 'abc');

      client.sendText('');

      await _eventually(() => tv.receivedText.isEmpty);
      expect(
        tv.receivedImeBatchEdit!.editInfo.single.textFieldStatus.value,
        '',
      );
    });

    test('unsupported_key_code_throws_argument_error', () async {
      final (tv, client) = await _ready();

      expect(() => client.sendKey(9999), throwsArgumentError);

      expect(client.isReady, isTrue);
      client.sendKey(KeyCodes.home);
      await _eventually(() => tv.receivedKeyCodes.isNotEmpty);
      expect(tv.receivedKeyCodes, [KeyCodes.home]);
    });

    test('sendKey_before_ready_throws_StateError', () {
      final client = RemoteClient(
        host: InternetAddress.loopbackIPv4.address,
        identity: _paired,
        deviceInfo: _deviceInfo,
      );
      addTearDown(client.close);

      expect(() => client.sendKey(KeyCodes.home), throwsStateError);
      expect(() => client.launchAppLink('market://x'), throwsStateError);
      expect(() => client.sendText('a'), throwsStateError);
    });

    test('sending_after_close_throws_StateError', () async {
      final (_, client) = await _ready();
      await client.close();

      expect(() => client.sendKey(KeyCodes.home), throwsStateError);
      expect(() => client.launchAppLink('market://x'), throwsStateError);
      expect(() => client.sendText('a'), throwsStateError);
    });

    test('sendKey_with_an_unknown_code_throws_ArgumentError', () async {
      final (tv, client) = await _ready();

      expect(() => client.sendKey(99999), throwsArgumentError);
      expect(() => client.sendKey(-1), throwsArgumentError);
      expect(tv.receivedKeyCodes, isEmpty);
    });
  });

  group('events', () {
    test('emits_volume_events', () async {
      final (tv, client) = await _ready();
      final volume = _first<VolumeChanged>(client);

      tv.sendVolume(level: 7, max: 100, muted: false);

      expect(await volume, const VolumeChanged(7, 100, false));
    });

    test('emits_current_app', () async {
      final (tv, client) = await _ready();
      final app = _first<CurrentAppChanged>(client);

      tv.sendCurrentApp('com.netflix.ninja');

      expect(await app, const CurrentAppChanged('com.netflix.ninja'));
    });

    test('emits_ime_show', () async {
      final (tv, client) = await _ready();
      final shown = _first<ImeShowRequested>(client);

      tv.sendImeShow();

      expect(await shown, const ImeShowRequested());
    });

    test('emits_power_state', () async {
      final (tv, client) = await _ready();
      final power = client.events
          .where((e) => e is PowerStateChanged)
          .take(2)
          .toList();

      tv
        ..setPowerOn(true)
        ..setPowerOn(false);

      expect(await power.timeout(_wait), [
        const PowerStateChanged(true),
        const PowerStateChanged(false),
      ]);
    });

    test('emits_remote_errors', () async {
      final (tv, client) = await _ready();
      final error = _first<RemoteErrorReceived>(client);

      tv.sendMessage(RemoteMessage(remoteError: RemoteError(value: true)));

      expect((await error).message, isNotEmpty);
    });

    test('ignores_unknown_messages_and_empty_app_info', () async {
      final (tv, client) = await _ready();
      final seen = <RemoteEvent>[];
      client.events.listen(seen.add);
      final volume = _first<VolumeChanged>(client);

      tv.sendMessages([
        RemoteMessage(remoteImeKeyInject: RemoteImeKeyInject()),
        RemoteMessage(remoteVoiceBegin: RemoteVoiceBegin()),
        RemoteMessage(
          remoteSetVolumeLevel: RemoteSetVolumeLevel(
            volumeLevel: 1,
            volumeMax: 2,
          ),
        ),
      ]);
      await volume;

      expect(seen, [const VolumeChanged(1, 2, false)]);
      expect(client.isReady, isTrue);
    });

    test('handles_several_messages_in_one_chunk_in_order', () async {
      final (tv, client) = await _ready();
      final three = client.events.take(3).toList();

      tv.sendMessages([
        RemoteMessage(
          remoteSetVolumeLevel: RemoteSetVolumeLevel(
            volumeLevel: 5,
            volumeMax: 50,
            volumeMuted: true,
          ),
        ),
        RemoteMessage(
          remoteImeKeyInject: RemoteImeKeyInject(
            appInfo: RemoteAppInfo(appPackage: 'com.youtube.tv'),
          ),
        ),
        RemoteMessage(remoteStart: RemoteStart(started: true)),
      ]);

      expect(await three.timeout(_wait), [
        const VolumeChanged(5, 50, true),
        const CurrentAppChanged('com.youtube.tv'),
        const PowerStateChanged(true),
      ]);
    });
  });

  group('closing', () {
    test('emits_closed_on_server_drop', () async {
      final (tv, client) = await _ready();
      final all = client.events.toList();

      await tv.dropConnections();

      // RemoteClosed is the only and last event, and the stream then ends.
      expect(await all.timeout(_wait), [
        const RemoteClosed(RemoteCloseReason.remoteClosed),
      ]);
      expect(client.isReady, isFalse);
      expect(() => client.sendKey(KeyCodes.home), throwsStateError);
    });

    test('close_emits_closedByClient_once_and_is_idempotent', () async {
      final (tv, client) = await _ready(
        sendPings: true,
        pingInterval: const Duration(milliseconds: 50),
      );
      await _eventually(() => tv.clientAnsweredLastPing);
      final all = client.events.toList();

      await client.close();
      await client.close();

      expect(await all.timeout(_wait), [
        const RemoteClosed(RemoteCloseReason.closedByClient),
      ]);
      expect(client.isReady, isFalse);
      // The TV notices the hang-up.
      await _eventually(() => !tv.clientAnsweredLastPing);
    });

    test('close_before_connect_is_safe', () async {
      final tv = await _startTv();
      final client = _client(tv);
      final all = client.events.toList();

      await client.close();

      expect(await all.timeout(_wait), [
        const RemoteClosed(RemoteCloseReason.closedByClient),
      ]);
      await expectLater(client.connect, throwsStateError);
    });

    test('a_server_drop_after_close_does_not_emit_again', () async {
      final (tv, client) = await _ready();
      final all = client.events.toList();
      await client.close();

      await tv.dropConnections();

      expect(await all.timeout(_wait), hasLength(1));
    });
  });
}
