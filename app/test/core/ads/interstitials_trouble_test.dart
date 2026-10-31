import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/ads/ad_unit_ids.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/interstitials.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_consent_service.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_tracking_service.dart';
import '../../helpers/test_app_config.dart';
import '../../helpers/test_premium.dart';

// Interstitial pacing against the shared connection-trouble rule (Rulings
// P8-R12, P8-C9): the triggers that rule added or dropped, pinned at the
// caller so a private trouble timer can't come back unnoticed.

const _connecting = TvConnectionState(status: ConnectionStatus.connecting);
const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _disconnected = TvConnectionState(
  status: ConnectionStatus.disconnected,
);
const _failedAttempt = TvConnectionState(
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

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    await store.setLaunchCount(2);
  });

  final start = DateTime.utc(2026, 10, 31, 12);

  void timed(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      withClock(async.getClock(start), () => body(async));
    });
  }

  /// Every rule but trouble is met; [session] answers the session provider
  /// (it may throw).
  ({ProviderContainer container, Interstitials interstitials}) rig(
    FakeAsync async,
    Future<RemoteSession> Function() session,
  ) {
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
        adUnitIdsProvider.overrideWithValue(
          const AdUnitIds(
            banner: AdMobTestIds.androidBanner,
            interstitial: AdMobTestIds.androidInterstitial,
          ),
        ),
        consentServiceProvider.overrideWithValue(FakeConsentService()),
        trackingServiceProvider.overrideWithValue(FakeTrackingService()),
        premiumProvider.overrideWith(() => TestPremium(PremiumState.free)),
        appConfigProvider.overrideWith(
          () => TestAppConfig(const {'ads_interstitial_enabled': true}),
        ),
        remoteSessionProvider.overrideWith((ref) => session()),
      ],
    );
    unawaited(
      container.read(consentControllerProvider.notifier).ensureGathered(),
    );
    _settle(async);
    container.listen(interstitialsProvider, (_, _) {});
    final interstitials = container.read(interstitialsProvider.notifier);
    _settle(async);
    return (container: container, interstitials: interstitials);
  }

  bool? show(FakeAsync async, Interstitials interstitials) {
    bool? answer;
    unawaited(
      interstitials
          .maybeShow(InterstitialTrigger.leftSettings)
          .then((v) => answer = v),
    );
    _settle(async);
    return answer;
  }

  test('a_failed_first_connect_blocks_the_interstitial', () {
    timed((async) {
      final session = FakeRemoteSession(initial: _connecting);
      final r = rig(async, () async => session);
      session.emit(_failedAttempt);
      _settle(async);
      session.emit(_disconnected);
      _settle(async);

      async.elapse(const Duration(seconds: 30));
      expect(show(async, r.interstitials), isFalse, reason: '30 s after');
      async.elapse(const Duration(seconds: 30));
      expect(show(async, r.interstitials), isTrue, reason: '60 s after');
    });
  });

  test('a_session_that_cannot_be_opened_blocks_the_interstitial', () {
    timed((async) {
      var fail = true;
      final session = FakeRemoteSession(initial: _connected);
      final r = rig(async, () async {
        if (fail) throw StateError('no identity');
        return session;
      });
      // It opens on the next try.
      fail = false;
      r.container.invalidate(remoteSessionProvider);
      _settle(async);

      async.elapse(const Duration(seconds: 30));
      expect(show(async, r.interstitials), isFalse, reason: '30 s after');
      async.elapse(const Duration(seconds: 30));
      expect(show(async, r.interstitials), isTrue, reason: '60 s after');
    });
  });

  test('an_app_initiated_disconnect_does_not_block_the_interstitial', () {
    timed((async) {
      final session = FakeRemoteSession(initial: _connected);
      final r = rig(async, () async => session);
      async.elapse(const Duration(seconds: 100));

      // The background grace or a TV switch: the app closes it itself.
      session.emit(_disconnected);
      _settle(async);
      async.elapse(const Duration(seconds: 5));

      expect(show(async, r.interstitials), isTrue);
    });
  });
}
