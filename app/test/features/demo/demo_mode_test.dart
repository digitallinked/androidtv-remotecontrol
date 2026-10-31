import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/demo/demo_providers.dart';
import 'package:tv_remote/features/demo/demo_remote_session.dart';
import 'package:tv_remote/features/demo/presentation/demo_badge.dart';
import 'package:tv_remote/features/demo/presentation/tv_preview_card.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/a11y.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';

/// The saved TVs, without a database stream (its cleanup timer would
/// outlive the test).
final Override _noSavedTvs = savedDevicesProvider.overrideWith(
  (ref) => Stream.value(const []),
);

/// After tapping "Try demo": the first pump opens the remote screen, which
/// builds the demo session; the second outlasts its 600 ms connect delay.
Future<void> _connectDemo(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await t.pumpAndSettle();
}

/// A navigator key whose `currentContext` can be replaced by [context].
class _FlakyNavigatorKey extends LabeledGlobalKey<NavigatorState> {
  _FlakyNavigatorKey() : super('flaky');

  /// Holds the context returned instead of the navigator's own, while set.
  final ValueNotifier<BuildContext?> context = ValueNotifier(null);

  @override
  BuildContext? get currentContext => context.value ?? super.currentContext;
}

/// The live-region nodes outside the status pill (which announces the
/// connection, Phase 4).
List<SemanticsNode> _liveRegions(WidgetTester t) => [
  for (final n in allSemanticsNodes(t))
    if (n.getSemanticsData().flagsCollection.isLiveRegion &&
        !n.label.startsWith('Connection'))
      n,
];

/// How many nodes a screen reader can tap to leave the demo.
int _leaveActions(WidgetTester t) => allSemanticsNodes(t)
    .where(
      (n) =>
          n.label == 'Leave' &&
          n.getSemanticsData().hasAction(SemanticsAction.tap),
    )
    .length;

void main() {
  late ProviderContainer container;

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  GoRouter routerOf(WidgetTester t) => containerOf(t).read(appRouterProvider);

  Future<void> tryDemo(WidgetTester t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.onboarding,
      overrides: [_noSavedTvs],
    );
    container = containerOf(t);
    await t.tap(find.text('Try demo'));
    await _connectDemo(t);
  }

  testWidgets('demo_mode_shows_pressed_keys_in_preview', (t) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);
    expect(find.text('TV preview'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Demo TV'), findsOneWidget);
    expect(
      find.text('Press a button to see what the TV would do.'),
      findsOneWidget,
    );
    expect(find.textContaining('Screen on'), findsOneWidget);
    expect(find.textContaining('Volume 8 of 20'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(find.text('Pressed Home'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Volume up'));
    await t.pump();
    expect(find.textContaining('Volume 9 of 20'), findsOneWidget);
    expect(find.text('Pressed Volume up'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Mute'));
    await t.pump();
    // The preview card and the volume rocker both say so.
    expect(
      find.descendant(
        of: find.byType(TvPreviewCard),
        matching: find.text('Muted'),
      ),
      findsOneWidget,
    );
    expect(find.text('Muted'), findsNWidgets(2));
    expect(find.textContaining('Volume 9 of 20'), findsNothing);
    handle.dispose();
  });

  testWidgets('preview_shows_holding_and_released', (t) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);

    final hold = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Volume up')),
    );
    await t.pump(kHoldThreshold + const Duration(milliseconds: 50));
    expect(find.text('Holding Volume up'), findsOneWidget);

    await hold.up();
    await t.pump();
    expect(find.text('Released Volume up'), findsOneWidget);
    expect(find.text('Holding Volume up'), findsNothing);
    handle.dispose();
  });

  testWidgets('preview_shows_opened_app', (t) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);

    await t.tap(find.bySemanticsLabel('Open Netflix'));
    await t.pump();

    expect(
      find.text('Opened market://launch?id=com.netflix.ninja'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('preview_shows_typed_text', (t) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);

    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'hi');
    await t.pump(const Duration(milliseconds: 150));

    expect(find.text('Typed "hi"'), findsOneWidget);
    handle.dispose();
    // The sheet's own flush on close needs the demo still connected.
    await t.pumpAndSettle();
  });

  testWidgets('preview_shows_screen_off_after_power', (t) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);
    expect(find.textContaining('Screen on'), findsOneWidget);

    final hold = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Power')),
    );
    await t.pump(PowerButton.holdDuration + const Duration(milliseconds: 50));
    await hold.up();
    await t.pump();

    expect(find.textContaining('Screen off'), findsOneWidget);
    expect(find.text('Pressed Power'), findsOneWidget);
    handle.dispose();
    await t.pumpAndSettle();
  });

  testWidgets('demo_search_from_the_sheet_keeps_one_sheet', (t) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);

    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    expect(find.text('Type on your TV'), findsOneWidget);

    await t.tap(find.text('Open search on TV'));
    await t.pumpAndSettle();

    // The demo TV asked for the keyboard (ImeShowRequested), but it is open.
    expect(find.text('Type on your TV'), findsOneWidget);
    expect(find.text('Pressed Search'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('demo_search_from_the_remote_opens_the_keyboard_by_itself', (
    t,
  ) async {
    await tryDemo(t);
    expect(find.text('Type on your TV'), findsNothing);

    // The demo TV opens its search box: the remote's keyboard follows by
    // itself (Ruling P4-R12), as it does for a real TV's text field.
    (container.read(remoteSessionProvider).value! as DemoRemoteSession).sendKey(
      KeyCodes.search,
    );
    await t.pumpAndSettle();

    expect(find.text('Type on your TV'), findsOneWidget);
    expect(find.text('Pressed Search'), findsOneWidget);
  });

  testWidgets('try_demo_completes_onboarding_and_targets_the_demo_tv', (
    t,
  ) async {
    final store = await pumpRouterApp(
      t,
      initialLocation: AppRoutes.onboarding,
      overrides: [_noSavedTvs],
    );
    container = containerOf(t);
    expect(store.onboardingComplete, isFalse);
    await t.tap(find.text('Try demo'));
    await _connectDemo(t);

    expect(container.read(settingsControllerProvider).onboardingComplete, true);
    expect(container.read(activeTargetProvider), const DemoTarget());
    expect(routerOf(t).state.uri.path, AppRoutes.remote);
  });

  testWidgets('demo_badge_visible_everywhere', (t) async {
    await tryDemo(t);
    for (final route in [
      AppRoutes.remote,
      AppRoutes.apps,
      AppRoutes.settings,
      AppRoutes.devices,
      AppRoutes.discover,
    ]) {
      routerOf(t).go(route);
      await t.pumpAndSettle();
      expect(find.text('Demo mode'), findsOneWidget, reason: route);
    }
  });

  testWidgets('the_badge_strip_sits_above_the_screen_and_is_48dp_high', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await tryDemo(t);

    final strip = t.getRect(find.byType(DemoBadgeOverlay));
    final appBar = t.getRect(find.byType(AppBar));
    final label = t.getRect(find.text('Demo mode'));
    expect(label.top, greaterThanOrEqualTo(strip.top));
    expect(
      t.getSize(find.widgetWithText(TextButton, 'Leave')).height,
      greaterThanOrEqualTo(48),
    );
    // The screen starts below the strip: nothing is covered.
    expect(appBar.top, greaterThanOrEqualTo(label.bottom));
    // Both are in the semantics tree: the page route's barrier must not
    // hide the strip.
    expect(find.bySemanticsLabel('Demo mode'), findsOneWidget);
    expect(find.bySemanticsLabel('Leave'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('demo_strip_leave_is_inert_while_a_sheet_is_open', (t) async {
    final handle = t.ensureSemantics();
    try {
      await tryDemo(t);
      final leave = find.widgetWithText(TextButton, 'Leave');
      expect(_leaveActions(t), 1);

      await t.tap(find.bySemanticsLabel('Keyboard'));
      await t.pumpAndSettle();
      expect(find.text('Type on your TV'), findsOneWidget);

      // The strip sits above the navigator, outside the sheet's barrier.
      await t.tap(leave, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text('Leave demo?'), findsNothing);
      expect(find.text('Type on your TV'), findsOneWidget);
      expect(_leaveActions(t), 0);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Type on your TV'), findsNothing);
      expect(_leaveActions(t), 1);

      await t.tap(leave);
      await t.pumpAndSettle();
      expect(find.text('Leave demo?'), findsOneWidget);
      // The dialog is a modal too: Leave can't stack a second one.
      expect(_leaveActions(t), 0);
      await t.tap(find.text('Stay'));
      await t.pumpAndSettle();
      expect(_leaveActions(t), 1);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('only_the_last_action_line_is_a_live_region', (t) async {
    final handle = t.ensureSemantics();
    try {
      await tryDemo(t);
      await t.tap(find.bySemanticsLabel('Home'));
      await t.pump();

      final live = _liveRegions(t);
      expect(live, hasLength(1), reason: '${live.map((n) => n.label)}');
      expect(live.single.label, 'Pressed Home');
      // The card's title and its status line are read, but not announced.
      expect(find.bySemanticsLabel(RegExp('^TV preview')), findsOneWidget);
      expect(
        _liveRegions(t).any((n) => n.label.contains('TV preview')),
        isFalse,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('leave_demo_returns_to_discover_and_hides_badge', (t) async {
    await tryDemo(t);
    await t.tap(find.text('Leave'));
    await t.pumpAndSettle();
    expect(find.text('Leave demo?'), findsOneWidget);
    expect(find.text("You'll go back to the list of TVs."), findsOneWidget);

    await t.tap(find.text('Leave demo'));
    await t.pumpAndSettle();

    expect(find.text('Choose your TV'), findsOneWidget);
    expect(find.text('Demo mode'), findsNothing);
    expect(container.read(activeTargetProvider), isNull);
  });

  testWidgets('stay_keeps_demo', (t) async {
    await tryDemo(t);
    await t.tap(find.text('Leave'));
    await t.pumpAndSettle();

    await t.tap(find.text('Stay'));
    await t.pumpAndSettle();

    expect(find.text('Leave demo?'), findsNothing);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('TV preview'), findsOneWidget);
    expect(container.read(activeTargetProvider), const DemoTarget());
  });

  testWidgets('leave_stays_usable_after_the_dialog_fails_to_open', (t) async {
    final navigatorKey = _FlakyNavigatorKey();
    await pumpRouterApp(
      t,
      initialLocation: '/',
      overrides: [
        isDemoActiveProvider.overrideWithValue(true),
        appRouterProvider.overrideWith(
          (ref) => GoRouter(
            navigatorKey: navigatorKey,
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
    // A context without a navigator above it: showDialog throws.
    navigatorKey.context.value = t.element(find.byType(ProviderScope));

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await t.tap(find.text('Leave'));
      await t.pump();
    }, (error, _) => errors.add(error));
    expect(errors, hasLength(1));

    navigatorKey.context.value = null;
    await t.tap(find.text('Leave'));
    await t.pumpAndSettle();

    expect(find.text('Leave demo?'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('demo_survives_${brightness.name}_theme_and_200_percent_text', (
      t,
    ) async {
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.onboarding,
        overrides: [_noSavedTvs],
        brightness: brightness,
        textScale: 2,
      );
      await t.tap(find.text('Try demo'));
      await _connectDemo(t);

      expect(find.text('Demo mode'), findsOneWidget);
      expect(find.text('TV preview'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('the_demo_remote_fits_320dp_at_${scale}x_text', (t) async {
      t.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpRouterApp(
        t,
        initialLocation: AppRoutes.onboarding,
        overrides: [_noSavedTvs],
        textScale: scale,
      );
      await t.ensureVisible(find.text('Try demo'));
      await t.tap(find.text('Try demo'));
      await _connectDemo(t);

      expect(t.takeException(), isNull);
      expect(find.text('Demo mode'), findsOneWidget);
      for (final finder in [
        find.byType(TvPreviewCard),
        find.byType(RemoteBody),
      ]) {
        final rect = t.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      // The strip is a row of its own: the card never sits under it.
      expect(
        t.getRect(find.byType(AppBar)).top,
        greaterThanOrEqualTo(t.getRect(find.text('Demo mode')).bottom),
      );
    });
  }

  testWidgets('real_session_shows_no_badge_or_preview', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      overrides: [
        _noSavedTvs,
        remoteSessionProvider.overrideWith(
          (ref) async => FakeRemoteSession(
            initial: const TvConnectionState(
              status: ConnectionStatus.connected,
            ),
          ),
        ),
      ],
    );

    expect(find.text('Demo mode'), findsNothing);
    expect(find.text('TV preview'), findsNothing);
    expect(find.byType(TvPreviewCard), findsNothing);
  });
}
