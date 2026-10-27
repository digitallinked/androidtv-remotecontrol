import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/review/review_prompter.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../../helpers/fake_config_source.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_review_requester.dart';
import '../../helpers/manual_session_signals.dart';
import '../../helpers/recording_analytics_sink.dart';

const _disconnected = TvConnectionState(status: ConnectionStatus.disconnected);
const _connecting = TvConnectionState(status: ConnectionStatus.connecting);
const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _reconnecting = TvConnectionState(status: ConnectionStatus.reconnecting);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

/// Lets every pending future and zero-delay timer run, without moving the
/// clock.
void settle(FakeAsync async) {
  async
    ..flushMicrotasks()
    ..elapse(Duration.zero);
}

/// Everything one review test controls.
typedef _Rig = ({
  ProviderContainer container,
  FakeRemoteSession session,
  ManualSessionSignals signals,
  ReviewPrompter prompter,
});

void main() {
  late SettingsStore store;
  late RecordingAnalyticsSink sink;
  late FakeReviewRequester requester;

  final start = DateTime.utc(2026, 10, 28, 12);

  /// A fresh install: empty preferences, analytics allowed (a region that
  /// needs no consent) and a review API that is there.
  void install(FakeAsync async, {int launchCount = 2, int presses = 0}) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    unawaited(
      SettingsStore.open().then((s) async {
        store = s;
        await s.setConsentRegion(ConsentRegion.notRequired);
        await s.setLaunchCount(launchCount);
        await s.setReviewKeyPresses(presses);
      }),
    );
    settle(async);
    sink = RecordingAnalyticsSink();
    requester = FakeReviewRequester();
  }

  /// One launch of the app on [store]: the configuration is activated and
  /// the prompter is started and kept listened to, as `App` does.
  _Rig launch(
    FakeAsync async, {
    Map<String, Object?> config = const {},
    bool demo = false,
  }) {
    final session = FakeRemoteSession(isDemo: demo);
    final signals = ManualSessionSignals();
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        remoteConfigSourceProvider.overrideWithValue(FakeConfigSource(config)),
        remoteSessionProvider.overrideWith((ref) async => session),
        sessionSignalsProvider.overrideWithValue(signals),
        reviewRequesterProvider.overrideWithValue(requester),
        analyticsSinkProvider.overrideWithValue(sink),
        // The guard throws, as in a debug build.
        analyticsDebugBuildProvider.overrideWithValue(true),
      ],
    );
    // As at startup: last launch's values are activated, then sealed.
    unawaited(container.read(appConfigProvider.notifier).load());
    settle(async);
    container
      ..read(appConfigProvider.notifier).seal()
      ..listen(appAnalyticsProvider, (_, _) {})
      ..listen(reviewPrompterProvider, (_, _) {});
    settle(async);
    return (
      container: container,
      session: session,
      signals: signals,
      prompter: container.read(reviewPrompterProvider.notifier),
    );
  }

  void press(FakeAsync async, _Rig r, int times) {
    for (var i = 0; i < times; i++) {
      r.prompter.countPress();
    }
    settle(async);
  }

  /// A clean start of a session: connecting, then connected.
  void connect(FakeAsync async, _Rig r) {
    r.session.emit(_connecting);
    settle(async);
    r.session.emit(_connected);
    settle(async);
  }

  /// The app closes the connection itself (a TV switch, the background
  /// grace).
  void disconnect(FakeAsync async, _Rig r) {
    r.session.emit(_disconnected);
    settle(async);
  }

  List<String> reviewEvents() => [
    for (final name in sink.eventNames)
      if (name == 'review_prompt_shown') name,
  ];

  /// Runs [body] with a fake clock that starts at [start] and moves with
  /// `async.elapse`.
  void timed(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(async.getClock(start), () => body(async));
    });
  }

  test('review_prompt_after_150_presses_and_2_sessions_never_after_error', () {
    timed((async) {
      // The first launch: never, however much the remote is used.
      install(async, launchCount: 1);
      var r = launch(async);
      press(async, r, 150);
      connect(async, r);
      expect(requester.requests, 0, reason: 'first launch');
      expect(reviewEvents(), isEmpty);

      // One press short of the threshold.
      install(async);
      r = launch(async);
      press(async, r, 149);
      connect(async, r);
      expect(requester.requests, 0, reason: '149 presses');

      // A connection loss 30 s before the connect.
      install(async);
      r = launch(async);
      press(async, r, 149);
      connect(async, r);
      press(async, r, 1);
      r.session.emit(_reconnecting);
      settle(async);
      r.session.emit(_offline);
      settle(async);
      async.elapse(const Duration(seconds: 10));
      disconnect(async, r);
      async.elapse(const Duration(seconds: 20));
      connect(async, r);
      expect(requester.requests, 0, reason: 'a loss 30 s ago');
      // Once 60 s have passed, the next clean start may ask.
      disconnect(async, r);
      async.elapse(const Duration(seconds: 30));
      connect(async, r);
      expect(requester.requests, 1, reason: 'a loss 60 s ago');

      // A "Not connected" notice 30 s before the connect.
      install(async);
      r = launch(async);
      press(async, r, 150);
      r.container.read(notConnectedNoticesProvider.notifier).notify();
      settle(async);
      async.elapse(const Duration(seconds: 30));
      connect(async, r);
      expect(requester.requests, 0, reason: 'a notice 30 s ago');

      // A reconnect after a loss is not the start of a session, even when
      // it took longer than 60 s.
      install(async);
      r = launch(async);
      press(async, r, 149);
      connect(async, r);
      press(async, r, 1);
      r.session.emit(_reconnecting);
      settle(async);
      async.elapse(const Duration(seconds: 90));
      r.session.emit(_connected);
      settle(async);
      expect(requester.requests, 0, reason: 'a recovery');

      // The second launch, 150 presses and a clean connect.
      install(async);
      r = launch(async);
      press(async, r, 150);
      connect(async, r);
      expect(requester.availabilityChecks, 1);
      expect(requester.requests, 1);
      expect(reviewEvents(), ['review_prompt_shown']);
      expect(store.reviewPromptShown, isTrue);
    });
  });

  test('review_prompt_shown_at_most_once', () {
    timed((async) {
      install(async, presses: 150);
      final r = launch(async);
      connect(async, r);
      expect(requester.requests, 1);

      // Another TV, later the same day.
      async.elapse(const Duration(hours: 1));
      disconnect(async, r);
      connect(async, r);
      expect(requester.requests, 1);

      // Another launch on the same install.
      r.container.dispose();
      final again = launch(async);
      press(async, again, 500);
      connect(async, again);
      expect(requester.requests, 1);
      expect(reviewEvents(), hasLength(1));
    });
  });

  test('threshold_comes_from_remote_config', () {
    timed((async) {
      install(async);
      final r = launch(
        async,
        config: const {'review_prompt_min_key_presses': 5},
      );
      press(async, r, 4);
      connect(async, r);
      expect(requester.requests, 0);

      disconnect(async, r);
      press(async, r, 1);
      connect(async, r);
      expect(requester.requests, 1);
    });
  });

  test('demo_never_prompts', () {
    timed((async) {
      install(async, presses: 150);
      final r = launch(async, demo: true);
      press(async, r, 20);
      connect(async, r);
      expect(requester.availabilityChecks, 0);
      expect(requester.requests, 0);
      expect(reviewEvents(), isEmpty);
      expect(store.reviewPromptShown, isFalse);

      // Demo presses are not counted either.
      r.signals.background();
      settle(async);
      expect(store.reviewKeyPresses, 150);
    });
  });

  test('unavailable_review_api_marks_nothing', () {
    timed((async) {
      install(async, presses: 150);
      requester.available = false;
      final r = launch(async);
      connect(async, r);
      expect(requester.availabilityChecks, 1);
      expect(requester.requests, 0);
      expect(store.reviewPromptShown, isFalse);
      expect(reviewEvents(), isEmpty);

      // It tries again on the next clean start.
      requester.available = true;
      disconnect(async, r);
      connect(async, r);
      expect(requester.requests, 1);
      expect(store.reviewPromptShown, isTrue);
    });
  });

  test('press_count_survives_restart', () {
    timed((async) {
      install(async);
      final r = launch(async);
      press(async, r, 25);
      expect(store.reviewKeyPresses, 20, reason: 'written every 10 presses');
      r.signals.background();
      settle(async);
      expect(store.reviewKeyPresses, 25, reason: 'and on pause');

      // The next launch carries on from 25: 124 more is one short.
      r.container.dispose();
      final again = launch(async);
      press(async, again, 124);
      connect(async, again);
      expect(requester.requests, 0);

      disconnect(async, again);
      press(async, again, 1);
      connect(async, again);
      expect(requester.requests, 1);
    });
  });
}
