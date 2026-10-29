import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../helpers/failing_preferences.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/platform_override.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_analytics_sink.dart';
import '../../helpers/recording_crash_reporter.dart';
import '../../helpers/test_devices.dart';

const String _connectTitle = 'Find your TV';
const String _connectBody =
    'Your phone finds your Android TV on the same Wi-Fi network. Pair once '
    'with the code your TV shows.';
const String _connectNote =
    'The app only looks on your Wi-Fi network. It never asks for your '
    'location.';
const String _controlTitle = 'Control it from your phone';
const String _controlBody =
    'Swipe the touchpad or use the D-pad, change the volume and type with '
    "your phone's keyboard.";
const String _appsTitle = 'Open apps in one tap';
const String _appsBody =
    'Keep your favourite TV apps in a row on the remote and open them '
    'without searching.';
const String _explainerTitle = 'Allow local network access';

/// The texts that carry each card's meaning, in card order.
const List<List<String>> _cardTexts = [
  [_connectTitle, _connectBody, _connectNote],
  [_controlTitle, _controlBody],
  [_appsTitle, _appsBody],
];

/// The button whose label is [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  late RecordingAnalyticsSink sink;
  late RecordingCrashReporter crashes;

  setUp(() {
    sink = RecordingAnalyticsSink();
    crashes = RecordingCrashReporter();
  });

  List<Override> overrides() => [
    analyticsSinkProvider.overrideWithValue(sink),
    analyticsDebugBuildProvider.overrideWithValue(true),
    crashReporterProvider.overrideWithValue(crashes),
  ];

  Future<SettingsStore> pump(
    WidgetTester t, {
    Brightness brightness = Brightness.light,
    TextScaler? textScaler,
    List<Override> extra = const [],
  }) async => pumpRouterApp(
    t,
    initialLocation: AppRoutes.onboarding,
    brightness: brightness,
    textScaler: textScaler,
    // Analytics is allowed, and a bad event throws as in a debug build.
    prepareSettings: (store) async {
      await store.setConsentRegion(ConsentRegion.notRequired);
    },
    overrides: [...overrides(), ...extra],
  );

  Future<void> next(WidgetTester t) async {
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
  }

  Future<void> toLastCard(WidgetTester t) async {
    await next(t);
    await next(t);
  }

  /// After "Try demo": the remote opens, then outlasts the demo's 600 ms
  /// connect delay.
  Future<void> settleDemo(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  testWidgets('onboarding_shows_three_cards_in_order', (t) async {
    final handle = t.ensureSemantics();
    try {
      await pump(t);
      expect(find.text(_connectTitle), findsOneWidget);
      expect(find.bySemanticsLabel('Card 1 of 3'), findsOneWidget);
      expect(
        t.getSemantics(find.text(_connectTitle)),
        isSemantics(isHeader: true),
      );
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Try demo'), findsOneWidget);

      await next(t);
      expect(find.text(_controlTitle), findsOneWidget);
      expect(find.text(_connectTitle), findsNothing);
      expect(find.bySemanticsLabel('Card 2 of 3'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await next(t);
      expect(find.text(_appsTitle), findsOneWidget);
      expect(find.bySemanticsLabel('Card 3 of 3'), findsOneWidget);
      expect(
        t.getSemantics(find.text(_appsTitle)),
        isSemantics(isHeader: true),
      );
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Try demo'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('swiping_pages_and_back_returns_a_card', (t) async {
    await pump(t);
    await t.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await t.pumpAndSettle();
    expect(find.text(_controlTitle), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text(_connectTitle), findsOneWidget);
    expect(find.text(_controlTitle), findsNothing);
  });

  testWidgets('onboarding_shown_once', (t) async {
    final store = await pump(t);
    expect(store.onboardingComplete, isFalse);
    await toLastCard(t);
    await t.tap(find.text('Get started'));
    await t.pumpAndSettle();

    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(store.onboardingComplete, isTrue);
    // Written through, not only cached: a store opened afresh sees it.
    expect((await SettingsStore.open()).onboardingComplete, isTrue);
    expect(
      await resolveInitialLocation(
        settings: store,
        devices: InMemoryDeviceRepository(),
      ),
      AppRoutes.discover,
    );
    expect(
      await resolveInitialLocation(
        settings: store,
        devices: InMemoryDeviceRepository([savedTv()]),
      ),
      AppRoutes.remote,
    );
  });

  testWidgets('skip_goes_to_discover', (t) async {
    final store = await pump(t);
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();

    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(store.onboardingComplete, isTrue);
  });

  testWidgets('try_demo_opens_the_demo_remote', (t) async {
    final store = await pump(t);
    await next(t);
    await t.tap(find.text('Try demo'));
    await settleDemo(t);

    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(containerOf(t).read(activeTargetProvider), isA<DemoTarget>());
    expect(store.onboardingComplete, isTrue);
  });

  testWidgets('onboarding_complete_logged_by_every_exit', (t) async {
    final exits = <String, Future<void> Function()>{
      'skip': () async {
        await t.tap(find.text('Skip'));
        await t.pumpAndSettle();
      },
      'get started': () async {
        await toLastCard(t);
        await t.tap(find.text('Get started'));
        await t.pumpAndSettle();
      },
      'try demo': () async {
        await t.tap(find.text('Try demo'));
        await settleDemo(t);
      },
    };
    for (final e in exits.entries) {
      sink
        ..events.clear()
        ..calls.clear();
      await pump(t);
      expect(sink.eventNames, isEmpty, reason: e.key);
      await e.value();
      expect(sink.eventNames, ['onboarding_complete'], reason: e.key);
      expect(sink.events.single.params, isEmpty, reason: e.key);
    }
  });

  testWidgets('get_started_still_navigates_when_the_write_fails', (t) async {
    // The store holds on to the preferences it opened on, so it opens on
    // ones that start failing once the screen is up.
    final prefs = FailingSharedPreferencesAsync(failing: false);
    SharedPreferencesAsyncPlatform.instance = prefs;
    final store = await SettingsStore.open();
    await store.setConsentRegion(ConsentRegion.notRequired);
    await pump(t, extra: [settingsStoreProvider.overrideWithValue(store)]);
    prefs.failing = true;

    await toLastCard(t);
    await t.tap(find.text('Get started'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.byType(DiscoveryScreen), findsOneWidget);
    final error = crashes.errors.single;
    expect(error.reason, 'onboarding write');
    expect(error.fatal, isFalse);
    expect(error.error, isA<StateError>());
    expect(sink.eventNames, ['onboarding_complete']);
  });

  testWidgets('a_double_tap_finishes_once', (t) async {
    await pump(t);
    await toLastCard(t);
    await t.tap(find.text('Get started'));
    await t.tap(find.text('Get started'));
    await t.pumpAndSettle();

    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(sink.eventNames, ['onboarding_complete']);
    expect(
      sink.screens.where((s) => s == AppRouteNames.discover),
      hasLength(1),
    );
  });

  testWidgets('connect_card_says_no_location_is_needed', (t) async {
    await pump(t);
    expect(find.text(_connectNote), findsOneWidget);
  });

  /// Checks the explainer is up, alone, and can't be left without its one
  /// action; nothing was written, logged or opened yet.
  Future<void> expectExplainerHolds(WidgetTester t, SettingsStore store) async {
    expect(find.text(_explainerTitle), findsOneWidget);
    final buttons = find.descendant(
      of: find.byType(AppDialog<void>),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons, findsOneWidget);
    expect(
      find.descendant(of: buttons, matching: find.text('Continue')),
      findsOneWidget,
    );

    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(find.text(_explainerTitle), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text(_explainerTitle), findsOneWidget);

    expect(find.byType(DiscoveryScreen), findsNothing);
    expect(store.onboardingComplete, isFalse);
    expect(sink.eventNames, isEmpty);
  }

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_get_started_explains_local_network_before_discovery',
    (t) async {
      final store = await pump(t);
      await toLastCard(t);
      await t.tap(find.text('Get started'));
      await t.pumpAndSettle();
      await expectExplainerHolds(t, store);

      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(find.text(_explainerTitle), findsNothing);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(store.onboardingComplete, isTrue);
      expect(sink.eventNames, ['onboarding_complete']);
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_skip_explains_local_network_before_discovery',
    (t) async {
      final store = await pump(t);
      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();
      await expectExplainerHolds(t, store);

      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(store.onboardingComplete, isTrue);
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'ios_try_demo_shows_no_permission_dialog',
    (t) async {
      await pump(t);
      await t.tap(find.text('Try demo'));
      await t.pump();
      expect(find.text(_explainerTitle), findsNothing);
      await settleDemo(t);
      expect(find.text(_explainerTitle), findsNothing);
      expect(find.byType(AppDialog<void>), findsNothing);
      expect(find.byType(RemoteScreen), findsOneWidget);
    },
  );

  testWidgets('android_shows_no_permission_dialog', (t) async {
    expect(defaultTargetPlatform, TargetPlatform.android);
    await pump(t);
    await toLastCard(t);
    await t.tap(find.text('Get started'));
    await t.pump();
    expect(find.byType(AppDialog<void>), findsNothing);
    await t.pumpAndSettle();
    expect(find.byType(AppDialog<void>), findsNothing);
    expect(find.text(_explainerTitle), findsNothing);
    expect(find.byType(DiscoveryScreen), findsOneWidget);
  });

  testWidgets('reduce_motion_jumps_between_cards', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(t);

    await t.tap(find.text('Next'));
    await t.pump();
    expect(find.text(_controlTitle), findsOneWidget);
    expect(find.text(_connectTitle), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  /// Walks the three cards on a 320 dp screen with [textScaler]: nothing
  /// throws, every text that carries meaning can be brought fully onto the
  /// screen, and the buttons are at least 48 dp and can be tapped.
  Future<void> expectFits(
    WidgetTester t, {
    required TextScaler textScaler,
    required Brightness brightness,
  }) async {
    const size = Size(320, 640);
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pump(t, brightness: brightness, textScaler: textScaler);

    for (var card = 0; card < _cardTexts.length; card++) {
      final last = card == _cardTexts.length - 1;
      final reason = 'card ${card + 1} ${brightness.name}';
      expect(t.takeException(), isNull, reason: reason);
      for (final text in _cardTexts[card]) {
        final finder = find.text(text);
        await t.ensureVisible(finder);
        await t.pumpAndSettle();
        final scrollable = Scrollable.of(t.element(finder));
        final viewport = t.getRect(find.byWidget(scrollable.widget));
        final rect = t.getRect(finder);
        final why = '$reason "$text" at $rect in $viewport';
        expect(
          viewport.left >= 0 &&
              viewport.right <= size.width &&
              viewport.top >= 0 &&
              viewport.bottom <= size.height,
          isTrue,
          reason: why,
        );
        expect(
          rect.left >= viewport.left && rect.right <= viewport.right,
          isTrue,
          reason: why,
        );
        if (rect.height <= viewport.height) {
          expect(
            rect.top >= viewport.top && rect.bottom <= viewport.bottom,
            isTrue,
            reason: why,
          );
          continue;
        }
        // A paragraph taller than the card's viewport scrolls: its first and
        // its last line can each be brought into view.
        final position = scrollable.position..jumpTo(0);
        await t.pump();
        expect(t.getRect(finder).top, greaterThanOrEqualTo(viewport.top));
        position.jumpTo(position.maxScrollExtent);
        await t.pump();
        expect(
          t.getRect(finder).bottom,
          lessThanOrEqualTo(viewport.bottom),
          reason: why,
        );
        position.jumpTo(0);
        await t.pump();
      }
      final labels = [
        if (!last) ...['Skip', 'Next'] else 'Get started',
        'Try demo',
      ];
      for (final label in labels) {
        final button = _button(label);
        expect(button.hitTestable(), findsOneWidget, reason: '$reason $label');
        final box = t.getSize(button);
        expect(box.height, greaterThanOrEqualTo(48), reason: '$reason $label');
        expect(box.width, greaterThanOrEqualTo(48), reason: '$reason $label');
        final rect = t.getRect(button);
        expect(
          rect.left >= 0 && rect.right <= size.width && rect.bottom <= 640,
          isTrue,
          reason: '$reason $label at $rect',
        );
      }
      if (!last) await next(t);
    }
    expect(t.takeException(), isNull);
  }

  for (final b in Brightness.values) {
    testWidgets('onboarding_fits_320dp_at_200_percent_text_${b.name}', (
      t,
    ) async {
      await expectFits(
        t,
        textScaler: const TextScaler.linear(2),
        brightness: b,
      );
    });
  }

  testWidgets('onboarding_fits_a_non_linear_text_scaler', (t) async {
    for (final b in Brightness.values) {
      await expectFits(
        t,
        textScaler: const NonlinearTwoXScaler(),
        brightness: b,
      );
    }
  });

  testWidgets('onboarding_meets_tap_target_and_contrast_guidelines', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    try {
      for (final b in Brightness.values) {
        await pump(t, brightness: b);
        for (var card = 0; card < 3; card++) {
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          if (card < 2) await next(t);
        }
      }
    } finally {
      handle.dispose();
    }
  });
}
