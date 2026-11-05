import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:tv_remote/core/crash/crash_scrubber.dart';
import 'package:tv_remote/core/crash/error_log.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';
import 'package:tv_remote/features/apps/presentation/widgets/app_tile.dart';
import 'package:tv_remote/features/discovery/application/discovery_controller.dart';
import 'package:tv_remote/features/discovery/data/discovery_providers.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/remote/presentation/widgets/dpad.dart';
import 'package:tv_remote/features/remote/presentation/widgets/pad_pager.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_app_tile.dart';
import 'package:tv_remote/features/remote/presentation/widgets/touchpad.dart';

import '../helpers/a11y.dart';
import '../helpers/disk_exception.dart';
import '../helpers/fake_ads_sdk.dart';
import '../helpers/fake_consent_service.dart';
import '../helpers/fake_pairing_client.dart';
import '../helpers/fake_purchase_service.dart';
import '../helpers/fake_remote_session.dart';
import '../helpers/fake_tracking_service.dart';
import '../helpers/fake_tv_discovery.dart';
import '../helpers/fake_wake_on_lan.dart';
import '../helpers/gather_consent.dart';
import '../helpers/in_memory_device_repository.dart';
import '../helpers/in_memory_secure_store.dart';
import '../helpers/in_memory_shortcut_repository.dart';
import '../helpers/nonlinear_text_scaler.dart';
import '../helpers/pseudo_localizations.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/recording_link_opener.dart';
import '../helpers/test_app_config.dart';
import '../helpers/test_devices.dart';
import '../helpers/test_identity.dart';
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

/// The app's provider container.
ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

/// The in-memory shortcut store the app runs on.
InMemoryShortcutRepository _shortcutStore(WidgetTester t) =>
    _container(t).read(shortcutRepositoryProvider)
        as InMemoryShortcutRepository;

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

/// Brings [finder] into view and taps it, without settling. A row a lazy
/// list hasn't built yet is scrolled to first.
Future<void> _tap(WidgetTester t, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(finder.first);
  await t.pump();
  await t.tap(finder.first);
}

/// Brings the page's first text field back into view after a tap further
/// down: a field half scrolled away is a short tap target.
Future<void> _backToFirstField(WidgetTester t) async {
  await t.ensureVisible(find.byType(TextField).first);
  await t.pumpAndSettle();
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
  List<Override> overrides = const [],
}) async {
  final clients = FakePairingClients()..onCreate = script;
  await _pump(
    t,
    look,
    route: AppRoutes.discover,
    settle: false,
    overrides: [
      pairingClientFactoryProvider.overrideWithValue(clients.create),
      ...overrides,
    ],
  );
  final target = tv(_tvName);
  final router = _container(t).read(appRouterProvider);
  unawaited(router.push(AppRoutes.pair(target.serviceName), extra: target));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _enterCode(WidgetTester t, String code) async {
  await t.enterText(find.byType(TextField), code);
  await t.pump();
  await t.pump();
}

/// Opens the remote on a session in [state], with two saved TVs; the first
/// has the Wake-on-LAN address [wolMac].
Future<FakeRemoteSession> _openRemote(
  WidgetTester t,
  _Look look, {
  TvConnectionState state = _connected,
  Future<void> Function(SettingsStore store)? prepareSettings,
  String? wolMac,
  List<Override> overrides = const [],
}) async {
  final devices = [
    savedTv(wolMac: wolMac),
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
      ...overrides,
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

/// Opens the new-shortcut editor from Edit apps.
Future<void> _openNewShortcut(WidgetTester t, _Look look) async {
  await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
  await t.tap(find.byTooltip(_l(t).manageAppsAdd));
  await t.pumpAndSettle();
  await _tapText(t, _l(t).addAppCustom);
  _expectOn(find.text(_l(t).commonSave), 'new shortcut');
}

/// Opens the paywall on [service], with its plans on show.
Future<void> _openPaywall(
  WidgetTester t,
  _Look look,
  FakePurchaseService service,
) async {
  await _pump(
    t,
    look,
    route: AppRoutes.paywall(source: PaywallSource.settings),
    overrides: [purchaseServiceProvider.overrideWithValue(service)],
  );
  _expectOn(find.text(_l(t).paywallHeadline), 'paywall');
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
      // The keyboard's Done submits: at 200% the sheet's button can sit
      // under its scrolling text.
      await t.testTextInput.receiveAction(TextInputAction.done);
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
    open: _openNewShortcut,
  ),
  'shortcut_editor_edit': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      // At 200% the row can sit below the fold, or not be built yet.
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
  'settings_error_log_empty': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsErrorLog);
      _expectOn(find.text(_l(t).pageTitleErrorLog), 'error log');
      _expectOn(find.text(_l(t).errorLogEmpty), 'empty error log');
    },
  ),
  'settings_error_log': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      final log = ErrorLog()
        ..bind(
          namesKnown: Future<void>.value(),
          scrubber: CrashScrubber.new,
          file: () async => null,
        );
      addTearDown(log.dispose);
      await t.pump();
      await log.recordError(StateError('a'), null, reason: 'discovery');
      await log.recordError(StateError('b'), null, fatal: true);
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.settingsErrorLog,
        overrides: [errorLogProvider.overrideWithValue(log)],
      );
      _expectOn(find.text(_l(t).errorLogCopyAll), 'error log');
    },
  ),
  'settings_error_log_copy_failed': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      final log = ErrorLog()
        ..bind(
          namesKnown: Future<void>.value(),
          scrubber: CrashScrubber.new,
          file: () async => null,
        );
      addTearDown(log.dispose);
      await t.pump();
      await log.recordError(StateError('a'), null, reason: 'discovery');
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.settingsErrorLog,
        overrides: [errorLogProvider.overrideWithValue(log)],
      );
      final messenger = t.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard');
          }
          return null;
        });
      await _tapText(t, _l(t).errorLogCopyAll);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      _expectOn(find.text(_l(t).errorLogCopyFailed), 'copy failed');
    },
  ),
  'settings_error_log_clear_dialog': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      final log = ErrorLog()
        ..bind(
          namesKnown: Future<void>.value(),
          scrubber: CrashScrubber.new,
          file: () async => null,
        );
      addTearDown(log.dispose);
      await t.pump();
      await log.recordError(StateError('a'), null);
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.settingsErrorLog,
        overrides: [errorLogProvider.overrideWithValue(log)],
      );
      await _tapText(t, _l(t).errorLogClear);
      _expectOn(find.text(_l(t).errorLogClearTitle), 'clear the error log');
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

  // Error, failure and unavailable states (Task 9.6, Ruling P9-R9).
  'discovery_failed': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      await _openDiscovery(t, look);
      // The platform's search can't start (Wi-Fi off, NSD refused).
      _discoveries.created.last.fail(StateError('nsd'));
      await t.pump();
      _expectOn(find.text(_l(t).discoverErrorTitle), 'search failed');
    },
  ),
  'discovery_open_failed': (
    group: 'discovery',
    ios: false,
    open: (t, look) async {
      // A TV added by IP address is found by mDNS; merging the rows fails.
      final devices = InMemoryDeviceRepository([
        savedTv(name: 'manual:192.168.0.20'),
      ])..failNextWrite = const DiskException();
      _discoveries = FakeTvDiscoveries();
      await _pump(
        t,
        look,
        route: AppRoutes.discover,
        settle: false,
        overrides: [
          tvDiscoveryFactoryProvider.overrideWithValue(_discoveries.create),
          deviceRepositoryProvider.overrideWithValue(devices),
          savedDevicesProvider.overrideWith((ref) => devices.watchAll()),
        ],
      );
      await t.pump();
      _discoveries.created.last.emit([tv(_tvName)]);
      await t.pump();
      await _tap(t, find.text(_tvName));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      _expectOn(find.text(_l(t).discoverOpenFailed), 'open failed');
    },
  ),
  'pairing_protocol_error': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(
        t,
        look,
        script: (c) =>
            c.startError = const PairingException(PairingFailure.protocolError),
      );
      _expectOn(find.text(_l(t).pairErrorTitle), 'pairing error');
    },
  ),
  'pairing_identity_failed': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      // The phone's key can't be stored, so there is nothing to pair with.
      final store = InMemorySecureKeyValueStore()
        ..throwOnWrite = const DiskException();
      await _openPairing(
        t,
        look,
        overrides: [
          identityStoreProvider.overrideWithValue(
            IdentityStore(store, generate: () async => testIdentity()),
          ),
        ],
      );
      _expectOn(find.text(_l(t).pairIdentityTitle), 'identity failed');
    },
  ),
  'pairing_save_failed': (
    group: 'pairing',
    ios: false,
    open: (t, look) async {
      await _openPairing(
        t,
        look,
        overrides: [
          deviceRepositoryProvider.overrideWithValue(
            InMemoryDeviceRepository()..failNextWrite = const DiskException(),
          ),
        ],
      );
      await _enterCode(t, 'AB12CD');
      await t.pump();
      _expectOn(find.text(_l(t).pairSaveFailedTitle), 'save failed');
    },
  ),
  'remote_wake_failed': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(
        t,
        look,
        state: _offline,
        wolMac: 'AA:BB:CC:DD:EE:FF',
        overrides: [
          wakeOnLanServiceProvider.overrideWithValue(
            FakeWakeOnLan()..result = false,
          ),
        ],
      );
      await t.longPress(find.byType(PowerButton));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).powerWakeFailed), 'wake failed');
    },
  ),
  'wol_setup_sheet_invalid': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look, state: _offline);
      await t.longPress(find.byType(PowerButton));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'AA:BB',
      );
      // The keyboard's Done saves: at 200% the sheet's button can sit
      // under its scrolling text.
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).wolMacError), 'MAC error');
    },
  ),
  'wol_setup_sheet_save_failed': (
    group: 'remote',
    ios: false,
    open: (t, look) async {
      await _openRemote(t, look, state: _offline);
      await t.longPress(find.byType(PowerButton));
      await t.pumpAndSettle();
      (_container(t).read(deviceRepositoryProvider) as InMemoryDeviceRepository)
              .failNextWrite =
          const DiskException();
      await t.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'AA:BB:CC:DD:EE:FF',
      );
      // The keyboard's Done saves: at 200% the sheet's button can sit
      // under its scrolling text.
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).wolSaveFailed), 'MAC save failed');
    },
  ),
  'manage_apps_load_failed': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.manageApps,
        shortcuts: _UnreadableShortcuts(),
      );
      _expectOn(find.text(_l(t).manageAppsEmpty), 'edit apps failed');
    },
  ),
  'manage_apps_save_failed': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      _shortcutStore(t).failNextWrite = const DiskException();
      await _tap(t, find.byTooltip(_l(t).manageAppsRemove('Netflix')));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).manageAppsSaveFailed), 'edit apps save');
    },
  ),
  'add_app_sheet_save_failed': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.manageApps);
      await t.tap(find.byTooltip(_l(t).manageAppsAdd));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('add_app_search')), 'kodi');
      await t.pumpAndSettle();
      _shortcutStore(t).failNextWrite = const DiskException();
      await _tap(
        t,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Kodi'),
        ),
      );
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).manageAppsSaveFailed), 'add app failed');
    },
  ),
  'shortcut_editor_invalid': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _openNewShortcut(t, look);
      await t.enterText(find.byKey(const ValueKey('shortcut_package')), 'x');
      await t.pump();
      await _tap(t, find.text(_l(t).commonSave));
      await t.pumpAndSettle();
      await _backToFirstField(t);
      _expectOn(find.text(_l(t).shortcutNameError), 'name error');
      _expectOn(find.text(_l(t).shortcutPackageError), 'package error');
    },
  ),
  'shortcut_editor_save_failed': (
    group: 'apps',
    ios: false,
    open: (t, look) async {
      await _openNewShortcut(t, look);
      await t.enterText(find.byKey(const ValueKey('shortcut_name')), 'Zed');
      await t.enterText(
        find.byKey(const ValueKey('shortcut_package')),
        'com.example.zed',
      );
      await t.pump();
      _shortcutStore(t).failNextWrite = const DiskException();
      await _tap(t, find.text(_l(t).commonSave));
      await t.pumpAndSettle();
      await _backToFirstField(t);
      _expectOn(find.text(_l(t).manageAppsSaveFailed), 'shortcut failed');
    },
  ),
  'edit_device_not_found': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.editDevice('Ghost TV'));
      _expectOn(find.text(_l(t).editDeviceNotFound), 'edit TV gone');
    },
  ),
  'edit_device_load_failed': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.editDevice(_tvName),
        devices: InMemoryDeviceRepository()..watchError = StateError('disk'),
      );
      _expectOn(find.text(_l(t).devicesLoadFailed), 'edit TV failed');
    },
  ),
  'edit_device_invalid': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.editDevice(_tvName));
      await t.enterText(find.byType(TextField).first, 'N' * 41);
      await t.enterText(find.byType(TextField).last, 'AA:BB');
      await t.pump();
      await _tap(t, find.text(_l(t).commonSave));
      await t.pumpAndSettle();
      await _backToFirstField(t);
      _expectOn(find.text(_l(t).editDeviceNameError), 'name error');
      _expectOn(find.text(_l(t).wolMacError), 'MAC error');
    },
  ),
  'edit_device_save_failed': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      final devices = InMemoryDeviceRepository([savedTv()]);
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.editDevice(_tvName),
        devices: devices,
      );
      await t.enterText(find.byType(TextField).first, 'Den');
      await t.pump();
      devices.failNextWrite = const DiskException();
      await _tap(t, find.text(_l(t).commonSave));
      await t.pumpAndSettle();
      await _backToFirstField(t);
      _expectOn(find.text(_l(t).editDeviceSaveFailed), 'save failed');
    },
  ),
  'edit_device_remove_failed': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      final devices = InMemoryDeviceRepository([savedTv()]);
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.editDevice(_tvName),
        devices: devices,
      );
      await _tapText(t, _l(t).editDeviceRemove);
      devices.failNextWrite = const DiskException();
      await _tap(t, find.text(_l(t).editDeviceRemoveConfirm));
      await t.pumpAndSettle();
      await _backToFirstField(t);
      _expectOn(find.text(_l(t).editDeviceRemoveFailed), 'remove failed');
    },
  ),
  'edit_device_wol_unavailable': (
    group: 'devices',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(
        t,
        look,
        AppRoutes.editDevice(_tvName),
        overrides: [wakeOnLanAvailableProvider.overrideWithValue(false)],
      );
      _expectOn(find.text(_l(t).editDeviceWolUnavailable), 'no Wake-on-LAN');
    },
  ),
  'help_faq_not_found': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pumpWithSavedTv(t, look, AppRoutes.settingsHelp);
      await _tapText(t, _l(t).faqNotFoundQ);
      _expectOn(find.text(_l(t).faqNotFoundA), 'FAQ answer');
    },
  ),
  'settings_link_failed': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.settingsPrivacy,
        overrides: [
          linkOpenerProvider.overrideWithValue(
            RecordingLinkOpener()..result = false,
          ),
        ],
      );
      await _tapText(t, _l(t).settingsPrivacy);
      _expectOn(find.text(_l(t).settingsLinkFailed), 'link failed');
    },
  ),
  'privacy_ad_choices_failed': (
    group: 'settings',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.settingsPrivacy,
        overrides: [
          consentServiceProvider.overrideWithValue(
            FakeConsentService(optionsRequired: true, optionsResult: false),
          ),
        ],
      );
      await _tapText(t, _l(t).privacyAdChoices);
      _expectOn(find.text(_l(t).privacyAdChoicesFailed), 'ad choices failed');
    },
  ),
  'update_gate_store_failed': (
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
          linkOpenerProvider.overrideWithValue(
            RecordingLinkOpener()..result = false,
          ),
        ],
      );
      await _tap(t, find.text(_l(t).updateRequiredAction));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).updateRequiredFailed), 'store failed');
    },
  ),
  'paywall_unavailable': (
    group: 'paywall',
    ios: false,
    open: (t, look) async {
      await _pump(
        t,
        look,
        route: AppRoutes.paywall(source: PaywallSource.settings),
        overrides: [
          purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
        ],
      );
      _expectOn(find.text(_l(t).paywallUnavailableTitle), 'unavailable');
    },
  ),
  'paywall_purchase_network_error': (
    group: 'paywall',
    ios: false,
    open: (t, look) async {
      await _openPaywall(
        t,
        look,
        FakePurchaseService(
          offer: testOffer(),
          nextPurchase: const PurchaseFailed(PurchaseFailure.network),
        ),
      );
      await _tap(t, find.text(_l(t).paywallContinue));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).paywallNetworkError), 'network error');
    },
  ),
  'paywall_purchase_failed': (
    group: 'paywall',
    ios: false,
    open: (t, look) async {
      await _openPaywall(
        t,
        look,
        FakePurchaseService(
          offer: testOffer(),
          nextPurchase: const PurchaseFailed(PurchaseFailure.unknown),
        ),
      );
      await _tap(t, find.text(_l(t).paywallContinue));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).paywallFailed), 'purchase failed');
    },
  ),
  'paywall_restore_failed': (
    group: 'paywall',
    ios: false,
    open: (t, look) async {
      await _openPaywall(
        t,
        look,
        FakePurchaseService(
          offer: testOffer(),
          nextRestore: RestoreOutcome.failed,
        ),
      );
      await _tap(t, find.text(_l(t).paywallRestore));
      await t.pumpAndSettle();
      _expectOn(find.text(_l(t).paywallRestoreFailed), 'restore failed');
    },
  ),
};

/// The screens that show an error, a failure or something unavailable: the
/// error-state sweep opens these (Ruling P9-R9).
const List<String> _errorStates = [
  'discovery_empty',
  'discovery_failed',
  'discovery_open_failed',
  'manual_ip_sheet_invalid',
  'troubleshooting_sheet_from_discovery',
  'legacy_service_sheet',
  'pairing_code_mismatch',
  'pairing_bad_code',
  'pairing_code_expired',
  'pairing_timed_out',
  'pairing_unreachable',
  'pairing_protocol_error',
  'pairing_identity_failed',
  'pairing_save_failed',
  'pairing_not_found',
  'remote_no_tv',
  'remote_reconnecting',
  'remote_offline',
  'remote_needs_pairing',
  'remote_session_error',
  'remote_wake_failed',
  'keyboard_sheet_not_connected',
  'wol_setup_sheet_invalid',
  'wol_setup_sheet_save_failed',
  'identity_changed_dialog',
  'apps_search_no_match',
  'apps_load_failed',
  'manage_apps_load_failed',
  'manage_apps_save_failed',
  'add_app_sheet_save_failed',
  'shortcut_editor_invalid',
  'shortcut_editor_save_failed',
  'devices_load_failed',
  'edit_device_not_found',
  'edit_device_load_failed',
  'edit_device_invalid',
  'edit_device_save_failed',
  'edit_device_remove_failed',
  'edit_device_wol_unavailable',
  'settings_privacy',
  'settings_link_failed',
  'privacy_ad_choices_failed',
  'update_gate',
  'update_gate_store_failed',
  'paywall_unavailable',
  'paywall_purchase_network_error',
  'paywall_purchase_failed',
  'paywall_restore_failed',
  'route_not_found',
];

/// Error strings no screen of the sweep shows, each with the reason and the
/// test that does show it. Keys come from `app_ms.arb` whose names match
/// [_errorKeyPattern].
const Map<String, String> _errorKeysNotInSweep = {};

/// The ARB keys that name an error, a failure or something unavailable.
final RegExp _errorKeyPattern = RegExp(
  '(Failed|Error|Unavailable|Offline|NotFound)',
);

/// Opens every screen of the sweep in turn, as [locale] (or with
/// [delegates]' strings) at [textScale] (or with [textScaler]) on a [size]
/// screen in [brightness], and calls [check] with each screen's name once it
/// is on show. [groups] limits the sweep to those parts of the app, and
/// [names] to those screens.
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
  Iterable<String>? names,
}) async {
  var opened = 0;
  final routes = <String?>{};
  final only = names?.toSet();
  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    if (groups != null && !groups.contains(screen.group)) continue;
    if (only != null && !only.contains(name)) continue;
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
      final router = _container(t).read(appRouterProvider);
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
  // A field's hint and value count: a screen reader reads them out.
  final spoken = [data.label, data.tooltip, data.hint, data.value];
  expect(
    spoken.join(' '),
    contains(text),
    reason: '$reason: semantics ${spoken.map((s) => '"$s"').join(' / ')}',
  );
}

/// App-bar, dialog and sheet titles may end in an ellipsis only with their
/// full text in semantics; button labels are never cut.
///
/// Two kinds of button text follow the title rule instead, by design:
/// - a TV name (the user's data, not our copy), such as the remote's TV
///   switcher, ends in an ellipsis like a long TV name does everywhere
///   (Task 8.4);
/// - a pad tab's `FittedLabel` (in the `SegmentedButton<PadPage>`)
///   ellipsises once it is back at its 100% size; `l10n_short_labels_test`
///   checks with the real font that it doesn't at 100%.
///
/// Dialog and sheet text follows the title rule too.
void _expectTitlesAndButtonsReadable(WidgetTester t, String why) {
  for (final (element, _) in _paragraphs(find.byType(AppBar))) {
    _expectReadable(t, element, '$why app-bar title');
  }
  // Dialogs and sheets: their titles, and everything else in them, are
  // shown in full or ellipsised with the full text in semantics.
  for (final (element, _) in _paragraphs(find.byType(Dialog))) {
    _expectReadable(t, element, '$why dialog');
  }
  for (final (element, _) in _paragraphs(find.byType(BottomSheet))) {
    _expectReadable(t, element, '$why sheet');
  }
  final tvNames = {_tvName, _otherTvName, _l(t).demoTvName};
  for (final (element, paragraph) in _paragraphs(
    find.byWidgetPredicate((w) => w is ButtonStyleButton),
  )) {
    if (tvNames.contains(paragraph.text.toPlainText())) {
      _expectReadable(t, element, '$why TV name');
      continue;
    }
    // Only the pad tabs: any other FittedLabel button has no real-font
    // test behind it, so it gets the button rule.
    if (element.findAncestorWidgetOfExactType<FittedLabel>() != null &&
        element.findAncestorWidgetOfExactType<SegmentedButton<PadPage>>() !=
            null) {
      _expectReadable(t, element, '$why pad tab');
      continue;
    }
    expect(
      _truncated(paragraph),
      isFalse,
      reason: '$why: button "${paragraph.text.toPlainText()}" is cut',
    );
  }
}

/// What the Malay sweeps showed: every paragraph's text, for
/// `every_error_string_is_opened_by_the_sweep`.
final Set<String> _renderedMalay = {};

/// Whether one of [element]'s ancestors is a widget of the private type
/// [typeName]: a row or strip of the app that has no public type.
bool _under(Element element, String typeName) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    found = ancestor.widget.runtimeType.toString() == typeName;
    return !found;
  });
  return found;
}

/// Whether [decorator]'s label is floated above its field.
bool _floated(InputDecorator decorator) =>
    switch (decorator.decoration.floatingLabelBehavior ??
    FloatingLabelBehavior.auto) {
      FloatingLabelBehavior.never => false,
      FloatingLabelBehavior.always => true,
      FloatingLabelBehavior.auto => !decorator.isEmpty || decorator.isFocused,
    };

/// Spoken by [_expectTouchpadHintSpoken] instead of [_expectReadable].
const String _touchpadHint = 'touchpad idle hint';

/// Why [element]'s text may end in an ellipsis, or null when it must be
/// shown whole. Each case is matched by its role, never by widget type
/// alone, and keeps its full text in semantics:
/// - (a) an app-bar title (the Phase 7 rule);
/// - (b) a TV name the user gave or the TV reports (P8-C14);
/// - (c) text inside the Remote layout preview (decision #50), which
///   [_paragraphs] already leaves out;
/// - a pad tab's `FittedLabel` (Task 8.13), and a colour key's, but only in
///   the colour-key row (P9-C6.2): `l10n_short_labels_test` checks both with
///   the real font at 100%;
/// - a field's floated label, the field's own semantics label (P9-C6.1);
///   unfloated, it must fit;
/// - an app's name in its tile, and an app id in an Edit apps or add-app
///   row: data, like TV names (P9-C6.3, 4);
/// - the touchpad's idle hint, whose guidance the pad speaks as its hint
///   (P9-C6.6).
String? _mayEllipsize(WidgetTester t, Element element, String text) {
  if (element.findAncestorWidgetOfExactType<AppBar>() != null) {
    return 'app-bar title';
  }
  if ({_tvName, _otherTvName, 'Old TV', _l(t).demoTvName}.contains(text)) {
    return 'TV name';
  }
  if (element.findAncestorWidgetOfExactType<FittedLabel>() != null) {
    if (element.findAncestorWidgetOfExactType<SegmentedButton<PadPage>>() !=
        null) {
      return 'pad tab';
    }
    if (_under(element, '_ColourKeys')) return 'colour key';
  }
  final decorator = element.findAncestorWidgetOfExactType<InputDecorator>();
  if (decorator != null &&
      text == decorator.decoration.labelText &&
      _floated(decorator)) {
    return 'floated field label';
  }
  final tile =
      element.findAncestorWidgetOfExactType<AppTile>()?.app ??
      element.findAncestorWidgetOfExactType<QuickAppTile>()?.app;
  if (tile != null && text == tile.name) return 'app name';
  if (isValidPackageName(text) &&
      (_under(element, '_AppRowItem') || _under(element, '_AppRow'))) {
    return 'app id';
  }
  if (text == _l(t).touchpadIdleHint &&
      element.findAncestorWidgetOfExactType<Touchpad>() != null) {
    return _touchpadHint;
  }
  return null;
}

/// The touchpad's idle hint ends in an ellipsis, and the pad gives a screen
/// reader the same guidance as its hint (P9-C6.6). The hint text itself is
/// excluded from semantics, so the pad's own `Semantics` is checked: under
/// a sheet or dialog the live tree hides the whole page, the pad included.
/// `the_touchpad_speaks_the_guidance_of_its_idle_hint` checks the live tree.
void _expectTouchpadHintSpoken(WidgetTester t, Element element, String why) {
  final paragraph = element.renderObject! as RenderParagraph;
  expect(paragraph.overflow, TextOverflow.ellipsis, reason: why);
  String? hint;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Semantics && widget.properties.hint != null) {
      hint = widget.properties.hint;
    }
    return widget is! Touchpad && hint == null;
  });
  expect(hint, _l(t).touchpadHint, reason: '$why: the pad speaks it');
}

/// Whether [paragraph] is faded out of sight: a field's hint behind the text
/// typed in, or its helper behind an error. It isn't shown, so it can't be
/// cut.
bool _faded(RenderParagraph paragraph) {
  for (RenderObject? node = paragraph; node != null; node = node.parent) {
    if (node is RenderOpacity && node.opacity == 0) return true;
    if (node is RenderAnimatedOpacity && node.opacity.value == 0) return true;
  }
  return false;
}

/// The paragraphs on screen (page, dialog, sheet and snackbar) that cut
/// their text, each with its widget path. Only the exceptions of
/// [_mayEllipsize] may end in an ellipsis, and then only with the full text
/// in semantics, which this checks too (semantics must be on). Records the
/// Malay text it sees for `every_error_string_is_opened_by_the_sweep`.
List<String> _cutTexts(WidgetTester t, String why) {
  final malay = _l(t).localeName == 'ms';
  final cut = <String>[];
  for (final (element, paragraph) in _paragraphs(find.byType(MaterialApp))) {
    if (_faded(paragraph)) continue;
    final text = paragraph.text.toPlainText();
    if (malay) _renderedMalay.add(text);
    if (!_truncated(paragraph)) continue;
    final exception = _mayEllipsize(t, element, text);
    if (exception == _touchpadHint) {
      _expectTouchpadHintSpoken(t, element, '$why $exception');
    } else if (exception != null) {
      _expectReadable(t, element, '$why $exception');
    } else {
      cut.add(
        '"$text" (maxLines ${paragraph.maxLines}) at '
        '${element.debugGetCreatorChain(8)}',
      );
    }
  }
  return cut;
}

/// Every paragraph on screen shows its text whole ([_cutTexts]). A failure
/// names the screen, each cut text and its widget path.
void _expectAllTextReadable(WidgetTester t, String why) {
  final cut = _cutTexts(t, why);
  expect(cut, isEmpty, reason: '$why: text is cut:\n${cut.join('\n')}');
}

/// [_expectAllTextReadable] as the screen opened, then again a screen at a
/// time down every vertical list that scrolls: a lazy list builds only the
/// rows near the screen.
Future<void> _expectAllTextReadableScrolled(WidgetTester t, String why) async {
  _expectAllTextReadable(t, why);
  final lists = [
    for (final element in find.byType(Scrollable).evaluate())
      (element as StatefulElement).state as ScrollableState,
  ];
  for (final list in lists) {
    if (!list.mounted) continue;
    final position = list.position;
    if (position.axis != Axis.vertical ||
        !position.hasContentDimensions ||
        position.maxScrollExtent <= 0) {
      continue;
    }
    for (var step = 0; step < 40; step++) {
      if (!list.mounted || position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        math.min(
          position.pixels + position.viewportDimension * 0.8,
          position.maxScrollExtent,
        ),
      );
      await t.pump();
      _expectAllTextReadable(t, '$why, scrolled to ${position.pixels.round()}');
    }
  }
}

/// [message] (an ARB value) as a pattern for a whole paragraph: each
/// `{placeholder}` matches any text.
RegExp _messagePattern(String message) {
  final parts = message.split(RegExp(r'\{\w+\}')).map(RegExp.escape);
  return RegExp('^${parts.join('.+')}\$', dotAll: true);
}

/// Sweeps [names] (every screen by default) at 320 dp, in dark and light,
/// as [locale] or with [delegates]' strings: nothing overflows and all the
/// text is whole ([_expectAllTextReadableScrolled]).
Future<void> _sweepAllText(
  WidgetTester t, {
  Locale? locale,
  List<LocalizationsDelegate<Object?>>? delegates,
  double textScale = 1,
  TextScaler? textScaler,
  List<String>? names,
  String label = '',
}) => withSemantics(t, () async {
  for (final b in Brightness.values) {
    final seen = <String>[];
    final routes = await forEachScreen(
      t,
      (name) async {
        seen.add(name);
        if (locale == const Locale('ms')) _expectMalay(t, name);
        final why = '$name ${b.name}$label';
        // Openers don't settle (spinners never stop): let a field's label,
        // hint and error finish their fades, so what is checked is what
        // stays on screen.
        await t.pump(const Duration(milliseconds: 600));
        expectNoClipping(t, reason: why);
        await _expectAllTextReadableScrolled(t, why);
        expectNoClipping(t, reason: '$why, scrolled');
      },
      locale: locale,
      delegates: delegates,
      textScale: textScale,
      textScaler: textScaler,
      brightness: b,
      names: names,
    );
    final expected = names == null
        ? _screens.keys.toList()
        : [
            for (final name in _screens.keys)
              if (names.contains(name)) name,
          ];
    expect(seen, expected, reason: 'every screen, ${b.name}');
    if (names == null) _expectEveryRoute(routes, b.name);
  }
});

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

  testWidgets('every_screen_shows_all_its_text_whole_in_malay_at_200_percent', (
    t,
  ) async {
    await _sweepAllText(t, locale: const Locale('ms'), textScale: 2);
  });

  testWidgets(
    'every_screen_shows_all_its_text_whole_with_a_non_linear_scaler',
    (t) async {
      await _sweepAllText(
        t,
        locale: const Locale('ms'),
        textScaler: const NonlinearTwoXScaler(),
        label: ' non-linear',
      );
    },
  );

  testWidgets('every_screen_shows_all_its_text_whole_in_the_pseudo_locale', (
    t,
  ) async {
    await _sweepAllText(
      t,
      delegates: [PseudoLocalizations.delegate],
      textScale: 2,
      label: ' pseudo',
    );
  });

  testWidgets('every_error_state_fits_320dp_in_malay_at_200_percent_text', (
    t,
  ) async {
    expect(
      _screens.keys,
      containsAll(_errorStates),
      reason: 'every error state has an opener',
    );
    await _sweepAllText(
      t,
      locale: const Locale('ms'),
      textScale: 2,
      names: _errorStates,
    );
  });

  test('every_error_string_is_opened_by_the_sweep', () {
    expect(
      _renderedMalay,
      isNotEmpty,
      reason: 'the Malay sweeps above record what they show: run the file',
    );
    final ms =
        json.decode(File('lib/app/l10n/app_ms.arb').readAsStringSync())
            as Map<String, Object?>;
    final errorKeys = {
      for (final key in ms.keys)
        if (!key.startsWith('@') && _errorKeyPattern.hasMatch(key)) key,
    };
    for (final MapEntry(:key, value: reason) in _errorKeysNotInSweep.entries) {
      expect(errorKeys, contains(key), reason: '$key is an error key');
      expect(reason.trim(), isNotEmpty, reason: '$key needs a reason');
    }
    bool shown(String key) =>
        _renderedMalay.any(_messagePattern(ms[key]! as String).hasMatch);
    final missing = [
      for (final key in errorKeys)
        if (!_errorKeysNotInSweep.containsKey(key) && !shown(key)) key,
    ]..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'error strings no screen of the sweep shows: open their state in '
          '_screens, or allow-list them in _errorKeysNotInSweep with a reason',
    );
    final stale = [
      for (final key in _errorKeysNotInSweep.keys)
        if (shown(key)) key,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'the sweep shows these: take them off _errorKeysNotInSweep',
    );
  });

  testWidgets('the_text_sweep_still_fails_outside_each_exemption', (t) async {
    // Each exemption is matched by role: the same kind of text anywhere
    // else is still reported as cut (Ruling P9-C6).
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const label = 'A field label far too long for one line';
    const fitted = 'A fitted label that is not a colour key';
    const appName = 'Prime Video';
    const appId = 'com.amazon.amazonvideo.livingroom';
    late String idleHint;
    Widget narrow(Widget child) => SizedBox(width: 96, child: child);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            idleHint = AppLocalizations.of(context).touchpadIdleHint;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      // An empty, unfocused field: its label isn't floated.
                      const TextField(
                        decoration: InputDecoration(labelText: label),
                      ),
                      narrow(const FittedLabel(fitted)),
                      narrow(
                        const Text(
                          appName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      narrow(
                        const Text(
                          appId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      narrow(
                        Text(
                          idleHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final cut = _cutTexts(t, 'mutations');
    for (final text in [label, fitted, appName, appId, idleHint]) {
      expect(
        cut.where((c) => c.startsWith('"$text"')),
        hasLength(1),
        reason: '"$text" outside its exemption is still cut',
      );
    }
  });

  testWidgets('the_touchpad_speaks_the_guidance_of_its_idle_hint', (t) async {
    await withSemantics(t, () async {
      for (final locale in const [Locale('en'), Locale('ms')]) {
        await _openRemote(t, (
          brightness: Brightness.light,
          size: const Size(320, 640),
          textScale: 1,
          textScaler: null,
          locale: locale,
          delegates: null,
        ));
        expect(find.text(_l(t).touchpadIdleHint), findsOneWidget);
        final data = t.getSemantics(find.byType(Touchpad)).getSemanticsData();
        expect(data.label, contains(_l(t).touchpadLabel), reason: '$locale');
        // The spoken hint covers what the idle hint shows: swipe to move,
        // tap to select (and more).
        expect(data.hint, _l(t).touchpadHint, reason: '$locale');
        await t.pumpWidget(const SizedBox.shrink());
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
