import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// The power key in the app bar (Ruling P4-R10): a 56 dp key that must be
/// held, so a stray tap can't turn the TV off.
///
/// A tap only calls [onHint] (the screen explains that the key is held).
/// Holding it for [holdDuration], or a screen reader's long-press action,
/// calls [onPower]. A screen reader's plain activation is the hint too, so
/// its user is told how to use the key.
class PowerButton extends StatelessWidget {
  /// Creates the key.
  const PowerButton({required this.onHint, required this.onPower, super.key});

  /// How long the key must be held to count as the power action.
  static const Duration holdDuration = Duration(milliseconds: 600);

  /// Called on a tap, which does not power anything.
  final VoidCallback onHint;

  /// Called when the key is held, or on a screen reader's long press.
  final VoidCallback onPower;

  @override
  Widget build(BuildContext context) {
    return AppKeyButton(
      semanticLabel: keyLabel(AppLocalizations.of(context), KeyCodes.power),
      icon: Icon(
        Icons.power_settings_new,
        color: context.appColors.dangerText,
      ),
      onTap: onHint,
      onLongPressStart: onPower,
      longPressDuration: holdDuration,
      // Without this a screen reader's long press would fall back to the tap.
      onSemanticLongPress: onPower,
    );
  }
}
