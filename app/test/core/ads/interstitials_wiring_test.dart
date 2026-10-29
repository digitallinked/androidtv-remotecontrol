import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/bootstrap.dart';
import 'package:tv_remote/core/ads/interstitials.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_ads_overrides.dart';
import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/fake_config_source.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/gather_consent.dart';
import '../../helpers/recording_crash_reporter.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// Pumps the real app with one loaded interstitial and every rule met, drops
  /// the connection if [trouble], and asks whether the ad shows.
  Future<({bool? shown, FakeAdsSdk sdk})> run(
    WidgetTester t, {
    required bool trouble,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'settings.onboarding_complete': true,
          'review.launch_count': 2,
        });
    final sdk = FakeAdsSdk(loads: true);
    final session = FakeRemoteSession(
      initial: const TvConnectionState(status: ConnectionStatus.connected),
    );
    await t.pumpWidget(
      await buildRootWidget(
        flavor: Flavor.dev,
        crashReporter: RecordingCrashReporter(),
        overrides: [
          ...fakeAdsOverrides(sdk: sdk),
          // Through the source: startup loads the config from it.
          remoteConfigSourceProvider.overrideWithValue(
            FakeConfigSource(const {'ads_interstitial_enabled': true}),
          ),
          remoteSessionProvider.overrideWith((ref) async => session),
          tvDiscoveryFactoryProvider.overrideWithValue(
            FakeTvDiscoveries().create,
          ),
          savedDevicesProvider.overrideWith(
            (ref) => Stream.value(const <SavedDevice>[]),
          ),
        ],
        openDatabase: () => AppDatabase(NativeDatabase.memory()),
      ),
    );
    await t.pumpAndSettle();
    await gatherConsent(t);
    expect(sdk.interstitialLoads, 1, reason: 'one ad is kept loaded');

    if (trouble) {
      session.emit(const TvConnectionState(status: ConnectionStatus.offline));
      await t.pump();
    }
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
    );
    bool? shown;
    unawaited(
      container
          .read(interstitialsProvider.notifier)
          .maybeShow(InterstitialTrigger.leftSettings)
          .then((v) => shown = v),
    );
    await t.pump();
    await t.pump();
    return (shown: shown, sdk: sdk);
  }

  testWidgets('without_trouble_the_loaded_ad_shows', (t) async {
    // The control: every rule is met, so the ad of the next test would show.
    final r = await run(t, trouble: false);
    expect(r.shown, isTrue);
    expect(r.sdk.shows, 1);
  });

  testWidgets('the_app_keeps_interstitial_pacing_listening_to_the_connection', (
    t,
  ) async {
    // The pacing only knows about trouble if it was started at launch: it
    // must be listening to the connection before the connection drops. `App`
    // starts it, so this pumps the real app and never starts or listens to it
    // by hand. (It pins that start, not how `App` holds the provider: `watch`
    // versus `read` makes no difference to this behaviour.) The connection
    // drops, and straight afterwards no ad may show.
    final r = await run(t, trouble: true);
    expect(r.shown, isFalse);
    expect(r.sdk.shows, 0);
  });
}
