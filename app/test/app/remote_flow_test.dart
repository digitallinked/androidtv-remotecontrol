import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/features/keyboard/keyboard_sheet.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

import '../helpers/fake_remote_client.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

/// Seam tests for the remote: the real router, screen, `RemoteActions`,
/// providers and `TvRemoteSession`, with only the TV's socket (the client)
/// faked. They check that a press on the screen reaches the client, and that
/// the TV's state reaches the screen.
///
/// Theater Mode is off by default and the wake lock is a fake, so no test here
/// needs to account for a dimmed first touch.
void main() {
  late AppDatabase db;
  late FakeRemoteClients clients;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clients = FakeRemoteClients();
  });

  /// Opens the remote of a saved TV on a phone-sized view; the session
  /// connects through [clients].
  Future<FakeRemoteClient> pumpRemote(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await DriftDeviceRepository(db).upsert(savedTv());
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      database: db,
      overrides: [
        remoteClientFactoryProvider.overrideWithValue(clients.create),
      ],
    );
    expect(find.text('Connected'), findsOneWidget);
    return clients.created.single;
  }

  /// A press of [code] held for [hold], lifted afterwards.
  Future<void> holdKey(
    WidgetTester t,
    String label, {
    Duration hold = const Duration(milliseconds: 400),
  }) async {
    final gesture = await t.startGesture(
      t.getCenter(find.bySemanticsLabel(label)),
    );
    await t.pump(hold);
    await gesture.up();
    await t.pump();
  }

  testWidgets('touchpad_dpad_and_numbers_reach_the_client', (t) async {
    final handle = t.ensureSemantics();
    final client = await pumpRemote(t);

    // One swipe of 30 dp is one step: 24 dp for the first, then 40 each.
    final swipe = await t.startGesture(t.getCenter(find.byType(Touchpad)));
    await swipe.moveBy(const Offset(30, 0));
    await swipe.up();
    await t.pump();

    await t.tap(find.text('D-pad'));
    await t.pumpAndSettle();
    await t.tapAt(t.getCenter(find.byType(Dpad)));
    await t.pump();

    await t.tap(find.text('Numbers'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Number 5'));
    await t.pump();

    expect(client.sentKeys, [
      (KeyCodes.dpadRight, KeyDirection.short),
      (KeyCodes.dpadCenter, KeyDirection.short),
      (KeyCodes.digit(5), KeyDirection.short),
    ]);
    expect(KeyCodes.digit(5), 12);
    handle.dispose();
  });

  testWidgets('smooth_press_hold_reaches_the_client_as_start_and_end_long', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final client = await pumpRemote(t);

    await holdKey(t, 'Volume up', hold: kHoldThreshold * 2);

    expect(client.sentKeys, [
      (KeyCodes.volumeUp, KeyDirection.startLong),
      (KeyCodes.volumeUp, KeyDirection.endLong),
    ]);
    handle.dispose();
  });

  testWidgets('drop_mid_hold_does_not_crash_and_the_next_press_is_refused', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final client = await pumpRemote(t);

    final gesture = await t.startGesture(
      t.getCenter(find.bySemanticsLabel('Volume up')),
    );
    await t.pump(kHoldThreshold + const Duration(milliseconds: 50));
    expect(client.sentKeys, [(KeyCodes.volumeUp, KeyDirection.startLong)]);

    // The TV goes away while the finger is still down.
    client.drop();
    await t.pump();
    await gesture.up();
    await t.pump();
    expect(t.takeException(), isNull);
    // The pill cross-fades to the new state.
    await t.pump(const Duration(milliseconds: 250));
    expect(find.text('Connected'), findsNothing);

    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(find.text('Not connected to your TV'), findsOneWidget);
    // Nothing reached the dead client, and the release was best effort.
    expect(client.sentKeys, [(KeyCodes.volumeUp, KeyDirection.startLong)]);
    handle.dispose();
  });

  testWidgets('typing_reaches_the_client_once_debounced', (t) async {
    final handle = t.ensureSemantics();
    final client = await pumpRemote(t);

    await t.tap(find.bySemanticsLabel('Keyboard'));
    await t.pumpAndSettle();
    expect(KeyboardSheet.isOpen, isTrue);

    await t.enterText(find.byType(TextField), 'abc');
    expect(client.sentTexts, isEmpty);
    await t.pump(const Duration(milliseconds: 150));
    expect(client.sentTexts, ['abc']);

    await t.tap(find.text('Enter'));
    await t.pumpAndSettle();
    // Nothing was pending, so Enter sends only the key, and the sheet closes.
    expect(client.sentTexts, ['abc']);
    expect(client.sentKeys.last, (KeyCodes.enter, KeyDirection.short));
    expect(client.sentKeys.last.$1, 66);
    expect(KeyboardSheet.isOpen, isFalse);
    handle.dispose();
  });

  testWidgets('volume_value_clears_after_a_drop_and_returns_with_the_tv', (
    t,
  ) async {
    final client = await pumpRemote(t);
    expect(find.text('12'), findsNothing);

    client.push(const VolumeChanged(12, 40, false));
    await t.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);

    client.drop();
    await t.pumpAndSettle();
    expect(find.text('12'), findsNothing);

    // The session retries after its first backoff (1 s) with a new client.
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(clients.created, hasLength(2));
    expect(find.text('12'), findsNothing);

    clients.created.last.push(const VolumeChanged(12, 40, false));
    await t.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('remote_screen_has_no_mic_button', (t) async {
    await pumpRemote(t);
    for (final page in ['Touchpad', 'D-pad', 'Numbers']) {
      await t.tap(find.text(page));
      await t.pumpAndSettle();
      for (final icon in [Icons.mic, Icons.mic_none, Icons.mic_outlined]) {
        expect(
          find.byIcon(icon),
          findsNothing,
          reason: '$page ${icon.codePoint}',
        );
      }
    }
  });
}
