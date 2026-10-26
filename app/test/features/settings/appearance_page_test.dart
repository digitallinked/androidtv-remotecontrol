import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/dynamic_color_support.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

import '../../helpers/pump_router_app.dart';

void main() {
  Future<SettingsStore> pumpAppearance(
    WidgetTester t, {
    bool dynamicSupported = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    Future<void> Function(SettingsStore store)? prepare,
  }) {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    return pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsAppearance,
      textScale: textScale,
      brightness: brightness,
      prepareSettings: prepare,
      overrides: [
        dynamicColorSupportedProvider.overrideWith(
          (ref) async => dynamicSupported,
        ),
      ],
    );
  }

  testWidgets('dynamic_colour_switch_shows_only_when_supported', (t) async {
    await pumpAppearance(t);
    expect(find.text('Colours from wallpaper'), findsNothing);

    final store = await pumpAppearance(t, dynamicSupported: true);
    expect(find.text('Colours from wallpaper'), findsOneWidget);
    expect(store.dynamicColor, isFalse);

    await t.tap(find.text('Colours from wallpaper'));
    await t.pumpAndSettle();

    expect(store.dynamicColor, isTrue);
    expect(
      t
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Colours from wallpaper'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('language_choices_come_from_supported_locales', (t) async {
    final store = await pumpAppearance(
      t,
      prepare: (s) => s.setLocaleCode('en'),
    );

    final language = find.byType(RadioListTile<String?>);
    expect(language, findsNWidgets(2));
    expect(
      find.descendant(of: language, matching: find.text('Same as phone')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: language, matching: find.text('English')),
      findsOneWidget,
    );
    expect(
      t
          .widget<RadioGroup<String?>>(find.byType(RadioGroup<String?>))
          .groupValue,
      'en',
    );

    await t.tap(
      find.descendant(of: language, matching: find.text('Same as phone')),
    );
    await t.pumpAndSettle();
    expect(store.localeCode, isNull);

    await t.tap(find.descendant(of: language, matching: find.text('English')));
    await t.pumpAndSettle();
    expect(store.localeCode, 'en');
  });

  testWidgets('stored_theme_is_selected', (t) async {
    await pumpAppearance(
      t,
      prepare: (s) => s.setThemePreference(ThemePreference.dark),
    );

    final group = t.widget<RadioGroup<ThemePreference>>(
      find.byType(RadioGroup<ThemePreference>),
    );
    expect(group.groupValue, ThemePreference.dark);
    for (final label in const ['Same as phone', 'Light', 'Dark']) {
      expect(
        find.descendant(
          of: find.byType(RadioListTile<ThemePreference>),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testWidgets('choosing_a_theme_writes_the_store', (t) async {
    final store = await pumpAppearance(t);

    await t.tap(find.text('Light'));
    await t.pumpAndSettle();

    expect(store.themePreference, ThemePreference.light);
  });

  for (final b in Brightness.values) {
    testWidgets('appearance_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      await pumpAppearance(
        t,
        dynamicSupported: true,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );
      for (var i = 0; i < 14; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump();
      }

      expect(t.takeException(), isNull);
      expect(find.text('Language'), findsOneWidget);
    });
  }
}
