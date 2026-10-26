// Proves the app's test fakes behave like the real classes they stand in for.
// When a fake and the real class disagree, a passing widget test can hide a
// bug that only shows against a real TV.

import 'dart:typed_data';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

import 'fake_remote_client.dart';
import 'fake_remote_session.dart';
import 'key_input_recorder.dart';
import 'test_identity.dart';

FakeRemoteClient _client([FakeConnect outcome = FakeConnect.succeed]) {
  final clients = FakeRemoteClients()..defaultOutcome = outcome;
  return clients.create(host: 'h', port: 6466, identity: testIdentity())
      as FakeRemoteClient;
}

void main() {
  group('FakeRemoteClient', () {
    test(
      'fake_client_reports_the_server_key_before_ready_like_the_real_one',
      () async {
        final c = _client();
        expect(c.serverPublicKeySha256, isNull);
        Uint8List? keyAtReady;
        c.events.listen((event) {
          if (event is RemoteReady) keyAtReady = c.serverPublicKeySha256;
        });

        await c.connect();
        await pumpEventQueue();

        expect(keyAtReady, isNotNull);
        expect(c.serverPublicKeySha256, isNotNull);
      },
    );

    test('the_server_key_stays_null_when_the_handshake_fails', () async {
      for (final outcome in [
        FakeConnect.networkError,
        FakeConnect.certificateRejected,
      ]) {
        final c = _client(outcome);
        await expectLater(c.connect(), throwsA(isA<RemoteConnectException>()));
        expect(c.serverPublicKeySha256, isNull, reason: '$outcome');
      }
      final hung = _client(FakeConnect.hang);
      final connecting = hung.connect().then<void>((_) {}, onError: (_) {});
      await pumpEventQueue();
      expect(hung.serverPublicKeySha256, isNull);
      await hung.close();
      await connecting;
    });

    test('fake_client_holds_pushes_until_ready', () async {
      final c = _client();
      final seen = <RemoteEvent>[];
      c.events.listen(seen.add);
      c.push(const VolumeChanged(3, 20, false));
      expect(seen, isEmpty);

      await c.connect();
      await pumpEventQueue();

      expect(seen, [const RemoteReady(), const VolumeChanged(3, 20, false)]);
    });

    test('pushes_after_ready_are_delivered_at_once', () async {
      final c = _client();
      final seen = <RemoteEvent>[];
      c.events.listen(seen.add);
      await c.connect();

      c.push(const PowerStateChanged(true));
      await pumpEventQueue();

      expect(seen, [const RemoteReady(), const PowerStateChanged(true)]);
    });

    test('fake_client_connect_after_close_throws_state_error', () async {
      final c = _client();
      await c.close();

      await expectLater(c.connect(), throwsStateError);
    });

    test('fake_client_rejects_unsupported_key_codes', () async {
      final c = _client();
      await c.connect();

      expect(() => c.sendKey(9999), throwsArgumentError);
      expect(() => c.sendKey(-1), throwsArgumentError);
      expect(c.sentKeys, isEmpty);
      c.sendKey(66);
      expect(c.sentKeys, [(66, KeyDirection.short)]);
    });
  });

  group('FakeRemoteSession', () {
    test('fake_session_records_directions_and_can_fail_a_send', () {
      final s = FakeRemoteSession(
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      )..sendKey(19, direction: KeyDirection.startLong);
      expect(s.sentPresses, [(19, KeyDirection.startLong)]);
      expect(s.sentKeys, [19]);

      s.failNextSends = 1;
      expect(() => s.sendKey(19), throwsA(isA<NotConnectedException>()));
      expect(s.failNextSends, 0);
      s.sendKey(19);
      expect(s.sentKeys, [19, 19]);
    });

    test('a_failed_send_applies_to_links_and_text_too', () {
      final s = FakeRemoteSession(
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      )..failNextSends = 2;

      expect(
        () => s.launchAppLink('market://x'),
        throwsA(isA<NotConnectedException>()),
      );
      expect(() => s.sendText('a'), throwsA(isA<NotConnectedException>()));
      s.sendText('a');
      expect(s.sentTexts, ['a']);
      expect(s.sentLinks, isEmpty);
    });

    test('fake_session_rejects_unsupported_key_codes', () {
      final s = FakeRemoteSession(
        initial: const TvConnectionState(status: ConnectionStatus.connected),
      );

      expect(() => s.sendKey(9999), throwsArgumentError);
      expect(s.sentPresses, isEmpty);
    });

    test('a_session_that_is_not_connected_still_throws_not_connected', () {
      final s = FakeRemoteSession()..failNextSends = 1;

      expect(() => s.sendKey(19), throwsA(isA<NotConnectedException>()));
      expect(s.failNextSends, 1, reason: 'only a connected send consumes it');
    });
  });

  group('KeyInputRecorder', () {
    test('records_commands_and_refuses_them_while_not_connected', () {
      const app = AppEntry(package: 'com.netflix.ninja', name: 'Netflix');
      final r = KeyInputRecorder();

      expect(r.tap(19), isTrue);
      r
        ..holdStart(24)
        ..holdEnd(24);
      expect(r.launch(app), isTrue);
      expect(r.typeText('abc'), isTrue);
      expect(r.calls, [
        'tap:19',
        'holdStart:24',
        'holdEnd:24',
        'launch:com.netflix.ninja',
        'text:abc',
      ]);

      r
        ..calls.clear()
        ..connected = false;
      expect(r.tap(19), isFalse);
      expect(r.launch(app), isFalse);
      expect(r.typeText('abc'), isFalse);
      r
        ..holdStart(24)
        ..holdEnd(24);
      expect(r.refused, 3);
      expect(r.calls, ['holdStart:24', 'holdEnd:24']);
    });
  });
}
