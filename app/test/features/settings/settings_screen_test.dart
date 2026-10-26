import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';

import '../../helpers/pump_router_app.dart';

void main() {
  /// Pumps the hub on a phone-sized view.
  Future<void> pumpHub(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      textScale: textScale,
      brightness: brightness,
    );
  }

  Finder appBarTitle(String title) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(title));

  /// Scrolls to the top, then down until [target] is on screen.
  Future<void> reveal(WidgetTester t, Finder target) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      target,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  testWidgets('hub_lists_every_section_and_opens_its_page', (t) async {
    await pumpHub(t);

    for (final header in const [
      'Remote',
      'App',
      'Help and feedback',
      'About',
    ]) {
      await reveal(t, find.text(header));
      expect(find.text(header), findsOneWidget, reason: header);
    }

    const rows = [
      ('Remote layout', 'Remote layout'),
      ('Remote behaviour', 'Remote behaviour'),
      ('Apps', 'Edit apps'),
      ('Your TVs', 'Your TVs'),
      ('Appearance', 'Appearance'),
      ('Help', 'Help'),
      ('About this app', 'About this app'),
    ];
    for (final (row, title) in rows) {
      await reveal(t, find.text(row));
      await t.tap(find.text(row));
      await t.pumpAndSettle();
      expect(appBarTitle(title), findsOneWidget, reason: row);

      await t.pageBack();
      await t.pumpAndSettle();
      expect(appBarTitle('Settings'), findsOneWidget, reason: '$row back');
    }
  });

  testWidgets('hub_has_one_banner_slot_and_no_fab', (t) async {
    await pumpHub(t);

    expect(find.byKey(const ValueKey('banner_slot_settings')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('hub_scroll_ends_with_banner_clearance', (t) async {
    await pumpHub(t, size: const Size(390, 500));
    await reveal(t, find.text('Terms of use'));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await t.pumpAndSettle();

    final terms = t.getRect(find.text('Terms of use'));
    final bottom = t.getRect(find.byType(Scaffold).first).bottom;
    expect(bottom - terms.bottom, greaterThanOrEqualTo(48));
  });

  testWidgets('external_rows_say_they_open_the_browser', (t) async {
    final handle = t.ensureSemantics();
    await pumpHub(t);

    for (final title in const ['Privacy policy', 'Terms of use']) {
      await reveal(t, find.text(title));
      expect(
        t.getSemantics(find.text(title)).hint,
        contains('Opens in your browser'),
        reason: title,
      );
    }
    expect(
      t.getSemantics(find.text('About this app')).hint,
      isNot(contains('Opens in your browser')),
    );
    handle.dispose();
  });

  testWidgets('link_rows_say_the_page_could_not_open_until_they_are_wired', (
    t,
  ) async {
    await pumpHub(t);
    await reveal(t, find.text('Privacy policy'));

    await t.tap(find.text('Privacy policy'));
    await t.pump();

    expect(find.textContaining("Couldn't open the page"), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('settings_hub_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      await pumpHub(
        t,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );

      for (var i = 0; i < 14; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump();
      }
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('Terms of use'), findsOneWidget);
    });
  }
}
