import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/pairing/presentation/widgets/pairing_code_field.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../test/helpers/fake_tv_harness.dart';
import '../../test/helpers/pump_router_app.dart';
import '../../test/helpers/pump_until.dart';

bool _shows(Finder finder) => finder.evaluate().isNotEmpty;

/// Discover → pair → press keys, against the protocol library's fake TV over
/// real TLS: the app's real pairing client, remote client, session and
/// screens; only discovery is faked.
///
/// The app is unmounted at the end, and the flow waits for the TV to see the
/// connection close, also when a step failed (then only that step's failure
/// is reported).
Future<void> discoverPairPressKeyFlow(WidgetTester t) async {
  final harness = await FakeTvHarness.start(t);
  addTearDown(harness.close);
  final semantics = t.ensureSemantics();
  try {
    await harness.cleanUpAfter(() => _steps(t, harness));
  } finally {
    // In the test body, not a tear-down: flutter_test checks for live
    // semantics handles before tear-downs run.
    semantics.dispose();
  }
}

Future<void> _steps(WidgetTester t, FakeTvHarness harness) async {
  final tv = harness.tv;

  await pumpRouterApp(
    t,
    initialLocation: AppRoutes.discover,
    overrides: harness.overrides,
    settle: false,
  );
  await pumpUntil(
    t,
    () => _shows(find.text('Fake TV')),
    reason: 'the fake TV in the list of TVs',
  );

  await t.tap(find.text('Fake TV'));
  final codeField = find.descendant(
    of: find.byType(PairingCodeField),
    matching: find.byType(TextField),
  );
  await pumpUntil(
    t,
    () => _shows(codeField) && tv.displayedCode != null,
    reason: 'the code field and a code on the TV',
  );

  await t.enterText(codeField, tv.displayedCode!);
  await pumpUntil(
    t,
    () => _shows(find.byType(RemoteScreen)) && _shows(find.text('Connected')),
    reason: 'the remote screen, connected',
  );
  // Let the page transition finish so the keys can be hit.
  await t.pumpAndSettle();

  await t.tap(find.bySemanticsLabel('Home'));
  await pumpUntil(
    t,
    () => tv.receivedKeyCodes.contains(KeyCodes.home),
    reason: 'the TV to receive Home',
  );

  await t.tap(find.bySemanticsLabel('Volume up'));
  await pumpUntil(
    t,
    () => tv.receivedKeyCodes.contains(KeyCodes.volumeUp),
    reason: 'the TV to receive Volume up',
  );

  final devices = ProviderScope.containerOf(
    t.element(find.byType(RemoteScreen)),
  ).read(deviceRepositoryProvider);
  final saved = await t.runAsync(() => devices.find('Fake TV'));
  expect(saved, isNotNull, reason: 'pairing saves the TV');
  expect(saved!.serverKeyPin, isNotNull, reason: "the TV's key is pinned");
  expect(tv.openRemoteConnections, 1);
}
