import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/presentation/manage_apps_screen.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

import '../../helpers/in_memory_shortcut_repository.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_catalogue.dart';

/// The package of a row in the "*" default row, by its name.
String _packageOf(String name) => switch (name) {
  'Netflix' => 'com.netflix.ninja',
  'YouTube' => 'com.google.android.youtube.tv',
  _ => throw ArgumentError(name),
};

const _star = [
  'Netflix',
  'YouTube',
  'Prime Video',
  'Disney+',
  'Spotify',
  'Apple TV',
];

void main() {
  // Some tests pump the screen twice, each time on a fresh in-memory
  // database: two databases at once are intended here.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late InMemoryShortcutRepository repo;

  setUp(() => repo = InMemoryShortcutRepository());

  Future<void> pumpManage(
    WidgetTester t, {
    List<Override> overrides = const [],
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => pumpRouterApp(
    t,
    initialLocation: AppRoutes.manageApps,
    textScale: textScale,
    brightness: brightness,
    overrides: [
      shortcutRepositoryProvider.overrideWithValue(repo),
      ...overrides,
    ],
  );

  List<String> shown(WidgetTester t) => [
    for (final e in find.byType(AppIconSquare).evaluate())
      (e.widget as AppIconSquare).app.name,
  ];

  List<String> stored() => [for (final a in repo.apps) a.name];

  /// The labels of the custom semantic actions of the row that shows [name].
  List<String> actionsOf(WidgetTester t, String name) {
    final data = t.getSemantics(find.text(name)).getSemanticsData();
    return [
      for (final id in data.customSemanticsActionIds ?? const <int>[])
        CustomSemanticsAction.getAction(id)!.label!,
    ];
  }

  void perform(WidgetTester t, String name, String label) {
    final node = t.getSemantics(find.text(name));
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

  Future<void> drag(WidgetTester t, String name, Offset by) async {
    final handle = find.bySemanticsLabel('Reorder $name');
    final g = await t.startGesture(t.getCenter(handle));
    await t.pump(kLongPressTimeout);
    // In small steps: the list moves one place per drag update.
    const steps = 14;
    for (var i = 0; i < steps; i++) {
      await g.moveBy(by / steps.toDouble());
      await t.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    await t.pumpAndSettle();
  }

  testWidgets('lists_the_shortcuts_with_their_controls', (t) async {
    await pumpManage(t);
    expect(find.text('Edit apps'), findsOneWidget);
    expect(
      find.text(
        'Drag the handle to change the order. '
        'The remote shows your apps in this order.',
      ),
      findsOneWidget,
    );
    expect(shown(t), _star);
    expect(find.text('com.netflix.ninja'), findsOneWidget);
    expect(find.byTooltip('Edit Netflix'), findsOneWidget);
    expect(find.byTooltip('Remove Netflix'), findsOneWidget);
    expect(find.byTooltip('Add app'), findsOneWidget);
    // Rows are at least 56 dp high and every control is at least 48 dp.
    final row = find.ancestor(
      of: find.text('Netflix'),
      matching: find.byType(ConstrainedBox),
    );
    expect(t.getSize(row.first).height, greaterThanOrEqualTo(56));
    for (final tooltip in ['Edit Netflix', 'Remove Netflix', 'Add app']) {
      final size = t.getSize(find.byTooltip(tooltip));
      expect(size.shortestSide, greaterThanOrEqualTo(48), reason: tooltip);
    }
  });

  testWidgets('reorder_persists', (t) async {
    final handle = t.ensureSemantics();
    await pumpManage(t);
    await drag(t, 'Prime Video', const Offset(0, -140)); // two rows up
    expect(stored().take(3), ['Prime Video', 'Netflix', 'YouTube']);
    expect(stored(), hasLength(6));
    expect(shown(t).take(3), ['Prime Video', 'Netflix', 'YouTube']);
    handle.dispose();
  });

  testWidgets('move_up_semantic_action_reorders', (t) async {
    final handle = t.ensureSemantics();
    await pumpManage(t);
    perform(t, 'Disney+', 'Move up');
    await t.pumpAndSettle();
    expect(stored(), [
      'Netflix',
      'YouTube',
      'Disney+',
      'Prime Video',
      'Spotify',
      'Apple TV',
    ]);
    expect(shown(t), stored());
    perform(t, 'Netflix', 'Move down');
    await t.pumpAndSettle();
    expect(stored().take(3), ['YouTube', 'Netflix', 'Disney+']);
    handle.dispose();
  });

  testWidgets('first_row_has_no_move_up_and_last_has_no_move_down', (t) async {
    final handle = t.ensureSemantics();
    await pumpManage(t);
    expect(actionsOf(t, 'Netflix'), contains('Move down'));
    expect(actionsOf(t, 'Netflix'), isNot(contains('Move up')));
    expect(actionsOf(t, 'Apple TV'), contains('Move up'));
    expect(actionsOf(t, 'Apple TV'), isNot(contains('Move down')));
    expect(actionsOf(t, 'Spotify'), containsAll(['Move up', 'Move down']));
    handle.dispose();
  });

  testWidgets('each_row_exposes_move_up_and_down_exactly_once', (t) async {
    final handle = t.ensureSemantics();
    await pumpManage(t);
    // Count the actions over the whole semantics tree: five rows can move up
    // and five can move down, so a second source of them would show here.
    final counts = <String, int>{};
    void visit(SemanticsNode node) {
      for (final id
          in node.getSemanticsData().customSemanticsActionIds ??
              const <int>[]) {
        final label = CustomSemanticsAction.getAction(id)!.label!;
        counts[label] = (counts[label] ?? 0) + 1;
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(
      t.getSemantics(find.byType(Scaffold).first).owner!.rootSemanticsNode!,
    );
    expect(counts['Move up'], 5);
    expect(counts['Move down'], 5);
    // And the node that has them is the one that carries the row's name.
    for (final name in _star) {
      final node = t.getSemantics(find.text(name));
      expect(node.label, contains(name));
      expect(
        node.getSemanticsData().customSemanticsActionIds,
        isNotEmpty,
        reason: name,
      );
    }
    handle.dispose();
  });

  testWidgets('the_handle_is_labelled_and_48dp', (t) async {
    final handle = t.ensureSemantics();
    await pumpManage(t);
    final handleFinder = find.bySemanticsLabel('Reorder YouTube');
    expect(handleFinder, findsOneWidget);
    expect(t.getSize(handleFinder), const Size.square(48));
    handle.dispose();
  });

  testWidgets('remove_then_undo_restores_the_order', (t) async {
    await pumpManage(t);
    await t.tap(find.byTooltip('Remove YouTube'));
    await t.pumpAndSettle();
    expect(find.text('YouTube removed'), findsOneWidget);
    expect(stored(), isNot(contains('YouTube')));
    expect(shown(t), isNot(contains('YouTube')));
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(stored(), _star);
    expect(shown(t), _star);
  });

  testWidgets('undo_puts_the_app_back_without_losing_later_changes', (
    t,
  ) async {
    await pumpManage(t);
    await t.tap(find.byTooltip('Remove YouTube'));
    await t.pumpAndSettle();
    // Something else changes the list while the snackbar is up.
    await repo.add(const AppEntry(package: 'org.xbmc.kodi', name: 'Kodi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(stored(), [
      'Netflix',
      'YouTube',
      'Prime Video',
      'Disney+',
      'Spotify',
      'Apple TV',
      'Kodi',
    ]);
  });

  testWidgets('undo_still_works_after_leaving_the_screen', (t) async {
    await pumpManage(t);
    await t.tap(find.byTooltip('Remove Spotify'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ManageAppsScreen), findsNothing);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(stored(), _star);
  });

  testWidgets('undo_after_leaving_keeps_changes_made_since', (t) async {
    await pumpManage(t);
    await t.tap(find.byTooltip('Remove Spotify'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ManageAppsScreen), findsNothing);
    // The list is edited elsewhere (another visit to Edit apps, say).
    await repo.add(const AppEntry(package: 'org.xbmc.kodi', name: 'Kodi'));
    await repo.remove('com.netflix.ninja');
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(stored(), [
      'YouTube',
      'Prime Video',
      'Disney+',
      'Apple TV',
      'Spotify', // its old index, in the list as it is now
      'Kodi',
    ]);
  });

  testWidgets('undo_works_when_nothing_else_listens_to_the_list', (t) async {
    // Settings → Edit apps: nothing else on screen watches the shortcuts, so
    // after leaving, Undo reads them with no listener.
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      overrides: [shortcutRepositoryProvider.overrideWithValue(repo)],
    );
    await t.tap(find.text('Apps'));
    await t.pumpAndSettle();
    expect(find.byType(ManageAppsScreen), findsOneWidget);
    await t.tap(find.byTooltip('Remove Spotify'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(ManageAppsScreen), findsNothing);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(stored(), _star);
    expect(find.text("Couldn't save your apps. Try again."), findsNothing);
  });

  testWidgets('removing_twice_offers_undo_for_the_last_removal', (t) async {
    await pumpManage(t);
    await t.tap(find.byTooltip('Remove Netflix'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Remove YouTube'));
    await t.pumpAndSettle();
    expect(find.text('YouTube removed'), findsOneWidget);
    expect(find.text('Netflix removed'), findsNothing);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(stored(), [
      'YouTube',
      'Prime Video',
      'Disney+',
      'Spotify',
      'Apple TV',
    ]);
  });

  testWidgets('reset_restores_region_defaults', (t) async {
    repo = InMemoryShortcutRepository(const [
      AppEntry(package: 'org.xbmc.kodi', name: 'Kodi'),
    ]);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.manageApps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [shortcutRepositoryProvider.overrideWithValue(repo)],
    );
    expect(shown(t), ['Kodi']);

    Future<void> openReset() async {
      await t.tap(find.byType(PopupMenuButton<void>));
      await t.pumpAndSettle();
      await t.tap(find.text('Reset to suggested apps'));
      await t.pumpAndSettle();
    }

    await openReset();
    expect(find.text('Reset your apps?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(stored(), ['Kodi']);

    await openReset();
    await t.tap(find.widgetWithText(TextButton, 'Reset'));
    await t.pumpAndSettle();
    expect(stored(), _star);
    expect(shown(t), _star);
  });

  testWidgets('reset_uses_the_phones_region', (t) async {
    repo = InMemoryShortcutRepository(const [
      AppEntry(package: 'org.xbmc.kodi', name: 'Kodi'),
    ]);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.manageApps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [
        shortcutRepositoryProvider.overrideWithValue(repo),
        deviceRegionProvider.overrideWithValue('MY'),
      ],
    );
    await t.tap(find.byType(PopupMenuButton<void>));
    await t.pumpAndSettle();
    await t.tap(find.text('Reset to suggested apps'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Reset'));
    await t.pumpAndSettle();
    expect(stored(), [
      for (final p in testCatalogue().defaultRows['MY']!)
        testCatalogue().byPackage(p)!.name,
    ]);
  });

  testWidgets('a_failed_write_says_so_and_resyncs', (t) async {
    await pumpManage(t);
    repo.failNextWrite = StateError('disk full');
    await t.tap(find.byTooltip('Remove YouTube'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't save your apps. Try again."), findsOneWidget);
    expect(find.text('YouTube removed'), findsNothing);
    // The list matches what is stored.
    expect(stored(), _star);
    expect(shown(t), _star);
  });

  testWidgets('a_failed_reorder_goes_back_to_the_stored_order', (t) async {
    final handle = t.ensureSemantics();
    await pumpManage(t);
    repo.failNextWrite = StateError('disk full');
    perform(t, 'Disney+', 'Move up');
    await t.pumpAndSettle();
    expect(find.text("Couldn't save your apps. Try again."), findsOneWidget);
    expect(stored(), _star);
    expect(shown(t), _star);
    handle.dispose();
  });

  testWidgets('an_empty_list_says_so', (t) async {
    repo = InMemoryShortcutRepository();
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.manageApps,
      prepareSettings: (store) => store.setShortcutsSeeded(true),
      overrides: [shortcutRepositoryProvider.overrideWithValue(repo)],
    );
    expect(
      find.text('No apps on your list. Add one to see it on the remote.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Add app'), findsOneWidget);
  });

  testWidgets('the_add_and_edit_buttons_open_their_sheets', (t) async {
    await pumpManage(t);
    await t.tap(find.byTooltip('Add app'));
    await t.pumpAndSettle();
    expect(find.text('Add an app'), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Edit Netflix'));
    await t.pumpAndSettle();
    expect(find.text('Edit shortcut'), findsOneWidget);
  });

  /// The name, the controls and the row of [name], as on screen.
  ({Rect name, Rect row, List<Rect> controls}) rowOf(
    WidgetTester t,
    String name,
  ) => (
    name: t.getRect(find.text(name)),
    row: t.getRect(
      find
          .ancestor(of: find.text(name), matching: find.byType(ConstrainedBox))
          .first,
    ),
    controls: [
      t.getRect(find.byTooltip('Edit $name')),
      t.getRect(find.byTooltip('Remove $name')),
      t.getRect(
        find.descendant(
          of: find.byKey(ValueKey('manage_app_${_packageOf(name)}')),
          matching: find.byType(ReorderableDragStartListener),
        ),
      ),
    ],
  );

  testWidgets('edit_apps_rows_stack_at_200_percent_text_on_320dp', (t) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final b in Brightness.values) {
      await pumpManage(t, textScale: 2, brightness: b);
      expect(t.takeException(), isNull);
      final r = rowOf(t, 'Netflix');
      final nameColumn = t.getSize(
        find
            .ancestor(of: find.text('Netflix'), matching: find.byType(Column))
            .first,
      );
      expect(nameColumn.width, greaterThanOrEqualTo(160));
      for (final c in r.controls) {
        expect(c.top, greaterThan(r.name.bottom));
        expect(c.shortestSide, greaterThanOrEqualTo(48));
        expect(c.bottom, lessThanOrEqualTo(r.row.bottom));
      }
      // Aligned to the end, in the order edit, remove, drag handle.
      expect(r.controls[0].right, lessThanOrEqualTo(r.controls[1].left));
      expect(r.controls[1].right, lessThanOrEqualTo(r.controls[2].left));
      expect(r.controls[2].right, greaterThan(r.row.right - 16));
      expect(r.row.height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('edit_apps_rows_stack_under_a_non_linear_text_scaler', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.manageApps,
      textScaler: const NonlinearTwoXScaler(),
      overrides: [shortcutRepositoryProvider.overrideWithValue(repo)],
    );
    expect(t.takeException(), isNull);
    final r = rowOf(t, 'Netflix');
    for (final c in r.controls) {
      expect(c.top, greaterThan(r.name.bottom));
    }
  });

  testWidgets('edit_apps_rows_stay_on_one_line_at_100_percent', (t) async {
    for (final width in [390.0, 320.0]) {
      t.view
        ..physicalSize = Size(width, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpManage(t);
      final r = rowOf(t, 'Netflix');
      for (final c in r.controls) {
        // On the name's line: the controls overlap it vertically.
        expect(c.top, lessThan(r.name.bottom), reason: '$width');
        expect(c.left, greaterThanOrEqualTo(r.name.right), reason: '$width');
      }
      expect(r.row.height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('stacked_rows_keep_the_move_actions', (t) async {
    // Tall enough to show the first rows under the 200% hint.
    t.view
      ..physicalSize = const Size(320, 1200)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final handle = t.ensureSemantics();
    await pumpManage(t, textScale: 2);
    // Stacked: the controls are under the name.
    expect(
      t.getRect(find.byTooltip('Edit Netflix')).top,
      greaterThan(t.getRect(find.text('Netflix')).bottom),
    );
    expect(actionsOf(t, 'Netflix'), contains('Move down'));
    expect(actionsOf(t, 'Netflix'), isNot(contains('Move up')));
    expect(actionsOf(t, 'YouTube'), containsAll(['Move up', 'Move down']));
    final node = t.getSemantics(find.text('Netflix'));
    expect(node.label, contains('Netflix'));
    expect(node.label, contains('com.netflix.ninja'));
    expect(find.bySemanticsLabel('Reorder Netflix'), findsOneWidget);
    expect(find.byTooltip('Edit Netflix'), findsOneWidget);
    expect(find.byTooltip('Remove Netflix'), findsOneWidget);
    perform(t, 'YouTube', 'Move up');
    await t.pumpAndSettle();
    expect(stored().take(2), ['YouTube', 'Netflix']);
    handle.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('manage_apps_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpManage(t, textScale: 2, brightness: b);
      expect(t.takeException(), isNull);
      expect(find.text('Netflix'), findsOneWidget);
      // Scroll to the last row: nothing throws.
      await t.dragUntilVisible(
        find.text('Apple TV'),
        find.byType(ReorderableListView),
        const Offset(0, -200),
      );
      expect(t.takeException(), isNull);
      // The controls keep their size.
      expect(
        t.getSize(find.byTooltip('Remove Apple TV')).shortestSide,
        greaterThanOrEqualTo(48),
      );
    });
  }
}
