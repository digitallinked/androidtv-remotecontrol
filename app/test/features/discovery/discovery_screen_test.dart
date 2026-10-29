import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nsd/nsd.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/discovery/presentation/discovery_screen.dart';
import 'package:tv_remote/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_remote_session.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/in_memory_device_repository.dart';
import '../../helpers/nonlinear_text_scaler.dart';
import '../../helpers/pump_router_app.dart';
import '../../helpers/test_devices.dart';

/// These saved TVs, paired.
Override _savedTvs(List<String> names) => savedDevicesProvider.overrideWith(
  (ref) => Stream.value([for (final name in names) savedTv(name: name)]),
);

/// Saved TVs held in [repo], with the repository itself behind the screen.
List<Override> _repoOverrides(InMemoryDeviceRepository repo) => [
  deviceRepositoryProvider.overrideWithValue(repo),
  savedDevicesProvider.overrideWith((ref) => repo.watchAll()),
  remoteSessionProvider.overrideWith((ref) async => FakeRemoteSession()),
];

/// A repository whose host update waits until [release] completes.
class _SlowHostRepository extends InMemoryDeviceRepository {
  _SlowHostRepository(super.initial);

  final Completer<void> release = Completer<void>();

  @override
  Future<void> setLastHost(String serviceName, String host) async {
    await release.future;
    await super.setLastHost(serviceName, host);
  }
}

/// A repository whose manual → mDNS merge waits until [release] completes.
class _SlowAdoptRepository extends InMemoryDeviceRepository {
  _SlowAdoptRepository(super.initial);

  final Completer<void> release = Completer<void>();

  @override
  Future<bool> adoptManualDevice({
    required String manualServiceName,
    required DiscoveredTv tv,
  }) async {
    await release.future;
    return super.adoptManualDevice(
      manualServiceName: manualServiceName,
      tv: tv,
    );
  }
}

void main() {
  late FakeTvDiscoveries discoveries;

  setUp(() => discoveries = FakeTvDiscoveries());

  /// Opens discovery. It does not settle: the search spinner never stops.
  Future<void> pumpDiscover(
    WidgetTester t, {
    List<Override> overrides = const [],
    double textScale = 1,
    TextScaler? textScaler,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.discover,
      settle: false,
      textScale: textScale,
      textScaler: textScaler,
      brightness: brightness,
      overrides: [
        tvDiscoveryFactoryProvider.overrideWithValue(discoveries.create),
        ...overrides,
      ],
    );
    await t.pump();
  }

  Future<void> found(WidgetTester t, List<DiscoveredTv> tvs) async {
    discoveries.created.last.emit(tvs);
    await t.pump();
  }

  Future<void> waitForTimeout(WidgetTester t) async {
    await t.pump(discoveryEmptyTimeout);
    await t.pump();
  }

  /// The state of the screen on top: a pushed route is not in the router's
  /// own location, so ask the topmost scaffold.
  GoRouterState top(WidgetTester t) =>
      GoRouterState.of(t.element(find.byType(Scaffold).last));

  ProviderContainer containerOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  testWidgets('shows_a_spinner_while_searching', (t) async {
    await pumpDiscover(t);
    expect(find.text('Looking for TVs on this Wi-Fi…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The actions that do not need a TV are there from the start.
    expect(find.text('Enter IP address'), findsOneWidget);
    expect(find.text('Try demo'), findsOneWidget);
  });

  testWidgets('shows_found_tvs_sorted_by_name', (t) async {
    await pumpDiscover(t);
    await found(t, [tv('bedroom'), tv('Attic'), tv('Den')]);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final titles = t
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, ['Attic', 'bedroom', 'Den']);
    expect(find.text('192.168.0.20'), findsNWidgets(3));
    expect(find.text('Enter IP address'), findsOneWidget);
  });

  testWidgets('tv_tiles_are_at_least_56dp_tall', (t) async {
    await pumpDiscover(t);
    await found(t, [tv('Den')]);
    expect(t.getSize(find.byType(ListTile)).height, greaterThanOrEqualTo(56));
  });

  testWidgets('legacy_tv_shows_update_service_help', (t) async {
    await pumpDiscover(t);
    await found(t, [tv('Old TV', legacy: true)]);
    expect(find.text('Update needed'), findsOneWidget);

    await t.tap(find.text('Old TV'));
    await t.pumpAndSettle();

    expect(find.text('Update needed on this TV'), findsOneWidget);
    expect(
      find.textContaining('Old TV uses an older remote service'),
      findsOneWidget,
    );
    expect(top(t).uri.path, AppRoutes.discover);

    expect(discoveries.created, hasLength(1));
    await t.tap(find.text('Scan again'));
    await t.pumpAndSettle();
    expect(find.text('Update needed on this TV'), findsNothing);
    expect(top(t).uri.path, AppRoutes.discover);
    // The button closes the sheet and starts a new browse.
    expect(discoveries.created, hasLength(2));
  });

  testWidgets('empty_state_after_10s_shows_troubleshooting', (t) async {
    await pumpDiscover(t);
    expect(find.text('Looking for TVs on this Wi-Fi…'), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
    await t.pump();
    expect(find.text('No TVs found yet'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await t.tap(find.text('Troubleshooting'));
    await t.pumpAndSettle();
    expect(find.text("Can't find your TV?"), findsOneWidget);
    // The empty state behind the sheet also mentions the Wi-Fi network.
    final sheet = find.byType(BottomSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.textContaining(text));
    expect(inSheet('same Wi-Fi network'), findsOneWidget);
    expect(inSheet('Android TV Remote Service'), findsOneWidget);
    expect(inSheet('Turn the TV on'), findsOneWidget);
    expect(inSheet('Restart the TV'), findsOneWidget);
    expect(inSheet("enter the TV's IP address"), findsOneWidget);
    // The iPhone-only step is not shown on Android.
    expect(inSheet('Local Network'), findsNothing);
    for (final number in ['1.', '2.', '3.', '4.', '5.']) {
      expect(find.text(number), findsOneWidget);
    }
    expect(find.text('6.'), findsNothing);
  });

  testWidgets(
    'troubleshooting_adds_the_local_network_step_on_ios',
    (t) async {
      await pumpDiscover(t);
      await waitForTimeout(t);
      await t.tap(find.text('Troubleshooting'));
      await t.pumpAndSettle();
      expect(find.textContaining('Local Network access'), findsOneWidget);
      expect(find.text('6.'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('tapping_a_tv_opens_pairing_with_the_tv_as_extra', (t) async {
    await pumpDiscover(t);
    final den = tv('Den', host: '192.168.0.31');
    await found(t, [den]);

    await t.tap(find.text('Den'));
    await t.pumpAndSettle();

    expect(top(t).uri.path, AppRoutes.pair('Den'));
    expect(top(t).extra, den);
  });

  testWidgets('a_saved_tv_without_a_pin_still_opens_pairing', (t) async {
    await pumpDiscover(
      t,
      overrides: [
        savedDevicesProvider.overrideWith(
          (ref) => Stream.value([savedTv(name: 'Den', noPin: true)]),
        ),
      ],
    );
    await found(t, [tv('Den')]);
    expect(find.text('Paired'), findsNothing);

    await t.tap(find.text('Den'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('Den'));
  });

  testWidgets('tapping_a_paired_tv_opens_the_remote', (t) async {
    await pumpDiscover(
      t,
      overrides: [
        _savedTvs(['Den']),
        remoteSessionProvider.overrideWith((ref) async => FakeRemoteSession()),
      ],
    );
    await found(t, [tv('Den'), tv('Attic')]);
    expect(find.text('Paired'), findsOneWidget);

    await t.tap(find.text('Den'));
    await t.pumpAndSettle();

    expect(
      containerOf(t).read(activeTargetProvider),
      const DeviceTarget('Den'),
    );
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('tapping_a_paired_tv_updates_its_host_before_connecting', (
    t,
  ) async {
    final repo = InMemoryDeviceRepository([savedTv(name: 'Den')]);
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    String? hostWhenActivated;
    containerOf(t).listen(activeTargetProvider, (_, next) {
      hostWhenActivated = repo.saved['Den']?.lastHost;
    });
    await found(t, [tv('Den', host: '192.168.0.33')]);

    await t.tap(find.text('Den'));
    await t.pumpAndSettle();

    expect(repo.saved['Den']!.lastHost, '192.168.0.33');
    expect(hostWhenActivated, '192.168.0.33');
    expect(
      containerOf(t).read(activeTargetProvider),
      const DeviceTarget('Den'),
    );
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('a_failed_host_update_still_connects', (t) async {
    final repo = InMemoryDeviceRepository([savedTv(name: 'Den')])
      ..failNextWrite = StateError('disk full');
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Den', host: '192.168.0.33')]);

    await t.tap(find.text('Den'));
    await t.pumpAndSettle();

    expect(repo.saved['Den']!.lastHost, '192.168.0.20');
    expect(
      containerOf(t).read(activeTargetProvider),
      const DeviceTarget('Den'),
    );
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('a_second_tap_while_connecting_is_ignored', (t) async {
    final repo = _SlowHostRepository([savedTv(name: 'Den')]);
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Den', host: '192.168.0.33')]);

    await t.tap(find.text('Den'));
    await t.pump();
    await t.tap(find.text('Den'));
    await t.pump();
    expect(repo.writes, 0);

    repo.release.complete();
    await t.pumpAndSettle();
    expect(repo.writes, 1);
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('manual_tv_found_by_mdns_shows_paired_and_merges_on_tap', (
    t,
  ) async {
    final repo = InMemoryDeviceRepository([
      savedTv(name: 'manual:192.168.0.20', nickname: 'Den'),
    ]);
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Living Room TV 3')]);
    expect(find.text('Paired'), findsOneWidget);

    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();

    expect(repo.saved.keys, ['Living Room TV 3']);
    final moved = repo.saved['Living Room TV 3']!;
    expect(moved.serverKeyPin, testPin);
    expect(moved.nickname, 'Den');
    expect(
      containerOf(t).read(activeTargetProvider),
      const DeviceTarget('Living Room TV 3'),
    );
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('a_merge_finished_after_leaving_discovery_moves_the_session', (
    t,
  ) async {
    const manual = 'manual:192.168.0.20';
    final repo = _SlowAdoptRepository([savedTv(name: manual, nickname: 'Den')]);
    await pumpDiscover(
      t,
      overrides: [
        deviceRepositoryProvider.overrideWithValue(repo),
        savedDevicesProvider.overrideWith((ref) => repo.watchAll()),
      ],
    );
    // The remote is following the manual row.
    containerOf(t).read(activeTargetProvider.notifier).activateDevice(manual);
    await found(t, [tv('Living Room TV 3')]);
    await t.tap(find.text('Living Room TV 3'));
    await t.pump();

    // The user leaves discovery while the merge is still running.
    GoRouter.of(t.element(find.byType(Scaffold).last)).go(AppRoutes.remote);
    await t.pumpAndSettle();
    expect(find.byType(DiscoveryScreen), findsNothing);

    repo.release.complete();
    await t.pumpAndSettle();

    expect(repo.saved.keys, ['Living Room TV 3']);
    expect(
      containerOf(t).read(activeTargetProvider),
      const DeviceTarget('Living Room TV 3'),
    );
    // No session is left on the manual row that no longer exists.
    final session = await containerOf(t).read(remoteSessionProvider.future);
    expect(session?.pairingTarget?.serviceName, 'Living Room TV 3');
    // The user stays where they went.
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('manual_tv_at_another_address_is_not_merged', (t) async {
    final repo = InMemoryDeviceRepository([
      savedTv(name: 'manual:192.168.0.20'),
    ]);
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Living Room TV 3', host: '192.168.0.55')]);
    expect(find.text('Paired'), findsNothing);

    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    expect(repo.saved.keys, ['manual:192.168.0.20']);
  });

  testWidgets('manual_tv_without_a_pin_is_not_merged', (t) async {
    final repo = InMemoryDeviceRepository([
      savedTv(name: 'manual:192.168.0.20', noPin: true),
    ]);
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Living Room TV 3')]);
    expect(find.text('Paired'), findsNothing);

    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();

    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    expect(repo.saved.keys, ['manual:192.168.0.20']);
    expect(repo.writes, 0);
  });

  testWidgets('a_manual_tv_is_not_merged_over_an_existing_mdns_row', (t) async {
    final repo = InMemoryDeviceRepository([
      savedTv(name: 'manual:192.168.0.20'),
      savedTv(noPin: true),
    ]);
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Living Room TV 3')]);
    expect(find.text('Paired'), findsNothing);

    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.pair('Living Room TV 3'));
    expect(repo.writes, 0);
  });

  testWidgets('a_failed_merge_says_so_and_stays', (t) async {
    final repo = InMemoryDeviceRepository([
      savedTv(name: 'manual:192.168.0.20'),
    ])..failNextWrite = StateError('disk full');
    await pumpDiscover(t, overrides: _repoOverrides(repo));
    await found(t, [tv('Living Room TV 3')]);

    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();

    expect(find.text("Couldn't open this TV. Try again."), findsOneWidget);
    expect(top(t).uri.path, AppRoutes.discover);
    expect(repo.saved.keys, ['manual:192.168.0.20']);
    expect(containerOf(t).read(activeTargetProvider), isNull);

    // A later tap works.
    await t.tap(find.text('Living Room TV 3'));
    await t.pumpAndSettle();
    expect(top(t).uri.path, AppRoutes.remote);
  });

  testWidgets('a_slow_saved_tv_list_counts_as_not_paired', (t) async {
    await pumpDiscover(
      t,
      overrides: [
        savedDevicesProvider.overrideWith(
          (ref) => const Stream<List<SavedDevice>>.empty(),
        ),
      ],
    );
    await found(t, [tv('Den')]);
    expect(find.text('Paired'), findsNothing);
  });

  testWidgets('discovery_error_offers_scan_again', (t) async {
    await pumpDiscover(t);
    discoveries.created.single.fail(
      NsdError(ErrorCause.securityIssue, 'denied'),
    );
    await t.pump();
    expect(find.text("Couldn't search for TVs"), findsOneWidget);
    expect(
      find.text('Check that Wi-Fi is on, then scan again.'),
      findsOneWidget,
    );

    await t.tap(find.text('Scan again'));
    await t.pump();

    expect(discoveries.created, hasLength(2));
    expect(find.text("Couldn't search for TVs"), findsNothing);
    expect(find.text('Looking for TVs on this Wi-Fi…'), findsOneWidget);
  });

  testWidgets('try_demo_starts_demo_and_opens_remote', (t) async {
    await pumpDiscover(t);
    await t.tap(find.text('Try demo'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();

    expect(top(t).uri.path, AppRoutes.remote);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(containerOf(t).read(activeTargetProvider), const DemoTarget());
  });

  testWidgets('leaving_the_screen_stops_discovery', (t) async {
    await pumpDiscover(t);
    final discovery = discoveries.created.single;
    expect(discovery.stopped, isFalse);

    await t.tap(find.text('Try demo'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();

    expect(discovery.stopped, isTrue);
  });

  testWidgets('discovery_screen_reflows_at_200_percent_text', (t) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);

    // Troubleshooting state, and its sheet.
    await pumpDiscover(t, textScale: 2);
    await waitForTimeout(t);
    expect(find.text('No TVs found yet'), findsOneWidget);
    expect(t.takeException(), isNull);
    // At 200% the empty state scrolls; the button starts below the fold.
    await t.ensureVisible(find.text('Troubleshooting'));
    await t.tap(find.text('Troubleshooting'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('same Wi-Fi network'),
      ),
      findsOneWidget,
    );

    // List state, with the widest trailing label.
    discoveries = FakeTvDiscoveries();
    await pumpDiscover(t, textScale: 2);
    await found(t, [
      tv('Living Room TV with a rather long name', legacy: true),
      tv('Den'),
    ]);
    expect(t.takeException(), isNull);
    expect(find.text('Update needed'), findsOneWidget);
    expect(find.text('Try demo'), findsOneWidget);
  });

  testWidgets('discovery_has_a_settings_button', (t) async {
    await pumpDiscover(t);
    final button = find.widgetWithIcon(IconButton, Icons.settings_outlined);
    expect(button, findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    final size = t.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await t.tap(button);
    await t.pumpAndSettle();
    expect(
      t.widget<SettingsScreen>(find.byType(SettingsScreen)).fromSetup,
      isTrue,
    );
    expect(top(t).uri.toString(), AppRoutes.settingsFromSetup);

    await t.pageBack();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(find.text('Choose your TV'), findsOneWidget);
  });

  testWidgets('discovery_app_bar_keeps_its_title_at_200_percent_text', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);

    for (final brightness in Brightness.values) {
      for (final scaler in const <TextScaler>[
        TextScaler.linear(2),
        NonlinearTwoXScaler(),
      ]) {
        final reason = '${brightness.name} $scaler';
        discoveries = FakeTvDiscoveries();
        await pumpDiscover(t, textScaler: scaler, brightness: brightness);
        expect(t.takeException(), isNull, reason: reason);
        expect(find.text('Choose your TV'), findsOneWidget, reason: reason);
        final button = find.widgetWithIcon(
          IconButton,
          Icons.settings_outlined,
        );
        expect(button, findsOneWidget, reason: reason);
        expect(
          t.getSize(button).height,
          greaterThanOrEqualTo(48),
          reason: reason,
        );
        // The title keeps the room left beside the action.
        final title = t.getRect(find.text('Choose your TV'));
        expect(title.right, lessThanOrEqualTo(t.getRect(button).left));
      }
    }
  });

  group('empty_state_icon_is_excluded_from_semantics', () {
    void expectExcluded(WidgetTester t, IconData icon) {
      final nearest = find
          .ancestor(
            of: find.byIcon(icon),
            matching: find.byType(ExcludeSemantics),
          )
          .first;
      final excluder = t.widget<ExcludeSemantics>(nearest);
      expect(excluder.excluding, isTrue);
      expect(excluder.child, isA<Icon>());
    }

    testWidgets('for_the_empty_state', (t) async {
      await pumpDiscover(t);
      await waitForTimeout(t);
      expectExcluded(t, Icons.tv_outlined);
    });

    testWidgets('for_the_error_state', (t) async {
      await pumpDiscover(t);
      discoveries.created.single.fail(
        NsdError(ErrorCause.securityIssue, 'denied'),
      );
      await t.pump();
      expectExcluded(t, Icons.wifi_off);
    });
  });

  test('the_empty_timeout_is_ten_seconds', () {
    expect(discoveryEmptyTimeout, const Duration(seconds: 10));
  });
}
