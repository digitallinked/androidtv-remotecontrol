import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/ads/tracking_preprompt.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_tracking_service.dart';
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
    double textScale = 1,
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
    textScale: textScale,
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
    // The user left the system prompt undecided, so the status is still
    // "not determined": only the stored flag keeps the dialog away.
    tracking.answer = TrackingStatus.notDetermined;
    await pump(t);
    await ask(t);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(tracking.requests, 1);

    await ask(t);

    expect(find.text('About ads in this app'), findsNothing);
    expect(tracking.requests, 1);
  });

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

  for (final b in Brightness.values) {
    testWidgetsOn(TargetPlatform.iOS, 'preprompt_fits_320dp_${b.name}', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pump(t, textScale: 2, brightness: b);
      await ask(t);

      expect(t.takeException(), isNull);
      expect(find.text('About ads in this app'), findsOneWidget);
      // Continue is reachable at this size.
      await t.ensureVisible(find.text('Continue'));
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      final button = t.getRect(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.height, greaterThanOrEqualTo(48));
    });
  }
}
