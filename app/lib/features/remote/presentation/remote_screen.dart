import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';
import 'package:tv_remote/app/widgets/status_strip.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/device/keep_awake.dart';
import 'package:tv_remote/core/device/theater_mode.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/app_database.dart' show SavedDevice;
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/saved_device_x.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/demo/presentation/tv_preview_card.dart';
import 'package:tv_remote/features/keyboard/keyboard_sheet.dart';
import 'package:tv_remote/features/remote/application/ime_requests.dart';
import 'package:tv_remote/features/remote/application/power_controller.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';
import 'package:tv_remote/features/remote/presentation/widgets/device_switcher.dart';
import 'package:tv_remote/features/remote/presentation/widgets/pad_pager.dart';
import 'package:tv_remote/features/remote/presentation/widgets/power_button.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';
import 'package:tv_remote/features/remote/presentation/widgets/wol_setup_sheet.dart';

/// The remote control for the active TV: the TV's name in the app bar, its
/// live connection status in a strip under it, and the controls below.
///
/// While the session reloads (a switch to another TV) the previous remote
/// stays on screen, with the status `connecting` and every press refused.
///
/// It never opens pairing by itself. A TV that needs pairing shows a "Pair
/// again" action in the status pill, and a TV whose security key changed also
/// asks once per session.
class RemoteScreen extends ConsumerStatefulWidget {
  /// Creates the remote screen.
  const RemoteScreen({super.key});

  @override
  ConsumerState<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends ConsumerState<RemoteScreen> {
  /// The session the identity-changed dialog was last shown for.
  RemoteSession? _askedAboutIdentityFor;

  /// The "Not connected" snackbar on screen, if any. One is enough: a swipe
  /// on the touchpad refuses several steps at once.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notConnectedBar;

  /// A power action is in flight (see [_power]).
  bool _powering = false;

  /// The navigation style the pad area shows or last showed. The pager reads
  /// its first page once, so a style that settings changes to something else
  /// is applied by giving the body a new key ([_bodyEpoch]); the user's own
  /// swipes update this first and so never rebuild the pager.
  late NavigationStyle _shownStyle;

  /// Changes when the body must start afresh on the stored style.
  int _bodyEpoch = 0;

  /// The consent step was asked for by this screen (see
  /// [didChangeDependencies]).
  bool _consentAsked = false;

  @override
  void initState() {
    super.initState();
    _shownStyle = ref.read(settingsControllerProvider).navigationStyle;
    // Also fires for a state that is already there when the screen opens.
    ref.listenManual(
      connectionStateProvider,
      _onConnectionState,
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The ad consent form waits for the remote: it opens the first time this
    // screen is the top route, never over onboarding, discovery or pairing
    // (Ruling P6-R8). Reading `isCurrentOf` here also calls this again when
    // a page or dialog on top leaves. The controller shows the form once per
    // launch, whatever number of times this screen is built.
    if (_consentAsked || !(ModalRoute.isCurrentOf(context) ?? false)) return;
    _consentAsked = true;
    // After the frame, so the controller never changes state during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(consentControllerProvider.notifier).ensureGathered());
    });
  }

  /// The status the controls and the pill show: the socket's state, never the
  /// saved one. Loading and errors count as not connected.
  ConnectionStatus _statusOf(AsyncValue<TvConnectionState> state) {
    if (state.isLoading) return ConnectionStatus.connecting;
    return state.value?.status ?? ConnectionStatus.disconnected;
  }

  /// The name to show for [session]'s TV: the saved label (so a rename shows
  /// at once, without rebuilding the session), else the name the session
  /// carries (Ruling P5-R9).
  String _label(
    AppLocalizations l10n,
    RemoteSession session,
    List<SavedDevice> devices,
  ) {
    if (session.isDemo) return l10n.demoTvName;
    final serviceName = session.pairingTarget?.serviceName;
    for (final device in devices) {
      if (device.serviceName == serviceName) return device.label;
    }
    return session.tvName;
  }

  /// The saved TVs as last emitted; empty while loading.
  List<SavedDevice> get _savedDevices =>
      ref.read(savedDevicesProvider).value ?? const [];

  void _onConnectionState(
    AsyncValue<TvConnectionState>? previous,
    AsyncValue<TvConnectionState> next,
  ) {
    final state = next.value;
    if (next.isLoading ||
        state == null ||
        state.status != ConnectionStatus.needsPairing ||
        state.lastError != RemoteCloseReason.serverKeyChanged) {
      return;
    }
    final session = ref.read(remoteSessionProvider).value;
    if (session == null || identical(session, _askedAboutIdentityFor)) return;
    _askedAboutIdentityFor = session;
    // After the frame: this may run while the screen is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_askToPairAgain(session));
    });
  }

  Future<void> _askToPairAgain(RemoteSession session) async {
    final l10n = AppLocalizations.of(context);
    final pairAgain = await showAppDialog<bool>(
      context: context,
      title: l10n.remoteIdentityChangedTitle,
      message: l10n.remoteIdentityChangedMessage(
        _label(l10n, session, _savedDevices),
      ),
      actions: [
        AppDialogAction(label: l10n.remoteNotNow, value: false),
        AppDialogAction(
          label: l10n.statusPairAgainAction,
          value: true,
          isPrimary: true,
        ),
      ],
    );
    if (pairAgain ?? false) _pairAgain(session);
  }

  void _pairAgain(RemoteSession session) {
    final target = session.pairingTarget;
    if (!mounted || target == null) return;
    // No `extra`: the pairing screen looks the TV up again, because its
    // address may have changed since it was saved (Ruling P5-R10 c).
    unawaited(context.push(AppRoutes.pair(target.serviceName)));
  }

  /// Says why a press did nothing (Ruling P4-R3): one snackbar per refused
  /// command, with Reconnect when the connection is closed.
  void _showNotConnected() {
    // A sheet or dialog on top (the keyboard) explains it itself.
    if (!mounted ||
        _notConnectedBar != null ||
        !(ModalRoute.isCurrentOf(context) ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final sessionState = ref.read(remoteSessionProvider);
    final session = sessionState.value;
    final status = sessionState.isLoading
        ? ConnectionStatus.connecting
        : _statusOf(ref.read(connectionStateProvider));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final bar = messenger.showAppSnackBar(
      SnackBar(
        content: Text(l10n.remoteNotConnected),
        // Offline and needs-pairing have an action in the status pill;
        // a closed connection has none, so offer it here.
        action: session != null && status == ConnectionStatus.disconnected
            ? SnackBarAction(
                label: l10n.statusReconnectAction,
                onPressed: session.reconnect,
              )
            : null,
      ),
    );
    _notConnectedBar = bar;
    unawaited(
      bar.closed.then((_) {
        if (identical(_notConnectedBar, bar)) _notConnectedBar = null;
      }),
    );
  }

  /// Says [message] in a snackbar of its own. The "Not connected" snackbar
  /// has its own controller, [_showNotConnected].
  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showAppSnackBar(SnackBar(content: Text(message)));
  }

  /// The power key was held (Ruling P4-R10): the controller powers the TV or
  /// wakes it, and the outcome is said here. A refusal is already announced
  /// by the "Not connected" notice.
  Future<void> _power() async {
    // A second hold while the first is still waking the TV or asking for
    // the MAC would wake twice, buzz twice or stack a second sheet.
    if (_powering) return;
    _powering = true;
    try {
      final l10n = AppLocalizations.of(context);
      final controller = ref.read(powerControllerProvider);
      final session = controller.session;
      final tvName = session == null
          ? ''
          : _label(l10n, session, _savedDevices);

      final outcome = await controller.press();
      if (!mounted) return;
      if (outcome != PowerOutcome.needsMac) {
        _sayPowerOutcome(l10n, outcome, tvName);
        return;
      }

      PowerOutcome? afterSave;
      await showWolSetupSheet(
        context,
        tvName: tvName,
        onSave: (mac) async => afterSave = await controller.saveMacAndWake(mac),
      );
      // Said even when the sheet was dismissed while it was saving.
      final saved = afterSave;
      if (saved != null) _sayPowerOutcome(l10n, saved, tvName);
    } finally {
      _powering = false;
    }
  }

  void _sayPowerOutcome(
    AppLocalizations l10n,
    PowerOutcome outcome,
    String tvName,
  ) {
    switch (outcome) {
      case PowerOutcome.waking:
        _say(l10n.powerWaking(tvName));
      case PowerOutcome.wakeFailed:
        _say(l10n.powerWakeFailed);
      case PowerOutcome.cannotWake:
        _say(l10n.powerTurnOnWithTvRemote);
      // The key press needs no message; a refusal has its own snackbar; the
      // setup sheet is opened by the caller.
      case PowerOutcome.sentPowerKey ||
          PowerOutcome.notConnected ||
          PowerOutcome.needsMac:
        break;
    }
  }

  void _openKeyboard() {
    unawaited(
      showKeyboardSheet(context, input: ref.read(remoteActionsProvider)),
    );
  }

  /// The TV started a text field: open the keyboard when the user wants that
  /// and nothing else is on top of the remote (Ruling P4-R12).
  void _onImeShowRequested() {
    if (!mounted ||
        !ref.read(settingsControllerProvider).autoOpenKeyboard ||
        !(ModalRoute.isCurrentOf(context) ?? false) ||
        KeyboardSheet.isOpen) {
      return;
    }
    _openKeyboard();
  }

  /// Touchpad and D-pad are remembered as the navigation style; Numbers is a
  /// detour that is never saved (Ruling P4-R7).
  void _onPageChanged(PadPage page) {
    final style = switch (page) {
      PadPage.touchpad => NavigationStyle.touchpad,
      PadPage.dpad => NavigationStyle.dpad,
      PadPage.numbers => null,
    };
    if (style == null) return;
    _shownStyle = style;
    if (ref.read(settingsControllerProvider).navigationStyle == style) return;
    unawaited(
      ref
          .read(settingsControllerProvider.notifier)
          .update((store) => store.setNavigationStyle(style)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionState = ref.watch(remoteSessionProvider);
    final connection = ref.watch(connectionStateProvider);
    final session = sessionState.value;

    // Nothing to keep on screen yet.
    if (sessionState.isLoading && session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pageTitleRemote)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (sessionState.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pageTitleRemote)),
        body: _Message(
          title: l10n.remoteSessionErrorTitle,
          body: l10n.remoteSessionErrorBody,
          actionLabel: l10n.remoteRetry,
          onAction: () => ref.invalidate(remoteSessionProvider),
        ),
      );
    }
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pageTitleRemote)),
        body: _Message(
          title: l10n.remoteNoTvTitle,
          actionLabel: l10n.remoteNoTvAction,
          onAction: () => context.go(AppRoutes.discover),
        ),
      );
    }

    // Every refused press (offline, or a TV switch in progress) says why.
    ref
      ..listen(notConnectedNoticesProvider, (_, _) => _showNotConnected())
      ..listen(imeShowRequestsProvider, (_, next) {
        if (next is AsyncData<ImeShowSignal> && next.value.isFresh) {
          _onImeShowRequested();
        }
      });
    // Watched, not read: the provider is autoDispose. Listening keeps the
    // power controller (which uses these actions) alive the same way.
    final input = ref.watch(remoteActionsProvider);
    ref
      ..listen(powerControllerProvider, (_, _) {})
      ..listen(appUsageTrackerProvider, (_, _) {})
      // Settings (a page on top of this one) changed the style.
      ..listen(
        settingsControllerProvider.select((s) => s.navigationStyle),
        (_, next) {
          if (next != _shownStyle) {
            setState(() {
              _shownStyle = next;
              _bodyEpoch++;
            });
          }
        },
      );
    final (navigationStyle, quickAccess) = ref.watch(
      settingsControllerProvider.select(
        (s) => (s.navigationStyle, s.quickAccessRow),
      ),
    );
    final devices = ref.watch(savedDevicesProvider).value ?? const [];
    final target = ref.watch(activeTargetProvider);

    // The session is rebuilding for another TV: the old one is disposed and
    // its state is stale, so the remote shows "connecting".
    final reloading = sessionState.isLoading;
    final status = reloading
        ? ConnectionStatus.connecting
        : _statusOf(connection);
    final connected = status == ConnectionStatus.connected;
    final canPairAgain = !reloading && session.pairingTarget != null;

    var tvName = _label(l10n, session, devices);
    var serviceName = session.pairingTarget?.serviceName;
    if (reloading && target is DeviceTarget) {
      serviceName = target.serviceName;
      for (final device in devices) {
        if (device.serviceName == serviceName) tvName = device.label;
      }
    }

    final liveVolume = ref.watch(volumeProvider).value;
    final liveApp = ref.watch(currentAppProvider).value;
    final initialPage =
        MediaQuery.accessibleNavigationOf(context) ||
            navigationStyle == NavigationStyle.dpad
        ? PadPage.dpad
        : PadPage.touchpad;

    final scaffold = Scaffold(
      // The keyboard sheet has the text field; the remote keeps its layout.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 64,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.pageTitleSettings,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppSizes.touchMin),
          ),
          onPressed: () => unawaited(context.push(AppRoutes.settings)),
        ),
        titleSpacing: AppSpacing.s,
        title: DeviceSwitcher(
          currentName: tvName,
          currentServiceName: serviceName,
          devices: devices,
          onSelect: (name) {
            // The current TV keeps its session: rebuilding would drop a
            // working connection for nothing.
            if (name == serviceName) return;
            ref.read(activeTargetProvider.notifier).activateDevice(name);
          },
          onAddTv: () => context.push(AppRoutes.discover),
          onManageTvs: () => context.push(AppRoutes.devices),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
            child: PowerButton(
              onHint: () => _say(l10n.powerHoldHint),
              onPower: () => unawaited(_power()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            StatusStrip(
              status: status,
              onReconnect: reloading ? null : session.reconnect,
              onPairAgain: canPairAgain ? () => _pairAgain(session) : null,
            ),
            Expanded(
              child: RemoteBody(
                key: ValueKey(_bodyEpoch),
                input: input,
                enabled: connected,
                quickAccess: quickAccess,
                apps: ref.watch(shortcutsProvider).value ?? const [],
                currentApp: connected ? liveApp : null,
                initialPage: initialPage,
                onPageChanged: _onPageChanged,
                volume: connected ? liveVolume : null,
                onKeyboard: _openKeyboard,
                onAllApps: () => unawaited(context.push(AppRoutes.apps)),
                preview: session.isDemo ? const TvPreviewCard() : null,
              ),
            ),
          ],
        ),
      ),
    );

    final (keepAwake, theater) = ref.watch(
      settingsControllerProvider.select(
        (s) => (s.keepScreenAwake, s.theaterMode),
      ),
    );
    return KeepAwake(
      enabled: keepAwake,
      child: TheaterMode(enabled: theater, child: scaffold),
    );
  }
}

/// A centred message with one action, for the states without a TV.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.body,
  });

  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = this.body;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null)
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
