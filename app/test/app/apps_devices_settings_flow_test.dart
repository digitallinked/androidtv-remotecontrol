import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/presentation/apps_screen.dart';
import 'package:tv_remote/features/devices/presentation/devices_screen.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../helpers/fake_remote_client.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/fake_wake_on_lan.dart';
import '../helpers/in_memory_app_usage_repository.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/in_memory_shortcut_repository.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

/// Seam tests for Phase 5: Apps, Your TVs and Settings working with the real
/// router, screens, providers and `TvRemoteSession`. Only the TV's socket
/// (the client), discovery, the wake-up signal and the stores are faked, and
/// the stores are in memory (drift's own streams leave timers behind).
void main() {
  late InMemoryDeviceRepository devices;
  late InMemoryShortcutRepository shortcuts;
  late InMemoryAppUsageRepository usage;
  late FakeRemoteClients clients;
  late FakeWakeOnLan wol;
  late FakeTvDiscoveries discoveries;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    devices = InMemoryDeviceRepository([savedTv()]);
    shortcuts = InMemoryShortcutRepository();
    usage = InMemoryAppUsageRepository();
    clients = FakeRemoteClients();
    wol = FakeWakeOnLan();
    discoveries = FakeTvDiscoveries();
  });

  /// Opens the app at [location] on a phone-sized view, with the stores above.
  Future<void> pumpApp(
    WidgetTester t, {
    String location = AppRoutes.remote,
    bool settle = true,
    List<Override> overrides = const [],
  }) {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: location,
      settle: settle,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(devices),
        savedDevicesProvider.overrideWith(
          (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
        ),
        remoteClientFactoryProvider.overrideWithValue(clients.create),
        shortcutRepositoryProvider.overrideWithValue(shortcuts),
        appUsageRepositoryProvider.overrideWithValue(usage),
        wakeOnLanServiceProvider.overrideWithValue(wol),
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        ...overrides,
      ],
    );
  }

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  Finder appBarText(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  /// The state of the screen on top; a pushed route is not in the router's
  /// own location.
  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  Future<void> tapAndSettle(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  /// Opens the Apps screen from the last tile of the remote's quick row.
  Future<void> openAllApps(WidgetTester t) async {
    await t.drag(
      find.descendant(
        of: find.byType(QuickAccessBar),
        matching: find.byType(ListView),
      ),
      const Offset(-1000, 0),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('All apps'));
    await t.pumpAndSettle();
    expect(find.byType(AppsScreen), findsOneWidget);
  }

  /// Lets work that ends on real (not fake-clock) async, like closing a
  /// client, finish.
  Future<void> letCloseFinish(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
  }

  /// The TV reports [package] as its foreground app.
  Future<void> tvShows(
    WidgetTester t,
    FakeRemoteClient client,
    String package,
  ) async {
    client.push(CurrentAppChanged(package));
    await t.pumpAndSettle();
  }

  Future<void> back(WidgetTester t, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await t.pageBack();
      await t.pumpAndSettle();
    }
  }

  /// Remote → Settings → [tile].
  Future<void> openFromSettings(WidgetTester t, String tile) async {
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    await tapAndSettle(t, find.text(tile));
  }

  void performCustomAction(WidgetTester t, String rowName, String label) {
    final node = t.getSemantics(find.text(rowName));
    final action = node
        .getSemanticsData()
        .customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .whereType<CustomSemanticsAction>()
        .firstWhere((a) => a.label == label);
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(action),
    );
  }

  /// Sends every key press of a hold of [label] lasting [hold].
  Future<void> holdKey(
    WidgetTester t,
    String label,
    Duration hold,
  ) async {
    final gesture = await t.startGesture(
      t.getCenter(find.bySemanticsLabel(label)),
    );
    await t.pump(hold);
    await gesture.up();
    await t.pump();
  }

  // -- Apps --

  testWidgets('edit_apps_then_the_remote_row_follows', (t) async {
    final handle = t.ensureSemantics();
    await pumpApp(t);
    expect(find.text('Connected'), findsOneWidget);

    await openFromSettings(t, 'Apps');
    expect(appBarText('Edit apps'), findsOneWidget);

    // A custom shortcut.
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    await tapAndSettle(t, find.text('Create a custom shortcut'));
    await t.enterText(find.byKey(const ValueKey('shortcut_name')), 'Zed');
    await t.enterText(
      find.byKey(const ValueKey('shortcut_package')),
      'com.example.zed',
    );
    await tapAndSettle(t, find.widgetWithText(FilledButton, 'Save'));
    expect(shortcuts.apps.last.package, 'com.example.zed');
    expect(shortcuts.apps.last.isCustom, isTrue);

    // To the top, one place at a time, the way a screen reader does it.
    for (var i = 0; i < 6; i++) {
      performCustomAction(t, 'Zed', 'Move up');
      await t.pumpAndSettle();
    }
    expect(shortcuts.apps.first.name, 'Zed');
    expect(shortcuts.apps, hasLength(7));

    // Edit apps → Settings → the remote.
    await back(t, 2);
    expect(find.byType(RemoteScreen), findsOneWidget);
    final tiles = t.widgetList<QuickAppTile>(find.byType(QuickAppTile));
    expect(tiles.first.app.name, 'Zed');
    expect(find.bySemanticsLabel('Open Zed'), findsOneWidget);
    expect(
      t.getTopLeft(find.bySemanticsLabel('Open Zed')).dx,
      lessThan(t.getTopLeft(find.bySemanticsLabel('Open Netflix')).dx),
    );

    // And the tile reaches the client.
    await t.tap(find.bySemanticsLabel('Open Zed'));
    await t.pump();
    expect(clients.created.single.sentLinks, [
      'market://launch?id=com.example.zed',
    ]);
    handle.dispose();
  });

  testWidgets('recently_used_on_tv_appears_in_the_add_sheet', (t) async {
    await pumpApp(t);
    final client = clients.created.single;
    await tvShows(t, client, 'com.mediatek.wwtv.tvcenter');
    await tvShows(t, client, 'com.example.tvapp');
    expect(
      usage.stats.keys,
      containsAll([
        'com.mediatek.wwtv.tvcenter',
        'com.example.tvapp',
      ]),
    );

    await openFromSettings(t, 'Apps');
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(BottomSheet), matching: f);
    expect(inSheet(find.text('Recently used on your TV')), findsOneWidget);
    expect(inSheet(find.text('Tvapp')), findsOneWidget);
    expect(inSheet(find.text('Tvcenter')), findsNothing);
    expect(inSheet(find.text('com.mediatek.wwtv.tvcenter')), findsNothing);
  });

  testWidgets(
    'apps_screen_launch_reaches_the_client_and_returns_to_the_remote',
    (
      t,
    ) async {
      await pumpApp(t);
      final client = clients.created.single;
      await tvShows(t, client, 'com.netflix.ninja');
      expect(usage.stats['com.netflix.ninja']?.seenCount, 1);
      final stateBefore = t.state(find.byType(RemoteScreen));

      await openAllApps(t);
      expect(find.byType(AppsScreen), findsOneWidget);
      await t.enterText(find.byType(TextField), 'plex');
      await t.pumpAndSettle();
      expect(find.text('More apps'), findsOneWidget);
      await t.tap(find.text('Plex'));
      await t.pumpAndSettle();

      expect(client.sentLinks.last, 'market://launch?id=com.plexapp.android');
      expect(find.byType(RemoteBody), findsOneWidget);
      expect(find.byType(AppsScreen), findsNothing);
      // The same remote came back, so the usage tracker kept its memory and did
      // not count the app that was already on the TV a second time.
      expect(
        identical(t.state(find.byType(RemoteScreen)), stateBefore),
        isTrue,
      );
      expect(usage.stats['com.netflix.ninja']?.seenCount, 1);
      // Launching from the list does not add the app to it.
      expect(
        shortcuts.apps.map((a) => a.package),
        isNot(contains('com.plexapp.android')),
      );

      // The TV now shows Plex: that is one new sighting.
      client.push(const CurrentAppChanged('com.plexapp.android'));
      await t.pumpAndSettle();
      expect(usage.stats['com.plexapp.android']?.seenCount, 1);
      expect(usage.stats['com.netflix.ninja']?.seenCount, 1);
    },
  );

  testWidgets(
    'demo_launch_from_the_apps_screen_shows_in_the_preview_and_is_not_recorded',
    (
      t,
    ) async {
      await pumpApp(t, location: AppRoutes.discover, settle: false);
      await t.pump();
      await t.tap(find.text('Try demo'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(find.text('Demo mode'), findsOneWidget);

      await openAllApps(t);
      await t.tap(find.text('Netflix'));
      await t.pumpAndSettle();

      expect(find.byType(RemoteBody), findsOneWidget);
      expect(
        find.text('Opened market://launch?id=com.netflix.ninja'),
        findsOneWidget,
      );
      expect(usage.stats, isEmpty);
      expect(clients.created, isEmpty);
    },
  );

  // -- Your TVs --

  testWidgets('renaming_the_active_tv_updates_the_title_and_switcher', (
    t,
  ) async {
    await pumpApp(t);
    expect(appBarText('Living Room TV 3'), findsOneWidget);

    await openFromSettings(t, 'Your TVs');
    await tapAndSettle(t, find.text('Living Room TV 3'));
    await t.enterText(
      find.widgetWithText(TextField, 'Name on this phone'),
      'Bedroom',
    );
    await tapAndSettle(t, find.widgetWithText(FilledButton, 'Save'));
    expect(devices.saved['Living Room TV 3']!.nickname, 'Bedroom');
    expect(appBarText('Bedroom'), findsOneWidget);

    await back(t, 3);
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(appBarText('Bedroom'), findsOneWidget);
    expect(appBarText('Living Room TV 3'), findsNothing);
    // No new session: renaming is not a reason to drop a working connection.
    expect(clients.created, hasLength(1));
    expect(find.text('Connected'), findsOneWidget);

    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Bedroom'),
      ),
      findsOneWidget,
    );
    expect(find.text('Living Room TV 3'), findsNothing);
  });

  /// Remote → Settings → Your TVs → [name] → Remove TV → Remove.
  Future<void> removeFromYourTvs(WidgetTester t, String name) async {
    await openFromSettings(t, 'Your TVs');
    await tapAndSettle(t, find.text(name));
    await tapAndSettle(t, find.text('Remove TV'));
    await tapAndSettle(t, find.widgetWithText(TextButton, 'Remove'));
    expect(find.byType(DevicesScreen), findsOneWidget);
  }

  testWidgets('deleting_the_active_tv_switches_to_the_next_saved_tv', (
    t,
  ) async {
    devices = InMemoryDeviceRepository([
      savedTv(at: DateTime.utc(2026, 10, 25, 12, 5)),
      savedTv(
        name: 'Bedroom TV',
        host: '192.168.0.21',
        at: DateTime.utc(2026, 10, 25, 12, 1),
      ),
    ]);
    await pumpApp(t);
    expect(appBarText('Living Room TV 3'), findsOneWidget);
    final first = clients.created.single;

    await removeFromYourTvs(t, 'Living Room TV 3');
    await back(t, 2);

    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(appBarText('Bedroom TV'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    await letCloseFinish(t);
    expect(first.closed, isTrue);
    expect(clients.created.last.host, '192.168.0.21');
    expect(containerOf(t).read(activeTargetProvider), isNull);
    expect(devices.saved.keys, ['Bedroom TV']);
  });

  testWidgets('deleting_the_only_tv_shows_no_tv_selected', (t) async {
    await pumpApp(t);
    final first = clients.created.single;

    await removeFromYourTvs(t, 'Living Room TV 3');
    await back(t, 2);

    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.text('No TV selected'), findsOneWidget);
    expect(find.byType(RemoteBody), findsNothing);
    await letCloseFinish(t);
    expect(first.closed, isTrue);
    expect(clients.created, hasLength(1));
  });

  testWidgets('mac_saved_in_edit_tv_is_used_by_power', (t) async {
    // Nothing to connect to: power can only wake the TV.
    clients.defaultOutcome = FakeConnect.networkError;
    await pumpApp(t);
    expect(find.text('Connected'), findsNothing);

    await openFromSettings(t, 'Your TVs');
    await tapAndSettle(t, find.text('Living Room TV 3'));
    await t.enterText(find.byType(TextField).last, 'aa-bb-cc-dd-ee-f0');
    await tapAndSettle(t, find.widgetWithText(FilledButton, 'Save'));
    expect(devices.saved['Living Room TV 3']!.wolMac, 'AA:BB:CC:DD:EE:F0');
    await back(t, 3);
    expect(find.byType(RemoteScreen), findsOneWidget);

    await t.longPress(find.byType(PowerButton));
    await t.pumpAndSettle();

    // No setup sheet: the saved address is used.
    expect(find.byType(TextField), findsNothing);
    expect(wol.wakes, [('AA:BB:CC:DD:EE:F0', '192.168.0.20')]);
    expect(find.text('Waking Living Room TV 3…'), findsOneWidget);
  });

  // -- The manual → mDNS merge --

  final stalePin = serverKeyPinFromSha256(List<int>.filled(32, 9));
  const manualName = 'manual:192.168.0.20';

  /// Emits [tvs] on the discovery screen that is open.
  Future<void> discover(WidgetTester t, List<DiscoveredTv> tvs) async {
    discoveries.created.last.emit(tvs);
    await t.pump();
  }

  testWidgets('merged_tv_with_a_different_key_asks_to_pair_again', (t) async {
    // Added by IP address when the TV had key A; the mDNS TV at that address
    // now presents key B (the clients' default).
    devices = InMemoryDeviceRepository([
      savedTv(name: manualName, pin: stalePin),
    ]);
    await pumpApp(t, location: AppRoutes.discover, settle: false);
    await t.pump();
    await discover(t, [tv('Living Room TV 3')]);
    expect(find.text('Paired'), findsOneWidget);

    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();

    // The pin moved with the row, so the different key is caught.
    expect(devices.saved.keys, ['Living Room TV 3']);
    expect(find.text("This TV's identity changed"), findsOneWidget);
    expect(devices.saved['Living Room TV 3']!.serverKeyPin, isNull);
    expect(clients.created.single.host, '192.168.0.20');
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('merge_while_the_active_target_is_the_manual_row', (t) async {
    devices = InMemoryDeviceRepository([savedTv(name: manualName)]);
    await pumpApp(t);
    final container = containerOf(t);
    container.read(activeTargetProvider.notifier).activateDevice(manualName);
    await t.pumpAndSettle();
    expect(appBarText(manualName), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    final first = clients.created.last;

    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add a TV'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await discover(t, [tv('Living Room TV 3')]);
    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();

    // The session moved to the merged name; nothing points at the old row.
    expect(container.read(activeTargetProvider), isA<DeviceTarget>());
    expect(
      (container.read(activeTargetProvider)! as DeviceTarget).serviceName,
      'Living Room TV 3',
    );
    expect(devices.saved.keys, ['Living Room TV 3']);
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(appBarText('Living Room TV 3'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    await letCloseFinish(t);
    expect(first.closed, isTrue);
    final session = container.read(remoteSessionProvider).value!;
    expect(session.pairingTarget?.serviceName, 'Living Room TV 3');
  });

  // -- Settings --

  testWidgets('settings_toggles_change_the_remote_live', (t) async {
    final handle = t.ensureSemantics();
    await pumpApp(t);
    final client = clients.created.single;

    await holdKey(t, 'Volume up', const Duration(milliseconds: 400));
    expect(client.sentKeys.first.$2, KeyDirection.startLong);
    client.sentKeys.clear();

    await openFromSettings(t, 'Remote behaviour');
    await tapAndSettle(t, find.text('Smooth Press'));
    await back(t, 2);
    expect(find.byType(RemoteScreen), findsOneWidget);

    await holdKey(t, 'Volume up', const Duration(milliseconds: 500));
    expect(client.sentKeys.length, greaterThan(1));
    expect(
      client.sentKeys.every(
        (k) => k.$1 == KeyCodes.volumeUp && k.$2 == KeyDirection.short,
      ),
      isTrue,
      reason: '${client.sentKeys}',
    );
    handle.dispose();
  });

  testWidgets('settings_subpage_back_returns_to_the_hub', (t) async {
    await pumpApp(t);
    await openFromSettings(t, 'Appearance');
    expect(appBarText('Appearance'), findsOneWidget);
    // One hub page under the child.
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);

    await back(t);
    expect(appBarText('Settings'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await back(t);
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('apps_and_devices_children_return_to_one_parent_page', (t) async {
    await pumpApp(t, location: AppRoutes.apps);
    final apps = GoRouter.of(t.element(find.byType(AppsScreen)));
    unawaited(apps.push(AppRoutes.manageApps));
    await t.pumpAndSettle();
    expect(appBarText('Edit apps'), findsOneWidget);
    expect(find.byType(AppsScreen, skipOffstage: false), findsOneWidget);
    await back(t);
    expect(appBarText('Apps'), findsOneWidget);
    expect(find.byType(AppsScreen), findsOneWidget);

    await pumpApp(t, location: AppRoutes.devices);
    final tvs = GoRouter.of(t.element(find.byType(DevicesScreen)));
    unawaited(tvs.push(AppRoutes.editDevice('Living Room TV 3')));
    await t.pumpAndSettle();
    expect(find.text('Remove TV'), findsOneWidget);
    expect(find.byType(DevicesScreen, skipOffstage: false), findsOneWidget);
    expect(top(t).uri.path, AppRoutes.editDevice('Living Room TV 3'));
    await back(t);
    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(find.text('Remove TV'), findsNothing);
  });

  testWidgets('each_settings_page_title_names_the_page', (t) async {
    await pumpApp(t);
    // The hub's tile → the page it opens.
    const pages = {
      'Remote layout': 'Remote layout',
      'Remote behaviour': 'Remote behaviour',
      'Apps': 'Edit apps',
      'Your TVs': 'Your TVs',
      'Appearance': 'Appearance',
      'Help': 'Help',
      'About this app': 'About this app',
    };
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(appBarText('Settings'), findsOneWidget);
    for (final e in pages.entries) {
      await tapAndSettle(t, find.text(e.key));
      expect(appBarText(e.value), findsOneWidget, reason: e.key);
      expect(appBarText('Settings'), findsNothing, reason: e.key);
      await back(t);
      expect(appBarText('Settings'), findsOneWidget, reason: e.key);
    }

    // Opened by address, the same names.
    const routes = {
      AppRoutes.manageApps: 'Edit apps',
      AppRoutes.devices: 'Your TVs',
      AppRoutes.settingsAppearance: 'Appearance',
      AppRoutes.settingsRemoteLayout: 'Remote layout',
      AppRoutes.settingsRemoteBehaviour: 'Remote behaviour',
      AppRoutes.settingsHelp: 'Help',
      AppRoutes.settingsAbout: 'About this app',
    };
    for (final e in routes.entries) {
      await pumpApp(t, location: e.key);
      expect(appBarText(e.value), findsOneWidget, reason: e.key);
      expect(appBarText('Settings'), findsNothing, reason: e.key);
    }
    // A TV's own page is named after the TV.
    await pumpApp(t, location: AppRoutes.editDevice('Living Room TV 3'));
    expect(appBarText('Living Room TV 3'), findsOneWidget);
  });

  // -- Banner slot and microphone --

  /// Every route of the app, with how many banner slots it shows.
  final bannerRoutes = <String, int>{
    AppRoutes.onboarding: 0,
    AppRoutes.discover: 0,
    AppRoutes.pair('Living Room TV 3'): 0,
    AppRoutes.remote: 0,
    AppRoutes.apps: 1,
    AppRoutes.manageApps: 0,
    AppRoutes.devices: 0,
    AppRoutes.editDevice('Living Room TV 3'): 0,
    AppRoutes.settings: 1,
    AppRoutes.settingsAppearance: 0,
    AppRoutes.settingsRemoteLayout: 0,
    AppRoutes.settingsRemoteBehaviour: 0,
    AppRoutes.settingsHelp: 0,
    AppRoutes.settingsAbout: 0,
    AppRoutes.paywall(source: 'test'): 0,
  };

  /// Pumps [route], tolerating the screens that never settle.
  Future<void> pumpRoute(WidgetTester t, String route) async {
    final live =
        route == AppRoutes.discover ||
        route == AppRoutes.pair('Living Room TV 3');
    await pumpApp(t, location: route, settle: !live);
    if (live) {
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('banner_slot_only_on_apps_and_the_settings_hub', (t) async {
    for (final e in bannerRoutes.entries) {
      await pumpRoute(t, e.key);
      expect(find.byType(BannerSlot), findsNWidgets(e.value), reason: e.key);
    }
    await pumpRoute(t, AppRoutes.apps);
    expect(
      t.widget<BannerSlot>(find.byType(BannerSlot)).placement,
      AdPlacement.apps,
    );
    await pumpRoute(t, AppRoutes.settings);
    expect(
      t.widget<BannerSlot>(find.byType(BannerSlot)).placement,
      AdPlacement.settings,
    );

    // A child page on top of the hub or the Apps screen hides their slot.
    await pumpRoute(t, AppRoutes.settings);
    await tapAndSettle(t, find.text('Appearance'));
    expect(find.byType(BannerSlot), findsNothing);
    await pumpRoute(t, AppRoutes.apps);
    await t.tap(find.byTooltip('Edit apps'));
    await t.pumpAndSettle();
    expect(find.byType(BannerSlot), findsNothing);
  });

  /// Opens every sheet and dialog reachable from Apps, Edit apps, Your TVs,
  /// Settings and its pages, one at a time, and calls [check] with the name
  /// of what is open.
  Future<void> forEachSheet(
    WidgetTester t,
    Future<void> Function(String name) check,
  ) async {
    Future<void> closeSheet() async {
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
    }

    // Edit apps: add sheet, then the editor of a new and an existing app.
    await pumpApp(t, location: AppRoutes.manageApps);
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    await check('add app sheet');
    await tapAndSettle(t, find.text('Create a custom shortcut'));
    await check('new shortcut editor');
    await closeSheet();
    await t.tap(find.byTooltip('Edit Netflix'));
    await t.pumpAndSettle();
    await check('edit shortcut editor');
    await closeSheet();

    // Edit TV: the MAC help sheet.
    await pumpApp(t, location: AppRoutes.editDevice('Living Room TV 3'));
    await tapAndSettle(t, find.text('Where do I find it?'));
    await check('mac help sheet');
    await closeSheet();

    // Help: troubleshooting.
    await pumpApp(t, location: AppRoutes.settingsHelp);
    await tapAndSettle(t, find.text('Show troubleshooting steps'));
    await check('troubleshooting sheet');
  }

  testWidgets('no_sheet_has_a_banner_slot', (t) async {
    await forEachSheet(t, (name) async {
      expect(find.byType(BottomSheet), findsOneWidget, reason: name);
      expect(find.byType(BannerSlot), findsNothing, reason: name);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(BannerSlot),
          skipOffstage: false,
        ),
        findsNothing,
        reason: name,
      );
    });
  });

  testWidgets('no_mic_button_anywhere', (t) async {
    const mics = [Icons.mic, Icons.mic_none, Icons.mic_outlined];
    void expectNoMic(String where) {
      for (final icon in mics) {
        expect(
          find.byIcon(icon, skipOffstage: false),
          findsNothing,
          reason: '$where ${icon.codePoint}',
        );
      }
    }

    for (final route in bannerRoutes.keys) {
      await pumpRoute(t, route);
      expectNoMic(route);
    }
    await forEachSheet(t, (name) async => expectNoMic(name));
  });
}
