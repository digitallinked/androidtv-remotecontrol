import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/session_supervisor.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/manual_session_signals.dart';

void main() {
  late FakeRemoteSession s;
  late ManualSessionSignals signals;
  late SessionSupervisor supervisor;
  var clock = DateTime.utc(2026);

  void start() {
    clock = DateTime.utc(2026);
    s = FakeRemoteSession();
    signals = ManualSessionSignals();
    supervisor = SessionSupervisor(
      session: s,
      signals: signals,
      now: () => clock,
    );
  }

  test('closes_socket_after_60s_in_background', () {
    fakeAsync((a) {
      start();
      signals.background();
      a.elapse(const Duration(seconds: 59));
      expect(s.disconnectCalls, 0);
      a.elapse(const Duration(seconds: 1));
      expect(s.disconnectCalls, 1);
      supervisor.dispose();
    });
  });

  test('returning_within_60s_keeps_the_socket', () {
    fakeAsync((a) {
      start();
      signals.background();
      a.elapse(const Duration(seconds: 30));
      clock = clock.add(const Duration(seconds: 30));
      signals.foreground();
      a.elapse(const Duration(seconds: 60));
      expect(s.disconnectCalls, 0);
      expect(s.connectCalls, 0);
      expect(s.resumeCalls, 1);
      expect(s.networkCalls, 0);
      supervisor.dispose();
    });
  });

  test('resume_nudge_waits_for_the_debounce', () {
    fakeAsync((a) {
      start();
      signals
        ..background()
        ..foreground();
      a.elapse(const Duration(milliseconds: 499));
      expect(s.resumeCalls, 0);
      a.elapse(const Duration(milliseconds: 1));
      expect(s.resumeCalls, 1);
      supervisor.dispose();
    });
  });

  test('resume_triggers_reconnect', () {
    fakeAsync((a) {
      start();
      signals.background();
      clock = clock.add(const Duration(seconds: 61));
      a.elapse(const Duration(seconds: 61));
      signals.foreground();
      a.flushMicrotasks();
      expect(s.connectCalls, 1);
      expect(s.resumeCalls + s.networkCalls, 0);
      a.elapse(const Duration(seconds: 5));
      expect(s.connectCalls, 1);
      expect(s.resumeCalls + s.networkCalls, 0);
      supervisor.dispose();
    });
  });

  test(
    'resume_after_suspension_longer_than_grace_reconnects_even_if_timer_never_'
    'fired',
    () {
      fakeAsync((a) {
        start();
        signals.background();
        // The wall clock jumps, no fake time passes (iOS suspended the timer).
        clock = clock.add(const Duration(minutes: 10));
        signals.foreground();
        a.flushMicrotasks();
        expect((s.disconnectCalls, s.connectCalls), (1, 1));
        supervisor.dispose();
      });
    },
  );

  test('no_forced_reconnect_while_needs_pairing', () {
    fakeAsync((a) {
      start();
      s.emit(const TvConnectionState(status: ConnectionStatus.needsPairing));
      signals.background();
      clock = clock.add(const Duration(minutes: 10));
      a.elapse(const Duration(minutes: 10));
      signals.foreground();
      a.flushMicrotasks();
      expect(s.connectCalls, 0);
      supervisor.dispose();
    });
  });

  test('burst_of_resume_and_network_changes_is_coalesced_into_one_nudge', () {
    fakeAsync((a) {
      start();
      signals.background();
      a.elapse(const Duration(seconds: 5));
      clock = clock.add(const Duration(seconds: 5));
      signals.foreground();
      for (var i = 0; i < 3; i++) {
        a.elapse(const Duration(milliseconds: 150));
        signals.networkChanged();
      }
      a.elapse(const Duration(milliseconds: 499));
      expect(s.networkCalls + s.resumeCalls, 0);
      a.elapse(const Duration(milliseconds: 1));
      expect((s.networkCalls, s.resumeCalls), (1, 0));
      a.elapse(const Duration(seconds: 5));
      expect((s.networkCalls, s.resumeCalls), (1, 0));
      supervisor.dispose();
    });
  });

  test('network_change_in_foreground_nudges_once_after_the_debounce', () {
    fakeAsync((a) {
      start();
      signals.networkChanged();
      a.elapse(const Duration(milliseconds: 499));
      expect(s.networkCalls, 0);
      a.elapse(const Duration(milliseconds: 1));
      expect((s.networkCalls, s.resumeCalls), (1, 0));
      supervisor.dispose();
    });
  });

  test('network_changes_in_background_are_ignored', () {
    fakeAsync((a) {
      start();
      signals.background();
      a.elapse(const Duration(seconds: 10));
      signals.networkChanged();
      a.elapse(const Duration(seconds: 1));
      expect(s.networkCalls + s.resumeCalls + s.connectCalls, 0);
      supervisor.dispose();
    });
  });

  test('network_change_after_the_grace_disconnect_opens_no_connection', () {
    fakeAsync((a) {
      start();
      signals.background();
      clock = clock.add(const Duration(seconds: 61));
      a.elapse(const Duration(seconds: 61));
      expect(s.disconnectCalls, 1);
      signals.networkChanged();
      a.elapse(const Duration(seconds: 10));
      expect(
        s.networkCalls + s.resumeCalls + s.connectCalls + s.reconnectCalls,
        0,
      );
      supervisor.dispose();
    });
  });

  test('pending_nudge_is_dropped_when_the_app_goes_to_background', () {
    fakeAsync((a) {
      start();
      signals.networkChanged();
      a.elapse(const Duration(milliseconds: 100));
      signals.background();
      a.elapse(const Duration(seconds: 1));
      expect(s.networkCalls + s.resumeCalls, 0);
      supervisor.dispose();
    });
  });

  test('returning_after_grace_reconnects_exactly_once_despite_a_burst', () {
    fakeAsync((a) {
      start();
      signals.background();
      clock = clock.add(const Duration(seconds: 61));
      a.elapse(const Duration(seconds: 61));
      signals
        ..networkChanged() // backgrounded: ignored
        ..foreground()
        ..networkChanged()
        ..networkChanged();
      a
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 5));
      expect(s.connectCalls, 1);
      expect(s.disconnectCalls, 2); // the grace one and the pre-connect one
      expect(s.resumeCalls, 0);
      // Only the foreground network changes nudge, as one call.
      expect(s.networkCalls, 1);
      supervisor.dispose();
    });
  });

  test('repeated_visibility_signals_are_idempotent', () {
    fakeAsync((a) {
      start();
      signals
        ..foreground() // already in the foreground
        ..background()
        ..background();
      a.elapse(const Duration(seconds: 60));
      expect(s.disconnectCalls, 1);
      supervisor.dispose();
    });
  });

  test('dispose_cancels_pending_timers_and_ignores_later_signals', () {
    fakeAsync((a) {
      start();
      signals.background();
      supervisor.dispose();
      a.elapse(const Duration(seconds: 120));
      expect(s.disconnectCalls, 0);

      start();
      signals.networkChanged();
      supervisor.dispose();
      a.elapse(const Duration(seconds: 1));
      expect(s.networkCalls, 0);

      signals
        ..background()
        ..foreground()
        ..networkChanged();
      a.elapse(const Duration(seconds: 120));
      expect(
        s.disconnectCalls + s.connectCalls + s.networkCalls + s.resumeCalls,
        0,
      );
    });
  });
}
