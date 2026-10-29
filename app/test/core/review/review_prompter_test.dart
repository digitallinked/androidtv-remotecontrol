import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/review/review_prompter.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_config_source.dart';
import '../../helpers/fake_consent_service.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_review_requester.dart';
import '../../helpers/manual_session_signals.dart';
import '../../helpers/recording_analytics_sink.dart';
import '../../helpers/recording_crash_reporter.dart';

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
  late RecordingCrashReporter reporter;

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
    reporter = RecordingCrashReporter();
  }

  /// A new launch reads the stored values again, as a restarted app does: a
  /// fresh store over the same preferences.
  void reopenStore(FakeAsync async) {
    unawaited(SettingsStore.open().then((s) => store = s));
    settle(async);
  }

  /// One launch of the app on [store]: the configuration is activated and
  /// the prompter is started and kept listened to, as `App` does.
  ///
  /// The ad consent comes from [consent] (by default no form is needed), and
  /// with [gather] the consent step runs, as the remote screen starts it.
  _Rig launch(
    FakeAsync async, {
    Map<String, Object?> config = const {},
    bool demo = false,
    FakeConsentService? consent,
    bool gather = true,
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
        consentServiceProvider.overrideWithValue(
          consent ?? FakeConsentService(),
        ),
        crashReporterProvider.overrideWithValue(reporter),
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
    if (gather) {
      unawaited(
        container.read(consentControllerProvider.notifier).ensureGathered(),
      );
      settle(async);
    }
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
      // 59 s after the loss is still too soon.
      disconnect(async, r);
      async.elapse(const Duration(seconds: 29));
      connect(async, r);
      expect(requester.requests, 0, reason: 'a loss 59 s ago');
      // Once 60 s have passed, the next clean start may ask.
      disconnect(async, r);
      async.elapse(const Duration(seconds: 1));
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

      // A request the plugin reports as failed marks nothing either.
      requester
        ..available = true
        ..requestSucceeds = false;
      disconnect(async, r);
      connect(async, r);
      expect(requester.requests, 1);
      expect(store.reviewPromptShown, isFalse);
      expect(reviewEvents(), isEmpty);

      // It tries again on the next clean start.
      requester.requestSucceeds = true;
      disconnect(async, r);
      connect(async, r);
      expect(requester.requests, 2);
      expect(store.reviewPromptShown, isTrue);
      expect(reviewEvents(), ['review_prompt_shown']);
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
      settle(async);
      reopenStore(async);
      expect(store.reviewKeyPresses, 25);
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

  test('presses_are_saved_when_the_app_closes', () {
    timed((async) {
      install(async);
      final r = launch(async);
      press(async, r, 25);
      expect(store.reviewKeyPresses, 20);

      r.container.dispose();
      settle(async);
      reopenStore(async);
      expect(store.reviewKeyPresses, 25);
    });
  });

  test('two_quick_session_starts_ask_once', () {
    timed((async) {
      install(async, presses: 150);
      final hold = Completer<void>();
      requester.holdAvailability = hold;
      final r = launch(async);
      connect(async, r);
      disconnect(async, r);
      connect(async, r);
      disconnect(async, r);
      connect(async, r);
      expect(requester.availabilityChecks, 1);

      hold.complete();
      settle(async);
      expect(requester.requests, 1);
      expect(reviewEvents(), hasLength(1));
    });
  });

  test('a_flag_that_cannot_be_stored_is_reported', () {
    timed((async) {
      install(async, presses: 150);
      unawaited(
        SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: SettingsStore.keys,
          ),
        ).then((prefs) => store = _NoFlagStore(prefs)),
      );
      settle(async);
      final r = launch(async);
      connect(async, r);

      expect(requester.requests, 1);
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.fatal, isFalse);
      expect(reporter.errors.single.reason, 'review prompt flag');
    });
  });

  group('no_review_prompt_on_a_consent_form_launch', () {
    test('form_shown', () {
      timed((async) {
        install(async, presses: 150);
        final r = launch(
          async,
          consent: FakeConsentService(formOutcome: ConsentFormOutcome.shown),
        );
        connect(async, r);
        disconnect(async, r);
        async.elapse(const Duration(minutes: 5));
        connect(async, r);
        expect(requester.availabilityChecks, 0);
        expect(requester.requests, 0);
        expect(store.reviewPromptShown, isFalse);
      });
    });

    test('pending_then_not_needed_asks_once', () {
      timed((async) {
        install(async, presses: 150);
        final hold = Completer<void>();
        final r = launch(
          async,
          consent: FakeConsentService(holdShowForm: hold),
        );
        connect(async, r);
        expect(requester.availabilityChecks, 0, reason: 'consent pending');
        expect(requester.requests, 0);

        hold.complete();
        settle(async);
        expect(requester.requests, 1);
        expect(reviewEvents(), hasLength(1));
      });
    });

    test('pending_then_trouble_within_a_minute_does_not_ask', () {
      timed((async) {
        install(async, presses: 150);
        final hold = Completer<void>();
        final r = launch(
          async,
          consent: FakeConsentService(holdShowForm: hold),
        );
        connect(async, r);
        // A drop and a reconnect while the consent form is still pending:
        // connected again at T.
        r.session.emit(_reconnecting);
        settle(async);
        r.session.emit(_connected);
        settle(async);

        async.elapse(const Duration(seconds: 10));
        hold.complete();
        settle(async);
        expect(requester.requests, 0);
        expect(reviewEvents(), isEmpty);
      });
    });

    test('pending_then_quiet_for_a_minute_asks', () {
      timed((async) {
        install(async, presses: 150);
        final hold = Completer<void>();
        final r = launch(
          async,
          consent: FakeConsentService(holdShowForm: hold),
        );
        connect(async, r);
        r.session.emit(_reconnecting);
        settle(async);
        r.session.emit(_connected);
        settle(async);

        // Still connected and a quiet minute has passed when consent ends.
        async.elapse(const Duration(seconds: 61));
        hold.complete();
        settle(async);
        expect(requester.requests, 1);
        expect(reviewEvents(), hasLength(1));
      });
    });

    test('pending_then_form_shown_never_asks', () {
      timed((async) {
        install(async, presses: 150);
        final hold = Completer<void>();
        final r = launch(
          async,
          consent: FakeConsentService(
            holdShowForm: hold,
            formOutcome: ConsentFormOutcome.shown,
          ),
        );
        connect(async, r);
        hold.complete();
        settle(async);
        disconnect(async, r);
        connect(async, r);
        expect(requester.availabilityChecks, 0);
        expect(requester.requests, 0);
      });
    });

    test('pending_while_disconnected_waits_for_the_next_start', () {
      timed((async) {
        install(async, presses: 150);
        final hold = Completer<void>();
        final r = launch(
          async,
          consent: FakeConsentService(holdShowForm: hold),
        );
        connect(async, r);
        disconnect(async, r);
        hold.complete();
        settle(async);
        expect(requester.requests, 0, reason: 'no longer connected');

        connect(async, r);
        expect(requester.requests, 1);
      });
    });
  });
}

/// A store whose review flag can't be written.
class _NoFlagStore extends SettingsStore {
  _NoFlagStore(super.prefs);

  @override
  Future<void> setReviewPromptShown(bool value) =>
      Future.error(StateError('disk full'));
}
