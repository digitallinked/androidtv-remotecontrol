import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/links/link_opener.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_link_opener.dart';

void main() {
  Future<void> pumpHub(WidgetTester t, RecordingLinkOpener opener) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      overrides: [linkOpenerProvider.overrideWithValue(opener)],
    );
  }

  Future<void> tapRow(WidgetTester t, String title) async {
    final row = find.text(title);
    await t.scrollUntilVisible(
      row,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(row);
    await t.pumpAndSettle();
    await t.tap(row);
    await t.pumpAndSettle();
  }

  testWidgets('privacy_and_terms_open_in_the_browser', (t) async {
    final opener = RecordingLinkOpener();
    await pumpHub(t, opener);

    await tapRow(t, 'Privacy policy');
    await tapRow(t, 'Terms of use');

    expect(opener.opened, [AppLinks.privacyPolicy, AppLinks.terms]);
    expect(find.textContaining("Couldn't open the page"), findsNothing);
  });

  testWidgets('a_link_that_fails_to_open_says_so', (t) async {
    final opener = RecordingLinkOpener()..result = false;
    await pumpHub(t, opener);

    await tapRow(t, 'Privacy policy');

    expect(opener.opened, [AppLinks.privacyPolicy]);
    expect(find.textContaining("Couldn't open the page"), findsOneWidget);
  });

  test('links_are_https_and_the_email_is_valid', () {
    for (final uri in [AppLinks.privacyPolicy, AppLinks.terms]) {
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    }
    expect(
      AppLinks.supportEmail,
      matches(RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')),
    );
  });
}
