import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/status_pill.dart';

/// The row under an app bar that holds the connection pill: at least 48 dp
/// high and start-aligned; the pill wraps at large text.
///
/// The remote and the Apps screen show the same strip, so the TV's state is
/// one thing the user learns once.
class StatusStrip extends StatelessWidget {
  /// Creates the strip for [status].
  const StatusStrip({
    required this.status,
    required this.onReconnect,
    required this.onPairAgain,
    super.key,
  });

  /// The connection state to show.
  final ConnectionStatus status;

  /// Called by the pill's Reconnect button; `null` hides it.
  final VoidCallback? onReconnect;

  /// Called by the pill's Pair again button; `null` hides it.
  final VoidCallback? onPairAgain;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill(
            status: status,
            onReconnect: onReconnect,
            onPairAgain: onPairAgain,
          ),
        ),
      ),
    );
  }
}
