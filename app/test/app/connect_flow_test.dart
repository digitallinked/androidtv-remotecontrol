import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_signals.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import '../helpers/fake_pairing_client.dart';
import '../helpers/fake_remote_client.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/manual_session_signals.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_devices.dart';

/// Seam tests for the connect flow: the real router, screens, providers and
/// sessions, with only the TV (clients, discovery, pairing) faked. They check
/// that the pieces added one task at a time work together.
void main() {
  late AppDatabase db;
  late DriftDeviceRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftDeviceRepository(db);
    addTearDown(db.close);
  });

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  /// Types the code the fake TV shows and waits for the pairing to finish.
  Future<void> pairWithCode(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byType(TextField), 'AB12CD');
    await t.pumpAndSettle();
  }

  testWidgets('discovery_then_pairing_ends_connected_on_the_remote', (t) async {
    final discoveries = FakeTvDiscoveries();
    final clients = FakeRemoteClients();
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      database: db,
      settle: false,
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        pairingClientFactoryProvider.overrideWithValue(
          FakePairingClients().create,
        ),
        remoteClientFactoryProvider.overrideWithValue(clients.create),
      ],
    );
    await t.pump();
    discoveries.created.last.emit([tv('Living Room TV 3')]);
    await t.pump();

    await t.tap(find.text('Living Room TV 3'));
    await pairWithCode(t);

    expect(find.text('Connected'), findsOneWidget);
    expect(clients.created, hasLength(1));
    final saved = await repository.find('Living Room TV 3');
    expect(saved?.serverKeyPin, testPin);
    final session = containerOf(t).read(remoteSessionProvider).value;
    expect(session?.tvName, 'Living Room TV 3');
  });

  testWidgets('a_changed_tv_identity_is_repaired_and_reconnects', (t) async {
    final stalePin = serverKeyPinFromSha256(List<int>.filled(32, 9));
    await repository.upsert(savedTv(pin: stalePin));
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      database: db,
      settle: false,
      overrides: [
        pairingClientFactoryProvider.overrideWithValue(
          FakePairingClients().create,
        ),
      ],
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text("This TV's identity changed"), findsOneWidget);
    final container = containerOf(t);
    final first = container.read(remoteSessionProvider).value;
    expect(first, isNotNull);
    // The distrusted pin is already forgotten.
    expect((await repository.find('Living Room TV 3'))?.serverKeyPin, isNull);

    await t.tap(find.text('Pair again').last);
    await pairWithCode(t);

    expect(find.text('Connected'), findsOneWidget);
    final second = container.read(remoteSessionProvider).value;
    expect(identical(first, second), isFalse);
    expect((await repository.find('Living Room TV 3'))?.serverKeyPin, testPin);
  });

  testWidgets('background_longer_than_the_grace_disconnects_and_resumes', (
    t,
  ) async {
    final clients = FakeRemoteClients();
    final signals = ManualSessionSignals();
    await repository.upsert(savedTv());
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      database: db,
      overrides: [
        remoteClientFactoryProvider.overrideWithValue(clients.create),
        sessionSignalsProvider.overrideWithValue(signals),
      ],
    );
    expect(find.text('Connected'), findsOneWidget);
    expect(clients.created, hasLength(1));

    signals.background();
    await t.pump(const Duration(seconds: 61));
    // The close runs on real async work; let it finish.
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(find.text('Connected'), findsNothing);

    signals.foreground();
    await t.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(clients.created, hasLength(2));
  });

  testWidgets('switching_from_the_demo_to_a_saved_tv_ends_the_demo', (t) async {
    final clients = FakeRemoteClients();
    await repository.upsert(savedTv());
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      database: db,
      settle: false,
      overrides: [
        remoteClientFactoryProvider.overrideWithValue(clients.create),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
      ],
    );
    await t.pump();
    await t.tap(find.text('Try demo'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();
    final container = containerOf(t);
    final demo = container.read(remoteSessionProvider).value!;
    expect(demo.isDemo, isTrue);
    expect(find.text('Demo mode'), findsOneWidget);
    var demoEnded = false;
    demo.events.listen((_) {}, onDone: () => demoEnded = true);

    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Living Room TV 3'),
      ),
    );
    await t.pumpAndSettle();

    final session = container.read(remoteSessionProvider).value!;
    expect(session.isDemo, isFalse);
    expect(session, isNot(same(demo)));
    expect(find.text('Demo mode'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);
    expect(demoEnded, isTrue, reason: 'the demo session was disposed');
    expect(demo.current.status, ConnectionStatus.disconnected);
    expect(clients.created, hasLength(1));
  });
}
