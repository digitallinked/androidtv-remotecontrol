import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/features/demo/presentation/tv_preview_card.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';

import '../../test/helpers/fake_pairing_client.dart';
import '../../test/helpers/fake_remote_client.dart';
import '../../test/helpers/pump_router_app.dart';

Finder _inPreview(Finder finder) =>
    find.descendant(of: find.byType(TvPreviewCard), matching: finder);

/// Try the demo from onboarding, use the remote, type, and leave: no TV, no
/// socket. The demo's simulated TV answers every control in the preview card.
Future<void> demoModeFlow(WidgetTester t) async {
  final semantics = t.ensureSemantics();
  try {
    await _steps(t);
  } finally {
    // In the test body, not a tear-down: flutter_test checks for live
    // semantics handles before tear-downs run.
    semantics.dispose();
  }
}

Future<void> _steps(WidgetTester t) async {
  var remoteClients = 0;
  var pairingClients = 0;
  final fakeRemotes = FakeRemoteClients();
  final fakePairings = FakePairingClients();

  await pumpRouterApp(
    t,
    initialLocation: AppRoutes.onboarding,
    overrides: [
      remoteClientFactoryProvider.overrideWithValue(
        ({required host, required port, required identity}) {
          remoteClients++;
          return fakeRemotes.create(host: host, port: port, identity: identity);
        },
      ),
      pairingClientFactoryProvider.overrideWithValue(
        ({required host, required identity}) {
          pairingClients++;
          return fakePairings.create(host: host, identity: identity);
        },
      ),
    ],
  );

  await t.tap(find.text('Try demo'));
  await t.pump();
  // The demo TV "connects" after a short simulated delay.
  await t.pump(const Duration(milliseconds: 700));
  await t.pumpAndSettle();
  expect(find.byType(RemoteScreen), findsOneWidget);
  expect(find.text('Demo mode'), findsOneWidget);
  expect(find.byType(TvPreviewCard), findsOneWidget);
  expect(_inPreview(find.textContaining('Volume 8 of 20')), findsOneWidget);

  await t.tap(find.bySemanticsLabel('Volume up'));
  await t.pump();
  expect(_inPreview(find.textContaining('Volume 9 of 20')), findsOneWidget);
  expect(_inPreview(find.text('Pressed Volume up')), findsOneWidget);

  await t.tap(find.text('D-pad'));
  await t.pumpAndSettle();
  // The pad's five buttons are painted, so tap the upper arm by position.
  final pad = t.getRect(
    find.descendant(of: find.byType(Dpad), matching: find.byType(CustomPaint)),
  );
  await t.tapAt(Offset(pad.center.dx, pad.top + pad.height * 0.15));
  await t.pump();
  expect(_inPreview(find.text('Pressed Up')), findsOneWidget);

  await t.tap(find.bySemanticsLabel('Keyboard'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), 'hi');
  await t.pump(const Duration(milliseconds: 150));
  expect(_inPreview(find.text('Typed "hi"')), findsOneWidget);
  // Close the keyboard sheet the way the system back gesture does.
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();

  await t.tap(find.text('Leave'));
  await t.pumpAndSettle();
  expect(find.text('Leave demo?'), findsOneWidget);
  await t.tap(find.text('Leave demo'));
  await t.pumpAndSettle();

  expect(find.byType(DiscoveryScreen), findsOneWidget);
  expect(find.text('Demo mode'), findsNothing);
  expect(remoteClients, 0, reason: 'the demo never creates a remote client');
  expect(pairingClients, 0, reason: 'the demo never creates a pairing client');
}
