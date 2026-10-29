import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../../../helpers/fake_remote_session.dart';
import '../../../helpers/recording_haptics.dart';

void main() {
  late FakeRemoteSession session;
  late RecordingHaptics h;
  late int refused;
  late List<RemoteActionEvent> sent;

  setUp(() {
    session = FakeRemoteSession(
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    );
    h = RecordingHaptics();
    refused = 0;
    sent = [];
  });

  RemoteActions actions({
    bool smooth = true,
    bool haptics = true,
    RemoteSession? s,
    bool noSession = false,
  }) => RemoteActions(
    session: noSession ? null : (s ?? session),
    smoothPress: smooth,
    hapticsEnabled: haptics,
    haptics: h,
    onRefused: () => refused++,
    onSent: sent.add,
  );

  void goOffline() => session.emit(
    const TvConnectionState(status: ConnectionStatus.offline),
  );

  test('smooth_press_sends_start_and_end_long', () {
    fakeAsync((a) {
      final x = actions()..holdStart(KeyCodes.volumeUp);
      a.elapse(const Duration(seconds: 2));
      x.holdEnd(KeyCodes.volumeUp);
      expect(session.sentPresses, [
        (KeyCodes.volumeUp, KeyDirection.startLong),
        (KeyCodes.volumeUp, KeyDirection.endLong),
      ]);
      expect(h.events, ['medium']);
      x.dispose();
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('repeat_mode_sends_short_every_120ms', () {
    fakeAsync((a) {
      final x = actions(smooth: false)..holdStart(KeyCodes.dpadDown);
      expect(session.sentPresses, hasLength(1));
      a.elapse(const Duration(milliseconds: 360));
      expect(session.sentPresses, hasLength(4));
      x.holdEnd(KeyCodes.dpadDown);
      a.elapse(const Duration(seconds: 1));
      expect(session.sentPresses, hasLength(4));
      expect(session.sentPresses.map((p) => p.$2).toSet(), {
        KeyDirection.short,
      });
      expect(h.events, ['medium']);
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('haptics_respect_setting', () {
    fakeAsync((a) {
      actions(haptics: false)
        ..tap(KeyCodes.home)
        ..holdStart(KeyCodes.volumeUp)
        ..holdEnd(KeyCodes.volumeUp)
        ..tap(KeyCodes.power)
        ..dispose();
      expect(h.events, isEmpty);
      expect(session.sentPresses, hasLength(4));

      actions()
        ..tap(KeyCodes.home)
        ..holdStart(KeyCodes.volumeUp)
        ..holdEnd(KeyCodes.volumeUp)
        ..tap(KeyCodes.power)
        ..dispose();
      expect(h.events, ['light', 'medium', 'heavy']);
    });
  });

  test('not_connected_shows_snackbar_and_sends_nothing', () {
    fakeAsync((a) {
      goOffline();
      final x = actions();
      expect(x.tap(KeyCodes.home), isFalse);
      expect(
        x.launch(const AppEntry(package: 'com.netflix.ninja', name: 'N')),
        isFalse,
      );
      expect(x.typeText('hi'), isFalse);
      expect(refused, 3);
      expect(session.sentPresses, isEmpty);
      expect(session.sentLinks, isEmpty);
      expect(session.sentTexts, isEmpty);
      expect(h.events, isEmpty);
      expect(sent, isEmpty);
    });
  });

  test('reloading_session_refuses_commands', () {
    fakeAsync((a) {
      final x = actions(noSession: true);
      expect(x.tap(KeyCodes.home), isFalse);
      expect(refused, 1);
      expect(h.events, isEmpty);
    });
  });

  test('a_send_that_fails_mid_flight_is_refused', () {
    fakeAsync((a) {
      session.failNextSends = 1;
      final x = actions();
      expect(x.tap(KeyCodes.home), isFalse);
      expect(refused, 1);
      expect(h.events, isEmpty);
      expect(sent, isEmpty);
      expect(x.tap(KeyCodes.home), isTrue);
    });
  });

  test('a_refused_hold_start_activates_no_hold', () {
    fakeAsync((a) {
      goOffline();
      final x = actions()..holdStart(KeyCodes.volumeUp);
      expect(refused, 1);
      expect(h.events, isEmpty);
      expect(a.pendingTimers, isEmpty);
      x.holdEnd(KeyCodes.volumeUp);
      expect(refused, 1);
    });
  });

  test('center_hold_is_a_long_press_with_smooth_press_and_a_tap_without', () {
    fakeAsync((a) {
      actions()
        ..holdStart(KeyCodes.dpadCenter)
        ..holdEnd(KeyCodes.dpadCenter);
      expect(session.sentPresses, [
        (KeyCodes.dpadCenter, KeyDirection.startLong),
        (KeyCodes.dpadCenter, KeyDirection.endLong),
      ]);

      session.sentPresses.clear();
      final x = actions(smooth: false)..holdStart(KeyCodes.dpadCenter);
      a.elapse(const Duration(seconds: 1));
      x.holdEnd(KeyCodes.dpadCenter);
      expect(session.sentPresses, [(KeyCodes.dpadCenter, KeyDirection.short)]);
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('non_holdable_keys_hold_as_a_single_tap', () {
    fakeAsync((a) {
      final x = actions()..holdStart(KeyCodes.home);
      expect(session.sentPresses, [(KeyCodes.home, KeyDirection.short)]);
      x.holdEnd(KeyCodes.home);
      a.elapse(const Duration(seconds: 1));
      expect(session.sentPresses, hasLength(1));
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('a_new_hold_ends_the_previous_one', () {
    fakeAsync((a) {
      final x = actions()
        ..holdStart(KeyCodes.volumeUp)
        ..holdStart(KeyCodes.channelUp);
      expect(session.sentPresses, [
        (KeyCodes.volumeUp, KeyDirection.startLong),
        (KeyCodes.volumeUp, KeyDirection.endLong),
        (KeyCodes.channelUp, KeyDirection.startLong),
      ]);
      // The old key's late release does nothing.
      x.holdEnd(KeyCodes.volumeUp);
      expect(session.sentPresses, hasLength(3));
      x.holdEnd(KeyCodes.channelUp);
      expect(session.sentPresses.last, (
        KeyCodes.channelUp,
        KeyDirection.endLong,
      ));
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('hold_auto_releases_after_15s', () {
    fakeAsync((a) {
      final x = actions()..holdStart(KeyCodes.volumeDown);
      a.elapse(const Duration(seconds: 14, milliseconds: 999));
      expect(session.sentPresses, hasLength(1));
      a.elapse(const Duration(milliseconds: 1));
      expect(session.sentPresses.last, (
        KeyCodes.volumeDown,
        KeyDirection.endLong,
      ));
      x.holdEnd(KeyCodes.volumeDown);
      expect(session.sentPresses, hasLength(2));
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('repeat_hold_auto_releases_after_15s', () {
    fakeAsync((a) {
      actions(smooth: false).holdStart(KeyCodes.dpadUp);
      a.elapse(const Duration(seconds: 15));
      // The first send plus one per 120 ms tick; the guard fires first at 15 s,
      // so the tick due at the same instant never runs.
      expect(session.sentPresses, hasLength(125));
      a.elapse(const Duration(seconds: 5));
      expect(session.sentPresses, hasLength(125));
      expect(session.sentPresses.map((p) => p.$2).toSet(), {
        KeyDirection.short,
      });
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('a_throwing_listener_does_not_disarm_the_hold_guard', () {
    fakeAsync((a) {
      final x = RemoteActions(
        session: session,
        smoothPress: true,
        hapticsEnabled: true,
        haptics: h,
        onRefused: () => refused++,
        onSent: (_) => throw StateError('analytics failed'),
      )..holdStart(KeyCodes.volumeUp);
      a.elapse(const Duration(seconds: 15));
      expect(session.sentPresses, [
        (KeyCodes.volumeUp, KeyDirection.startLong),
        (KeyCodes.volumeUp, KeyDirection.endLong),
      ]);
      expect(a.pendingTimers, isEmpty);
      x.dispose();
    });
  });

  test('a_throwing_listener_does_not_break_repeat_or_tap', () {
    fakeAsync((a) {
      final x = RemoteActions(
        session: session,
        smoothPress: false,
        hapticsEnabled: true,
        haptics: h,
        onRefused: () => refused++,
        onSent: (_) => throw StateError('analytics failed'),
      );
      expect(x.tap(KeyCodes.home), isTrue);
      expect(
        x.launch(const AppEntry(package: 'p', name: 'P')),
        isTrue,
      );
      expect(x.typeText('a'), isTrue);
      x.holdStart(KeyCodes.dpadDown);
      a.elapse(const Duration(milliseconds: 240));
      expect(
        session.sentPresses.where((p) => p.$1 == KeyCodes.dpadDown),
        hasLength(3),
      );
      x.holdEnd(KeyCodes.dpadDown);
      expect(refused, 0);
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('unsupported_key_code_throws_even_when_not_connected', () {
    fakeAsync((a) {
      goOffline();
      expect(() => actions().tap(9999), throwsArgumentError);
      expect(refused, 0);
    });
  });

  test('dispose_releases_an_active_hold', () {
    fakeAsync((a) {
      final x = actions()
        ..holdStart(KeyCodes.volumeUp)
        ..dispose();
      expect(session.sentPresses.last, (
        KeyCodes.volumeUp,
        KeyDirection.endLong,
      ));
      expect(a.pendingTimers, isEmpty);
      final count = session.sentPresses.length;
      expect(x.tap(KeyCodes.home), isFalse);
      expect(x.launch(const AppEntry(package: 'p', name: 'P')), isFalse);
      expect(x.typeText('x'), isFalse);
      x
        ..holdStart(KeyCodes.volumeUp)
        ..dispose();
      expect(session.sentPresses, hasLength(count));
      expect(session.sentLinks, isEmpty);
      expect(session.sentTexts, isEmpty);
    });
  });

  test('dispose_stops_a_repeating_hold', () {
    fakeAsync((a) {
      actions(smooth: false)
        ..holdStart(KeyCodes.dpadLeft)
        ..dispose();
      final count = session.sentPresses.length;
      a.elapse(const Duration(seconds: 1));
      expect(session.sentPresses, hasLength(count));
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('release_after_the_connection_dropped_is_silent', () {
    fakeAsync((a) {
      final x = actions()..holdStart(KeyCodes.volumeUp);
      goOffline();
      x.holdEnd(KeyCodes.volumeUp);
      expect(refused, 0);
      expect(a.pendingTimers, isEmpty);
    });
  });

  test('repeat_stops_and_reports_once_when_the_connection_drops', () {
    fakeAsync((a) {
      final x = actions(smooth: false)..holdStart(KeyCodes.dpadDown);
      session.failNextSends = 5;
      a.elapse(const Duration(seconds: 1));
      expect(refused, 1);
      expect(session.sentPresses, hasLength(1));
      expect(a.pendingTimers, isEmpty);
      x.holdEnd(KeyCodes.dpadDown);
      expect(refused, 1);
    });
  });

  test('power_tap_uses_heavy_haptic', () {
    fakeAsync((a) {
      actions().tap(KeyCodes.power);
      expect(h.events, ['heavy']);
    });
  });

  test('tap_reports_the_sent_key', () {
    fakeAsync((a) {
      actions().tap(KeyCodes.back);
      expect(sent, [const KeySent(KeyCodes.back, KeyDirection.short)]);
      expect(session.sentPresses, [(KeyCodes.back, KeyDirection.short)]);
    });
  });

  test('hold_start_reports_the_first_send_only', () {
    fakeAsync((a) {
      actions()
        ..holdStart(KeyCodes.volumeUp)
        ..holdEnd(KeyCodes.volumeUp);
      expect(sent, [const KeySent(KeyCodes.volumeUp, KeyDirection.startLong)]);

      sent.clear();
      actions(smooth: false)
        ..holdStart(KeyCodes.dpadDown)
        ..holdEnd(KeyCodes.dpadDown);
      a.elapse(const Duration(seconds: 1));
      expect(sent, [const KeySent(KeyCodes.dpadDown, KeyDirection.short)]);
    });
  });

  test('launch_sends_the_app_link', () {
    fakeAsync((a) {
      expect(
        actions().launch(
          const AppEntry(package: 'com.netflix.ninja', name: 'Netflix'),
        ),
        isTrue,
      );
      expect(session.sentLinks, ['market://launch?id=com.netflix.ninja']);
      expect(sent, [const AppLaunched('com.netflix.ninja')]);
      expect(h.events, ['light']);
    });
  });

  test('type_text_reports_length_only', () {
    fakeAsync((a) {
      expect(actions().typeText('hello'), isTrue);
      expect(session.sentTexts, ['hello']);
      expect(sent, [const TextSent(5)]);
      expect(sent.single.toString(), isNot(contains('hello')));
      expect(h.events, isEmpty);
    });
  });

  test('listener_errors_are_logged_in_debug_without_event_data', () {
    final logged = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    addTearDown(() => debugPrint = original);

    final x = RemoteActions(
      session: session,
      smoothPress: true,
      hapticsEnabled: false,
      haptics: h,
      onRefused: () => refused++,
      onSent: (event) => throw StateError('secret detail 24'),
    );

    // The press still counts as sent.
    expect(x.tap(KeyCodes.volumeUp), isTrue);
    expect(session.sentKeys, [KeyCodes.volumeUp]);
    expect(logged, hasLength(1));
    expect(logged.single, contains('RemoteActions listener failed on KeySent'));
    expect(logged.single, contains('StateError'));
    // Neither the key code, nor the error's message.
    expect(logged.single, isNot(contains('24')));
    expect(logged.single, isNot(contains('secret')));
  });

  test('a_policy_error_from_the_listener_is_not_swallowed_in_debug', () {
    final x = RemoteActions(
      session: session,
      smoothPress: true,
      hapticsEnabled: false,
      haptics: h,
      onRefused: () => refused++,
      onSent: (event) => throw AnalyticsPolicyError('key_press: bad'),
    );
    // A bad analytics event fails the test that triggered it; the key was
    // sent before the listener ran.
    expect(
      () => x.tap(KeyCodes.volumeUp),
      throwsA(isA<AnalyticsPolicyError>()),
    );
    expect(session.sentKeys, [KeyCodes.volumeUp]);
  });

  test('unsupported_key_code_throws', () {
    fakeAsync((a) {
      expect(() => actions().tap(9999), throwsArgumentError);
    });
  });

  test('events_compare_by_value', () {
    expect(
      const KeySent(1, KeyDirection.short),
      const KeySent(1, KeyDirection.short),
    );
    expect(
      const KeySent(1, KeyDirection.short).hashCode,
      const KeySent(1, KeyDirection.short).hashCode,
    );
    expect(
      const KeySent(1, KeyDirection.short),
      isNot(const KeySent(1, KeyDirection.startLong)),
    );
    expect(const AppLaunched('a'), const AppLaunched('a'));
    expect(const AppLaunched('a'), isNot(const AppLaunched('b')));
    expect(const TextSent(3), const TextSent(3));
    expect(const TextSent(3), isNot(const TextSent(4)));
  });

  test('holdable_and_repeatable_key_sets', () {
    expect(RemoteActions.holdableKeys, contains(KeyCodes.dpadCenter));
    expect(RemoteActions.repeatableKeys, isNot(contains(KeyCodes.dpadCenter)));
    expect(
      RemoteActions.repeatableKeys,
      RemoteActions.holdableKeys.difference({KeyCodes.dpadCenter}),
    );
    expect(RemoteActions.holdableKeys, isNot(contains(KeyCodes.home)));
  });
}
