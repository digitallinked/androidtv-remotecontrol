import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/app_snack_bar.dart';
import 'package:tv_remote/core/session/remote_session.dart';

/// The status the status strip, the controls and the "Not connected"
/// snackbar show: the socket's state, never the saved one.
///
/// While the session or its connection is loading (a switch to another TV)
/// it is `connecting`, so a stale value of the old TV never shows. Errors
/// count as not connected.
ConnectionStatus shownConnectionStatus(
  AsyncValue<RemoteSession?> session,
  AsyncValue<TvConnectionState> connection,
) {
  if (session.isLoading || connection.isLoading) {
    return ConnectionStatus.connecting;
  }
  return connection.value?.status ?? ConnectionStatus.disconnected;
}

/// One screen's "Not connected" snackbar, said when a press was refused
/// because the TV isn't connected (Ruling P4-R3).
///
/// One at a time: while it is on screen, more refusals add nothing (a swipe
/// on the touchpad refuses several steps at once). None while another page,
/// sheet or dialog is on top of the screen, which explains it itself. A
/// closed connection gets a Reconnect action; offline and needs-pairing have
/// theirs in the status strip.
class NotConnectedSnackBar {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _bar;

  /// Shows the snackbar from [context], the screen's own, for [session] in
  /// [status], unless one is already up or the screen isn't the top route.
  ///
  /// With [replaceCurrent] another snackbar on screen goes first.
  void show(
    BuildContext context, {
    required RemoteSession? session,
    required ConnectionStatus status,
    bool replaceCurrent = false,
  }) {
    if (!context.mounted ||
        _bar != null ||
        !(ModalRoute.isCurrentOf(context) ?? false)) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (replaceCurrent) messenger.hideCurrentSnackBar();
    final bar = messenger.showAppSnackBar(
      SnackBar(
        content: Text(l10n.remoteNotConnected),
        action: session != null && status == ConnectionStatus.disconnected
            ? SnackBarAction(
                label: l10n.statusReconnectAction,
                onPressed: session.reconnect,
              )
            : null,
      ),
    );
    _bar = bar;
    unawaited(
      bar.closed.then((_) {
        if (identical(_bar, bar)) _bar = null;
      }),
    );
  }
}
