import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/tv/manual_tv.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';

import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/pump_router_app.dart';

void main() {
  late FakeTvDiscoveries discoveries;

  setUp(() => discoveries = FakeTvDiscoveries());

  Future<void> openSheet(WidgetTester t, {double textScale = 1}) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      settle: false,
      textScale: textScale,
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
      ],
    );
    await t.pump();
    await t.tap(find.text('Enter IP address'));
    await t.pumpAndSettle();
  }

  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  testWidgets('manual_ip_sheet_shows_label_hint_and_help', (t) async {
    await openSheet(t);
    expect(find.text('TV IP address'), findsOneWidget);
    expect(
      find.text(
        'Find it on the TV under Settings → Network & Internet → '
        'your network.',
      ),
      findsOneWidget,
    );
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.textInputAction, TextInputAction.done);
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(field.decoration?.hintText, '192.168.1.20');
  });

  testWidgets('manual_ip_validates_ipv4', (t) async {
    await openSheet(t);

    await t.enterText(find.byType(TextField), '192.168.1.300');
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(find.text('Enter an address like 192.168.1.20'), findsOneWidget);
    // The sheet stays open and nothing was pushed.
    expect(find.byType(TextField), findsOneWidget);
    expect(top(t).uri.path, AppRoutes.discover);

    await t.enterText(find.byType(TextField), ' 192.168.1.30 ');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();

    expect(top(t).uri.path, AppRoutes.pair('manual:192.168.1.30'));
    expect(top(t).extra, manualTv('192.168.1.30'));
  });

  testWidgets('the_keyboard_done_action_submits', (t) async {
    await openSheet(t);
    await t.enterText(find.byType(TextField), '10.0.0.5');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('manual:10.0.0.5'));
  });

  testWidgets('closing_the_sheet_navigates_nowhere', (t) async {
    await openSheet(t);
    await t.enterText(find.byType(TextField), '10.0.0.5');
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(top(t).uri.path, AppRoutes.discover);
  });

  testWidgets('manual_ip_sheet_reflows_at_200_percent_text', (t) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await openSheet(t, textScale: 2);
    await t.enterText(find.byType(TextField), 'nope');
    await t.tap(find.text('Continue'));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Enter an address like 192.168.1.20'), findsOneWidget);
  });
}
