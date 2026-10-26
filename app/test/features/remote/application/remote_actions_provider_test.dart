import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/haptics/haptics.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

import '../../../helpers/fake_remote_session.dart';
import '../../../helpers/recording_haptics.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);

void main() {
  late SettingsStore store;
  late RecordingHaptics haptic;
  late FakeRemoteSession a;
  late FakeRemoteSession b;
  late List<FakeRemoteSession> queue;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    haptic = RecordingHaptics();
    a = FakeRemoteSession(initial: _connected);
    b = FakeRemoteSession(initial: _connected);
    queue = [a, b];
  });

  ProviderContainer makeContainer({List<Override> extra = const []}) {
    var next = 0;
    return ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        hapticsProvider.overrideWithValue(haptic),
        remoteSessionProvider.overrideWith(
          (ref) async => queue[next++ % queue.length],
        ),
        ...extra,
      ],
    )..listen(remoteActionsProvider, (_, _) {}); // Alive, like on the screen.
  }

  test('provider_follows_the_smooth_press_setting', () async {
    final c = makeContainer();
    await c.read(remoteSessionProvider.future);
    await c.pump();

    c.read(remoteActionsProvider).holdStart(KeyCodes.volumeUp);
    expect(a.sentPresses.single.$2, KeyDirection.startLong);

    // Changing the setting rebuilds the actions, which releases the hold.
    await c
        .read(settingsControllerProvider.notifier)
        .update((s) => s.setSmoothPressEnabled(false));
    await c.pump();
    expect(a.sentPresses.last, (KeyCodes.volumeUp, KeyDirection.endLong));

    a.sentPresses.clear();
    final repeating = c.read(remoteActionsProvider)
      ..holdStart(KeyCodes.dpadDown);
    expect(a.sentPresses, [(KeyCodes.dpadDown, KeyDirection.short)]);
    repeating.holdEnd(KeyCodes.dpadDown);
  });

  test('provider_follows_the_haptics_setting', () async {
    final c = makeContainer();
    await c.read(remoteSessionProvider.future);
    await c.pump();

    c.read(remoteActionsProvider).tap(KeyCodes.home);
    await c
        .read(settingsControllerProvider.notifier)
        .update((s) => s.setHapticsEnabled(false));
    await c.pump();
    c.read(remoteActionsProvider).tap(KeyCodes.home);

    expect(haptic.events, ['light']);
    expect(a.sentPresses, hasLength(2));
  });

  test(
    'provider_rebuild_on_tv_switch_releases_the_hold_on_the_old_session',
    () async {
      final c = makeContainer();
      await c.read(remoteSessionProvider.future);
      await c.pump();
      c.read(remoteActionsProvider).holdStart(KeyCodes.volumeUp);
      expect(a.sentPresses, [(KeyCodes.volumeUp, KeyDirection.startLong)]);

      c.invalidate(remoteSessionProvider);
      await c.pump();

      expect(a.sentPresses.last, (KeyCodes.volumeUp, KeyDirection.endLong));

      // While the new session loads, commands are refused, not sent to A.
      final loading = c.read(remoteActionsProvider);
      expect(loading.tap(KeyCodes.home), isFalse);
      expect(a.sentPresses, hasLength(2));
      expect(c.read(notConnectedNoticesProvider), 1);

      await c.read(remoteSessionProvider.future);
      await c.pump();
      expect(c.read(remoteActionsProvider).tap(KeyCodes.home), isTrue);
      expect(b.sentPresses, [(KeyCodes.home, KeyDirection.short)]);
    },
  );

  test('a_failed_session_load_refuses_commands', () async {
    var calls = 0;
    final c = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        hapticsProvider.overrideWithValue(haptic),
        remoteSessionProvider.overrideWith((ref) async {
          if (calls++ == 0) return a;
          throw StateError('identity unusable');
        }),
      ],
    )..listen(remoteActionsProvider, (_, _) {});
    await c.read(remoteSessionProvider.future);
    await c.pump();
    c.invalidate(remoteSessionProvider);
    await expectLater(c.read(remoteSessionProvider.future), throwsStateError);
    await c.pump();

    expect(c.read(remoteActionsProvider).tap(KeyCodes.home), isFalse);
    expect(a.sentPresses, isEmpty);
    expect(c.read(notConnectedNoticesProvider), 1);
  });

  test('refusals_bump_the_not_connected_notices', () async {
    a.emit(const TvConnectionState(status: ConnectionStatus.offline));
    final c = makeContainer();
    await c.read(remoteSessionProvider.future);
    await c.pump();
    expect(c.read(notConnectedNoticesProvider), 0);

    expect(c.read(remoteActionsProvider).tap(KeyCodes.home), isFalse);

    expect(c.read(notConnectedNoticesProvider), 1);
    expect(a.sentPresses, isEmpty);
    expect(haptic.events, isEmpty);
  });

  test('listener_sees_each_sent_command', () async {
    final heard = <RemoteActionEvent>[];
    final c = makeContainer(
      extra: [remoteActionListenerProvider.overrideWithValue(heard.add)],
    );
    await c.read(remoteSessionProvider.future);
    await c.pump();

    c.read(remoteActionsProvider)
      ..tap(KeyCodes.back)
      ..typeText('abc');

    expect(heard, [
      const KeySent(KeyCodes.back, KeyDirection.short),
      const TextSent(3),
    ]);
  });

  test('the_default_listener_ignores_events', () {
    final c = ProviderContainer.test();
    c.read(remoteActionListenerProvider)(const TextSent(1));
  });
}
