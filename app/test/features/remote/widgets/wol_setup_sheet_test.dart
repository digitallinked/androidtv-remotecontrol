import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/features/remote/presentation/widgets/wol_setup_sheet.dart';

void main() {
  late List<String> saved;
  late Future<void> Function(String mac) onSave;
  String? result;
  var closed = false;

  setUp(() {
    saved = [];
    result = null;
    closed = false;
    onSave = (mac) async => saved.add(mac);
  });

  Future<void> openSheet(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: brightness),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showWolSetupSheet(
                  context,
                  tvName: 'Living Room TV',
                  onSave: (mac) => onSave(mac),
                );
                closed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
  }

  Future<void> save(WidgetTester t, String text) async {
    await t.enterText(find.byType(TextField), text);
    await t.tap(find.text('Save and turn on'));
    await t.pumpAndSettle();
  }

  testWidgets('the_sheet_explains_where_to_find_the_mac', (t) async {
    await openSheet(t);
    expect(find.text('Turn on Living Room TV from your phone'), findsOneWidget);
    expect(find.textContaining('Settings → System → About'), findsOneWidget);
    expect(find.textContaining('not the Bluetooth one'), findsOneWidget);
    expect(find.textContaining("can't be woken"), findsOneWidget);
    expect(find.text('MAC address'), findsOneWidget);
  });

  testWidgets('the_field_is_set_up_for_a_mac', (t) async {
    await openSheet(t);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.visiblePassword);
    expect(field.textCapitalization, TextCapitalization.characters);
    expect(field.autocorrect, isFalse);
    expect(field.decoration!.hintText, 'AA:BB:CC:DD:EE:FF');
  });

  testWidgets('the_field_keeps_only_mac_characters_up_to_17', (t) async {
    await openSheet(t);
    await t.enterText(find.byType(TextField), 'zq-aa:bb?');
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      '-aa:bb',
    );
    await t.enterText(find.byType(TextField), 'AA:BB:CC:DD:EE:FF');
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'AA:BB:CC:DD:EE:FF',
    );
    // One more character is refused: the field keeps what it had.
    await t.enterText(find.byType(TextField), 'AA:BB:CC:DD:EE:FF0');
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text.length,
      lessThanOrEqualTo(17),
    );
  });

  testWidgets('an_invalid_address_shows_an_error_and_saves_nothing', (t) async {
    await openSheet(t);
    await save(t, 'aa:bb');
    expect(
      find.text('Enter 6 pairs of letters or digits, like AA:BB:CC:DD:EE:FF'),
      findsOneWidget,
    );
    expect(saved, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    // Typing again takes the complaint away.
    await t.enterText(find.byType(TextField), 'aa:bb:');
    await t.pump();
    expect(find.textContaining('Enter 6 pairs'), findsNothing);
  });

  testWidgets('a_multicast_address_is_refused', (t) async {
    await openSheet(t);
    await save(t, '01:00:5E:00:00:01');
    expect(find.textContaining('Enter 6 pairs'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('a_valid_address_is_saved_normalised_and_the_sheet_closes', (
    t,
  ) async {
    await openSheet(t);
    await save(t, ' aa-bb-cc-dd-ee-f0 ');
    expect(saved, ['AA:BB:CC:DD:EE:F0']);
    expect(find.byType(TextField), findsNothing);
    expect(closed, isTrue);
    expect(result, 'AA:BB:CC:DD:EE:F0');
  });

  testWidgets('save_failure_keeps_the_sheet_open_with_an_error', (t) async {
    onSave = (_) => Future<void>.error(Exception('disk full'));
    await openSheet(t);
    await save(t, 'aa:bb:cc:dd:ee:f0');
    expect(
      find.text("Couldn't save the MAC address. Try again."),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(closed, isFalse);
    // The text is kept and a second try can work.
    onSave = (mac) async => saved.add(mac);
    await t.tap(find.text('Save and turn on'));
    await t.pumpAndSettle();
    expect(saved, ['AA:BB:CC:DD:EE:F0']);
    expect(result, 'AA:BB:CC:DD:EE:F0');
  });

  testWidgets('the_button_waits_while_saving', (t) async {
    final gate = Completer<void>();
    onSave = (mac) {
      saved.add(mac);
      return gate.future;
    };
    await openSheet(t);
    await t.enterText(find.byType(TextField), 'aa:bb:cc:dd:ee:f0');
    await t.tap(find.text('Save and turn on'));
    await t.pump();
    await t.tap(find.text('Save and turn on'), warnIfMissed: false);
    await t.pump();
    expect(saved, hasLength(1));
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    gate.complete();
    await t.pumpAndSettle();
    expect(result, 'AA:BB:CC:DD:EE:F0');
  });

  testWidgets('the_keyboard_done_key_saves', (t) async {
    await openSheet(t);
    await t.enterText(find.byType(TextField), 'aabbccddeef0');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(saved, ['AA:BB:CC:DD:EE:F0']);
  });

  testWidgets('closing_the_sheet_returns_null_and_saves_nothing', (t) async {
    await openSheet(t);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
    expect(saved, isEmpty);
  });

  testWidgets('wol_sheet_fits_320dp_at_200_percent_text', (t) async {
    for (final brightness in Brightness.values) {
      await openSheet(
        t,
        size: const Size(320, 568),
        textScale: 2,
        brightness: brightness,
      );
      expect(t.takeException(), isNull, reason: '$brightness');
      // An error under the field makes it taller; it must still fit.
      await t.enterText(find.byType(TextField), 'aa');
      await t.ensureVisible(find.text('Save and turn on'));
      await t.tap(find.text('Save and turn on'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$brightness with an error');
      expect(find.textContaining('Enter 6 pairs'), findsOneWidget);
      expect(
        t.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      // The sheet scrolls; the button can be brought into view.
      await t.ensureVisible(find.text('Save and turn on'));
      final screen = t.view.physicalSize / t.view.devicePixelRatio;
      expect(
        t.getRect(find.byType(FilledButton)).bottom,
        lessThanOrEqualTo(screen.height),
      );
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
    }
  });
}
