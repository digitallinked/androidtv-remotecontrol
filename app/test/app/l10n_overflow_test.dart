import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/fitted_label.dart';
import 'package:tv_remote/core/ads/ads_service.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';

import '../helpers/a11y.dart';
import '../helpers/fake_ads_sdk.dart';
import '../helpers/fake_consent_service.dart';
import '../helpers/fake_pairing_client.dart';
import '../helpers/fake_purchase_service.dart';
import '../helpers/fake_remote_session.dart';
import '../helpers/fake_tracking_service.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/gather_consent.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/in_memory_shortcut_repository.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/pseudo_localizations.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/test_app_config.dart';
import '../helpers/test_devices.dart';
import '../helpers/test_premium.dart';

/// How every screen of a sweep is shown.
typedef _Look = ({
  Brightness brightness,
  Size size,
  double textScale,
  TextScaler? textScaler,
  Locale? locale,
  List<LocalizationsDelegate<Object?>>? delegates,
});

/// A screen of the sweep: the part of the app it belongs to, and how to open
/// it as a user would meet it. Openers find what they tap through the
/// strings of the locale on show, so they work in any language.
typedef _Screen = ({
  String group,
  bool ios,
  Future<void> Function(WidgetTester t, _Look look) open,
});

const String _tvName = 'Living Room TV 3';
const String _otherTvName = 'Bedroom TV';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

/// The colour and media rows need a taller screen: a 640 dp remote gives
/// its pad the room and drops the quick row by design.
const Set<String> _tallScreens = {'remote_colour_row', 'remote_media_row'};

/// A context inside the app's `Localizations`, on any screen (the update
/// gate replaces the navigator).
BuildContext _inside(WidgetTester t) => t.element(
  find
      .descendant(
        of: find.byType(Localizations).first,
        matching: find.byType(Directionality),
      )
      .first,
);

/// The strings of the locale on show.
AppLocalizations _l(WidgetTester t) => AppLocalizations.of(_inside(t));

void _expectOn(Finder landmark, String name) =>
    expect(landmark, findsWidgets, reason: '$name is on show');

/// A shortcut store whose stream always fails.
class _UnreadableShortcuts extends InMemoryShortcutRepository {
  @override
  Stream<List<AppEntry>> watchAll() => Stream.error(StateError('disk'));
}

/// Hands out the discovery fakes of the screen being opened.
FakeTvDiscoveries _discoveries = FakeTvDiscoveries();

Future<SettingsStore> _pump(
  WidgetTester t,
  _Look look, {
  required String route,
  List<Override> overrides = const [],
  bool settle = true,
  Future<void> Function(SettingsStore store)? prepareSettings,
  AppDatabase? database,
}) async {
  t.view
    ..physicalSize = look.size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return pumpRouterApp(
    t,
    initialLocation: route,
    brightness: look.brightness,
    textScale: look.textScale,
    textScaler: look.textScaler,
    locale: look.locale,
    localizationsDelegates: look.delegates,
    settle: settle,
    prepareSettings: prepareSettings,
    overrides: overrides,
    database: database,
  );
}

/// Pumps [route] with one saved TV in the repository the pages read.
Future<void> _pumpWithSavedTv(
  WidgetTester t,
  _Look look,
  String route, {
  InMemoryShortcutRepository? shortcuts,
  InMemoryDeviceRepository? devices,
  List<Override> overrides = const [],
}) => _pump(
  t,
  look,
  route: route,
  prepareSettings: shortcuts == null
      ? null
      : (store) => store.setShortcutsSeeded(true),
  overrides: [
    deviceRepositoryProvider.overrideWithValue(
      devices ?? InMemoryDeviceRepository([savedTv()]),
    ),
    savedDevicesProvider.overrideWith(
      (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
    ),
    if (shortcuts != null)
      shortcutRepositoryProvider.overrideWithValue(shortcuts),
    ...overrides,
  ],
);

/// Brings [finder] into view and taps it, without settling.
Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder.first);
  await t.pump();
  await t.tap(finder.first);
}

/// Taps the text [text], scrolling a lazily built list to it first.
Future<void> _tapText(WidgetTester t, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await t.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await _tap(t, find.text(text));
  await t.pumpAndSettle();
}

Future<void> _close(WidgetTester t) async {
  await t.tap(find.byTooltip(_l(t).closeAction).last);
  await t.pumpAndSettle();
}

/// Opens discovery: it does not settle, the search spinner never stops.
Future<void> _openDiscovery(WidgetTester t, _Look look) async {
  _discoveries = FakeTvDiscoveries();
  await _pump(
    t,
    look,
    route: AppRoutes.discover,
    settle: false,
    overrides: [
      tvDiscoveryFactoryProvider.overrideWithValue(_discoveries.create),
    ],
  );
  await t.pump();
}

Future<void> _waitForEmpty(WidgetTester t, String name) async {
  await t.pump(discoveryEmptyTimeout);
  await t.pump();
  _expectOn(find.text(_l(t).discoverEmptyTitle), name);
}

/// Opens pairing as discovery does, pushed over the TV list. It does not
/// settle: the countdown never stops.
Future<void> _openPairing(
  WidgetTester t,
  _Look look, {
  void Function(FakePairingClient client)? script,
}) async {
  final clients = FakePairingClients()..onCreate = script;
  await _pump(
    t,
    look,
    route: AppRoutes.discover,
    settle: false,
    overrides: [pairingClientFactoryProvider.overrideWithValue(clients.create)],
  );
  final target = tv(_tvName);
  final router = ProviderScope.containerOf(
    t.element(find.byType(MaterialApp)),
  ).read(appRouterProvider);
  unawaited(router.push(AppRoutes.pair(target.serviceName), extra: target));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _enterCode(WidgetTester t, String code) async {
  await t.enterText(find.byType(TextField), code);
  await t.pump();
  await t.pump();
}

/// Opens the remote on a session in [state], with two saved TVs.
Future<FakeRemoteSession> _openRemote(
  WidgetTester t,
  _Look look, {
  TvConnectionState state = _connected,
  Future<void> Function(SettingsStore store)? prepareSettings,
}) async {
  final devices = [
    savedTv(),
    savedTv(name: _otherTvName, host: '192.168.0.21'),
  ];
  final fake = FakeRemoteSession(
    pairingTarget: devices.first.toDiscoveredTv(),
    initial: state,
  )..push(const VolumeChanged(12, 40, false));
  await _pump(
    t,
    look,
    route: AppRoutes.remote,
    prepareSettings: prepareSettings,
    overrides: [
      remoteSessionProvider.overrideWith((ref) async => fake),
      deviceRepositoryProvider.overrideWithValue(
        InMemoryDeviceRepository(devices),
      ),
      savedDevicesProvider.overrideWith((ref) => Stream.value(devices)),
    ],
  );
  return fake;
}

Future<void> _openKeyboard(WidgetTester t, String name) async {
  await _tap(t, find.bySemanticsLabel(_l(t).keyKeyboard));
  await t.pumpAndSettle();
  _expectOn(find.text(_l(t).keyboardTitle), name);
}

Future<void> _next(WidgetTester t, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await _tap(t, find.text(_l(t).onboardingNext));
    await t.pumpAndSettle();
  }
}

Future<void> _openDemo(WidgetTester t, _Look look) async {
  await _pump(t, look, route: AppRoutes.onboarding);
  await _tap(t, find.text(_l(t).onboardingTryDemo));
  // The remote opens, then the demo TV connects after 600 ms.
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
  await t.pumpAndSettle();
}

/// Every route of [AppRoutes] (with a saved TV, the demo and a paywall
/// source), their other states, and the sheets and dialogs that open on
/// them (Phases 5–7 and Task 8.4).
final Map<String, _Screen> _screens = {
  // Onboarding.
  'onboarding_connect': (
    group: 'onboarding',
    ios: false,
    open: (t, look) async {
      await _pump(t, look, route: AppRoutes.onboarding);
      _expectOn(find.text(_l(t).onboardingConnectTitle), 'card 1');
    },
  ),
  'onboarding_control': (
    group: 'onboarding',
    ios: false,
    open: (t, look) async {
      await _pump(t, look, route: AppRoutes.onboarding);
      await _next(t);
      _expectOn(find.text(_l(t).onboardingControlTitle), 'card 2');
    },
  ),
  'onboarding_apps': (
    group: 'onboarding',
    ios: false,
    open: (t, look) async {
      await _pump(t, look, route: AppRoutes.onboarding);
      await _next(t, 2);
      _expectOn(find.text(_l(t).onboardingAppsTitle), 'card 3');
    },
  ),
  'ios_local_network_explainer': (
    group: 'onboarding',
    ios: true,
    open: (t, look) async {
      await _pump(t, look, route: AppRoutes.onboarding);
      await _tap(t, find.text(_l(t).onboardingSkip));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).onboardingLocalNetworkTitle), 'explainer');
    },
  ),

  // Discovery and its sheets.
  'discovery_searching': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      _expectOn(find.text(_l(t).discoverSearching), 'searching');
    },
  ),
  'discovery_empty': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      await _waitForEmpty(t, 'empty');
    },
  ),
  'discovery_found': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      _discoveries.created.last.emit([
        tv('Old TV', legacy: true),
        tv(_tvName),
      ]);
      await t.pump();
      _expectOn(find.text(_l(t).discoverUpdateNeeded), 'found');
    },
  ),
  'manual_ip_sheet': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      await _tap(t, find.text(_l(t).discoverEnterIp));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).manualIpLabel), 'manual IP');
    },
  ),
  'manual_ip_sheet_invalid': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      await _tap(t, find.text(_l(t).discoverEnterIp));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '999.1.1.1');
      await _tap(t, find.text(_l(t).manualIpContinue));
      await t.pump();
      _expectOn(find.text(_l(t).manualIpError), 'manual IP error');
    },
  ),
  'troubleshooting_sheet_from_discovery': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      await _waitForEmpty(t, 'empty');
      await _tap(t, find.text(_l(t).discoverTroubleshooting));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).troubleshootTitle), 'troubleshooting');
    },
  ),
  'legacy_service_sheet': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      _discoveries.created.last.emit([tv('Old TV', legacy: true)]);
      await t.pump();
      await _tap(t, find.text('Old TV'));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).legacyTitle), 'legacy');
    },
  ),

  // Pairing.
  'pairing_waiting_for_code': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(t, look);
      _expectOn(find.text(_l(t).pairExpiresIn(60)), 'waiting');
    },
  ),
  'pairing_verifying': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(t, look, script: (c) => c.holdSubmit = Completer());
      await _enterCode(t, 'AB12CD');
      _expectOn(find.text(_l(t).pairVerifying), 'verifying');
    },
  ),
  'pairing_code_mismatch': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(t, look);
      await _enterCode(t, '000000');
      _expectOn(find.text(_l(t).pairCodeMismatch), 'mismatch');
    },
  ),
  'pairing_bad_code': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(
        t,
        look,
        script: (c) =>
            c.submitError = const PairingException(PairingFailure.badSecret),
      );
      await _enterCode(t, 'AB12CD');
      _expectOn(find.text(_l(t).pairRejectedTitle), 'rejected');
    },
  ),
  'pairing_code_expired': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(t, look);
      await t.pump(const Duration(seconds: 60));
      _expectOn(find.text(_l(t).pairExpiredTitle), 'expired');
    },
  ),
  'pairing_timed_out': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(
        t,
        look,
        script: (c) =>
            c.startError = const PairingException(PairingFailure.timeout),
      );
      _expectOn(find.text(_l(t).pairNoResponseTitle(_tvName)), 'timed out');
    },
  ),
  'pairing_unreachable': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(
        t,
        look,
        script: (c) => c.startError = const PairingException(
          PairingFailure.connectionFailed,
        ),
      );
      _expectOn(find.text(_l(t).pairCantReachTitle(_tvName)), 'unreachable');
    },
  ),
  'pairing_not_found': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _pump(t, look, route: AppRoutes.pair('Den'), settle: false);
      await t.pump();
      await t.pump();
      _expectOn(find.text(_l(t).pairNotFoundTitle), 'not found');
    },
  ),

  // The remote, its states, sheets and dialogs, and the demo.
  'remote_connected': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look);
      _expectOn(find.text(_l(t).remotePadTouchpad), 'remote');
    },
  ),
  'remote_no_tv': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.remote,
        overrides: [remoteSessionProvider.overrideWith((ref) async => null)],
      );
      _expectOn(find.text(_l(t).remoteNoTvTitle), 'no TV');
    },
  ),
  'remote_reconnecting': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(
        t,
        look,
        state: const TvConnectionState(
          status: ConnectionStatus.reconnecting,
          attempt: 1,
        ),
      );
      _expectOn(find.text(_l(t).statusReconnecting), 'reconnecting');
    },
  ),
  'remote_offline': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look, state: _offline);
      _expectOn(find.text(_l(t).statusReconnectAction), 'offline');
    },
  ),
  'remote_needs_pairing': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(
        t,
        look,
        state: const TvConnectionState(status: ConnectionStatus.needsPairing),
      );
      _expectOn(find.text(_l(t).statusPairAgainAction), 'needs pairing');
    },
  ),
  'remote_dpad': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(
        t,
        look,
        prepareSettings: (s) => s.setNavigationStyle(NavigationStyle.dpad),
      );
      _expectOn(find.byType(Dpad), 'D-pad');
    },
  ),
  'remote_numbers': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look);
      await _tap(t, find.text(_l(t).remotePadNumbers));
      await t.pumpAndSettle();
      _expectOn(find.bySemanticsLabel(_l(t).keyNumber(5)), 'numbers');
    },
  ),
  'remote_colour_row': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(
        t,
        look,
        prepareSettings: (s) => s.setQuickAccessRow(QuickAccessRow.colourKeys),
      );
      _expectOn(find.bySemanticsLabel(_l(t).keyRed), 'colour row');
    },
  ),
  'remote_media_row': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(
        t,
        look,
        prepareSettings: (s) => s.setQuickAccessRow(QuickAccessRow.mediaKeys),
      );
      _expectOn(find.bySemanticsLabel(_l(t).keyPlayPause), 'media row');
    },
  ),
  'remote_session_error': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.remote,
        overrides: [
          remoteSessionProvider.overrideWith(
            (ref) async => throw const IdentityStoreException('locked'),
          ),
        ],
      );
      _expectOn(find.text(_l(t).remoteSessionErrorTitle), 'session error');
    },
  ),
  'keyboard_sheet': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look);
      await _openKeyboard(t, 'keyboard');
    },
  ),
  'keyboard_sheet_not_connected': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      final fake = await _openRemote(t, look);
      await _openKeyboard(t, 'keyboard');
      fake.emit(_offline);
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).keyboardNotConnected), 'keyboard offline');
    },
  ),
  'wol_setup_sheet': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look, state: _offline);
      await t.longPress(find.byType(PowerButton));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).wolSetupTitle(_tvName)), 'Wake-on-LAN');
    },
  ),
  'device_switcher_sheet': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look);
      await _tap(t, find.byTooltip(_l(t).remoteSwitchTv));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).remoteManageTvs), 'switcher');
    },
  ),
  'identity_changed_dialog': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      final fake = await _openRemote(t, look);
      fake.emit(
        const TvConnectionState(
          status: ConnectionStatus.needsPairing,
          lastError: RemoteCloseReason.serverKeyChanged,
        ),
      );
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).remoteIdentityChangedTitle), 'identity');
    },
  ),
  'demo_remote': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openDemo(t, look);
      _expectOn(find.text(_l(t).demoBadgeLabel), 'demo');
      _expectOn(find.text(_l(t).tvPreviewTitle), 'demo');
    },
  ),
  'demo_leave_dialog': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openDemo(t, look);
      await _tap(t, find.text(_l(t).demoLeaveAction));
      await t.pumpAndSettle();
      _expectOn(find.byType(AppDialog<bool>), 'leave demo');
      _expectOn(find.text(_l(t).demoLeaveTitle), 'leave demo');
    },
  ),

  // Apps.
  'apps': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.apps);
      _expectOn(find.text(_l(t).appsYourApps), 'apps');
    },
  ),
  'apps_search_more_apps': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.apps);
      await t.enterText(find.byType(TextField), 'plex');
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).appsMoreApps), 'more apps');
    },
  ),
  'apps_search_no_match': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.apps);
      await t.enterText(find.byType(TextField), 'zzzz');
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).appsNoMatches('zzzz')), 'no match');
    },
  ),
  'apps_empty': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.apps,
        shortcuts: InMemoryShortcutRepository(),
      );
      _expectOn(find.text(_l(t).appsEmptyTitle), 'apps empty');
    },
  ),
  'apps_load_failed': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.apps,
        shortcuts: _UnreadableShortcuts(),
      );
      _expectOn(find.text(_l(t).appsLoadFailed), 'apps failed');
    },
  ),
  'manage_apps': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      _expectOn(find.text(_l(t).manageAppsReorderHint), 'edit apps');
    },
  ),
  'add_app_sheet': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      await t.tap(find.byTooltip(_l(t).manageAppsAdd));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).addAppCustom), 'add app');
    },
  ),
  'add_app_sheet_by_id': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      await t.tap(find.byTooltip(_l(t).manageAppsAdd));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('add_app_search')),
        'com.example.newapp',
      );
      await t.pumpAndSettle();
      _expectOn(find.byKey(const ValueKey('add_app_search')), 'add by id');
    },
  ),
  'shortcut_editor_new': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      await t.tap(find.byTooltip(_l(t).manageAppsAdd));
      await t.pumpAndSettle();
      await _tapText(t, _l(t).addAppCustom);
      _expectOn(find.text(_l(t).commonSave), 'new shortcut');
    },
  ),
  'shortcut_editor_edit': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      // At 200% the row can sit below the fold.
      await _tap(t, find.byTooltip(_l(t).manageAppsEdit('Netflix')));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).commonSave), 'edit shortcut');
    },
  ),
  'reset_apps_dialog': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      await t.tap(find.byType(PopupMenuButton<void>));
      await t.pumpAndSettle();
      await _tapText(t, _l(t).manageAppsReset);
      _expectOn(find.text(_l(t).manageAppsResetTitle), 'reset');
    },
  ),

  // Your TVs.
  'devices': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.devices);
      _expectOn(find.text(_l(t).pageTitleDevices), 'your TVs');
    },
  ),
  'devices_load_failed': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.devices,
        devices: InMemoryDeviceRepository()..watchError = StateError('disk'),
      );
      _expectOn(find.text(_l(t).devicesLoadFailed), 'your TVs failed');
    },
  ),
  'edit_device': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.editDevice(_tvName));
      _expectOn(find.text(_l(t).editDeviceRemove), 'edit TV');
    },
  ),
  'mac_help_sheet': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.editDevice(_tvName));
      await _tapText(t, _l(t).editDeviceWolHelp);
      _expectOn(find.byTooltip(_l(t).closeAction), 'MAC help');
    },
  ),
  'remove_tv_dialog': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.editDevice(_tvName));
      await _tapText(t, _l(t).editDeviceRemove);
      _expectOn(find.text(_l(t).editDeviceRemoveTitle(_tvName)), 'remove');
    },
  ),

  // Settings.
  'settings': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settings);
      _expectOn(find.text(_l(t).pageTitleSettings), 'settings');
    },
  ),
  'settings_from_setup': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pump(t, look, route: AppRoutes.settingsFromSetup);
      _expectOn(find.text(_l(t).pageTitleSettings), 'settings from setup');
    },
  ),
  'settings_appearance': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsAppearance);
      _expectOn(find.text(_l(t).pageTitleAppearance), 'appearance');
    },
  ),
  'settings_remote_layout': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsRemoteLayout);
      _expectOn(find.text(_l(t).pageTitleRemoteLayout), 'remote layout');
    },
  ),
  'settings_remote_behaviour': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsRemoteBehaviour);
      _expectOn(find.text(_l(t).pageTitleRemoteBehaviour), 'behaviour');
    },
  ),
  'settings_help': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsHelp);
      _expectOn(find.text(_l(t).pageTitleHelp), 'help');
    },
  ),
  'help_troubleshooting_sheet': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsHelp);
      await _tapText(t, _l(t).helpTroubleshootingAction);
      _expectOn(find.text(_l(t).troubleshootTitle), 'help troubleshooting');
      await _close(t);
    },
  ),
  'feedback_dialog': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsHelp);
      await _tapText(t, _l(t).settingsFeedback);
      _expectOn(find.text(_l(t).feedbackTitle), 'feedback');
    },
  ),
  'settings_about': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsAbout);
      _expectOn(find.text(_l(t).pageTitleAbout), 'about');
    },
  ),
  'settings_privacy': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.settingsPrivacy,
        overrides: [
          consentServiceProvider.overrideWithValue(
            FakeConsentService(optionsRequired: true),
          ),
        ],
      );
      _expectOn(find.text(_l(t).pageTitlePrivacyChoices), 'privacy');
    },
  ),
  'update_gate': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.settings,
        overrides: [
          appConfigProvider.overrideWith(
            () => TestAppConfig({'min_supported_version': '9.0.0'}),
          ),
        ],
      );
      _expectOn(find.text(_l(t).updateRequiredTitle), 'update gate');
    },
  ),
  'tracking_preprompt': (
    group: 'settings',
    ios: true,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.settings,
        overrides: [
          adsSdkProvider.overrideWithValue(FakeAdsSdk(loads: true)),
          trackingServiceProvider.overrideWithValue(
            FakeTrackingService(current: TrackingStatus.notDetermined),
          ),
        ],
      );
      await gatherConsent(t);
      _expectOn(find.text(_l(t).trackingPrepromptTitle), 'pre-prompt');
    },
  ),

  // Premium.
  'paywall_ready': (
    group: 'paywall',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.paywall(source: PaywallSource.settings),
        overrides: [
          purchaseServiceProvider.overrideWithValue(
            FakePurchaseService(offer: testOffer()),
          ),
        ],
      );
      _expectOn(find.text(_l(t).paywallHeadline), 'paywall');
    },
  ),
  'paywall_active': (
    group: 'paywall',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.paywall(source: PaywallSource.themes),
        overrides: [
          premiumProvider.overrideWith(
            () => TestPremium(
              PremiumState(
                isPremium: true,
                known: true,
                expiresAt: DateTime.utc(2100),
              ),
            ),
          ),
        ],
      );
      _expectOn(find.text(_l(t).pageTitlePaywall), 'paywall active');
    },
  ),

  // An address that doesn't exist.
  'route_not_found': (
    group: 'other',
    ios: false,
    open: (t, look) async {
      await _pump(t, look, route: '/no-such-page');
      _expectOn(find.text(_l(t).routeNotFoundTitle), 'not found');
    },
  ),
};

/// Opens every screen of the sweep in turn, as [locale] (or with
/// [delegates]' strings) at [textScale] (or with [textScaler]) on a [size]
/// screen in [brightness], and calls [check] with each screen's name once it
/// is on show. [groups] limits the sweep to those parts of the app.
///
/// Returns the names of the routes the screens were on.
Future<Set<String?>> forEachScreen(
  WidgetTester t,
  Future<void> Function(String name) check, {
  Locale? locale,
  List<LocalizationsDelegate<Object?>>? delegates,
  double textScale = 1,
  TextScaler? textScaler,
  Size size = const Size(320, 640),
  Brightness brightness = Brightness.light,
  Set<String>? groups,
}) async {
  var opened = 0;
  final routes = <String?>{};
  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    if (groups != null && !groups.contains(screen.group)) continue;
    final look = (
      brightness: brightness,
      size: _tallScreens.contains(name) ? Size(size.width, 844) : size,
      textScale: textScale,
      textScaler: textScaler,
      locale: locale,
      delegates: delegates,
    );
    final previous = debugDefaultTargetPlatformOverride;
    if (screen.ios) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await screen.open(t, look);
      final router = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      ).read(appRouterProvider);
      // An address that matches no route has no state.
      final matches = router.routerDelegate.currentConfiguration;
      routes.add(matches.isEmpty ? null : router.state.name);
      await check(name);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
    // Leave the screen before the next one: spinners never settle.
    await t.pumpWidget(const SizedBox.shrink());
    opened++;
  }
  expect(opened, greaterThan(0), reason: 'the sweep opened screens');
  return routes;
}

/// Every named route of the app was on show in [routes], so a new route
/// has to join the sweep.
void _expectEveryRoute(Set<String?> routes, String why) {
  final missing = AppRouteNames.all.difference(routes);
  expect(missing, isEmpty, reason: '$why: routes the sweep never opens');
}

/// The Malay strings are on show, the second half included.
void _expectMalay(WidgetTester t, String name) {
  expect(Localizations.localeOf(_inside(t)), const Locale('ms'), reason: name);
  expect(_l(t).statusConnected, 'Disambungkan', reason: name);
  expect(_l(t).paywallRestore, 'Pulihkan pembelian', reason: name);
}

/// Whether [paragraph] cuts its text: it ran past its lines, or is wider
/// than its box on one line, or taller than its box.
bool _truncated(RenderParagraph paragraph) {
  final width = paragraph.size.width;
  return paragraph.didExceedMaxLines ||
      (!paragraph.softWrap &&
          paragraph.getMaxIntrinsicWidth(double.infinity) > width + 0.5) ||
      paragraph.getMaxIntrinsicHeight(width) > paragraph.size.height + 0.5;
}

/// The Remote layout page's preview: a scaled-down picture of the remote,
/// one image to a screen reader, never tapped.
final Finder _layoutPreview = find.byKey(const Key('layout_preview'));

/// The `RichText`s under [of] that hold words; icons are text too, in their
/// font, and have no words to lose. Text inside the layout preview is part
/// of a picture, so it is left out; the real remote is checked on its own.
Iterable<(Element, RenderParagraph)> _paragraphs(Finder of) sync* {
  final inPicture = find
      .descendant(of: _layoutPreview, matching: find.byType(RichText))
      .evaluate()
      .toSet();
  for (final element
      in find.descendant(of: of, matching: find.byType(RichText)).evaluate()) {
    if (inPicture.contains(element)) continue;
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty || text.runes.length == 1) continue;
    yield (element, paragraph);
  }
}

/// [element]'s text is shown in full, or ends in an ellipsis and gives its
/// full text to a screen reader (the Phase 7 rule). Semantics must be on.
void _expectReadable(WidgetTester t, Element element, String why) {
  final paragraph = element.renderObject! as RenderParagraph;
  if (!_truncated(paragraph)) return;
  final text = paragraph.text.toPlainText();
  final reason = '$why: "$text" is cut';
  expect(paragraph.overflow, TextOverflow.ellipsis, reason: reason);
  final data = t
      .getSemantics(find.byElementPredicate((e) => e == element))
      .getSemanticsData();
  expect(
    '${data.label} ${data.tooltip}',
    contains(text),
    reason: '$reason: semantics "${data.label}" / "${data.tooltip}"',
  );
}

/// App-bar titles may end in an ellipsis only with their full text in
/// semantics; button labels are never cut.
///
/// Two kinds of button text follow the title rule instead, by design:
/// - a TV name (the user's data, not our copy), such as the remote's TV
///   switcher, ends in an ellipsis like a long TV name does everywhere
///   (Task 8.4);
/// - a `FittedLabel` (the pad tabs) ellipsises once it is back at its 100%
///   size; `l10n_short_labels_test` checks with the real font that it
///   doesn't at 100%.
void _expectTitlesAndButtonsReadable(WidgetTester t, String why) {
  for (final (element, _) in _paragraphs(find.byType(AppBar))) {
    _expectReadable(t, element, '$why app-bar title');
  }
  final tvNames = {_tvName, _otherTvName, _l(t).demoTvName};
  for (final (element, paragraph) in _paragraphs(
    find.byWidgetPredicate((w) => w is ButtonStyleButton),
  )) {
    if (tvNames.contains(paragraph.text.toPlainText())) {
      _expectReadable(t, element, '$why TV name');
      continue;
    }
    if (element.findAncestorWidgetOfExactType<FittedLabel>() != null) {
      _expectReadable(t, element, '$why fitted label');
      continue;
    }
    expect(
      _truncated(paragraph),
      isFalse,
      reason: '$why: button "${paragraph.text.toPlainText()}" is cut',
    );
  }
}

void main() {
  testWidgets('every_screen_fits_the_pseudo_locale_at_320dp', (t) async {
    for (final b in Brightness.values) {
      final seen = <String>[];
      final routes = await forEachScreen(
        t,
        (name) async {
          seen.add(name);
          // The pseudo strings are on show, not English.
          expect(
            _l(t).statusConnected,
            pseudo('Connected'),
            reason: '$name: the pseudo-locale is loaded',
          );
          expectNoClipping(t, reason: '$name ${b.name}');
        },
        delegates: [PseudoLocalizations.delegate],
        brightness: b,
      );
      expect(seen, _screens.keys.toList(), reason: 'every screen, ${b.name}');
      _expectEveryRoute(routes, b.name);
    }
  });

  testWidgets('every_screen_fits_320dp_in_malay_at_200_percent_text', (
    t,
  ) async {
    await withSemantics(t, () async {
      for (final b in Brightness.values) {
        final seen = <String>[];
        final routes = await forEachScreen(
          t,
          (name) async {
            seen.add(name);
            _expectMalay(t, name);
            final why = '$name ${b.name}';
            expectNoClipping(t, reason: why);
            _expectTitlesAndButtonsReadable(t, why);
          },
          locale: const Locale('ms'),
          textScale: 2,
          brightness: b,
        );
        expect(seen, _screens.keys.toList(), reason: 'every screen, ${b.name}');
        _expectEveryRoute(routes, b.name);
      }
    });
  });

  testWidgets('every_screen_fits_a_non_linear_text_scaler_in_malay', (
    t,
  ) async {
    await withSemantics(t, () async {
      for (final b in Brightness.values) {
        final seen = <String>[];
        await forEachScreen(
          t,
          (name) async {
            seen.add(name);
            _expectMalay(t, name);
            final why = '$name ${b.name} non-linear';
            expectNoClipping(t, reason: why);
            _expectTitlesAndButtonsReadable(t, why);
          },
          locale: const Locale('ms'),
          textScaler: const NonlinearTwoXScaler(),
          brightness: b,
        );
        expect(seen, _screens.keys.toList(), reason: 'every screen, ${b.name}');
      }
    });
  });

  testWidgets('malay_screens_meet_the_guidelines', (t) async {
    await withSemantics(t, () async {
      final seen = <String>[];
      await forEachScreen(
        t,
        (name) async {
          seen.add(name);
          _expectMalay(t, name);
          await expectMeetsGuidelines(t, reason: name);
        },
        locale: const Locale('ms'),
      );
      expect(seen, _screens.keys.toList(), reason: 'every screen');
    });
  });
}
