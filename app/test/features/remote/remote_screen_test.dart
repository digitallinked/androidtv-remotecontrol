import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/remote/presentation/remote_screen.dart';

import '../../helpers/fake_remote_session.dart';
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
    expect(top(t).extra, savedTv().toDiscoveredTv());
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
    expect(top(t).extra, savedTv().toDiscoveredTv());
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
}
