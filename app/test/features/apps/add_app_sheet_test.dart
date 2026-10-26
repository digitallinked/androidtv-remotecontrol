import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

import '../../helpers/in_memory_app_usage_repository.dart';
import '../../helpers/in_memory_shortcut_repository.dart';
import '../../helpers/pump_router_app.dart';

const _netflix = AppEntry(package: 'com.netflix.ninja', name: 'Netflix');
const _youtube = AppEntry(
  package: 'com.google.android.youtube.tv',
  name: 'YouTube',
);

void main() {
  late InMemoryShortcutRepository repo;
  late InMemoryAppUsageRepository usage;

  setUp(() {
    repo = InMemoryShortcutRepository();
    usage = InMemoryAppUsageRepository();
  });

  /// Opens Edit apps and its add sheet. With [list] the user's list is
  /// exactly that; otherwise it is the default "*" row.
  Future<void> pumpSheet(
    WidgetTester t, {
    List<AppEntry>? list,
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    if (list != null) repo = InMemoryShortcutRepository(list);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.manageApps,
      textScale: textScale,
      brightness: brightness,
      prepareSettings: list == null
          ? null
          : (store) => store.setShortcutsSeeded(true),
      overrides: [
        shortcutRepositoryProvider.overrideWithValue(repo),
        appUsageRepositoryProvider.overrideWithValue(usage),
        ...overrides,
      ],
    );
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
  }

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  Future<void> search(WidgetTester t, String query) async {
    await t.enterText(find.byKey(const ValueKey('add_app_search')), query);
    await t.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester t, Finder row) async {
    await t.ensureVisible(row);
    await t.pumpAndSettle();
    await t.tap(row);
    await t.pumpAndSettle();
  }

  Future<void> seenOn(String package, int times) async {
    for (var i = 0; i < times; i++) {
      await usage.recordSeen(package, DateTime.utc(2026, 10, 27, 12, i));
    }
  }

  testWidgets('add_sheet_lists_recent_tv_apps_without_system_packages', (
    t,
  ) async {
    await seenOn('android', 5);
    await seenOn('com.mediatek.wwtv.tvcenter', 4);
    await seenOn('com.example.tvapp', 3);
    await seenOn('com.plexapp.android', 1);
    await seenOn('com.netflix.ninja', 9); // already on the list
    await pumpSheet(t);
    expect(find.text('Add an app'), findsOneWidget);
    expect(inSheet(find.text('Recently used on your TV')), findsOneWidget);
    final tvapp = inSheet(find.text('Tvapp'));
    final plex = inSheet(find.text('Plex'));
    expect(tvapp, findsOneWidget);
    expect(plex, findsOneWidget);
    expect(t.getTopLeft(tvapp).dy, lessThan(t.getTopLeft(plex).dy));
    expect(inSheet(find.text('android')), findsNothing);
    expect(inSheet(find.text('Android')), findsNothing);
    expect(inSheet(find.text('Tvcenter')), findsNothing);
    // Netflix is on the list: not offered anywhere in the sheet.
    expect(inSheet(find.text('Netflix')), findsNothing);
    // Each row shows its app ID.
    expect(inSheet(find.text('com.example.tvapp')), findsOneWidget);
  });

  testWidgets('recent_apps_are_not_repeated_under_suggested_apps', (t) async {
    await seenOn('com.plexapp.android', 2);
    await pumpSheet(t);
    expect(inSheet(find.text('Plex')), findsOneWidget);
  });

  testWidgets('the_empty_recent_section_says_what_it_is_for', (t) async {
    await pumpSheet(t);
    expect(
      inSheet(find.text('Apps you open on your TV show up here.')),
      findsOneWidget,
    );
    expect(inSheet(find.text('Suggested apps')), findsOneWidget);
  });

  testWidgets('suggested_apps_follow_the_region', (t) async {
    await pumpSheet(
      t,
      list: const [_netflix],
      overrides: [deviceRegionProvider.overrideWithValue('MY')],
    );
    expect(inSheet(find.text('Viu')), findsOneWidget);
    expect(inSheet(find.text('Hulu')), findsNothing);
    // Global apps are offered too, apps on the list are not.
    expect(inSheet(find.text('YouTube')), findsOneWidget);
    expect(inSheet(find.text('Netflix')), findsNothing);
  });

  testWidgets('search_finds_catalogue_apps_and_adds_by_id', (t) async {
    await pumpSheet(t);
    await search(t, 'kodi');
    expect(inSheet(find.text('Kodi')), findsOneWidget);
    expect(inSheet(find.text('Suggested apps')), findsNothing);

    await search(t, 'com.example.newapp');
    final byId = inSheet(find.text('Add app ID "com.example.newapp"'));
    expect(byId, findsOneWidget);
    await tapRow(t, byId);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Newapp added'), findsOneWidget);
    final added = repo.apps.last;
    expect(added.package, 'com.example.newapp');
    expect(added.name, 'Newapp');
    expect(added.customIcon, 'app');
    expect(added.isCustom, isFalse);
    expect(added.launchLink, 'market://launch?id=com.example.newapp');
  });

  testWidgets('the_by_id_row_needs_a_valid_id_that_is_not_known', (t) async {
    await pumpSheet(t);
    await search(t, 'newapp'); // not an app ID
    expect(inSheet(find.textContaining('Add app ID')), findsNothing);
    await search(t, 'com.netflix.ninja'); // already on the list
    expect(inSheet(find.textContaining('Add app ID')), findsNothing);
    await search(t, 'com.plexapp.android'); // in the catalogue
    expect(inSheet(find.textContaining('Add app ID')), findsNothing);
    expect(inSheet(find.text('Plex')), findsOneWidget);
    await search(t, ' com.example.other '); // trimmed
    expect(
      inSheet(find.text('Add app ID "com.example.other"')),
      findsOneWidget,
    );
  });

  testWidgets('no_match_says_so', (t) async {
    await pumpSheet(t);
    await search(t, 'zzzz');
    expect(
      inSheet(
        find.text(
          "No apps found. If you know the app's ID, type it to add it.",
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search_ranks_recent_apps_first_and_does_not_repeat_them', (
    t,
  ) async {
    await seenOn('com.example.plexity', 2);
    await pumpSheet(t);
    await search(t, 'plex');
    final recent = inSheet(find.text('Plexity'));
    final catalogue = inSheet(find.text('Plex'));
    expect(recent, findsOneWidget);
    expect(catalogue, findsOneWidget);
    expect(t.getTopLeft(recent).dy, lessThan(t.getTopLeft(catalogue).dy));
  });

  testWidgets('apps_already_added_are_disabled', (t) async {
    await pumpSheet(t);
    await search(t, 'netflix');
    expect(inSheet(find.text('Already on your list')), findsOneWidget);
    expect(
      inSheet(find.byIcon(Icons.check_circle_outline)),
      findsOneWidget,
    );
    final writes = repo.writes;
    await t.tap(inSheet(find.text('Netflix')));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(repo.writes, writes);
    expect(repo.apps.where((a) => a.package == _netflix.package), hasLength(1));
  });

  testWidgets('adding_an_app_appends_it_and_says_so', (t) async {
    await pumpSheet(t);
    await search(t, 'kodi');
    await tapRow(t, inSheet(find.text('Kodi')));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Kodi added'), findsOneWidget);
    expect(repo.apps.last.package, 'org.xbmc.kodi');
    expect(repo.apps.last.name, 'Kodi');
    expect(repo.apps, hasLength(7));
    // Edit apps behind the sheet shows it.
    expect(find.text('org.xbmc.kodi'), findsOneWidget);
  });

  testWidgets('a_suggested_app_can_be_added_without_searching', (t) async {
    await pumpSheet(t, list: const [_netflix]);
    await tapRow(t, inSheet(find.text('YouTube')));
    expect(repo.apps, [_netflix, _youtube]);
    expect(find.text('YouTube added'), findsOneWidget);
  });

  testWidgets('a_recent_unknown_app_is_added_with_the_generic_icon', (t) async {
    await seenOn('com.example.tvapp', 2);
    await pumpSheet(t);
    await tapRow(t, inSheet(find.text('Tvapp')));
    expect(repo.apps.last.name, 'Tvapp');
    expect(repo.apps.last.customIcon, 'app');
  });

  testWidgets('a_failed_add_says_so_and_keeps_the_sheet', (t) async {
    await pumpSheet(t);
    await search(t, 'kodi');
    repo.failNextWrite = StateError('disk full');
    await tapRow(t, inSheet(find.text('Kodi')));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      inSheet(find.text("Couldn't save your apps. Try again.")),
      findsOneWidget,
    );
    expect(repo.apps, hasLength(6));
    // Trying again works.
    await tapRow(t, inSheet(find.text('Kodi')));
    expect(find.byType(BottomSheet), findsNothing);
    expect(repo.apps.last.name, 'Kodi');
  });

  testWidgets('the_custom_row_opens_the_editor_once_the_sheet_is_closed', (
    t,
  ) async {
    await pumpSheet(t);
    await tapRow(t, inSheet(find.text('Create a custom shortcut')));
    expect(find.text('Add an app'), findsNothing);
    expect(find.text('New shortcut'), findsOneWidget);
  });

  testWidgets('a_broken_catalogue_leaves_the_rest_of_the_sheet_working', (
    t,
  ) async {
    await seenOn('com.example.tvapp', 1);
    await pumpSheet(
      t,
      list: const [],
      overrides: [
        catalogueProvider.overrideWith(
          (ref) async => throw const FormatException('corrupt'),
        ),
      ],
    );
    expect(t.takeException(), isNull);
    expect(find.text('Add an app'), findsOneWidget);
    expect(inSheet(find.text('Create a custom shortcut')), findsOneWidget);
    expect(
      inSheet(find.text('Apps you open on your TV show up here.')),
      findsOneWidget,
    );
    expect(inSheet(find.text('Suggested apps')), findsNothing);
    await search(t, 'com.example.newapp');
    expect(
      inSheet(find.text('Add app ID "com.example.newapp"')),
      findsOneWidget,
    );
    await search(t, 'zzz');
    expect(inSheet(find.textContaining('No apps found')), findsOneWidget);
  });

  testWidgets('the_search_field_is_not_focused_and_can_be_cleared', (t) async {
    await pumpSheet(t);
    final field = t.widget<TextField>(
      find.byKey(const ValueKey('add_app_search')),
    );
    expect(field.autofocus, isFalse);
    expect(find.byTooltip('Clear'), findsNothing);
    await search(t, 'kodi');
    await t.tap(find.byTooltip('Clear'));
    await t.pumpAndSettle();
    expect(inSheet(find.text('Create a custom shortcut')), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('add_sheet_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await seenOn('com.example.tvapp', 2);
      await pumpSheet(t, textScale: 2, brightness: b);
      expect(t.takeException(), isNull);
      await search(t, 'a');
      expect(t.takeException(), isNull);
      await search(t, 'netflix');
      expect(t.takeException(), isNull);
      await search(t, 'com.example.newapp');
      expect(t.takeException(), isNull);
      await search(t, 'zzzz');
      expect(t.takeException(), isNull);
      await search(t, '');
      expect(t.takeException(), isNull);
      expect(inSheet(find.text('Create a custom shortcut')), findsOneWidget);
    });
  }
}
