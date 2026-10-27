import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';

import '../../helpers/ad_clearance.dart';
import '../../helpers/fake_ads_sdk.dart';
import '../../helpers/gather_consent.dart';
import '../../helpers/in_memory_shortcut_repository.dart';
import '../../helpers/pump_router_app.dart';

final Finder _banner = find.byKey(const ValueKey('fake_banner'));

/// The vertical scroll view of the page: the one with the most to scroll.
ScrollPosition _list(WidgetTester t) {
  final positions = [
    for (final state in t.stateList<ScrollableState>(find.byType(Scrollable)))
      if (state.position.axis == Axis.vertical) state.position,
  ];
  expect(positions, isNotEmpty);
  return positions.reduce(
    (a, b) => a.maxScrollExtent >= b.maxScrollExtent ? a : b,
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('banner_has_48dp_clearance_from_nav_controls', (t) async {
    var checks = 0;
    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(844, 390),
    ]) {
      for (final scale in const [1.0, 2.0]) {
        // The Apps screen with its seeded shortcuts and with none (the
        // "Add apps" button), and the Settings hub.
        for (final (name, route, empty) in const [
          ('apps', AppRoutes.apps, false),
          ('apps_empty', AppRoutes.apps, true),
          ('settings', AppRoutes.settings, false),
        ]) {
          t.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await pumpRouterApp(
            t,
            initialLocation: route,
            textScale: scale,
            prepareSettings: (store) => store.setShortcutsSeeded(empty),
            overrides: [
              adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
              if (empty)
                shortcutRepositoryProvider.overrideWithValue(
                  InMemoryShortcutRepository(),
                ),
            ],
          );
          await gatherConsent(t);
          final reason = '$name at $size, text $scale';
          expect(_banner, findsOneWidget, reason: reason);

          final list = _list(t);
          // The end of a lazy list is only known once it has been reached,
          // so keep going until it stops moving.
          for (final fraction in const [0.0, 0.5, 1.0]) {
            for (var i = 0; i < 20; i++) {
              final target = list.maxScrollExtent * fraction;
              list.jumpTo(target);
              await t.pump();
              if (list.maxScrollExtent * fraction == target) break;
            }
            expect(tappableRects(t), isNotEmpty, reason: reason);
            expectClearance(t, t.getRect(_banner));
            checks++;
          }
        }
      }
    }
    expect(checks, greaterThanOrEqualTo(3 * 2 * 3));
  });

  testWidgets('the_clearance_check_catches_a_control_next_to_the_ad', (
    t,
  ) async {
    // A control 40 dp above the ad fails; 48 dp passes; one beside it is not
    // constrained.
    Future<void> pumpGap(double gap) => t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                top: 100,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned(
                left: 0,
                top: 100 + 48 + gap,
                width: 100,
                height: 60,
                child: const ColoredBox(
                  key: ValueKey('fake_banner'),
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await pumpGap(48);
    expectClearance(t, t.getRect(_banner));

    await pumpGap(40);
    expect(
      () => expectClearance(t, t.getRect(_banner)),
      throwsA(isA<TestFailure>()),
    );
  });
}
