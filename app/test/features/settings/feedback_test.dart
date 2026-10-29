import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/settings/application/feedback.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_link_opener.dart';
import '../../helpers/test_devices.dart';

const _info = AppInfo(
  appName: 'Remotely Dev',
  version: '1.0.0',
  buildNumber: '1',
  os: 'Android',
  osVersion: '12',
);

void main() {
  Future<void> pumpHub(
    WidgetTester t,
    RecordingLinkOpener opener, {
    List<SavedDevice> devices = const [],
    Override? appInfo,
    List<Override> more = const [],
  }) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settings,
      overrides: [
        linkOpenerProvider.overrideWithValue(opener),
        appInfo ?? appInfoProvider.overrideWith((ref) async => _info),
        savedDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        ...more,
      ],
    );
  }

  /// Opens the feedback dialog from the hub.
  Future<void> openFeedback(WidgetTester t) async {
    final row = find.text('Send feedback');
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

  testWidgets('feedback_mail_body_excludes_tv_name_and_ip', (t) async {
    final opener = RecordingLinkOpener();
    await pumpHub(
      t,
      opener,
      devices: [
        savedTv(
          nickname: 'Den',
          wolMac: 'AA:BB:CC:DD:EE:F0',
        ),
      ],
    );

    await openFeedback(t);
    await t.tap(find.text('Write email'));
    await t.pumpAndSettle();

    final mail = Uri.decodeFull(opener.opened.single.toString());
    for (final s in [
      'Living Room TV 3',
      'Den',
      '192.168.0.20',
      'AA:BB:CC:DD:EE:F0',
      'com.netflix.ninja',
    ]) {
      expect(mail, isNot(contains(s)), reason: s);
    }
    expect(
      RegExp(r'\b\d{1,3}(\.\d{1,3}){3}\b').hasMatch(mail),
      isFalse,
    );
    expect(mail, startsWith('mailto:${AppLinks.supportEmail}?'));
    expect(mail, contains('App: 1.0.0 (1)'));
    expect(mail, contains('System: Android 12'));
    expect(mail, contains('Feedback on Remotely Dev 1.0.0'));
    expect(mail, contains('Write your message here.'));
  });

  test('feedback_mail_encodes_spaces_as_percent_20', () {
    final uri = feedbackMailUri(
      info: _info,
      subject: 'Feedback on Remotely Dev 1.0.0',
      prompt: 'Write your message here.',
    );

    final text = uri.toString();
    expect(text, contains('%20'));
    expect(text, isNot(contains('+')));
    expect(text, contains('%0A'));
    expect(uri.scheme, 'mailto');
    expect(uri.path, AppLinks.supportEmail);
    expect(
      Uri.decodeComponent(text.split('body=').last),
      'Write your message here.\n\n\n---\nApp: 1.0.0 (1)\nSystem: Android 12',
    );
  });

  testWidgets('feedback_footer_names_the_os_release', (t) async {
    // The real app info, with the phone answering "Android 12": the footer
    // holds the release, not the kernel string.
    PackageInfo.setMockInitialValues(
      appName: 'Remotely Dev',
      packageName: 'app.remotely.dev',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final opener = RecordingLinkOpener();
    await pumpHub(
      t,
      opener,
      appInfo: appInfoProvider.overrideWith(appInfo),
      more: [
        osVersionReaderProvider.overrideWithValue(
          () async => (os: 'Android', version: '12'),
        ),
      ],
    );

    await openFeedback(t);
    await t.tap(find.text('Write email'));
    await t.pumpAndSettle();

    final mail = Uri.decodeFull(opener.opened.single.toString());
    expect(mail, contains('System: Android 12'));
    expect(mail, isNot(contains(Platform.operatingSystemVersion)));
  });

  testWidgets('feedback_cancel_opens_nothing', (t) async {
    final opener = RecordingLinkOpener();
    await pumpHub(t, opener);

    await openFeedback(t);
    expect(find.text('Send feedback?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    expect(find.text('Send feedback?'), findsNothing);
    expect(opener.opened, isEmpty);
  });

  testWidgets('no_email_app_shows_the_address', (t) async {
    final opener = RecordingLinkOpener()..result = false;
    await pumpHub(t, opener);

    await openFeedback(t);
    await t.tap(find.text('Write email'));
    await t.pumpAndSettle();

    expect(
      find.text('No email app found. Write to us at support@example.com.'),
      findsOneWidget,
    );
  });

  testWidgets('feedback_works_when_app_info_fails', (t) async {
    final opener = RecordingLinkOpener();
    await pumpHub(
      t,
      opener,
      appInfo: appInfoProvider.overrideWith(
        (ref) => throw StateError('no package info'),
      ),
    );

    await openFeedback(t);
    await t.tap(find.text('Write email'));
    await t.pumpAndSettle();

    final mail = Uri.decodeFull(opener.opened.single.toString());
    expect(mail, startsWith('mailto:'));
    expect(mail, contains('App: ? (?)'));
    expect(mail, contains('System: '));
  });

  testWidgets('the_fallback_subject_names_the_flavor_not_a_question_mark', (
    t,
  ) async {
    final opener = RecordingLinkOpener();
    await pumpHub(
      t,
      opener,
      appInfo: appInfoProvider.overrideWith(
        (ref) => throw StateError('no package info'),
      ),
    );

    await openFeedback(t);
    await t.tap(find.text('Write email'));
    await t.pumpAndSettle();

    final mail = Uri.decodeFull(opener.opened.single.toString());
    expect(mail, contains('subject=Feedback on Remotely Dev ?'));
  });

  test('feedback_mail_round_trips_awkward_text_through_the_query', () {
    const subject =
        'Q&A? #1 + 100% é 日本'
        '\nnext line';
    const prompt =
        'Tell us: a&b=c?d #e +f 50% é 日本'
        '\nsecond line';
    final text = feedbackMailUri(
      info: _info,
      subject: subject,
      prompt: prompt,
    ).toString();

    // Split the raw query by hand: `queryParameters` would turn a `+` into
    // a space, which is exactly what must not happen.
    final query = text.substring(text.indexOf('?') + 1);
    final parts = {
      for (final pair in query.split('&'))
        pair.substring(0, pair.indexOf('=')): Uri.decodeComponent(
          pair.substring(pair.indexOf('=') + 1),
        ),
    };
    expect(parts.keys, ['subject', 'body']);
    expect(parts['subject'], subject);
    expect(
      parts['body'],
      '$prompt\n\n\n---\nApp: 1.0.0 (1)\nSystem: Android 12',
    );

    // The raw text has no literal `+` (a `+` the user typed is `%2B`), no
    // raw newline, and spaces are `%20`.
    expect(text, isNot(contains('+')));
    expect(text, isNot(contains('\n')));
    expect(text, contains('%2B'));
    expect(text, contains('%20'));
    // Separators inside the values are escaped, so the query splits in two.
    expect(query.split('&'), hasLength(2));
    expect(query.split('#'), hasLength(1));
    expect(text.split('?'), hasLength(2));
  });
}
