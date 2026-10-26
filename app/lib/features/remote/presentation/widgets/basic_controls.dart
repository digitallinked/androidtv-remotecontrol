import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/app/widgets/rocker.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// The minimal set of remote keys: a D-pad, Back, Home, Mute and a volume
/// rocker. Phase 4 replaces it with the full remote.
///
/// While not [enabled] the keys are drawn faded, but taps still call [onKey]
/// so the screen can say why nothing happened.
class BasicControls extends StatelessWidget {
  /// Creates the controls.
  const BasicControls({required this.enabled, required this.onKey, super.key});

  /// Whether the TV can take key presses now.
  final bool enabled;

  /// Called with the key code of a tapped key.
  final ValueChanged<int> onKey;

  static const double _padKey = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget key(int code, IconData icon, {double size = AppSizes.keyMin}) {
      return AppKeyButton(
        semanticLabel: keyLabel(l10n, code),
        icon: Icon(icon),
        size: size,
        onTap: () => onKey(code),
      );
    }

    const gap = SizedBox.square(dimension: _padKey);
    final pad = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSizes.keyGap,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSizes.keyGap,
          children: [
            gap,
            key(KeyCodes.dpadUp, Icons.keyboard_arrow_up, size: _padKey),
            gap,
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSizes.keyGap,
          children: [
            key(KeyCodes.dpadLeft, Icons.keyboard_arrow_left, size: _padKey),
            key(KeyCodes.dpadCenter, Icons.circle_outlined, size: _padKey),
            key(KeyCodes.dpadRight, Icons.keyboard_arrow_right, size: _padKey),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSizes.keyGap,
          children: [
            gap,
            key(KeyCodes.dpadDown, Icons.keyboard_arrow_down, size: _padKey),
            gap,
          ],
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xl,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xl,
            children: [
              pad,
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSizes.keyGap,
                children: [
                  key(KeyCodes.back, Icons.arrow_back),
                  key(KeyCodes.home, Icons.home_outlined),
                  key(KeyCodes.mute, Icons.volume_off_outlined),
                ],
              ),
            ],
          ),
          Rocker(
            label: l10n.volumeLabel,
            upSemanticLabel: keyLabel(l10n, KeyCodes.volumeUp),
            downSemanticLabel: keyLabel(l10n, KeyCodes.volumeDown),
            onUp: () => onKey(KeyCodes.volumeUp),
            onDown: () => onKey(KeyCodes.volumeDown),
          ),
        ],
      ),
    );
  }
}
