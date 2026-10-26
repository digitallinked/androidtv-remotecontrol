import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/presentation/pairing_screen.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';

import '../../helpers/fake_remote_client.dart';
import '../../helpers/fake_remote_session.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);
const _needsPairing = TvConnectionState(status: ConnectionStatus.needsPairing);
const _identityChanged = TvConnectionState(
  status: ConnectionStatus.needsPairing,
  lastError: RemoteCloseReason.serverKeyChanged,
);

/// A session that says it is connected but whose socket is already gone.
class _LaggingSession extends FakeRemoteSession {
  _LaggingSession() : super(initial: _connected);

  @override
  void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}) =>
      throw const NotConnectedException();
}

void main() {
  late FakeRemoteSession fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeRemoteSession(
      pairingTarget: savedTv().toDiscoveredTv(),
    );
  });

  Future<void> pumpRemote(
    WidgetTester t, {
    RemoteSession? session,
    List<Override> overrides = const [],
    double textScale = 1,
  }) async {
    final s = session ?? fake;
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      textScale: textScale,
      overrides: [
        remoteSessionProvider.overrideWith((ref) async => s),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([
            savedTv(),
            savedTv(name: 'Bedroom TV', host: '192.168.0.21'),
          ]),
        ),
        ...overrides,
      ],
    );
    // Taken now: after a push the remote screen is no longer on stage.
    container = ProviderScope.containerOf(t.element(find.byType(RemoteScreen)));
  }

  /// The state of the screen on top: a pushed route is not in the router's
  /// own location, so ask the topmost scaffold.
  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  Finder inDialog(Finder f) => find.descendant(
    of: find.byType(AppDialog<bool>),
    matching: f,
  );

  testWidgets('status_pill_reflects_socket_state_not_saved_state', (t) async {
    fake.emit(
      const TvConnectionState(
        status: ConnectionStatus.reconnecting,
        attempt: 1,
      ),
    );
    await pumpRemote(t);
    // A saved, pinned TV is not "Connected".
    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    fake.emit(_connected);
    await t.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Reconnecting…'), findsNothing);
  });

  testWidgets('the_app_bar_names_the_tv', (t) async {
    await pumpRemote(t);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Living Room TV 3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the_demo_tv_is_named_in_the_current_language', (t) async {
    await pumpRemote(t, session: FakeRemoteSession(isDemo: true));
    expect(find.text('Demo TV'), findsOneWidget);
    expect(find.text('Pair again'), findsNothing);
  });

  testWidgets('offline_reconnect_calls_session_reconnect', (t) async {
    fake.emit(_offline);
    await pumpRemote(t);
    await t.tap(find.text('Reconnect'));
    await t.pump();
    expect(fake.reconnectCalls, 1);
  });

  testWidgets('needs_pairing_routes_to_pairing_screen', (t) async {
    fake.emit(_needsPairing);
    await pumpRemote(t);
    expect(find.text('Needs pairing'), findsOneWidget);
    // Nothing navigated by itself.
    expect(top(t).uri.path, AppRoutes.remote);
    await t.tap(find.text('Pair again'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    // No `extra`: the pairing screen re-resolves the TV's address.
    expect(top(t).extra, isNull);
  });

  testWidgets('pair_again_resolves_the_tv_before_pairing', (t) async {
    final resolved = <String>[];
    fake.emit(_needsPairing);
    await pumpRemote(
      t,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(
          InMemoryDeviceRepository([savedTv()]),
        ),
        hostResolverProvider.overrideWithValue((name) async {
          resolved.add(name);
          return '192.168.0.33';
        }),
      ],
    );

    await t.tap(find.text('Pair again'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    expect(t.widget<PairingScreen>(find.byType(PairingScreen)).tv, isNull);
    expect(resolved, ['Living Room TV 3']);
  });

  testWidgets('identity_changed_routes_to_pairing', (t) async {
    fake.emit(_connected);
    await pumpRemote(t);
    expect(find.byType(AppDialog<bool>), findsNothing);
    fake.emit(_identityChanged);
    await t.pumpAndSettle();
    expect(find.text("This TV's identity changed"), findsOneWidget);
    expect(
      find.textContaining('Living Room TV 3 presented a different security'),
      findsOneWidget,
    );
    await t.tap(inDialog(find.text('Pair again')));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    // No `extra`: the pairing screen re-resolves the TV's address.
    expect(top(t).extra, isNull);
    // The same state again asks nothing more.
    fake.emit(_identityChanged);
    await t.pumpAndSettle();
    expect(find.byType(AppDialog<bool>), findsNothing);
  });

  testWidgets('identity_changed_not_now_keeps_the_remote', (t) async {
    fake.emit(_connected);
    await pumpRemote(t);
    fake.emit(_identityChanged);
    await t.pumpAndSettle();
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(find.byType(RemoteScreen), findsOneWidget);
    expect(top(t).uri.path, AppRoutes.remote);
    expect(find.byType(AppDialog<bool>), findsNothing);
    expect(find.text('Needs pairing'), findsOneWidget);
    expect(find.text('Pair again'), findsOneWidget);
    // Once per session: it does not come back when the state repeats.
    fake.emit(_offline);
    await t.pumpAndSettle();
    fake.emit(_identityChanged);
    await t.pumpAndSettle();
    expect(find.byType(AppDialog<bool>), findsNothing);
  });

  testWidgets('certificate_rejected_shows_the_action_without_a_dialog', (
    t,
  ) async {
    fake.emit(
      const TvConnectionState(
        status: ConnectionStatus.needsPairing,
        lastError: RemoteCloseReason.certificateRejected,
      ),
    );
    await pumpRemote(t);
    expect(find.byType(AppDialog<bool>), findsNothing);
    expect(find.text('Pair again'), findsOneWidget);
  });

  testWidgets('keys_send_when_connected', (t) async {
    final handle = t.ensureSemantics();
    fake.emit(_connected);
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(fake.sentKeys, [KeyCodes.home]);
    await t.tap(find.bySemanticsLabel('Volume up'));
    await t.pump();
    expect(fake.sentKeys, [KeyCodes.home, 24]);
    expect(find.text('Not connected to your TV'), findsNothing);
    handle.dispose();
  });

  testWidgets('keys_show_not_connected_snackbar_when_offline', (t) async {
    final handle = t.ensureSemantics();
    fake.emit(_offline);
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(fake.sentKeys, isEmpty);
    expect(find.text('Not connected to your TV'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a_key_pressed_as_the_socket_drops_shows_the_snackbar', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t, session: _LaggingSession());
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Not connected to your TV'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('device_switcher_lists_saved_tvs_and_switches', (t) async {
    await pumpRemote(t);
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    expect(find.text('Bedroom TV'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Living Room TV 3'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Bedroom TV'));
    await t.pumpAndSettle();
    expect(
      container.read(activeTargetProvider),
      const DeviceTarget('Bedroom TV'),
    );
    expect(find.text('Bedroom TV'), findsNothing);
  });

  testWidgets('selecting_the_current_tv_keeps_the_session', (t) async {
    final clients = FakeRemoteClients();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftDeviceRepository(db).upsert(savedTv());
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      database: db,
      overrides: [
        remoteClientFactoryProvider.overrideWithValue(clients.create),
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv()]),
        ),
      ],
    );
    final c = ProviderScope.containerOf(t.element(find.byType(RemoteScreen)));
    final before = c.read(remoteSessionProvider).value;
    expect(before, isNotNull);
    expect(clients.created, hasLength(1));

    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Living Room TV 3'),
      ),
    );
    await t.pumpAndSettle();

    expect(c.read(remoteSessionProvider).value, same(before));
    expect(clients.created, hasLength(1));
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('device_switcher_add_tv_opens_discover', (t) async {
    await pumpRemote(t);
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add a TV'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, '/discover');
  });

  testWidgets('no_tv_shows_choose_a_tv_action', (t) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      overrides: [remoteSessionProvider.overrideWith((ref) async => null)],
    );
    expect(find.text('No TV selected'), findsOneWidget);
    await t.tap(find.text('Choose a TV'));
    await t.pumpAndSettle();
    expect(find.text('Choose your TV'), findsOneWidget);
  });

  testWidgets('identity_store_failure_offers_retry', (t) async {
    var builds = 0;
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.remote,
      overrides: [
        remoteSessionProvider.overrideWith((ref) async {
          builds++;
          throw const IdentityStoreException('boom');
        }),
      ],
    );
    expect(find.text("Couldn't prepare a secure connection"), findsOneWidget);
    expect(builds, 1);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(builds, 2);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('remote_screen_reflows_at_200_percent_text', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    fake.emit(_offline);
    await pumpRemote(t, textScale: 2);
    expect(t.takeException(), isNull);
    fake.emit(_needsPairing);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  for (final width in [360.0, 320.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('controls_fit_${width.toInt()}dp_at_${scale}x_text', (
        t,
      ) async {
        t.view
          ..physicalSize = Size(width, 640)
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        fake.emit(_connected);
        await pumpRemote(t, textScale: scale);
        expect(t.takeException(), isNull);
        final keys = find.byType(AppKeyButton);
        // The bottom cluster (two rockers, four keys, and the 2 x 2 grid)
        // and the power key in the app bar.
        expect(keys, findsNWidgets(9));
        for (final key in keys.evaluate()) {
          final size = t.getSize(find.byElementPredicate((e) => e == key));
          expect(size.width, greaterThanOrEqualTo(56));
          expect(size.height, greaterThanOrEqualTo(56));
        }
        final controls = t.getRect(find.byType(RemoteBody));
        expect(controls.left, greaterThanOrEqualTo(0));
        expect(controls.right, lessThanOrEqualTo(width));
      });
    }
  }

  testWidgets('disconnected_key_press_offers_reconnect', (t) async {
    final handle = t.ensureSemantics();
    await pumpRemote(t);
    await t.tap(find.bySemanticsLabel('Home'));
    await t.pump();
    expect(fake.sentKeys, isEmpty);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Not connected to your TV'), findsOneWidget);
    await t.tap(find.widgetWithText(SnackBarAction, 'Reconnect'));
    await t.pump();
    expect(fake.reconnectCalls, 1);
    handle.dispose();
  });

  testWidgets(
    'identity_changed_dialog_shows_when_the_screen_opens_in_that_state',
    (
      t,
    ) async {
      fake.emit(_identityChanged);
      await pumpRemote(t);
      expect(find.text("This TV's identity changed"), findsOneWidget);
      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();
      expect(find.byType(AppDialog<bool>), findsNothing);
      fake.emit(_offline);
      await t.pumpAndSettle();
      fake.emit(_identityChanged);
      await t.pumpAndSettle();
      expect(find.byType(AppDialog<bool>), findsNothing);
    },
  );

  testWidgets('settings_button_opens_settings_and_back_returns', (t) async {
    fake.emit(_connected);
    await pumpRemote(t);
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.settings);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byType(RemoteBody), findsOneWidget);
  });

  testWidgets('remote_app_bar_fits_320dp_at_200_percent_text', (t) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    fake.emit(_connected);
    await pumpRemote(t, textScale: 2);
    expect(t.takeException(), isNull);
    final bar = t.getRect(find.byType(AppBar));
    final settings = find.byTooltip('Settings');
    final switcher = find.byTooltip('Switch TV');
    final power = find.byType(PowerButton);
    for (final f in [settings, switcher, power]) {
      expect(f, findsOneWidget);
      final rect = t.getRect(f);
      expect(bar.contains(rect.topLeft), isTrue, reason: '$f');
      expect(bar.contains(rect.bottomRight), isTrue, reason: '$f');
      expect(f.hitTestable(), findsOneWidget, reason: '$f');
    }
    final rect = t.getRect(settings);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.right, lessThanOrEqualTo(t.getRect(switcher).left));
    expect(t.getRect(switcher).right, lessThanOrEqualTo(t.getRect(power).left));
  });
}
