import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_analytics_sink.dart';
import '../../helpers/test_devices.dart';

void main() {
  late RecordingAnalyticsSink sink;

  setUp(() => sink = RecordingAnalyticsSink());

  Future<void> pump(WidgetTester t, String location) => pumpRouterApp(
    t,
    initialLocation: location,
    // Analytics is allowed, and a bad event throws as in a debug build.
    prepareSettings: (store) => store.setConsentRegion(
      ConsentRegion.notRequired,
    ),
    overrides: [
      analyticsSinkProvider.overrideWithValue(sink),
      analyticsDebugBuildProvider.overrideWithValue(true),
      remoteSessionProvider.overrideWith(
        (ref) async => FakeRemoteSession(
          initial: const TvConnectionState(status: ConnectionStatus.connected),
        ),
      ),
      savedDevicesProvider.overrideWith(
        (ref) => Stream.value([savedTv(), savedTv(name: 'Bedroom TV')]),
      ),
    ],
  );

  GoRouter routerOf(WidgetTester t) =>
      GoRouter.of(t.element(find.byType(Scaffold).first));

  testWidgets('screen_names_never_contain_route_parameters', (t) async {
    await pump(t, AppRoutes.editDevice('Living Room TV 3'));
    unawaited(routerOf(t).push(AppRoutes.pair('Bravia/4K')));
    await t.pumpAndSettle();

    // go_router puts `GoRoute.name` into the page's name, which is what the
    // observer reads; the parameters stay in the path.
    expect(sink.screens, ['devices', 'edit_device', 'pair']);
    for (final s in sink.screens) {
      expect(s, isNot(contains('Living')));
      expect(s, isNot(contains('Bravia')));
      expect(AppRouteNames.all, contains(s));
    }
    expect(sink.calls.join(), isNot(contains('Living')));
    expect(sink.calls.join(), isNot(contains('Bravia')));
  });

  testWidgets('going_back_reports_the_screen_underneath', (t) async {
    await pump(t, AppRoutes.settings);
    unawaited(routerOf(t).push(AppRoutes.settingsAbout));
    await t.pumpAndSettle();
    expect(sink.screens, ['settings', 'settings_about']);

    routerOf(t).pop();
    await t.pumpAndSettle();
    expect(sink.screens, ['settings', 'settings_about', 'settings']);

    routerOf(t).go(AppRoutes.remote);
    await t.pumpAndSettle();
    expect(sink.screens.last, 'remote');
  });

  testWidgets('sheets_and_dialogs_are_not_screens', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);

    // A bottom sheet on the remote.
    await pump(t, AppRoutes.remote);
    expect(sink.screens, ['remote']);
    await t.tap(find.byTooltip('Switch TV'));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(sink.screens, ['remote']);

    // A dialog on the Settings hub.
    sink.screens.clear();
    await pump(t, AppRoutes.settings);
    final row = find.text('Send feedback');
    await t.scrollUntilVisible(
      row,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(sink.screens, ['settings']);
  });
}
