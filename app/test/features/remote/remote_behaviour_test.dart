import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/device/screen_services.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/keyboard/keyboard_sheet.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_screen_services.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);

void main() {
  late FakeRemoteSession fake;
  late RecordingWakeLock lock;
  late RecordingDimmer dimmer;
  late GoRouter router;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
    lock = RecordingWakeLock();
    dimmer = RecordingDimmer();
  });

  /// Pumps the remote on a phone-sized view. Theater Mode is off unless
  /// [theater] is set; keep-awake is on unless [keepAwake] is false.
  Future<void> pumpRemote(
    WidgetTester t, {
    bool theater = false,
    bool keepAwake = true,
    NavigationStyle nav = NavigationStyle.touchpad,
    bool accessibleNavigation = false,
  }) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      accessibleNavigation: accessibleNavigation,
      prepareSettings: (store) async {
        await store.setTheaterMode(theater);
        await store.setKeepScreenAwake(keepAwake);
        await store.setNavigationStyle(nav);
      },
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
        screenWakeLockProvider.overrideWithValue(lock),
        screenDimmerProvider.overrideWithValue(dimmer),
      ],
    );
    router = ProviderScope.containerOf(
      t.element(find.byType(RemoteBody)),
    ).read(appRouterProvider);
  }

  Future<void> idle(WidgetTester t, int seconds) =>
      t.pump(Duration(seconds: seconds));

  testWidgets('wakelock_only_on_remote_screen', (t) async {
    await pumpRemote(t);
    expect(lock.enabled, isTrue);
    unawaitedPush(router, AppRoutes.discover);
    await t.pumpAndSettle();
    expect(lock.enabled, isFalse);
    router.pop();
    await t.pumpAndSettle();
    expect(lock.enabled, isTrue);
    router.go(AppRoutes.settings);
    await t.pumpAndSettle();
    expect(lock.enabled, isFalse);
  });

  testWidgets('keep_awake_off_setting_never_enables', (t) async {
    await pumpRemote(t, keepAwake: false);
    expect(lock.changes, isEmpty);
    unawaitedPush(router, AppRoutes.discover);
    await t.pumpAndSettle();
    router.pop();
    await t.pumpAndSettle();
    expect(lock.changes, isEmpty);
  });

  testWidgets('sheet_over_remote_keeps_the_wakelock', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    expect(KeyboardSheet.isOpen, isTrue);
    expect(lock.enabled, isTrue);
    expect(lock.changes, [true]);
    handle.dispose();
  });

  testWidgets('backgrounding_the_app_releases_the_wakelock', (t) async {
    await pumpRemote(t);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(lock.enabled, isFalse);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(lock.enabled, isTrue);
  });

  testWidgets('theater_dims_after_30s_idle', (t) async {
    await pumpRemote(t, theater: true);
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
    expect(
      Theme.of(t.element(find.byType(RemoteBody))).extension<AppColors>(),
      AppColors.theater,
    );
  });

  testWidgets('first_touch_restores_without_sending_key', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t, theater: true, nav: NavigationStyle.dpad);
    await idle(t, 30);
    // The tap lands on the dimmed cover, not on the key under it.
    await t.tap(find.bySemanticsLabel('Home'), warnIfMissed: false);
    await t.pump();
    expect(fake.sentPresses, isEmpty);
    expect(dimmer.restores, 1);
    expect(
      Theme.of(t.element(find.byType(RemoteBody))).extension<AppColors>(),
      isNot(AppColors.theater),
    );
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(fake.sentPresses, [(KeyCodes.home, KeyDirection.short)]);
    handle.dispose();
  });

  testWidgets('a_long_first_touch_is_absorbed_whole', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t, theater: true);
    await idle(t, 30);
    final g = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Volume up')),
    );
    await t.pump(const Duration(seconds: 1));
    await g.up();
    await t.pump();
    expect(fake.sentPresses, isEmpty);
    expect(dimmer.restores, 1);
    handle.dispose();
  });

  testWidgets('touches_reset_the_idle_timer', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t, theater: true, nav: NavigationStyle.dpad);
    await idle(t, 20);
    await t.tap(find.bySemanticsLabel('Home'));
    await idle(t, 25);
    expect(dimmer.level, isNull);
    await idle(t, 5);
    expect(dimmer.level, 0.05);
    handle.dispose();
  });

  testWidgets('theater_off_never_dims', (t) async {
    await pumpRemote(t);
    await idle(t, 120);
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 0);
  });

  testWidgets('theater_suspended_with_screen_reader', (t) async {
    await pumpRemote(t, theater: true, accessibleNavigation: true);
    await idle(t, 60);
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 0);
  });

  testWidgets('open_sheet_pauses_the_idle_timer', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t, theater: true);
    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    expect(KeyboardSheet.isOpen, isTrue);
    await idle(t, 60);
    expect(dimmer.level, isNull);
    // Close the sheet: the timer starts again.
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    expect(KeyboardSheet.isOpen, isFalse);
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
    handle.dispose();
  });

  testWidgets('leaving_the_remote_restores_brightness', (t) async {
    await pumpRemote(t, theater: true);
    await idle(t, 30);
    expect(dimmer.level, 0.05);
    router.go(AppRoutes.settings);
    await t.pumpAndSettle();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
  });

  testWidgets('backgrounding_restores_brightness', (t) async {
    await pumpRemote(t, theater: true);
    await idle(t, 30);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
    t.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await idle(t, 29);
    expect(dimmer.level, isNull);
    await idle(t, 1);
    expect(dimmer.level, 0.05);
  });

  testWidgets('turning_theater_off_while_dimmed_restores', (t) async {
    await pumpRemote(t, theater: true);
    await idle(t, 30);
    final container = ProviderScope.containerOf(
      t.element(find.byType(RemoteBody)),
    );
    await container
        .read(settingsControllerProvider.notifier)
        .update((store) => store.setTheaterMode(false));
    await t.pump();
    expect(dimmer.level, isNull);
    expect(dimmer.restores, 1);
  });
}

/// Pushes [location] without waiting for the page to be popped.
void unawaitedPush(GoRouter router, String location) {
  router.push<void>(location).ignore();
}
