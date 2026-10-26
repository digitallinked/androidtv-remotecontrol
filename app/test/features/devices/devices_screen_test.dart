import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/devices/presentation/devices_screen.dart';
import 'package:tv_remote/features/devices/presentation/edit_device_screen.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);

void main() {
  late InMemoryDeviceRepository repo;
  late FakeRemoteSession session;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    // "Lounge" is the TV in use and has a nickname; "Bedroom TV" was never
    // paired (no key).
    final lounge = savedTv(
      nickname: 'Lounge',
      at: DateTime.utc(2026, 10, 25, 12, 5),
    );
    repo = InMemoryDeviceRepository([
      lounge,
      savedTv(
        name: 'Bedroom TV',
        host: '192.168.0.21',
        noPin: true,
        at: DateTime.utc(2026, 10, 25, 12, 1),
      ),
    ]);
    session = FakeRemoteSession(
      pairingTarget: lounge.toDiscoveredTv(),
      initial: _connected,
    );
  });

  Future<void> pumpDevices(
    WidgetTester t, {
    String location = AppRoutes.devices,
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: location,
      textScale: textScale,
      brightness: brightness,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(repo),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
        remoteSessionProvider.overrideWith((ref) async => session),
        ...overrides,
      ],
    );
  }

  testWidgets('devices_list_marks_the_tv_in_use_and_unpaired_tvs', (t) async {
    final semantics = t.ensureSemantics();
    await pumpDevices(t);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Your TVs'),
      ),
      findsOneWidget,
    );
    // The nickname is the title; the announced name and the state follow.
    expect(find.text('Lounge'), findsOneWidget);
    expect(find.text('Living Room TV 3 · In use'), findsOneWidget);
    expect(find.text('Bedroom TV'), findsOneWidget);
    expect(find.text('Needs pairing'), findsOneWidget);
    // Most recently used first, one row each.
    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(2));
    expect(
      t.getTopLeft(find.text('Lounge')).dy,
      lessThan(t.getTopLeft(find.text('Bedroom TV')).dy),
    );
    for (final tile in tiles.evaluate()) {
      expect(
        t.getSize(find.byWidget(tile.widget)).height,
        greaterThanOrEqualTo(56),
      );
    }
    // The row reads out what it opens.
    expect(find.bySemanticsLabel(RegExp('Edit Lounge')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tapping_a_tv_opens_its_edit_page', (t) async {
    await pumpDevices(t);
    await t.tap(find.text('Bedroom TV'));
    await t.pumpAndSettle();
    expect(find.byType(EditDeviceScreen), findsOneWidget);
    expect(
      GoRouterState.of(t.element(find.byType(EditDeviceScreen))).uri.path,
      AppRoutes.editDevice('Bedroom TV'),
    );
  });

  testWidgets('add_a_tv_opens_discovery', (t) async {
    await pumpDevices(t);
    await t.tap(find.byTooltip('Add a TV'));
    await t.pumpAndSettle();
    expect(find.byType(DiscoveryScreen), findsOneWidget);
  });

  testWidgets('empty_list_offers_to_add_a_tv', (t) async {
    repo = InMemoryDeviceRepository();
    session = FakeRemoteSession();
    await pumpDevices(t);
    expect(find.text('No TVs yet'), findsOneWidget);
    expect(
      find.text('Pair a TV to control it from this phone.'),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, 'Add a TV'));
    await t.pumpAndSettle();
    expect(find.byType(DiscoveryScreen), findsOneWidget);
  });

  testWidgets('manage_tvs_in_switcher_opens_your_tvs', (t) async {
    await pumpDevices(t, location: AppRoutes.remote);
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    // Before "Add a TV".
    expect(
      t.getTopLeft(find.text('Manage TVs')).dy,
      lessThan(t.getTopLeft(find.text('Add a TV')).dy),
    );
    await t.tap(find.text('Manage TVs'));
    await t.pumpAndSettle();
    expect(find.byType(DevicesScreen), findsOneWidget);
    // Back returns to the remote.
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byType(RemoteScreen), findsOneWidget);
  });

  testWidgets('devices_screen_has_no_banner_slot', (t) async {
    await pumpDevices(t);
    expect(find.byType(BannerSlot), findsNothing);
    expect(
      t.widget<Scaffold>(find.byType(Scaffold).last).bottomNavigationBar,
      isNull,
    );
  });

  testWidgets('devices_screen_fits_320dp_at_200_percent_text', (t) async {
    for (final brightness in Brightness.values) {
      await pumpDevices(
        t,
        textScale: 2,
        brightness: brightness,
        size: const Size(320, 640),
      );
      expect(t.takeException(), isNull);
      expect(find.text('Lounge'), findsOneWidget);
      expect(find.text('Bedroom TV'), findsOneWidget);
    }
    repo = InMemoryDeviceRepository();
    await pumpDevices(t, textScale: 2, size: const Size(320, 640));
    expect(t.takeException(), isNull);
    expect(find.text('No TVs yet'), findsOneWidget);
  });

  testWidgets('devices_screen_meets_the_accessibility_guidelines', (t) async {
    final semantics = t.ensureSemantics();
    await pumpDevices(t);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(t, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
