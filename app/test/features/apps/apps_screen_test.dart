import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/presentation/apps_screen.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/disk_exception.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/in_memory_shortcut_repository.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);
const _needsPairing = TvConnectionState(status: ConnectionStatus.needsPairing);

/// A shortcut store whose saved list never arrives.
class _NeverLoadingShortcuts extends InMemoryShortcutRepository {
  @override
  Stream<List<AppEntry>> watchAll() =>
      StreamController<List<AppEntry>>().stream;
}

/// A shortcut store whose stream fails until [broken] is cleared.
class _FlakyShortcuts extends InMemoryShortcutRepository {
  _FlakyShortcuts(super.initial);

  bool broken = true;

  @override
  Stream<List<AppEntry>> watchAll() =>
      broken ? Stream.error(StateError('disk')) : super.watchAll();
}

/// A shortcut store whose stream always fails with an [Exception], counting
/// how often it is asked for.
class _BrokenShortcuts extends InMemoryShortcutRepository {
  int subscriptions = 0;

  @override
  Stream<List<AppEntry>> watchAll() {
    subscriptions++;
    return Stream.error(const DiskException());
  }
}

void main() {
  late FakeRemoteSession fake;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
      initial: _connected,
    );
  });

  Future<void> pumpApps(
    WidgetTester t, {
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => pumpRouterApp(
    t,
    initialLocation: AppRoutes.apps,
    textScale: textScale,
    brightness: brightness,
    overrides: [
      remoteSessionProvider.overrideWith((ref) async => fake),
      ...overrides,
    ],
  );

  /// The state of the screen on top: a pushed route is not in the router's
  /// own location, so ask the topmost scaffold.
  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  Future<void> search(WidgetTester t, String query) async {
    await t.enterText(find.byType(TextField), query);
    await t.pumpAndSettle();
  }

  testWidgets('shows_the_seeded_shortcuts_under_your_apps', (t) async {
    await pumpApps(t);
    expect(find.text('Your apps'), findsOneWidget);
    expect(find.text('More apps'), findsNothing);
    expect(
      [
        for (final tile in t.widgetList<AppTile>(find.byType(AppTile)))
          tile.app.name,
      ],
      ['Netflix', 'YouTube', 'Prime Video', 'Disney+', 'Spotify', 'Apple TV'],
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Apps'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tile_launch_calls_remote_actions', (t) async {
    final handle = t.ensureSemantics();
    await pumpApps(t);
    await t.tap(find.bySemanticsLabel('Open YouTube'));
    await t.pumpAndSettle();
    expect(fake.sentLinks, [
      'market://launch?id=com.google.android.youtube.tv',
    ]);
    // The next thing to do is navigate inside the app: back on the remote.
    expect(find.byType(RemoteBody), findsOneWidget);
    expect(find.byType(AppsScreen), findsNothing);
    handle.dispose();
  });

  testWidgets('launching_after_a_push_leaves_no_apps_page_behind', (t) async {
    final handle = t.ensureSemantics();
    await pumpApps(t);
    // Remote → Apps, as the All apps tile does.
    GoRouter.of(t.element(find.byType(AppsScreen))).go(AppRoutes.remote);
    await t.pumpAndSettle();
    unawaited(
      GoRouter.of(t.element(find.byType(RemoteBody))).push(AppRoutes.apps),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Open Netflix'));
    await t.pumpAndSettle();
    expect(find.byType(RemoteBody), findsOneWidget);
    expect(find.byType(AppsScreen), findsNothing);
    handle.dispose();
  });

  testWidgets('refused_launch_shows_not_connected_and_stays', (t) async {
    final handle = t.ensureSemantics();
    fake.emit(_offline);
    await pumpApps(t);
    await t.tap(find.bySemanticsLabel('Open Netflix'));
    await t.pump();
    expect(find.text('Not connected to your TV'), findsOneWidget);
    expect(find.byType(AppsScreen), findsOneWidget);
    expect(find.byType(RemoteBody), findsNothing);
    expect(fake.sentLinks, isEmpty);
    handle.dispose();
  });

  testWidgets('repeated_refusals_show_one_snackbar', (t) async {
    final handle = t.ensureSemantics();
    fake.emit(_offline);
    await pumpApps(t);
    await t.tap(find.bySemanticsLabel('Open Netflix'));
    await t.pump();
    await t.tap(find.bySemanticsLabel('Open YouTube'));
    await t.pump();
    await t.tap(find.bySemanticsLabel('Open Spotify'));
    await t.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no_snackbar_while_another_page_is_on_top', (t) async {
    await pumpApps(t);
    final container = ProviderScope.containerOf(
      t.element(find.byType(AppsScreen)),
    );
    await t.tap(find.byTooltip('Edit apps'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.manageApps);
    container.read(notConnectedNoticesProvider.notifier).notify();
    await t.pump();
    expect(find.text('Not connected to your TV'), findsNothing);
  });

  testWidgets('the_status_strip_offers_reconnect', (t) async {
    fake.emit(_offline);
    await pumpApps(t);
    expect(find.text('Offline'), findsOneWidget);
    await t.tap(find.text('Reconnect'));
    await t.pump();
    expect(fake.reconnectCalls, 1);
  });

  testWidgets('the_status_strip_offers_pair_again', (t) async {
    fake.emit(_needsPairing);
    await pumpApps(t);
    await t.tap(find.text('Pair again'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    expect(top(t).extra, isNull);
  });

  testWidgets('search_filters_your_apps_and_shows_more_apps', (t) async {
    final handle = t.ensureSemantics();
    await pumpApps(t);
    await search(t, 'plex');
    expect(find.bySemanticsLabel('Open Netflix'), findsNothing);
    expect(find.text('Your apps'), findsNothing);
    expect(find.text('More apps'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Plex'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Open Plex'));
    await t.pumpAndSettle();
    // Launched without being added to the list.
    expect(fake.sentLinks, ['market://launch?id=com.plexapp.android']);
    expect(find.byType(RemoteBody), findsOneWidget);
    handle.dispose();
  });

  testWidgets('search_matches_your_apps_ignoring_case', (t) async {
    final handle = t.ensureSemantics();
    await pumpApps(t);
    await search(t, 'NETFLIX');
    expect(find.bySemanticsLabel('Open Netflix'), findsOneWidget);
    expect(find.bySemanticsLabel('Open YouTube'), findsNothing);
    expect(find.text('Your apps'), findsOneWidget);
    // Netflix is already a shortcut, so it is not offered a second time.
    expect(find.byType(AppTile), findsOneWidget);
    expect(find.text('More apps'), findsNothing);
    handle.dispose();
  });

  testWidgets('more_apps_never_repeat_your_apps_and_do_not_add_them', (
    t,
  ) async {
    final repository = InMemoryShortcutRepository();
    await pumpApps(
      t,
      overrides: [shortcutRepositoryProvider.overrideWithValue(repository)],
    );
    final before = [for (final a in repository.apps) a.package];
    await search(t, 'plex');
    await t.tap(find.text('Plex'));
    await t.pumpAndSettle();
    expect([for (final a in repository.apps) a.package], before);
  });

  testWidgets('no_match_says_so', (t) async {
    await pumpApps(t);
    await search(t, 'zzzz');
    expect(find.text('No apps match "zzzz".'), findsOneWidget);
    expect(find.byType(AppTile), findsNothing);
    expect(find.text('Your apps'), findsNothing);
  });

  testWidgets('the_clear_button_restores_the_list', (t) async {
    await pumpApps(t);
    expect(find.byTooltip('Clear'), findsNothing);
    await search(t, 'zzzz');
    await t.tap(find.byTooltip('Clear'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField)).controller?.text, '');
    expect(find.text('Your apps'), findsOneWidget);
    expect(find.byType(AppTile), findsNWidgets(6));
    expect(find.byTooltip('Clear'), findsNothing);
  });

  testWidgets('a_blank_query_is_not_a_search', (t) async {
    await pumpApps(t);
    await search(t, '   ');
    expect(find.text('Your apps'), findsOneWidget);
    expect(find.byType(AppTile), findsNWidgets(6));
    expect(find.textContaining('No apps match'), findsNothing);
  });

  testWidgets('the_search_field_is_a_search_field', (t) async {
    await pumpApps(t);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.search);
    expect(find.text('Search apps'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('empty_list_offers_add_apps', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(
          InMemoryShortcutRepository(),
        ),
      ],
    );
    expect(find.text('No apps yet'), findsOneWidget);
    expect(
      find.text('Add the apps you use on your TV to open them with one tap.'),
      findsOneWidget,
    );
    expect(find.text('Your apps'), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, 'Add apps'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.manageApps);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Edit apps'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an_empty_list_still_searches_the_catalogue', (t) async {
    final handle = t.ensureSemantics();
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(
          InMemoryShortcutRepository(),
        ),
      ],
    );
    await search(t, 'plex');
    expect(find.text('No apps yet'), findsNothing);
    expect(find.text('Your apps'), findsNothing);
    expect(find.text('More apps'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Plex'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shortcuts_error_shows_without_retrying', (t) async {
    final repository = _BrokenShortcuts();
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      settle: false,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(repository),
      ],
    );
    // One settle: a retried provider would spin here for ~38 s instead.
    await t.pumpAndSettle();
    expect(find.text("Couldn't load your apps."), findsOneWidget);
    expect(repository.subscriptions, 1);
  });

  testWidgets('unreadable_shortcuts_show_an_error_with_retry', (t) async {
    final repository = _FlakyShortcuts([
      const AppEntry(package: 'com.netflix.ninja', name: 'Netflix'),
    ]);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(repository),
      ],
    );
    expect(find.text("Couldn't load your apps."), findsOneWidget);
    expect(find.text('No apps yet'), findsNothing);
    expect(find.text('Your apps'), findsNothing);
    final retry = find.widgetWithText(FilledButton, 'Try again');
    expect(retry, findsOneWidget);
    expect(t.getSize(retry).height, greaterThanOrEqualTo(48));

    // Retry with a stream that works again shows the grid.
    repository.broken = false;
    await t.tap(retry);
    await t.pumpAndSettle();
    expect(find.text("Couldn't load your apps."), findsNothing);
    expect(find.text('Your apps'), findsOneWidget);
    expect(find.byType(AppTile), findsOneWidget);
  });

  testWidgets('search_finds_an_app_by_its_package', (t) async {
    final handle = t.ensureSemantics();
    await pumpApps(t);
    await search(t, 'ninja');
    expect(find.text('Your apps'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Netflix'), findsOneWidget);
    expect(find.byType(AppTile), findsOneWidget);
    handle.dispose();
  });

  // Catalogue order puts Disney+ Hotstar first; in India JioHotstar leads.
  // "startv" is in both packages and in neither name, so both have the same
  // name rank and only the region orders them (Ruling P7-R10).
  for (final (region, expected) in [
    (null, ['Disney+ Hotstar', 'JioHotstar']),
    ('IN', ['JioHotstar', 'Disney+ Hotstar']),
  ]) {
    testWidgets('search_ranks_the_phones_region_first_${region ?? 'none'}', (
      t,
    ) async {
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.apps,
        prepareSettings: (store) => store.setShortcutsSeeded(true),
        overrides: [
          remoteSessionProvider.overrideWith((ref) async => fake),
          shortcutRepositoryProvider.overrideWithValue(
            InMemoryShortcutRepository(),
          ),
          deviceRegionProvider.overrideWithValue(region),
        ],
      );
      await search(t, 'startv');
      expect([
        for (final tile in t.widgetList<AppTile>(find.byType(AppTile)))
          tile.app.name,
      ], expected);
    });
  }

  // The name rank comes before the region: 'hotstar' starts a word of
  // "Disney+ Hotstar" but is inside "JioHotstar", so even in India, where
  // only JioHotstar is listed, Disney+ Hotstar comes first (Ruling P7-R10).
  testWidgets('hotstar_in_india_lists_disney_plus_hotstar_first', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(
          InMemoryShortcutRepository(),
        ),
        deviceRegionProvider.overrideWithValue('IN'),
      ],
    );
    await search(t, 'hotstar');
    final names = [
      for (final tile in t.widgetList<AppTile>(find.byType(AppTile)))
        tile.app.name,
    ];
    expect(names, containsAllInOrder(['Disney+ Hotstar', 'JioHotstar']));
  });

  testWidgets('your_apps_filter_ranks_prefix_first', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(
          InMemoryShortcutRepository(const [
            AppEntry(package: 'com.example.amazon', name: 'Amazon Prime Video'),
            AppEntry(package: 'com.example.prime', name: 'Prime Video'),
          ]),
        ),
      ],
    );
    await search(t, 'pr');
    expect(find.text('Your apps'), findsOneWidget);
    final names = [
      for (final tile in t.widgetList<AppTile>(
        find.descendant(
          of: find.byType(SliverGrid).first,
          matching: find.byType(AppTile),
        ),
      ))
        tile.app.name,
    ];
    expect(names, ['Prime Video', 'Amazon Prime Video']);
  });

  testWidgets('empty_list_fits_without_scrolling', (t) async {
    t.view
      ..physicalSize = const Size(390, 800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(
          InMemoryShortcutRepository(),
        ),
      ],
    );
    expect(find.text('No apps yet'), findsOneWidget);
    final scrollable = t.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, 0);
  });

  /// Opens the Apps screen on [shortcuts] in a 390 × 800 view, and checks
  /// its list doesn't scroll: the banner clearance sits inside the state
  /// that fills the rest (Ruling P7-R11).
  Future<void> expectNoScroll(
    WidgetTester t,
    InMemoryShortcutRepository shortcuts, {
    required Finder shows,
    bool settle = true,
  }) async {
    t.view
      ..physicalSize = const Size(390, 800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.apps,
      settle: settle,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => fake),
        shortcutRepositoryProvider.overrideWithValue(shortcuts),
      ],
    );
    if (!settle) await t.pump();
    expect(shows, findsOneWidget);
    final scrollable = t.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, 0);
  }

  testWidgets('loading_list_fits_without_scrolling', (t) async {
    // The saved list never arrives: the screen keeps its spinner.
    await expectNoScroll(
      t,
      _NeverLoadingShortcuts(),
      shows: find.byType(CircularProgressIndicator),
      settle: false,
    );
  });

  testWidgets('failed_list_fits_without_scrolling', (t) async {
    await expectNoScroll(
      t,
      _FlakyShortcuts(const []),
      shows: find.text("Couldn't load your apps."),
    );
  });

  testWidgets('dragging_the_list_closes_the_keyboard', (t) async {
    await pumpApps(t);
    expect(
      t
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('edit_action_opens_edit_apps', (t) async {
    await pumpApps(t);
    final action = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.edit_outlined),
    );
    expect(action, findsOneWidget);
    expect(t.getSize(find.byTooltip('Edit apps')).shortestSide, 48);
    await t.tap(action);
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.manageApps);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Edit apps'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('current_app_is_marked', (t) async {
    final handle = t.ensureSemantics();
    await pumpApps(t);
    fake.push(const CurrentAppChanged('com.netflix.ninja'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Netflix, now on TV'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Netflix'), findsNothing);
    expect(find.bySemanticsLabel('Open YouTube'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the_current_app_is_not_marked_while_offline', (t) async {
    final handle = t.ensureSemantics();
    fake
      ..push(const CurrentAppChanged('com.netflix.ninja'))
      ..emit(_offline);
    await pumpApps(t);
    expect(find.bySemanticsLabel('Netflix, now on TV'), findsNothing);
    expect(find.bySemanticsLabel('Open Netflix'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('apps_screen_has_one_banner_slot_and_no_fab', (t) async {
    await pumpApps(t);
    expect(find.byType(BannerSlot), findsOneWidget);
    expect(find.byKey(const ValueKey('banner_slot_apps')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    final scaffold = t.widget<Scaffold>(
      find.descendant(
        of: find.byType(AppsScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.bottomNavigationBar, isNotNull);
    expect(scaffold.floatingActionButton, isNull);
  });

  testWidgets('the_list_ends_with_the_banner_clearance', (t) async {
    t.view
      ..physicalSize = const Size(360, 480)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApps(t);
    // Many matches: more than a screen of tiles.
    await search(t, 'a');
    final tiles = find.byType(AppTile);
    final scrollable = t.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(200));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await t.pumpAndSettle();
    final viewport = t.getRect(find.byType(CustomScrollView));
    var lowest = 0.0;
    for (final e in tiles.evaluate()) {
      final box = e.renderObject! as RenderBox;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      if (bottom > lowest) lowest = bottom;
    }
    expect(lowest, lessThanOrEqualTo(viewport.bottom - BannerSlot.clearance));
  });

  for (final b in Brightness.values) {
    testWidgets('apps_screen_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      fake.push(const CurrentAppChanged('com.netflix.ninja'));
      await pumpApps(t, textScale: 2, brightness: b);
      expect(t.takeException(), isNull);
      expect(find.byType(AppTile), findsWidgets);
      await search(t, 'prime');
      expect(t.takeException(), isNull);
      await search(t, 'zzzz');
      expect(t.takeException(), isNull);
      expect(find.text('No apps match "zzzz".'), findsOneWidget);
    });
  }

  testWidgets('every_tile_is_at_least_48dp', (t) async {
    await pumpApps(t, textScale: 2);
    for (final e in find.byType(AppTile).evaluate()) {
      final size = (e.renderObject! as RenderBox).size;
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
