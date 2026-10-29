import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/analytics/analytics_hooks.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/recording_analytics_sink.dart';
import '../../helpers/test_catalogue.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);

void main() {
  late RecordingAnalyticsSink sink;
  late SettingsStore store;
  late FakeRemoteSession session;
  // The session the provider builds next.
  late FakeRemoteSession active;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    await store.setConsentRegion(ConsentRegion.notRequired);
    sink = RecordingAnalyticsSink();
    session = FakeRemoteSession();
    active = session;
  });

  /// A container whose analytics is started the way the app starts it. The
  /// guard throws, as it does in a debug build.
  Future<ProviderContainer> start({
    double Function()? sampler,
  }) async {
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        analyticsSinkProvider.overrideWithValue(sink),
        analyticsDebugBuildProvider.overrideWithValue(true),
        catalogueProvider.overrideWith((ref) async => testCatalogue()),
        remoteSessionProvider.overrideWith((ref) async => active),
        if (sampler != null)
          analyticsSamplerProvider.overrideWithValue(sampler),
      ],
    )..listen(analyticsHooksProvider, (_, _) {});
    await container.read(catalogueProvider.future);
    await container.read(remoteSessionProvider.future);
    await pumpEventQueue();
    return container;
  }

  RemoteActionListener listenerOf(ProviderContainer c) =>
      c.read(remoteActionListenerProvider);

  test('key_press_is_sampled_at_10_percent', () async {
    var i = 0;
    final c = await start(sampler: () => (i++ % 10) / 10);
    final listener = listenerOf(c);
    for (var n = 0; n < 100; n++) {
      listener(const KeySent(KeyCodes.volumeUp, KeyDirection.short));
    }
    expect(sink.eventNames.where((n) => n == 'key_press'), hasLength(10));
    expect(sink.events, hasLength(10));
    expect(sink.events.first.params, {'key': 'volume_up'});
  });

  test('digits_are_logged_as_digit', () async {
    final c = await start(sampler: () => 0);
    listenerOf(c)(KeySent(KeyCodes.digit(5), KeyDirection.short));
    expect(sink.events.single.params, {'key': 'digit'});
  });

  test('text_is_never_logged', () async {
    final c = await start(sampler: () => 0);
    listenerOf(c)(const TextSent(12));
    await pumpEventQueue();
    expect(sink.calls, isEmpty);
  });

  test('app_launch_uses_catalogue_packages_or_custom', () async {
    final c = await start();
    listenerOf(c)(const AppLaunched('com.netflix.ninja'));
    listenerOf(c)(const AppLaunched('com.example.private'));
    expect(sink.events.map((e) => e.name), ['app_launch', 'app_launch']);
    expect(sink.events[0].params, {'package': 'com.netflix.ninja'});
    expect(sink.events[1].params, {'package': 'custom'});
  });

  test('app_launch_is_custom_while_the_catalogue_is_not_loaded', () async {
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        analyticsSinkProvider.overrideWithValue(sink),
        analyticsDebugBuildProvider.overrideWithValue(true),
        catalogueProvider.overrideWith(
          (ref) => Future<Never>.error(StateError('no catalogue')),
        ),
        remoteSessionProvider.overrideWith((ref) async => session),
      ],
    )..listen(analyticsHooksProvider, (_, _) {});
    container.read(remoteActionListenerProvider)(
      const AppLaunched('com.netflix.ninja'),
    );
    // The event waits for the collection switch the build started.
    await pumpEventQueue();
    expect(sink.events.single.params, {'package': 'custom'});
  });

  test('demo_sessions_log_no_tv_events', () async {
    final demo = active = FakeRemoteSession(isDemo: true);
    final c = await start(sampler: () => 0);
    listenerOf(c)(const KeySent(KeyCodes.home, KeyDirection.short));
    listenerOf(c)(const AppLaunched('com.netflix.ninja'));
    demo.emit(_connected);
    await pumpEventQueue();
    demo.emit(const TvConnectionState(status: ConnectionStatus.offline));
    await pumpEventQueue();
    expect(sink.calls, isEmpty);
  });

  test('connect_success_and_lost_carry_only_a_reason', () async {
    await start();
    session.emit(_connected);
    await pumpEventQueue();
    session.emit(
      const TvConnectionState(
        status: ConnectionStatus.reconnecting,
        attempt: 1,
        lastError: RemoteCloseReason.pingTimeout,
      ),
    );
    await pumpEventQueue();
    session.emit(_connected);
    await pumpEventQueue();

    expect(sink.eventNames, [
      'connect_success',
      'connect_lost',
      'connect_success',
    ]);
    expect(sink.events[0].params, isEmpty);
    expect(sink.events[1].params, {'reason': 'ping_timeout'});
    expect(sink.events[2].params, isEmpty);
  });

  test('connect_lost_without_a_reason_is_unknown', () async {
    await start();
    session.emit(_connected);
    await pumpEventQueue();
    session.emit(const TvConnectionState(status: ConnectionStatus.offline));
    await pumpEventQueue();

    expect(sink.eventNames, ['connect_success', 'connect_lost']);
    expect(sink.events[1].params, {'reason': 'unknown'});
  });

  test('losing_the_pairing_is_a_lost_connection', () async {
    await start();
    session.emit(_connected);
    await pumpEventQueue();
    session.emit(
      const TvConnectionState(
        status: ConnectionStatus.needsPairing,
        lastError: RemoteCloseReason.serverKeyChanged,
      ),
    );
    await pumpEventQueue();

    expect(sink.events.last.params, {'reason': 'server_key_changed'});
  });

  test('a_close_by_the_app_is_silent', () async {
    await start();
    session.emit(_connected);
    await pumpEventQueue();
    // What the real connection emits for disconnect(), a close and dispose:
    // `disconnected` with no reason (it never reports `closedByClient`).
    session.emit(
      const TvConnectionState(status: ConnectionStatus.disconnected),
    );
    await pumpEventQueue();

    expect(sink.eventNames, ['connect_success']);
  });

  test('going_to_the_background_and_back_logs_no_lost_connection', () async {
    await start();
    // The supervisor disconnects after the background grace, then connects.
    session.emit(_connected);
    await pumpEventQueue();
    session.emit(
      const TvConnectionState(status: ConnectionStatus.disconnected),
    );
    await pumpEventQueue();
    session.emit(const TvConnectionState(status: ConnectionStatus.connecting));
    await pumpEventQueue();
    session.emit(_connected);
    await pumpEventQueue();

    expect(sink.eventNames, ['connect_success', 'connect_success']);
  });

  test('switching_tvs_is_not_a_lost_connection', () async {
    final c = await start();
    session.emit(_connected);
    await pumpEventQueue();
    expect(sink.eventNames, ['connect_success']);

    final other = active = FakeRemoteSession();
    c.invalidate(remoteSessionProvider);
    await pumpEventQueue();
    other.emit(_connected);
    await pumpEventQueue();

    expect(sink.eventNames, ['connect_success', 'connect_success']);
  });

  test('layout_change_logged_for_settings_and_pad_swipes', () async {
    final c = await start();
    Future<void> change(
      Future<void> Function(SettingsStore store) update,
    ) async {
      await c.read(settingsControllerProvider.notifier).update(update);
      await pumpEventQueue();
    }

    // The pad swipe on the remote screen and the Settings page both write the
    // navigation style.
    await change((s) => s.setNavigationStyle(NavigationStyle.dpad));
    await change((s) => s.setQuickAccessRow(QuickAccessRow.mediaKeys));
    await change((s) => s.setQuickAccessRow(QuickAccessRow.colourKeys));
    await change((s) => s.setQuickAccessRow(QuickAccessRow.none));
    await change((s) => s.setNavigationStyle(NavigationStyle.touchpad));
    // Writing the same value again, or another setting, logs nothing.
    await change((s) => s.setNavigationStyle(NavigationStyle.touchpad));
    await change((s) => s.setHapticsEnabled(false));

    expect(sink.eventNames, everyElement('layout_change'));
    expect(
      [for (final e in sink.events) e.params['layout']],
      [
        'dpad',
        'media_keys',
        'colour_keys',
        'none',
        'touchpad',
      ],
    );
  });

  test('starting_the_hooks_logs_nothing_by_itself', () async {
    await start();
    expect(sink.calls, isEmpty);
  });
}
