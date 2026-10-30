import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// A pill that shows the live connection state of the TV.
///
/// The state is always written out as a label next to the coloured dot, so
/// colour is never the only signal. The pill is a live region: screen readers
/// announce changes. When the TV is [ConnectionStatus.offline] and
/// [onReconnect] is given, a "Reconnect" button is shown inside the pill; when
/// it is [ConnectionStatus.needsPairing] and [onPairAgain] is given, a "Pair
/// again" button is.
class StatusPill extends StatelessWidget {
  /// Creates a pill for [status].
  const StatusPill({
    required this.status,
    super.key,
    this.onReconnect,
    this.onPairAgain,
  });

  /// Key of the status dot, for tests.
  @visibleForTesting
  static const Key dotKey = Key('status_pill_dot');

  /// The connection state to show.
  final ConnectionStatus status;

  /// Called when the user taps "Reconnect". The button only appears while
  /// [status] is [ConnectionStatus.offline] and this is not null.
  final VoidCallback? onReconnect;

  /// Called when the user taps "Pair again". The button only appears while
  /// [status] is [ConnectionStatus.needsPairing] and this is not null.
  final VoidCallback? onPairAgain;

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
    final showPairAgain =
        status == ConnectionStatus.needsPairing && onPairAgain != null;
    final duration = AppMotion.durationOf(context, AppMotion.standard);

    final Widget action;
    if (showReconnect) {
      action = TextButton(
        key: const ValueKey('reconnect'),
        onPressed: onReconnect,
        child: Text(l10n.statusReconnectAction),
      );
    } else if (showPairAgain) {
      action = TextButton(
        key: const ValueKey('pair_again'),
        onPressed: onPairAgain,
        child: Text(l10n.statusPairAgainAction),
      );
    } else {
      action = const SizedBox.shrink(key: ValueKey('none'));
    }

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
          padding: EdgeInsetsDirectional.only(
            start: AppSpacing.m,
            end: showReconnect || showPairAgain ? AppSpacing.xs : AppSpacing.m,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
            // The pill grows or shrinks with its content instead of jumping.
            child: _Resize(
              duration: duration,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The label is spoken through the Semantics wrapper above,
                  // so the outgoing label of a cross-fade is never read and
                  // the pill stays one live region.
                  Flexible(
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // A new palette (a theme switch, Theater Mode) shows
                          // at once; only a status change tweens the colour.
                          TweenAnimationBuilder<Color?>(
                            key: ValueKey(colors),
                            tween: ColorTween(end: dot),
                            duration: duration,
                            curve: AppMotion.curve,
                            builder: (context, colour, _) => SizedBox.square(
                              dimension: 8,
                              child: DecoratedBox(
                                key: dotKey,
                                decoration: BoxDecoration(
                                  color: colour,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Flexible(
                            child: _CrossFade(
                              duration: duration,
                              child: Text(
                                label,
                                key: ValueKey(status),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: colors.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showReconnect || showPairAgain)
                    const SizedBox(width: AppSpacing.xs),
                  // Without an action the slot takes no share of the width,
                  // so the label keeps all of it (and a fading-out button
                  // its own width).
                  Flexible(
                    flex: showReconnect || showPairAgain ? 1 : 0,
                    child: _CrossFade(duration: duration, child: action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animates [child]'s size changes over [duration]; with a zero duration
/// (reduce motion) it is just [child]: an `AnimatedSize` that animates for no
/// time asserts in its own layout.
class _Resize extends StatelessWidget {
  const _Resize({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.curve,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}

/// Cross-fades from one child to the next (told apart by their keys), with
/// the outgoing child out of semantics and out of reach of the finger.
///
/// "Outgoing" is read from each child's own animation, which runs in reverse
/// while it leaves. Comparing keys would wrongly revive a child still fading
/// out after a quick A → B → A, leaving two live buttons.
class _CrossFade extends StatelessWidget {
  const _CrossFade({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.curve,
      // Only the incoming child sizes the slot, so the pill resizes once,
      // in step with the fade; the outgoing one fades where it was and the
      // pill's edge clips it.
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.centerStart,
        children: [
          for (final child in previous)
            PositionedDirectional(start: 0, child: child),
          ?current,
        ],
      ),
      transitionBuilder: _transition,
      child: child,
    );
  }

  static Widget _transition(Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, faded) {
        final leaving = switch (animation.status) {
          AnimationStatus.reverse || AnimationStatus.dismissed => true,
          AnimationStatus.forward || AnimationStatus.completed => false,
        };
        return ExcludeSemantics(
          excluding: leaving,
          child: IgnorePointer(ignoring: leaving, child: faded),
        );
      },
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
