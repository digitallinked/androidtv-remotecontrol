import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations_en.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/links/link_opener.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_link_opener.dart';

final _l10n = AppLocalizationsEn();

/// The eight questions and answers, in the order of the FAQ.
final List<(String, String)> _faq = [
  (_l10n.faqTvsQ, _l10n.faqTvsA),
  (_l10n.faqNotFoundQ, _l10n.faqNotFoundA),
  (_l10n.faqCodeQ, _l10n.faqCodeA),
  (_l10n.faqPowerQ, _l10n.faqPowerA),
  (_l10n.faqTypingQ, _l10n.faqTypingA),
  (_l10n.faqAppQ, _l10n.faqAppA),
  (_l10n.faqPrivacyQ, _l10n.faqPrivacyA),
  (_l10n.faqNewPhoneQ, _l10n.faqNewPhoneA),
];

const _info = AppInfo(
  appName: 'Remotely Dev',
  version: '1.0.0',
  buildNumber: '1',
  os: 'Android',
  osVersion: '12',
);

void main() {
  Future<void> pumpHelp(
    WidgetTester t, {
    RecordingLinkOpener? opener,
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
      initialLocation: AppRoutes.settingsHelp,
      textScale: textScale,
      brightness: brightness,
      overrides: [
        linkOpenerProvider.overrideWithValue(opener ?? RecordingLinkOpener()),
        appInfoProvider.overrideWith((ref) async => _info),
      ],
    );
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(
      target,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, String question) async {
    await reveal(t, find.text(question));
    await t.tap(find.text(question));
    await t.pumpAndSettle();
  }

  testWidgets('faq_opens_one_answer_at_a_time', (t) async {
    await pumpHelp(t);
    final (q1, a1) = _faq[0];
    final (q2, a2) = _faq[1];

    expect(find.text(a1), findsNothing);
    await open(t, q1);
    expect(find.text(a1), findsOneWidget);

    await open(t, q2);
    expect(find.text(a2), findsOneWidget);
    expect(find.text(a1), findsNothing);

    // Tapping the open question closes it.
    await t.tap(find.text(q2));
    await t.pumpAndSettle();
    expect(find.text(a2), findsNothing);
  });

  testWidgets('faq_answers_are_ours', (t) async {
    await pumpHelp(t);

    expect(
      find.byType(ExpansionTile, skipOffstage: false),
      findsNWidgets(_faq.length),
    );
    for (final (question, answer) in _faq) {
      await open(t, question);
      expect(find.text(answer), findsOneWidget, reason: question);
    }
  });

  testWidgets('faq_explains_a_new_phone', (t) async {
    await pumpHelp(t);
    const question = 'I moved to a new phone. Where are my TVs?';

    final titles = [
      for (final tile in t.widgetList<ExpansionTile>(
        find.byType(ExpansionTile, skipOffstage: false),
      ))
        (tile.title as Text).data,
    ];
    expect(
      titles.indexOf(question),
      titles.indexOf(_l10n.faqPrivacyQ) + 1,
      reason: 'the new-phone question follows the privacy question',
    );

    expect(find.text(_l10n.faqNewPhoneA), findsNothing);
    await open(t, question);
    expect(find.text(_l10n.faqNewPhoneA), findsOneWidget);
  });

  testWidgets('troubleshooting_button_opens_the_steps', (t) async {
    await pumpHelp(t);

    expect(find.text("Can't connect?"), findsOneWidget);
    await t.tap(find.text('Show troubleshooting steps'));
    await t.pumpAndSettle();

    expect(find.text("Can't find your TV?"), findsOneWidget);
  });

  testWidgets('help_feedback_button_starts_feedback', (t) async {
    final opener = RecordingLinkOpener();
    await pumpHelp(t, opener: opener);

    await reveal(t, find.text('Still stuck?'));
    await t.tap(find.widgetWithText(OutlinedButton, 'Send feedback'));
    await t.pumpAndSettle();
    expect(find.text('Send feedback?'), findsOneWidget);

    await t.tap(find.text('Write email'));
    await t.pumpAndSettle();
    expect(opener.opened.single.scheme, 'mailto');
  });

  testWidgets('faq_answers_use_body_large_in_primary_text_colour', (t) async {
    await pumpHelp(t);
    final (question, answer) = _faq.first;
    await open(t, question);

    final style = t.widget<Text>(find.text(answer)).style;
    final context = t.element(find.text(answer));
    expect(style?.fontSize, Theme.of(context).textTheme.bodyLarge?.fontSize);
    expect(style?.color, context.appColors.textPrimary);
  });

  for (final b in Brightness.values) {
    testWidgets('help_fits_320dp_at_200_percent_text_${b.name}', (t) async {
      await pumpHelp(
        t,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );

      for (final (question, answer) in _faq) {
        await open(t, question);
        expect(find.text(answer), findsOneWidget);
        expect(t.takeException(), isNull, reason: question);
      }
      await reveal(t, find.text('Still stuck?'));
      expect(
        find.widgetWithText(OutlinedButton, 'Send feedback'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
}
