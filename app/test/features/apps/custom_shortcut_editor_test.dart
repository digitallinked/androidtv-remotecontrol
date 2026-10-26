import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/shortcut_style.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';

import '../../helpers/in_memory_shortcut_repository.dart';
import '../../helpers/pump_router_app.dart';

const _nameError = 'Enter a name of up to 30 characters.';
const _packageError = 'Enter an app ID like com.example.app.';
const _taken = 'This app is already on your list.';
const _failed = "Couldn't save your apps. Try again.";

final Finder _name = find.byKey(const ValueKey('shortcut_name'));
final Finder _package = find.byKey(const ValueKey('shortcut_package'));

void main() {
  late InMemoryShortcutRepository repo;

  setUp(() => repo = InMemoryShortcutRepository());

  Future<void> pumpEditor(
    WidgetTester t, {
    String? edit,
    List<AppEntry>? list,
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
      overrides: [shortcutRepositoryProvider.overrideWithValue(repo)],
    );
    if (edit != null) {
      await t.tap(find.byTooltip('Edit $edit'));
    } else {
      await t.tap(find.byTooltip('Add app'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create a custom shortcut'));
    }
    await t.pumpAndSettle();
  }

  Future<void> type(WidgetTester t, Finder field, String text) async {
    await t.enterText(field, text);
    await t.pumpAndSettle();
  }

  Future<void> save(WidgetTester t) async {
    final button = find.widgetWithText(FilledButton, 'Save');
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, String label) async {
    final choice = find.bySemanticsLabel(label);
    await t.ensureVisible(choice);
    await t.pumpAndSettle();
    await t.tap(choice);
    await t.pumpAndSettle();
  }

  AppIconSquare previewSquare(WidgetTester t) => t.widget<AppIconSquare>(
    find.descendant(
      of: find.byKey(const ValueKey('shortcut_preview')),
      matching: find.byType(AppIconSquare),
    ),
  );

  testWidgets('the_editor_has_every_field', (t) async {
    await pumpEditor(t);
    expect(find.text('New shortcut'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('App ID'), findsOneWidget);
    expect(
      find.text(
        "The app's ID on the TV. It's in the app's Play Store web address, "
        'after "id=".',
      ),
      findsOneWidget,
    );
    expect(find.text('Tile colour'), findsOneWidget);
    expect(find.text('Icon'), findsOneWidget);
    final package = t.widget<TextField>(_package);
    expect(package.keyboardType, TextInputType.url);
    expect(package.autocorrect, isFalse);
    expect(package.readOnly, isFalse);
    // The preview is 72 dp.
    expect(previewSquare(t).size, 72);
  });

  testWidgets('editor_validates_name_and_package', (t) async {
    await pumpEditor(t);
    // Nothing is flagged before the user tried.
    expect(find.text(_nameError), findsNothing);
    expect(find.text(_packageError), findsNothing);

    await save(t);
    expect(find.text(_nameError), findsOneWidget);
    expect(find.text(_packageError), findsOneWidget);
    expect(repo.apps, hasLength(6));

    await type(t, _name, 'a' * 31);
    expect(find.text(_nameError), findsOneWidget);
    await type(t, _name, 'a' * 30);
    expect(find.text(_nameError), findsNothing);
    await type(t, _name, '   ');
    expect(find.text(_nameError), findsOneWidget);

    await type(t, _package, 'example');
    expect(find.text(_packageError), findsOneWidget);
    await type(t, _package, 'com.example.zed');
    expect(find.text(_packageError), findsNothing);

    await type(t, _name, 'Zed');
    await save(t);
    expect(repo.apps.last.name, 'Zed');
  });

  testWidgets('the_name_is_counted_in_characters_and_trimmed', (t) async {
    await pumpEditor(t);
    await type(t, _package, 'com.example.zed');
    // 30 emoji are 30 characters, though 60 UTF-16 code units.
    await type(t, _name, '😀' * 30);
    expect(find.text(_nameError), findsNothing);
    await type(t, _name, '😀' * 31);
    expect(find.text(_nameError), findsOneWidget);
    await type(t, _name, '  Zed  ');
    await save(t);
    expect(repo.apps.last.name, 'Zed');
  });

  testWidgets('editor_rejects_a_package_already_on_the_list', (t) async {
    await pumpEditor(t);
    await type(t, _name, 'Films');
    await type(t, _package, 'com.netflix.ninja');
    expect(find.text(_taken), findsOneWidget);
    final writes = repo.writes;
    await save(t);
    expect(find.text('New shortcut'), findsOneWidget);
    expect(repo.writes, writes);
    expect(repo.apps, hasLength(6));
  });

  testWidgets('editor_saves_colour_and_icon', (t) async {
    final handle = t.ensureSemantics();
    await pumpEditor(t);
    await type(t, _name, 'Zed');
    await type(t, _package, 'com.example.zed');
    await choose(t, 'Teal');
    await choose(t, 'Sports');
    await save(t);
    expect(find.text('New shortcut'), findsNothing);
    expect(find.text('Zed added'), findsOneWidget);
    final saved = repo.apps.last;
    expect(saved.package, 'com.example.zed');
    expect(saved.name, 'Zed');
    expect(saved.isCustom, isTrue);
    expect(saved.customColor, kShortcutColors[2]);
    expect(saved.customIcon, 'sports');
    // New shortcuts take the default launch link.
    expect(saved.launchLink, 'market://launch?id=com.example.zed');
    handle.dispose();
  });

  testWidgets('a_new_shortcut_defaults_to_the_first_letter_and_no_colour', (
    t,
  ) async {
    await pumpEditor(t);
    await type(t, _name, 'Zed');
    await type(t, _package, 'com.example.zed');
    await save(t);
    expect(repo.apps.last.customColor, isNull);
    expect(repo.apps.last.customIcon, isNull);
    expect(repo.apps.last.isCustom, isTrue);
  });

  testWidgets('editing_keeps_the_package_and_custom_flag', (t) async {
    await pumpEditor(t, edit: 'Netflix');
    expect(find.text('Edit shortcut'), findsOneWidget);
    expect(t.widget<TextField>(_package).readOnly, isTrue);
    expect(t.widget<TextField>(_package).controller!.text, 'com.netflix.ninja');
    expect(find.text(_taken), findsNothing);
    await type(t, _name, 'Films');
    await save(t);
    expect(find.text('Edit shortcut'), findsNothing);
    expect(find.text('Shortcut saved'), findsOneWidget);
    final saved = repo.apps.first;
    expect(saved.package, 'com.netflix.ninja');
    expect(saved.name, 'Films');
    expect(saved.isCustom, isFalse);
    expect(saved.launchLink, 'market://launch?id=com.netflix.ninja');
    expect(repo.apps, hasLength(6));
  });

  testWidgets('editing_a_custom_shortcut_shows_and_keeps_its_style', (t) async {
    final handle = t.ensureSemantics();
    await pumpEditor(
      t,
      edit: 'Zed',
      list: [
        AppEntry(
          package: 'com.example.zed',
          name: 'Zed',
          isCustom: true,
          customColor: kShortcutColors[2],
          customIcon: 'sports',
          launchLink: 'https://example.com/zed',
        ),
      ],
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Teal')),
      isSemantics(isSelected: true),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Sports')),
      isSemantics(isSelected: true),
    );
    await type(t, _name, 'Zed 2');
    await save(t);
    final saved = repo.apps.single;
    expect(saved.name, 'Zed 2');
    expect(saved.isCustom, isTrue);
    expect(saved.customColor, kShortcutColors[2]);
    expect(saved.customIcon, 'sports');
    expect(saved.launchLink, 'https://example.com/zed');
    handle.dispose();
  });

  testWidgets('preview_updates_as_you_type', (t) async {
    await pumpEditor(t);
    final preview = find.byKey(const ValueKey('shortcut_preview'));
    expect(
      find.descendant(of: preview, matching: find.text('Z')),
      findsNothing,
    );
    await type(t, _name, 'zed');
    expect(
      find.descendant(of: preview, matching: find.text('Z')),
      findsOneWidget,
    );
    // The name is shown under it, as typed.
    expect(
      find.descendant(of: preview, matching: find.text('zed')),
      findsOneWidget,
    );
    expect(previewSquare(t).size, 72);
  });

  testWidgets('preview_follows_the_colour_and_icon', (t) async {
    final handle = t.ensureSemantics();
    await pumpEditor(t);
    await type(t, _name, 'zed');
    await choose(t, 'Purple');
    await choose(t, 'Music');
    final square = previewSquare(t);
    expect(square.app.customColor, kShortcutColors[7]);
    expect(square.app.customIcon, 'music');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shortcut_preview')),
        matching: find.byIcon(kShortcutIcons['music']!),
      ),
      findsOneWidget,
    );
    await choose(t, 'First letter');
    await choose(t, 'Default');
    expect(previewSquare(t).app.customColor, isNull);
    expect(previewSquare(t).app.customIcon, isNull);
    handle.dispose();
  });

  testWidgets('selection_is_shown_without_colour_alone', (t) async {
    final handle = t.ensureSemantics();
    await pumpEditor(t);
    Finder checkIn(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byIcon(Icons.check),
    );
    // Default colour is selected: a check, and the selected flag.
    expect(checkIn('shortcut_colour_default'), findsOneWidget);
    expect(checkIn('shortcut_colour_2'), findsNothing);
    expect(
      t.getSemantics(find.bySemanticsLabel('Default')),
      isSemantics(isSelected: true, isButton: true),
    );
    await choose(t, 'Teal');
    expect(checkIn('shortcut_colour_2'), findsOneWidget);
    expect(checkIn('shortcut_colour_default'), findsNothing);
    final teal = t.getSemantics(find.bySemanticsLabel('Teal'));
    expect(teal, isSemantics(isSelected: true, isButton: true));
    expect(
      t.getSemantics(find.bySemanticsLabel('Blue')),
      isSemantics(isSelected: false, isButton: true),
    );
    // Icons: the selected one shows a check badge too.
    Finder badge(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byIcon(Icons.check_circle),
    );
    expect(badge('shortcut_icon_letter'), findsOneWidget);
    await choose(t, 'Sports');
    expect(badge('shortcut_icon_sports'), findsOneWidget);
    expect(badge('shortcut_icon_letter'), findsNothing);
    expect(
      t.getSemantics(find.bySemanticsLabel('Sports')),
      isSemantics(isSelected: true, isButton: true),
    );
    handle.dispose();
  });

  testWidgets('every_choice_is_48dp_and_named', (t) async {
    final handle = t.ensureSemantics();
    await pumpEditor(t);
    const colours = [
      'Default',
      'Slate',
      'Blue',
      'Teal',
      'Green',
      'Amber',
      'Orange',
      'Red',
      'Purple',
    ];
    const icons = [
      'First letter',
      'App',
      'Movies',
      'Live TV',
      'Sports',
      'Music',
      'Kids',
      'News',
      'Games',
      'Learning',
    ];
    for (final label in [...colours, ...icons]) {
      final finder = find.bySemanticsLabel(label);
      expect(finder, findsOneWidget, reason: label);
      expect(t.getSize(finder), const Size.square(48), reason: label);
    }
    handle.dispose();
  });

  testWidgets('a_failed_save_says_so_and_the_editor_stays_open', (t) async {
    await pumpEditor(t);
    await type(t, _name, 'Zed');
    await type(t, _package, 'com.example.zed');
    repo.failNextWrite = StateError('disk full');
    await save(t);
    expect(find.text('New shortcut'), findsOneWidget);
    expect(find.text(_failed), findsOneWidget);
    expect(repo.apps, hasLength(6));
    // Again, and it works.
    await save(t);
    expect(find.text('New shortcut'), findsNothing);
    expect(repo.apps.last.name, 'Zed');
  });

  testWidgets('a_failed_edit_says_so_and_the_editor_stays_open', (t) async {
    await pumpEditor(t, edit: 'Netflix');
    await type(t, _name, 'Films');
    repo.failNextWrite = StateError('disk full');
    await save(t);
    expect(find.text('Edit shortcut'), findsOneWidget);
    expect(find.text(_failed), findsOneWidget);
    expect(repo.apps.first.name, 'Netflix');
  });

  for (final b in Brightness.values) {
    testWidgets('editor_fits_320dp_at_200_percent_text_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpEditor(t, textScale: 2, brightness: b);
      expect(t.takeException(), isNull);
      await type(t, _name, 'Long shortcut name wraps ok');
      await type(t, _package, 'example');
      expect(t.takeException(), isNull);
      await save(t);
      expect(t.takeException(), isNull);
      expect(find.text(_nameError), findsNothing);
      expect(find.text(_packageError), findsOneWidget);
      // The last choices can be reached by scrolling.
      await t.ensureVisible(
        find.byKey(const ValueKey('shortcut_icon_learning')),
      );
      expect(t.takeException(), isNull);
    });
  }
}
