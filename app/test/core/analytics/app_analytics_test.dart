import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/recording_analytics_sink.dart';

void main() {
  late RecordingAnalyticsSink sink;
  late SettingsStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    sink = RecordingAnalyticsSink();
  });

  Future<ProviderContainer> containerFor({
    ConsentRegion region = ConsentRegion.notRequired,
    bool? usage,
    bool debugBuild = false,
    AnalyticsSink? withSink,
  }) async {
    await store.setConsentRegion(region);
    await store.setShareUsageStats(usage);
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        analyticsSinkProvider.overrideWithValue(withSink ?? sink),
        analyticsDebugBuildProvider.overrideWithValue(debugBuild),
      ],
    );
    // The app keeps analytics listened to (Riverpod pauses what nothing
    // listens to).
    return container..listen(appAnalyticsProvider, (_, _) {});
  }

  AppAnalytics analytics(ProviderContainer c) =>
      c.read(appAnalyticsProvider.notifier);

  // Provider updates that have listeners wait for the scheduler; `pump` runs
  // them.
  Future<void> flush(ProviderContainer c) async {
    await c.pump();
    await pumpEventQueue();
  }

  // A test helper with one boolean: positional reads best.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setUsage(ProviderContainer c, bool? value) => c
      .read(settingsControllerProvider.notifier)
      .update((s) => s.setShareUsageStats(value));

  test('guard_throws_in_debug_and_drops_in_release', () async {
    final debug = await containerFor(debugBuild: true);
    expect(
      () => analytics(debug).log(AnalyticsEvent.appLaunch('192.168.0.20')),
      throwsA(isA<AnalyticsPolicyError>()),
    );
    expect(
      () => analytics(debug).screen('/pair/Bravia'),
      throwsA(isA<AnalyticsPolicyError>()),
    );
    await flush(debug);
    expect(sink.calls, isEmpty);

    final release = await containerFor();
    analytics(release)
      ..log(AnalyticsEvent.appLaunch('192.168.0.20'))
      ..screen('/pair/Bravia')
      // A good event still goes through.
      ..log(const AnalyticsEvent.pairStart());
    await flush(release);
    expect(sink.calls, ['event:pair_start']);
  });

  test('the_policy_error_names_the_problem_but_not_the_value', () async {
    final c = await containerFor(debugBuild: true);
    expect(
      () => analytics(c).log(AnalyticsEvent.appLaunch('192.168.0.20')),
      throwsA(
        isA<AnalyticsPolicyError>()
            .having((e) => e.message, 'message', contains('app_launch'))
            .having((e) => e.message, 'message', isNot(contains('192.168')))
            .having((e) => '$e', 'toString', isNot(contains('192.168'))),
      ),
    );
  });

  test('nothing_is_sent_when_usage_sharing_is_off', () async {
    final c = await containerFor(usage: false);
    analytics(c)
      ..log(const AnalyticsEvent.pairStart())
      ..screen('remote')
      ..log(const AnalyticsEvent.pairSuccess());
    await flush(c);
    expect(sink.calls, isEmpty);
    expect(sink.collectionHistory, [false]);
  });

  test('events_flow_when_sharing_is_allowed_and_screens_keep_order', () async {
    final c = await containerFor();
    analytics(c)
      ..log(const AnalyticsEvent.pairStart())
      ..screen('pair')
      ..log(const AnalyticsEvent.pairSuccess());
    await flush(c);
    expect(sink.calls, [
      'event:pair_start',
      'screen:pair',
      'event:pair_success',
    ]);
    expect(sink.collectionHistory, [true]);
  });

  test('events_wait_until_the_region_is_known', () async {
    final c = await containerFor(region: ConsentRegion.unknown);
    analytics(c)
      ..log(const AnalyticsEvent.pairStart())
      ..screen('pair')
      ..log(const AnalyticsEvent.pairSuccess());
    await flush(c);
    expect(sink.calls, isEmpty);
    expect(sink.collectionHistory, [false]);

    await c
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.notRequired);
    await flush(c);
    expect(sink.calls, [
      'event:pair_start',
      'screen:pair',
      'event:pair_success',
    ]);
    expect(sink.collectionHistory, [false, true]);
  });

  test('waiting_events_are_dropped_when_sharing_is_denied', () async {
    final c = await containerFor(region: ConsentRegion.unknown);
    analytics(c)
      ..log(const AnalyticsEvent.pairStart())
      ..screen('pair');
    await c
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.required);
    await flush(c);
    expect(sink.calls, isEmpty);

    // Turning sharing on later sends nothing from before.
    await setUsage(c, true);
    await flush(c);
    expect(sink.calls, isEmpty);
    analytics(c).log(const AnalyticsEvent.pairSuccess());
    expect(sink.calls, ['event:pair_success']);
  });

  test('an_explicit_choice_decides_before_the_region_is_known', () async {
    final c = await containerFor(region: ConsentRegion.unknown);
    analytics(c).log(const AnalyticsEvent.pairStart());
    await setUsage(c, true);
    await flush(c);
    expect(sink.calls, ['event:pair_start']);
  });

  test('buffer_keeps_the_latest_50', () async {
    final c = await containerFor(region: ConsentRegion.unknown);
    for (var i = 1; i <= 60; i++) {
      analytics(c).log(AnalyticsEvent.tvDiscovered(i));
    }
    await c
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.notRequired);
    await flush(c);
    expect(sink.events, hasLength(50));
    expect(sink.events.first.params['count'], 11);
    expect(sink.events.last.params['count'], 60);
  });

  test('collection_follows_the_choice', () async {
    final c = await containerFor(region: ConsentRegion.required);
    await flush(c);
    await setUsage(c, true);
    await flush(c);
    await setUsage(c, false);
    await flush(c);
    expect(sink.collectionHistory, [false, true, false]);
  });

  test('a_failing_sink_never_throws', () async {
    final broken = RecordingAnalyticsSink(throwOnCall: true);
    final c = await containerFor(
      region: ConsentRegion.unknown,
      withSink: broken,
    );
    analytics(c)
      ..log(const AnalyticsEvent.pairStart())
      ..screen('pair');
    await c
        .read(consentRegionStateProvider.notifier)
        .set(ConsentRegion.notRequired);
    await flush(c);
    analytics(c)
      ..log(const AnalyticsEvent.pairSuccess())
      ..screen('remote');
    await setUsage(c, false);
    await flush(c);
    // Reaching here without an uncaught error is the assertion.
    expect(broken.calls, isEmpty);
  });
}
