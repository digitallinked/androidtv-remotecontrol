import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/demo/demo_remote_session.dart';

const _delay = Duration(milliseconds: 600);

/// Runs [body] with a demo session that is already connected.
void _whenConnected(
  void Function(DemoRemoteSession session, FakeAsync async) body,
) {
  fakeAsync((async) {
    final session = DemoRemoteSession();
    unawaited(session.connect());
    async.elapse(_delay);
    body(session, async);
  });
}

void main() {
  test('connects_after_the_delay_and_reports_tv_state', () {
    fakeAsync((async) {
      final session = DemoRemoteSession();
      final states = <ConnectionStatus>[];
      final events = <RemoteEvent>[];
      session.states.listen((s) => states.add(s.status));
      session.events.listen(events.add);
      async.flushMicrotasks();
      expect(session.current.status, ConnectionStatus.disconnected);

      var done = false;
      unawaited(session.connect().then((_) => done = true));
      async
        ..flushMicrotasks()
        ..elapse(_delay - const Duration(milliseconds: 1));
      expect(session.current.status, ConnectionStatus.connecting);
      expect(done, isFalse);

      async.elapse(const Duration(milliseconds: 1));
      expect(session.current.status, ConnectionStatus.connected);
      expect(done, isTrue);
      expect(states, [
        ConnectionStatus.disconnected,
        ConnectionStatus.connecting,
        ConnectionStatus.connected,
      ]);
      expect(session.volume, const VolumeChanged(8, 20, false));
      expect(session.isPowerOn, isTrue);
      expect(events, [
        const PowerStateChanged(true),
        const VolumeChanged(8, 20, false),
      ]);
      expect(session.isDemo, isTrue);
      expect(session.tvName, isEmpty);
      expect(session.pairingTarget, isNull);
    });
  });

  test('disconnect_clears_the_simulated_tv_state', () {
    _whenConnected((session, async) {
      session.launchAppLink('market://launch?id=com.netflix.ninja');
      expect(session.volume, isNotNull);
      expect(session.currentApp, 'com.netflix.ninja');

      unawaited(session.disconnect());
      async.flushMicrotasks();

      expect(session.current.status, ConnectionStatus.disconnected);
      expect(session.volume, isNull);
      expect(session.isPowerOn, isNull);
      expect(session.currentApp, isNull);

      unawaited(session.connect());
      async.elapse(_delay);
      expect(session.volume, const VolumeChanged(8, 20, false));
      expect(session.isPowerOn, isTrue);
    });
  });

  test('volume_keys_change_the_simulated_volume_within_bounds', () {
    _whenConnected((session, async) {
      final events = <RemoteEvent>[];
      session.events.listen(events.add);

      for (var i = 0; i < 15; i++) {
        session.sendKey(KeyCodes.volumeUp);
      }
      expect(session.volume, const VolumeChanged(20, 20, false));

      session.sendKey(KeyCodes.volumeDown);
      expect(session.volume, const VolumeChanged(19, 20, false));

      session.sendKey(KeyCodes.mute);
      expect(session.volume, const VolumeChanged(19, 20, true));
      session.sendKey(KeyCodes.mute);
      expect(session.volume?.muted, isFalse);

      for (var i = 0; i < 25; i++) {
        session.sendKey(KeyCodes.volumeDown);
      }
      expect(session.volume?.level, 0);

      async.flushMicrotasks();
      expect(events.last, const VolumeChanged(0, 20, false));
    });
  });

  test('a_held_key_acts_once_and_its_release_changes_nothing', () {
    _whenConnected((session, async) {
      session
        ..sendKey(KeyCodes.volumeUp, direction: KeyDirection.startLong)
        ..sendKey(KeyCodes.volumeUp, direction: KeyDirection.endLong);

      expect(session.volume?.level, 9);
      expect(
        session.lastAction,
        const DemoKeyPressed(KeyCodes.volumeUp, KeyDirection.endLong),
      );
    });
  });

  test('power_key_toggles_power_state', () {
    _whenConnected((session, async) {
      final events = <RemoteEvent>[];
      session.events.listen(events.add);

      session.sendKey(KeyCodes.power);
      expect(session.isPowerOn, isFalse);
      session.sendKey(KeyCodes.power);
      expect(session.isPowerOn, isTrue);

      async.flushMicrotasks();
      expect(events, [
        const PowerStateChanged(false),
        const PowerStateChanged(true),
      ]);
    });
  });

  test('launch_app_link_sets_current_app', () {
    _whenConnected((session, async) {
      final events = <RemoteEvent>[];
      session.events.listen(events.add);

      session.launchAppLink('market://launch?id=com.netflix.ninja');
      expect(session.currentApp, 'com.netflix.ninja');
      expect(
        session.lastAction,
        const DemoAppOpened('market://launch?id=com.netflix.ninja'),
      );

      // A link that names no package is recorded but changes no app.
      session.launchAppLink('https://example.com/watch');
      expect(session.currentApp, 'com.netflix.ninja');
      expect(
        session.lastAction,
        const DemoAppOpened('https://example.com/watch'),
      );

      async.flushMicrotasks();
      expect(events, [const CurrentAppChanged('com.netflix.ninja')]);
    });
  });

  test('actions_stream_and_last_action_record_every_command', () {
    _whenConnected((session, async) {
      final actions = <DemoAction>[];
      session.actions.listen(actions.add);
      expect(session.lastAction, isNull);

      session
        ..sendKey(KeyCodes.home)
        ..sendText('hello');
      async.flushMicrotasks();

      expect(actions, [
        const DemoKeyPressed(KeyCodes.home, KeyDirection.short),
        const DemoTextTyped('hello'),
      ]);
      expect(session.lastAction, const DemoTextTyped('hello'));
    });
  });

  test('commands_throw_until_connected', () {
    fakeAsync((async) {
      final session = DemoRemoteSession();
      void expectThrows() {
        expect(
          () => session.sendKey(KeyCodes.home),
          throwsA(isA<NotConnectedException>()),
        );
        expect(
          () => session.launchAppLink('market://launch?id=a.b'),
          throwsA(isA<NotConnectedException>()),
        );
        expect(
          () => session.sendText('x'),
          throwsA(isA<NotConnectedException>()),
        );
      }

      expectThrows();
      unawaited(session.connect());
      async.elapse(const Duration(milliseconds: 100));
      expectThrows();
      expect(session.lastAction, isNull);

      async.elapse(_delay);
      expect(() => session.sendKey(KeyCodes.home), returnsNormally);
    });
  });

  test('disconnect_and_reconnect_cycle', () {
    _whenConnected((session, async) {
      unawaited(session.disconnect());
      async.flushMicrotasks();
      expect(session.current.status, ConnectionStatus.disconnected);
      expect(
        () => session.sendKey(KeyCodes.home),
        throwsA(isA<NotConnectedException>()),
      );

      // It never goes offline: nudges change nothing.
      session
        ..notifyAppResumed()
        ..notifyNetworkChanged();
      expect(session.current.status, ConnectionStatus.disconnected);

      session.reconnect();
      expect(session.current.status, ConnectionStatus.connecting);
      async.elapse(_delay);
      expect(session.current.status, ConnectionStatus.connected);

      // Reconnect while connected does nothing.
      session.reconnect();
      expect(session.current.status, ConnectionStatus.connected);
    });
  });

  test('disconnect_while_connecting_cancels_the_connect', () {
    fakeAsync((async) {
      final session = DemoRemoteSession();
      var done = false;
      unawaited(session.connect().then((_) => done = true));
      async.elapse(const Duration(milliseconds: 100));

      unawaited(session.disconnect());
      async.elapse(_delay * 2);

      expect(session.current.status, ConnectionStatus.disconnected);
      expect(done, isTrue);
      expect(session.volume, isNull);
    });
  });

  test('dispose_stops_a_pending_connect_and_is_idempotent', () {
    fakeAsync((async) {
      final session = DemoRemoteSession();
      unawaited(session.connect());
      unawaited(session.dispose());
      unawaited(session.dispose());
      async.flushMicrotasks();

      expect(async.pendingTimers, isEmpty);
      expect(session.current.status, ConnectionStatus.disconnected);
      expect(
        () => session.sendKey(KeyCodes.home),
        throwsA(isA<NotConnectedException>()),
      );
    });
  });
}
