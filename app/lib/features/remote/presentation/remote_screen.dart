import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';
import 'package:tv_remote/app/widgets/status_pill.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/remote/presentation/widgets/basic_controls.dart';
import 'package:tv_remote/features/remote/presentation/widgets/device_switcher.dart';

/// The remote control for the active TV: the TV's name and live connection
/// status in the app bar, and the keys below.
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

  @override
  void initState() {
    super.initState();
    // Also fires for a state that is already there when the screen opens.
    ref.listenManual(
      connectionStateProvider,
      _onConnectionState,
      fireImmediately: true,
    );
  }

  /// The status the controls and the pill show: the socket's state, never the
  /// saved one. Loading and errors count as not connected.
  ConnectionStatus _statusOf(AsyncValue<TvConnectionState> state) {
    if (state.isLoading) return ConnectionStatus.connecting;
    return state.value?.status ?? ConnectionStatus.disconnected;
  }

  String _tvName(AppLocalizations l10n, RemoteSession session) =>
      session.isDemo ? l10n.demoTvName : session.tvName;

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
      message: l10n.remoteIdentityChangedMessage(_tvName(l10n, session)),
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
    unawaited(
      context.push(AppRoutes.pair(target.serviceName), extra: target),
    );
  }

  void _press(RemoteSession session, int code) {
    final status = _statusOf(ref.read(connectionStateProvider));
    if (status == ConnectionStatus.connected) {
      try {
        session.sendKey(code);
        return;
      } on NotConnectedException {
        // The state lags the socket by a microtask: fall through.
      }
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.remoteNotConnected),
          // Offline and needs-pairing have an action in the status pill;
          // a closed connection has none, so offer it here.
          action: status == ConnectionStatus.disconnected
              ? SnackBarAction(
                  label: l10n.statusReconnectAction,
                  onPressed: session.reconnect,
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionState = ref.watch(remoteSessionProvider);
    final connection = ref.watch(connectionStateProvider);

    if (sessionState.isLoading) {
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
    final session = sessionState.value;
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

    final status = _statusOf(connection);
    final canPairAgain = session.pairingTarget != null;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.s,
        title: DeviceSwitcher(
          currentName: _tvName(l10n, session),
          currentServiceName: session.pairingTarget?.serviceName,
          devices: ref.watch(savedDevicesProvider).value ?? const [],
          onSelect: ref.read(activeTargetProvider.notifier).activateDevice,
          onAddTv: () => context.push(AppRoutes.discover),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.m),
            // The app bar gives its actions unbounded width: cap the pill so
            // the TV name keeps room and the pill wraps at large text sizes.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.62,
              ),
              child: StatusPill(
                status: status,
                onReconnect: session.reconnect,
                onPairAgain: canPairAgain ? () => _pairAgain(session) : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        // Keys sit at the bottom, within thumb reach; the page scrolls when
        // they don't fit (landscape, large text).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 2 * AppSpacing.xl,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BasicControls(
                  enabled: status == ConnectionStatus.connected,
                  onKey: (code) => _press(session, code),
                ),
              ),
            ),
          ),
        ),
      ),
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
