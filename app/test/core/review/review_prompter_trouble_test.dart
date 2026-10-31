import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/review/review_prompter.dart';
import 'package:tv_remote/core/session/remote_session.dart';
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

// The review prompt against the shared connection-trouble rule (Rulings
// P8-R12, P8-C9, decision #43: no prompt within 60 s of trouble), pinned at
// the caller so a private trouble timer can't come back unnoticed.

const _disconnected = TvConnectionState(status: ConnectionStatus.disconnected);
const _connecting = TvConnectionState(status: ConnectionStatus.connecting);
const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _reconnecting = TvConnectionState(
  status: ConnectionStatus.reconnecting,
  attempt: 1,
  lastError: RemoteCloseReason.networkError,
);

void _settle(FakeAsync async) {
  async
    ..flushMicrotasks()
    ..elapse(Duration.zero);
}

void main() {
  late SettingsStore store;
  late FakeReviewRequester requester;

  final start = DateTime.utc(2026, 10, 31, 12);

  void timed(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(async.getClock(start), () => body(async));
    });
  }

  /// The second launch of an install with 150 presses: every rule but
  /// trouble is met. [session] answers the session provider (it may throw).
  ProviderContainer launch(
    FakeAsync async,
    Future<RemoteSession> Function() session,
  ) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    unawaited(
      SettingsStore.open().then((s) async {
        store = s;
        await s.setConsentRegion(ConsentRegion.notRequired);
        await s.setLaunchCount(2);
        await s.setReviewKeyPresses(150);
      }),
    );
    _settle(async);
    requester = FakeReviewRequester();
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        remoteConfigSourceProvider.overrideWithValue(
          FakeConfigSource(const {}),
        ),
        remoteSessionProvider.overrideWith((ref) => session()),
        sessionSignalsProvider.overrideWithValue(ManualSessionSignals()),
        reviewRequesterProvider.overrideWithValue(requester),
        consentServiceProvider.overrideWithValue(FakeConsentService()),
        crashReporterProvider.overrideWithValue(RecordingCrashReporter()),
        analyticsSinkProvider.overrideWithValue(RecordingAnalyticsSink()),
        analyticsDebugBuildProvider.overrideWithValue(true),
      ],
    );
    unawaited(container.read(appConfigProvider.notifier).load());
    _settle(async);
    container
      ..read(appConfigProvider.notifier).seal()
      ..listen(appAnalyticsProvider, (_, _) {})
      ..listen(reviewPrompterProvider, (_, _) {});
    _settle(async);
    unawaited(
      container.read(consentControllerProvider.notifier).ensureGathered(),
    );
    _settle(async);
    return container;
  }

  void emit(FakeAsync async, FakeRemoteSession s, TvConnectionState state) {
    s.emit(state);
    _settle(async);
  }

  /// A clean start: connecting, then connected.
  void connect(FakeAsync async, FakeRemoteSession s) {
    emit(async, s, _connecting);
    emit(async, s, _connected);
  }

  test('a_clean_start_after_a_long_reconnect_does_not_prompt', () {
    timed((async) {
      // The connection is already lost when the prompter starts listening.
      final session = FakeRemoteSession(initial: _reconnecting);
      launch(async, () async => session);

      // Reconnecting for 90 s, then the background grace closes it; the user
      // comes back 5 s later and the TV connects at once.
      async.elapse(const Duration(seconds: 90));
      emit(async, session, _disconnected);
      async.elapse(const Duration(seconds: 5));
      connect(async, session);
      expect(requester.requests, 0, reason: 'trouble ended 5 s ago');

      // The control: once the trouble is 60 s over, a clean start asks.
      emit(async, session, _disconnected);
      async.elapse(const Duration(seconds: 55));
      connect(async, session);
      expect(requester.requests, 1, reason: 'trouble ended 60 s ago');
    });
  });

  test('a_failed_first_connect_blocks_the_prompt', () {
    timed((async) {
      final session = FakeRemoteSession(initial: _connecting);
      launch(async, () async => session);
      emit(async, session, _reconnecting);
      emit(async, session, _disconnected);

      async.elapse(const Duration(seconds: 30));
      connect(async, session);
      expect(requester.requests, 0, reason: '30 s after');

      emit(async, session, _disconnected);
      async.elapse(const Duration(seconds: 30));
      connect(async, session);
      expect(requester.requests, 1, reason: '60 s after');
    });
  });

  test('a_session_that_cannot_be_opened_blocks_the_prompt', () {
    timed((async) {
      var fail = true;
      final session = FakeRemoteSession();
      final container = launch(async, () async {
        if (fail) throw StateError('no identity');
        return session;
      });
      fail = false;
      container.invalidate(remoteSessionProvider);
      _settle(async);

      async.elapse(const Duration(seconds: 30));
      connect(async, session);
      expect(requester.requests, 0, reason: '30 s after');

      emit(async, session, _disconnected);
      async.elapse(const Duration(seconds: 30));
      connect(async, session);
      expect(requester.requests, 1, reason: '60 s after');
    });
  });
}
