import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/error_log.dart';
import 'package:tv_remote/features/settings/presentation/error_log_page.dart';

import '../../helpers/a11y.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/pump_router_app.dart';

/// A log that can show entries at once, and keeps them in memory.
Future<ErrorLog> _log(WidgetTester t, {int entries = 0}) async {
  final log = ErrorLog()
    ..bind(
      namesKnown: Future<void>.value(),
      scrubber: CrashScrubber.new,
      file: () async => null,
    );
  addTearDown(log.dispose);
  await t.pump();
  for (var i = 1; i <= entries; i++) {
    await withClock(
      Clock.fixed(DateTime.utc(2026, 11, 5, 9, i)),
      () => log.recordError(
        StateError('failure $i'),
        StackTrace.fromString('#0 frame$i\n#1 next$i'),
        fatal: i == 2,
        reason: 'reason $i',
      ),
    );
  }
  return log;
}

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpPage(
    WidgetTester t,
    ErrorLog log, {
    double textScale = 1,
    TextScaler? textScaler,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
  }) => pumpRouterApp(
    t,
    initialLocation: AppRoutes.settingsErrorLog,
    textScale: textScale,
    textScaler: textScaler,
    brightness: brightness,
    locale: locale,
    overrides: [errorLogProvider.overrideWithValue(log)],
  );

  /// Records what is put on the clipboard.
  List<String> captureClipboard(WidgetTester t) {
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  testWidgets('the_empty_state_says_so_and_offers_nothing_to_do', (t) async {
    await pumpPage(t, await _log(t));

    expect(find.text(strings.pageTitleErrorLog), findsOneWidget);
    expect(find.text('No errors recorded.'), findsOneWidget);
    expect(find.text(strings.errorLogNote), findsOneWidget);
    expect(find.text('Copy all'), findsNothing);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('the_list_is_newest_first_with_time_reason_and_message', (
    t,
  ) async {
    await pumpPage(t, await _log(t, entries: 3));

    expect(find.text('No errors recorded.'), findsNothing);
    final newest = t.getTopLeft(find.text('reason 3'));
    final oldest = t.getTopLeft(find.text('reason 1'));
    expect(newest.dy, lessThan(oldest.dy));
    expect(find.textContaining('StateError: Bad state: failure 2'), findsOne);
    expect(find.textContaining('Serious'), findsOneWidget, reason: 'fatal');
    // The time shows in local time, with the date.
    final local = DateTime.utc(2026, 11, 5, 9, 3).toLocal();
    final material = MaterialLocalizations.of(
      t.element(find.byType(ErrorLogPage)),
    );
    expect(
      find.textContaining(material.formatShortDate(local)),
      findsNWidgets(3),
    );
  });

  testWidgets('tapping_an_entry_shows_its_stack_lines', (t) async {
    await pumpPage(t, await _log(t, entries: 1));
    expect(find.text('#0 frame1'), findsNothing);

    await t.tap(find.text('reason 1'));
    await t.pumpAndSettle();

    expect(find.text('#0 frame1'), findsOneWidget);
    expect(find.text('#1 next1'), findsOneWidget);
  });

  testWidgets('copy_all_copies_a_plain_text_log_and_confirms', (t) async {
    final copied = captureClipboard(t);
    await pumpPage(t, await _log(t, entries: 2));

    await t.tap(find.text('Copy all'));
    await t.pump();
    await t.pump();

    final text = copied.single;
    // The feedback footer's header: test_app_config's 1.0.0 (1), Android 12.
    expect(text, startsWith('App: 1.0.0 (1)\nSystem: Android 12\n'));
    expect(text, contains('2026-11-05T09:02:00.000Z  fatal  reason 2'));
    expect(text, contains('2026-11-05T09:01:00.000Z  reason 1'));
    expect(text, contains('StateError: Bad state: failure 1'));
    expect(text, contains('  #0 frame1\n'));
    expect(
      text.indexOf('reason 2'),
      lessThan(text.indexOf('reason 1')),
      reason: 'newest first',
    );
    expect(find.text('Error log copied'), findsOneWidget);
  });

  testWidgets('a_failed_copy_says_so', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard');
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(t, await _log(t, entries: 1));

    await t.tap(find.text('Copy all'));
    await t.pump();
    await t.pump();

    expect(find.text("Couldn't copy the log. Try again."), findsOneWidget);
    expect(find.text('Error log copied'), findsNothing);
  });

  testWidgets('clear_asks_first_and_cancel_keeps_everything', (t) async {
    final log = await _log(t, entries: 2);
    await pumpPage(t, log);

    await t.tap(find.text('Clear'));
    await t.pumpAndSettle();
    expect(find.byType(AppDialog<bool>), findsOneWidget);
    expect(find.text(strings.errorLogClearTitle), findsOneWidget);

    await t.tap(find.text(strings.commonCancel));
    await t.pumpAndSettle();
    expect(log.entries, hasLength(2));
    expect(find.text('reason 2'), findsOneWidget);
  });

  testWidgets('clear_empties_the_log_and_the_list', (t) async {
    final log = await _log(t, entries: 2);
    await pumpPage(t, log);

    await t.tap(find.text('Clear'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AppDialog<bool>),
        matching: find.text('Clear'),
      ),
    );
    await t.pumpAndSettle();

    expect(log.entries, isEmpty);
    expect(find.text('No errors recorded.'), findsOneWidget);
  });

  testWidgets('a_new_error_shows_while_the_page_is_open', (t) async {
    final log = await _log(t);
    await pumpPage(t, log);

    await log.recordError(StateError('fresh'), null, reason: 'fresh reason');
    await t.pumpAndSettle();

    expect(find.text('fresh reason'), findsOneWidget);
  });

  testWidgets('an_entry_with_no_reason_has_a_plain_heading', (t) async {
    final log = await _log(t);
    await log.recordError(StateError('x'), null);
    await pumpPage(t, log);

    expect(find.text(strings.errorLogNoReason), findsOneWidget);
  });

  testWidgets('help_opens_the_error_log', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsHelp,
      overrides: [errorLogProvider.overrideWithValue(await _log(t))],
    );

    await t.scrollUntilVisible(
      find.text(strings.pageTitleErrorLog),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text(strings.pageTitleErrorLog));
    await t.pumpAndSettle();

    expect(find.byType(ErrorLogPage), findsOneWidget);
  });

  testWidgets('the_page_has_no_ad_banner', (t) async {
    await pumpPage(t, await _log(t, entries: 1));

    expect(find.byType(BannerSlot), findsNothing);
  });

  for (final b in Brightness.values) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets(
        'fits_320dp_at_200_percent_${locale.languageCode}_${b.name}',
        (t) async {
          t.view
            ..physicalSize = const Size(320, 640)
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await pumpPage(
            t,
            await _log(t, entries: 3),
            textScale: 2,
            brightness: b,
            locale: locale,
          );
          expect(t.takeException(), isNull);
          // The Malay note is longer: the first entry is below the fold.
          await t.scrollUntilVisible(
            find.text('reason 3'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await t.tap(find.text('reason 3'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        },
      );
    }

    testWidgets('fits_a_non_linear_text_scaler_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpPage(
        t,
        await _log(t, entries: 3),
        textScaler: const NonlinearTwoXScaler(),
        brightness: b,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('meets_the_guidelines_${b.name}', (t) async {
      final handle = t.ensureSemantics();
      await pumpPage(t, await _log(t, entries: 2), brightness: b);
      await expectMeetsGuidelines(t, reason: 'error log');
      handle.dispose();
    });

    testWidgets('the_empty_page_meets_the_guidelines_${b.name}', (t) async {
      final handle = t.ensureSemantics();
      await pumpPage(t, await _log(t), brightness: b);
      await expectMeetsGuidelines(t, reason: 'error log');
      handle.dispose();
    });
  }

  testWidgets('reduce_motion_opens_an_entry_in_one_frame', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsErrorLog,
      disableAnimations: true,
      overrides: [
        errorLogProvider.overrideWithValue(await _log(t, entries: 1)),
      ],
    );

    await t.tap(find.text('reason 1'));
    await t.pump();

    expect(t.hasRunningAnimations, isFalse);
    expect(find.text('#0 frame1'), findsOneWidget);
  });
}
