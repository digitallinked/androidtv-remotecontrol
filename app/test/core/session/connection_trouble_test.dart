import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/connection_trouble.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/session_providers.dart';

import '../../helpers/fake_remote_session.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _window = Duration(seconds: 60);

/// Lets every pending future and zero-delay timer run, without moving the
/// clock.
void _settle(FakeAsync async) {
  async
    ..flushMicrotasks()
    ..elapse(Duration.zero);
}

void main() {
  final start = DateTime.utc(2026, 10, 31, 12);

  /// Runs [body] with a fake clock that starts at [start] and moves with
  /// `async.elapse`.
  void timed(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(async.getClock(start), () => body(async));
    });
  }

  ({ProviderContainer container, FakeRemoteSession session}) rig(
    FakeAsync async, {
    TvConnectionState initial = _connected,
  }) {
    final session = FakeRemoteSession(initial: initial);
    final container = ProviderContainer.test(
      overrides: [remoteSessionProvider.overrideWith((ref) async => session)],
    )..listen(connectionTroubleProvider, (_, _) {});
    _settle(async);
    return (container: container, session: session);
  }

  DateTime? lastTrouble(ProviderContainer c) =>
      c.read(connectionTroubleProvider);

  bool within(ProviderContainer c, [Duration window = _window]) =>
      c.read(connectionTroubleProvider.notifier).troubleWithin(window);

  test(
    'trouble_is_noted_on_entering_reconnecting_offline_or_needs_pairing',
    () {
      for (final status in [
        ConnectionStatus.reconnecting,
        ConnectionStatus.offline,
        ConnectionStatus.needsPairing,
      ]) {
        timed((async) {
          final r = rig(async);
          expect(lastTrouble(r.container), isNull, reason: 'connected');
          expect(within(r.container), isFalse);

          async.elapse(const Duration(seconds: 5));
          r.session.emit(TvConnectionState(status: status));
          _settle(async);

          expect(
            lastTrouble(r.container),
            start.add(const Duration(seconds: 5)),
            reason: status.name,
          );
          expect(within(r.container), isTrue, reason: status.name);
        });
      }
    },
  );

  test('a_failed_first_connect_is_trouble', () {
    timed((async) {
      final r = rig(
        async,
        initial: const TvConnectionState(status: ConnectionStatus.connecting),
      );
      expect(lastTrouble(r.container), isNull);

      // The TV could not be reached on the first attempt.
      r.session.emit(
        const TvConnectionState(
          status: ConnectionStatus.reconnecting,
          attempt: 1,
          lastError: RemoteCloseReason.networkError,
        ),
      );
      _settle(async);

      expect(lastTrouble(r.container), start);
    });
  });

  test('a_session_that_cannot_be_opened_is_trouble', () {
    timed((async) {
      final container = ProviderContainer.test(
        overrides: [
          remoteSessionProvider.overrideWith(
            (ref) async => throw StateError('no identity'),
          ),
        ],
      )..listen(connectionTroubleProvider, (_, _) {});
      _settle(async);

      expect(container.read(connectionTroubleProvider), start);
    });
  });

  test('trouble_is_noted_on_a_not_connected_notice', () {
    timed((async) {
      final r = rig(async);
      async.elapse(const Duration(seconds: 7));

      r.container.read(notConnectedNoticesProvider.notifier).notify();
      _settle(async);

      expect(lastTrouble(r.container), start.add(const Duration(seconds: 7)));
      expect(within(r.container), isTrue);
    });
  });

  test('trouble_within_is_false_after_the_window', () {
    timed((async) {
      final r = rig(async);
      r.session.emit(const TvConnectionState(status: ConnectionStatus.offline));
      _settle(async);

      async.elapse(const Duration(seconds: 59));
      expect(within(r.container), isTrue, reason: '59 s');
      async.elapse(const Duration(seconds: 1));
      expect(within(r.container), isFalse, reason: '60 s');
      expect(
        within(r.container, const Duration(seconds: 61)),
        isTrue,
        reason: 'a longer window',
      );
    });
  });

  test('connected_after_connected_is_not_trouble', () {
    timed((async) {
      final r = rig(async);
      r.session
        ..emit(_connected)
        ..emit(_connected);
      _settle(async);
      // The app closing the connection itself is not trouble either.
      r.session.emit(
        const TvConnectionState(status: ConnectionStatus.disconnected),
      );
      _settle(async);
      r.session.emit(
        const TvConnectionState(status: ConnectionStatus.connecting),
      );
      _settle(async);
      r.session.emit(_connected);
      _settle(async);

      expect(lastTrouble(r.container), isNull);
      expect(within(r.container), isFalse);
    });
  });

  test('trouble_lasts_until_it_ends', () {
    timed((async) {
      final r = rig(async);
      r.session.emit(
        const TvConnectionState(
          status: ConnectionStatus.reconnecting,
          attempt: 1,
        ),
      );
      _settle(async);

      // Still reconnecting after 89 s: the trouble is still going on.
      async.elapse(const Duration(seconds: 89));
      expect(within(r.container), isTrue, reason: 'still reconnecting');

      // The app closes it at 90 s (the background grace) and later opens a
      // clean session.
      async.elapse(const Duration(seconds: 1));
      r.session.emit(
        const TvConnectionState(status: ConnectionStatus.disconnected),
      );
      _settle(async);
      async.elapse(const Duration(seconds: 5));
      r.session.emit(
        const TvConnectionState(status: ConnectionStatus.connecting),
      );
      _settle(async);
      r.session.emit(_connected);
      _settle(async);

      expect(lastTrouble(r.container), start.add(const Duration(seconds: 90)));
      expect(within(r.container), isTrue, reason: 'ended 5 s ago');
      async.elapse(const Duration(seconds: 55));
      expect(within(r.container), isFalse, reason: 'ended 60 s ago');
    });
  });

  test('every_troubled_emission_refreshes_the_time', () {
    timed((async) {
      final r = rig(async);
      r.session.emit(
        const TvConnectionState(
          status: ConnectionStatus.reconnecting,
          attempt: 1,
        ),
      );
      _settle(async);
      async.elapse(const Duration(seconds: 3));
      r.session.emit(
        const TvConnectionState(
          status: ConnectionStatus.reconnecting,
          attempt: 2,
        ),
      );
      _settle(async);
      expect(lastTrouble(r.container), start.add(const Duration(seconds: 3)));

      async.elapse(const Duration(seconds: 4));
      r.session.emit(const TvConnectionState(status: ConnectionStatus.offline));
      _settle(async);
      expect(lastTrouble(r.container), start.add(const Duration(seconds: 7)));
    });
  });

  test('a_session_switch_while_reconnecting_ends_the_trouble', () {
    timed((async) {
      var session = FakeRemoteSession(
        initial: const TvConnectionState(
          status: ConnectionStatus.reconnecting,
          attempt: 1,
        ),
      );
      final container = ProviderContainer.test(
        overrides: [remoteSessionProvider.overrideWith((ref) async => session)],
      )..listen(connectionTroubleProvider, (_, _) {});
      _settle(async);
      async.elapse(const Duration(seconds: 120));

      // Another TV, already connected: the old session's trouble ends now.
      session = FakeRemoteSession(tvName: 'Den', initial: _connected);
      container.invalidate(remoteSessionProvider);
      _settle(async);

      expect(
        container.read(connectionTroubleProvider),
        start.add(const Duration(seconds: 120)),
      );
      async.elapse(const Duration(seconds: 60));
      expect(
        container
            .read(connectionTroubleProvider.notifier)
            .troubleWithin(_window),
        isFalse,
      );
    });
  });

  test('a_status_already_troubled_when_built_is_noted', () {
    timed((async) {
      final session = FakeRemoteSession(
        initial: const TvConnectionState(status: ConnectionStatus.offline),
      );
      final container = ProviderContainer.test(
        overrides: [remoteSessionProvider.overrideWith((ref) async => session)],
      )..listen(connectionStateProvider, (_, _) {});
      _settle(async);
      async.elapse(const Duration(seconds: 4));

      // Built only now, with the connection already offline.
      container.listen(connectionTroubleProvider, (_, _) {});
      _settle(async);

      expect(
        container.read(connectionTroubleProvider),
        start.add(const Duration(seconds: 4)),
      );
    });
  });
}
