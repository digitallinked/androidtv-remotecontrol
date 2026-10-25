import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// A pill that shows the live connection state of the TV.
///
/// The state is always written out as a label next to the coloured dot, so
/// colour is never the only signal. The pill is a live region: screen readers
/// announce changes. When the TV is [ConnectionStatus.offline] and
/// [onReconnect] is given, a "Reconnect" button is shown inside the pill.
class StatusPill extends StatelessWidget {
  /// Creates a pill for [status].
  const StatusPill({required this.status, super.key, this.onReconnect});

  /// Key of the status dot, for tests.
  @visibleForTesting
  static const Key dotKey = Key('status_pill_dot');

  /// The connection state to show.
  final ConnectionStatus status;

  /// Called when the user taps "Reconnect". The button only appears while
  /// [status] is [ConnectionStatus.offline] and this is not null.
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final label = switch (status) {
      ConnectionStatus.connected => l10n.statusConnected,
      ConnectionStatus.connecting => l10n.statusConnecting,
      ConnectionStatus.reconnecting => l10n.statusReconnecting,
      ConnectionStatus.offline => l10n.statusOffline,
      ConnectionStatus.needsPairing => l10n.statusNeedsPairing,
      ConnectionStatus.disconnected => l10n.statusDisconnected,
    };
    final dot = switch (status) {
      ConnectionStatus.connected => colors.success,
      ConnectionStatus.connecting => colors.accent,
      ConnectionStatus.reconnecting => colors.warning,
      ConnectionStatus.offline => colors.danger,
      ConnectionStatus.needsPairing => colors.danger,
      ConnectionStatus.disconnected => colors.textSecondary,
    };
    final showReconnect =
        status == ConnectionStatus.offline && onReconnect != null;

    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.statusSemantics(label),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.surface,
          shape: StadiumBorder(side: BorderSide(color: colors.outline)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.m,
            right: showReconnect ? AppSpacing.xs : AppSpacing.m,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The label is spoken through the Semantics wrapper above.
                Flexible(
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 8,
                          child: DecoratedBox(
                            key: dotKey,
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Flexible(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showReconnect) ...[
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    onPressed: onReconnect,
                    child: Text(l10n.statusReconnectAction),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
