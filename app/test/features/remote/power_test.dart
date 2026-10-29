import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/core/haptics/haptics.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/remote/application/power_controller.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_wake_on_lan.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_haptics.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);
const _mac = 'AA:BB:CC:DD:EE:F0';

void main() {
  late FakeRemoteSession fake;
  late FakeWakeOnLan wol;
  late RecordingHaptics haptics;
  late AppDatabase db;
  late DeviceRepository repo;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
    wol = FakeWakeOnLan();
    haptics = RecordingHaptics();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    repo = DriftDeviceRepository(db);
  });

  Future<void> pumpRemote(
    WidgetTester t, {
    String? wolMac,
    String? nickname,
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
    List<Override> overrides = const [],
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await repo.upsert(savedTv(wolMac: wolMac));
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      database: db,
      textScale: textScale,
      brightness: brightness,
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv(wolMac: wolMac, nickname: nickname)]),
        ),
        hapticsProvider.overrideWithValue(haptics),
        wakeOnLanServiceProvider.overrideWithValue(wol),
        ...overrides,
      ],
    );
  }

  final power = find.byType(PowerButton);

  /// Holds the power key past its 600 ms threshold and lets the wake-up
  /// (a database read) and its snackbar finish.
  Future<void> holdPower(WidgetTester t) async {
    await t.longPress(power);
    await t.pumpAndSettle();
  }

  testWidgets('power_requires_long_press', (t) async {
    await pumpRemote(t);
    await t.tap(power);
    await t.pump();
    expect(find.text('Hold to turn the TV on or off'), findsOneWidget);
    expect(fake.sentPresses, isEmpty);
    expect(haptics.events, isEmpty);

    await t.longPress(power);
    await t.pump();
    expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
    expect(haptics.events, ['heavy']);
  });

  testWidgets('a_550ms_press_is_still_a_tap', (t) async {
    await pumpRemote(t);
    final gesture = await t.startGesture(t.getCenter(power));
    await t.pump(const Duration(milliseconds: 550));
    await gesture.up();
    await t.pump();
    expect(find.text('Hold to turn the TV on or off'), findsOneWidget);
    expect(fake.sentPresses, isEmpty);
  });

  testWidgets('a_held_press_sends_power_before_the_finger_lifts', (t) async {
    await pumpRemote(t);
    final gesture = await t.startGesture(t.getCenter(power));
    await t.pump(const Duration(milliseconds: 650));
    expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
    await gesture.up();
    await t.pump();
    // Letting go is not a second press and not a tap.
    expect(fake.sentPresses, hasLength(1));
    expect(find.text('Hold to turn the TV on or off'), findsNothing);
  });

  testWidgets('semantic_long_press_on_power_sends_power', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    t.semantics.longPress(find.semantics.byLabel('Power'));
    await t.pump();
    expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
    expect(find.text('Hold to turn the TV on or off'), findsNothing);
    handle.dispose();
  });

  testWidgets('semantic_tap_on_power_gives_the_hint', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    t.semantics.tap(find.semantics.byLabel('Power'));
    await t.pump();
    expect(fake.sentPresses, isEmpty);
    expect(find.text('Hold to turn the TV on or off'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('power_is_a_56dp_key_in_the_app_bar', (t) async {
    await pumpRemote(t);
    expect(
      find.descendant(of: find.byType(AppBar), matching: power),
      findsOneWidget,
    );
    final size = t.getSize(
      find.descendant(of: power, matching: find.byType(AppKeyButton)),
    );
    expect(size.width, greaterThanOrEqualTo(56));
    expect(size.height, greaterThanOrEqualTo(56));
  });

  testWidgets('waking_shows_a_snackbar_with_the_tv_name', (t) async {
    fake.emit(_offline);
    await pumpRemote(t, wolMac: _mac);
    await holdPower(t);
    expect(find.text('Waking Living Room TV 3…'), findsOneWidget);
    expect(wol.wakes, [(_mac, '192.168.0.20')]);
    expect(fake.reconnectCalls, 1);
    expect(haptics.events, ['heavy']);
    expect(fake.sentPresses, isEmpty);
  });

  testWidgets('waking_uses_the_saved_nickname', (t) async {
    fake.emit(_offline);
    await pumpRemote(t, wolMac: _mac, nickname: 'Lounge');
    await holdPower(t);
    // Renamed on the phone: the session still carries the TV's own name.
    expect(find.text('Waking Lounge…'), findsOneWidget);
    expect(find.textContaining('Living Room TV 3'), findsNothing);
  });

  testWidgets('a_second_hold_while_waking_is_ignored', (t) async {
    fake.emit(_offline);
    final gate = Completer<void>();
    wol.gate = gate.future;
    await pumpRemote(t, wolMac: _mac);
    final onPower = t.widget<PowerButton>(power).onPower;

    onPower();
    await t.pump(const Duration(milliseconds: 100));
    onPower();
    await t.pump(const Duration(milliseconds: 100));
    gate.complete();
    await t.pumpAndSettle();

    expect(wol.wakes, hasLength(1));
    expect(fake.reconnectCalls, 1);
    expect(haptics.events, ['heavy']);
    expect(find.text('Waking Living Room TV 3…'), findsOneWidget);
  });

  testWidgets('a_second_hold_while_the_setup_sheet_is_open_is_ignored', (
    t,
  ) async {
    fake.emit(_offline);
    await pumpRemote(t);
    final onPower = t.widget<PowerButton>(power).onPower;

    onPower();
    await t.pumpAndSettle();
    onPower();
    await t.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // Closing the one sheet leaves nothing behind.
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    // Nothing was sent: asking for the MAC is no power action (P7-R12).
    expect(haptics.events, isEmpty);
  });

  testWidgets('power_works_again_after_the_first_action_finished', (t) async {
    fake.emit(_offline);
    await pumpRemote(t, wolMac: _mac);
    await holdPower(t);
    await holdPower(t);
    expect(wol.wakes, hasLength(2));
  });

  testWidgets('wake_on_lan_is_available_on_android_but_not_ios', (t) async {
    // The provider is not autoDispose: each platform gets its own container.
    bool availableOn(TargetPlatform platform) {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container.read(wakeOnLanAvailableProvider);
    }

    expect(kIosWakeOnLanEnabled, isFalse);
    try {
      expect(availableOn(TargetPlatform.android), isTrue);
      expect(availableOn(TargetPlatform.iOS), isFalse);
    } finally {
      // Before the test ends: the framework checks the variable first.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('wake_failure_says_so', (t) async {
    fake.emit(_offline);
    wol.result = false;
    await pumpRemote(t, wolMac: _mac);
    await holdPower(t);
    expect(
      find.textContaining("Couldn't send the wake-up signal"),
      findsOneWidget,
    );
    expect(fake.reconnectCalls, 0);
  });

  testWidgets('no_mac_opens_setup_sheet_and_saving_wakes', (t) async {
    fake.emit(_offline);
    await pumpRemote(t);
    await holdPower(t);
    expect(
      find.text('Turn on Living Room TV 3 from your phone'),
      findsOneWidget,
    );
    expect(wol.wakes, isEmpty);

    await t.enterText(find.byType(TextField), 'zz');
    await t.tap(find.text('Save and turn on'));
    await t.pump();
    expect(
      find.text('Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);

    await t.enterText(find.byType(TextField), 'aa-bb-cc-dd-ee-f0');
    await t.tap(find.text('Save and turn on'));
    await t.pumpAndSettle();
    expect((await repo.find('Living Room TV 3'))!.wolMac, _mac);
    expect(wol.wakes, [(_mac, '192.168.0.20')]);
    expect(fake.reconnectCalls, 1);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Waking Living Room TV 3…'), findsOneWidget);
    expect(haptics.events, ['heavy'], reason: 'one haptic, at the send');
  });

  testWidgets('closing_the_setup_sheet_sends_nothing', (t) async {
    fake.emit(_offline);
    await pumpRemote(t);
    await holdPower(t);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(wol.wakes, isEmpty);
    expect(fake.reconnectCalls, 0);
    expect((await repo.find('Living Room TV 3'))!.wolMac, isNull);
  });

  testWidgets('ios_without_entitlement_explains_turning_on_by_hand', (t) async {
    fake.emit(_offline);
    await pumpRemote(
      t,
      wolMac: _mac,
      overrides: [wakeOnLanAvailableProvider.overrideWithValue(false)],
    );
    await holdPower(t);
    expect(
      find.text(
        'Turn the TV on with its own remote. This app reconnects by itself.',
      ),
      findsOneWidget,
    );
    expect(wol.wakes, isEmpty);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('needs_pairing_power_shows_the_not_connected_snackbar', (
    t,
  ) async {
    fake.emit(const TvConnectionState(status: ConnectionStatus.needsPairing));
    await pumpRemote(t, wolMac: _mac);
    await holdPower(t);
    expect(find.text('Not connected to your TV'), findsOneWidget);
    expect(wol.wakes, isEmpty);
    expect(haptics.events, isEmpty);
  });

  testWidgets('power_key_fits_the_app_bar_at_320dp_and_200_percent_text', (
    t,
  ) async {
    for (final size in const [Size(320, 568), Size(568, 320)]) {
      for (final brightness in Brightness.values) {
        await pumpRemote(
          t,
          size: size,
          textScale: 2,
          brightness: brightness,
        );
        expect(t.takeException(), isNull, reason: '$size $brightness');
        final bar = t.getRect(find.byType(AppBar));
        final key = t.getRect(power);
        expect(key.width, greaterThanOrEqualTo(56));
        expect(bar.contains(key.topLeft), isTrue);
        expect(bar.contains(key.bottomRight), isTrue);
        expect(key.right, lessThanOrEqualTo(size.width));
        // The TV's name keeps room beside the key.
        final switcher = find.byTooltip('Switch TV');
        expect(switcher, findsOneWidget);
        expect(t.getRect(switcher).right, lessThanOrEqualTo(key.left));
      }
    }
  });

  group('one heavy haptic, only when something is sent (Ruling P7-R12)', () {
    late int refused;

    setUp(() {
      refused = 0;
      fake.emit(_offline);
    });

    PowerController controller({bool available = true}) => PowerController(
      session: fake,
      actions: RemoteActions(
        session: fake,
        smoothPress: true,
        hapticsEnabled: true,
        haptics: haptics,
        onRefused: () => refused++,
      ),
      devices: repo,
      wakeOnLan: wol,
      wakeOnLanAvailable: available,
      haptics: haptics,
      hapticsEnabled: true,
      onRefused: () => refused++,
    );

    int heavies() => haptics.events.where((e) => e == 'heavy').length;

    test('heavy_haptic_only_when_a_wake_is_sent', () async {
      await repo.upsert(savedTv(wolMac: _mac));
      expect(await controller().press(), PowerOutcome.waking);
      expect(heavies(), 1);
      expect(wol.wakes, hasLength(1));
    });

    test('heavy_haptic_when_a_wake_is_sent_but_fails', () async {
      await repo.upsert(savedTv(wolMac: _mac));
      wol.result = false;
      expect(await controller().press(), PowerOutcome.wakeFailed);
      expect(heavies(), 1, reason: 'the send was attempted');
      expect(wol.wakes, hasLength(1));
    });

    test('no_heavy_haptic_for_needs_mac', () async {
      await repo.upsert(savedTv());
      expect(await controller().press(), PowerOutcome.needsMac);
      expect(heavies(), 0);
      expect(wol.wakes, isEmpty);
    });

    test('no_heavy_haptic_when_it_cannot_wake', () async {
      await repo.upsert(savedTv(wolMac: _mac));
      expect(
        await controller(available: false).press(),
        PowerOutcome.cannotWake,
      );
      expect(heavies(), 0);
      expect(wol.wakes, isEmpty);
    });

    test('no_heavy_haptic_when_not_connected', () async {
      fake.emit(
        const TvConnectionState(status: ConnectionStatus.needsPairing),
      );
      expect(await controller().press(), PowerOutcome.notConnected);
      expect(heavies(), 0);
      expect(refused, 1);
    });

    test('save_mac_and_wake_fires_one_heavy_haptic', () async {
      await repo.upsert(savedTv());
      final c = controller();
      expect(await c.press(), PowerOutcome.needsMac);
      expect(heavies(), 0);
      expect(await c.saveMacAndWake(_mac), PowerOutcome.waking);
      expect(heavies(), 1);
      expect(wol.wakes, [(_mac, '192.168.0.20')]);
    });

    test('power_key_still_gets_one_heavy_haptic', () async {
      await repo.upsert(savedTv(wolMac: _mac));
      fake.emit(_connected);
      expect(await controller().press(), PowerOutcome.sentPowerKey);
      expect(haptics.events, ['heavy']);
      expect(fake.sentPresses, [(KeyCodes.power, KeyDirection.short)]);
      expect(wol.wakes, isEmpty);
    });
  });
}
