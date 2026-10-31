import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/ads/tracking_preprompt.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_tracking_service.dart';
import '../../helpers/fit_checks.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/platform_override.dart';
import '../../helpers/pump_app.dart';

void main() {
  late SettingsStore store;
  late FakeTrackingService tracking;
  late List<Future<void>> calls;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    tracking = FakeTrackingService(current: TrackingStatus.notDetermined);
    calls = [];
  });

  /// A screen with one button that asks for the tracking decision.
  Future<void> pump(
    WidgetTester t, {
    TextScaler textScaler = TextScaler.noScaling,
    Brightness brightness = Brightness.light,
  }) => pumpApp(
    t,
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        trackingServiceProvider.overrideWithValue(tracking),
      ],
      child: Consumer(
        builder: (context, ref, _) => FilledButton(
          onPressed: () => calls.add(ensureTrackingDecided(context, ref)),
          child: const Text('Ask'),
        ),
      ),
    ),
    textScaler: textScaler,
    brightness: brightness,
  );

  Future<void> ask(WidgetTester t) async {
    await t.tap(find.text('Ask'));
    await t.pumpAndSettle();
  }

  testWidgetsOn(TargetPlatform.iOS, 'att_prompt_only_after_preprompt_accept', (
    t,
  ) async {
    await pump(t);
    await ask(t);

    expect(find.text('About ads in this app'), findsOneWidget);
    expect(find.byType(AppDialog<void>), findsOneWidget);
    expect(tracking.requests, 0);
    // The only way on is Continue: no "Not now".
    expect(
      find.descendant(
        of: find.byType(AppDialog<void>),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsNothing);

    // Tapping outside and the system Back button leave it open.
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(find.text('About ads in this app'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('About ads in this app'), findsOneWidget);
    expect(tracking.requests, 0);
    expect(store.trackingPrepromptShown, isFalse);

    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await calls.single;

    expect(find.text('About ads in this app'), findsNothing);
    expect(tracking.requests, 1);
    expect(store.trackingPrepromptShown, isTrue);
  });

  testWidgetsOn(TargetPlatform.iOS, 'preprompt_shown_at_most_once', (t) async {
    // The system question never appeared (iOS shows nothing while the app
    // isn't active), so the status is still "not determined". The stored
    // flag keeps the dialog away, and the system is asked again directly.
    tracking.answer = TrackingStatus.notDetermined;
    await pump(t);
    await ask(t);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(tracking.requests, 1);

    await ask(t);

    expect(find.text('About ads in this app'), findsNothing);
    expect(find.byType(AppDialog<void>), findsNothing);
    expect(tracking.requests, 2);
  });

  testWidgetsOn(
    TargetPlatform.iOS,
    'an_answered_question_is_never_asked_again',
    (t) async {
      tracking.answer = TrackingStatus.denied;
      await pump(t);
      await ask(t);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(tracking.requests, 1);

      await ask(t);

      expect(find.byType(AppDialog<void>), findsNothing);
      expect(tracking.requests, 1);
    },
  );

  testWidgetsOn(TargetPlatform.iOS, 'concurrent_calls_share_one_dialog', (
    t,
  ) async {
    await pump(t);
    await t.tap(find.text('Ask'));
    await t.tap(find.text('Ask'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.byType(AppDialog<void>), findsOneWidget);

    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await Future.wait(calls);

    expect(tracking.requests, 1);
  });

  testWidgetsOn(
    TargetPlatform.android,
    'no_preprompt_on_android_or_when_decided',
    (t) async {
      await pump(t);
      await ask(t);
      expect(find.byType(AppDialog<void>), findsNothing);
      expect(tracking.requests, 0);
      expect(store.trackingPrepromptShown, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      for (final status in [
        TrackingStatus.denied,
        TrackingStatus.authorized,
        TrackingStatus.restricted,
        TrackingStatus.notApplicable,
      ]) {
        tracking.current = status;
        await ask(t);
        expect(find.byType(AppDialog<void>), findsNothing, reason: '$status');
        expect(tracking.requests, 0, reason: '$status');
      }
      expect(store.trackingPrepromptShown, isFalse);
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'preprompt_fits_320dp_at_200_percent_text',
    (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final l10n = lookupAppLocalizations(const Locale('en'));
      // The linear 200% and Android 14's non-linear curve, light and dark.
      for (final scaler in [
        const TextScaler.linear(2),
        const NonlinearTwoXScaler(),
      ]) {
        for (final b in Brightness.values) {
          final reason = '$scaler ${b.name}';
          await store.setTrackingPrepromptShown(false);
          tracking.current = TrackingStatus.notDetermined;
          await pump(t, textScaler: scaler, brightness: b);
          await ask(t);

          expect(t.takeException(), isNull, reason: reason);
          // Narrow screens give the dialog 16 dp insets, not 40: the body
          // gets 288 dp, not 240, so it isn't a column of single words.
          final surface = find
              .descendant(
                of: find.byType(AppDialog<void>),
                matching: find.byType(Material),
              )
              .first;
          expect(t.getSize(surface).width, 288, reason: reason);
          // The title, the body and the dialog's one button (Continue: no
          // "Not now", see above) each lie inside the dialog's scroll area,
          // or can be scrolled through it, not just inside the screen.
          for (final (what, text) in [
            ('title', l10n.trackingPrepromptTitle),
            ('body', l10n.trackingPrepromptBody),
            ('button', l10n.trackingPrepromptContinue),
          ]) {
            await expectWithinViewport(
              t,
              find.text(text),
              reason: '$what $reason',
            );
          }
          final button = find.ancestor(
            of: find.text(l10n.trackingPrepromptContinue),
            matching: find.byType(FilledButton),
          );
          await expectWithinViewport(t, button, reason: 'Continue $reason');
          expect(button.hitTestable(), findsOneWidget, reason: reason);
          expect(t.getSize(button).height, greaterThanOrEqualTo(48));

          await t.tap(find.text(l10n.trackingPrepromptContinue));
          await t.pumpAndSettle();
          expect(find.byType(AppDialog<void>), findsNothing, reason: reason);
        }
      }
    },
  );
}
