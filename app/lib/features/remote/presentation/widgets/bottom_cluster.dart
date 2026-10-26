import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';
import 'package:tv_remote/app/widgets/rocker.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/key_labels.dart';

/// The keys at the bottom of the remote, within thumb reach (Ruling P4-R8):
/// the volume rocker, a 2 × 2 grid (Mute and Keyboard over Back and Home) and
/// the channel rocker.
///
/// The cluster is 280 dp wide at its widest: it fits 288 dp, a 320 dp phone
/// less two 16 dp gutters, and has no padding of its own. The rockers hold
/// their keys: a hold starts after `kHoldThreshold` and ends on release.
class BottomCluster extends StatelessWidget {
  /// Creates the cluster, sending presses to [input].
  ///
  /// [volume] is the TV's level, or `null` when it is unknown or the TV isn't
  /// connected (the rocker then shows no value). [onKeyboard] opens the
  /// keyboard sheet.
  const BottomCluster({
    required this.input,
    required this.volume,
    required this.onKeyboard,
    super.key,
  });

  /// Where the keys go.
  final KeyInput input;

  /// The TV's volume, or `null` when unknown or not connected.
  final VolumeChanged? volume;

  /// Called when the Keyboard key is tapped.
  final VoidCallback onKeyboard;

  /// Width of the widest layout, in dp.
  static const double width = 280;

  /// Height the cluster takes at the default text size, in dp. Large text
  /// makes the rockers a little taller.
  static const double height = 160;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final volume = this.volume;

    Widget key(int code, IconData icon) => AppKeyButton(
      semanticLabel: keyLabel(l10n, code),
      icon: Icon(icon),
      onTap: () => input.tap(code),
    );

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSizes.keyGap,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSizes.keyGap,
          children: [
            key(KeyCodes.mute, Icons.volume_off_outlined),
            AppKeyButton(
              semanticLabel: l10n.keyKeyboard,
              icon: const Icon(Icons.keyboard_outlined),
              onTap: onKeyboard,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSizes.keyGap,
          children: [
            key(KeyCodes.back, Icons.arrow_back),
            key(KeyCodes.home, Icons.home_outlined),
          ],
        ),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: width),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Rocker(
              label: l10n.volumeLabel,
              value: volume == null
                  ? null
                  : volume.muted
                  ? l10n.remoteMutedValue
                  : l10n.remoteVolumeValue(volume.level),
              valueSemantics: volume == null
                  ? null
                  : volume.muted
                  ? l10n.remoteVolumeMutedSemantics
                  : l10n.remoteVolumeSemantics(volume.level, volume.max),
              upSemanticLabel: keyLabel(l10n, KeyCodes.volumeUp),
              downSemanticLabel: keyLabel(l10n, KeyCodes.volumeDown),
              longPressDuration: kHoldThreshold,
              onUp: () => input.tap(KeyCodes.volumeUp),
              onDown: () => input.tap(KeyCodes.volumeDown),
              onUpLongPressStart: () => input.holdStart(KeyCodes.volumeUp),
              onUpLongPressEnd: () => input.holdEnd(KeyCodes.volumeUp),
              onDownLongPressStart: () => input.holdStart(KeyCodes.volumeDown),
              onDownLongPressEnd: () => input.holdEnd(KeyCodes.volumeDown),
            ),
            grid,
            Rocker(
              label: l10n.channelLabel,
              upIcon: const Icon(Icons.keyboard_arrow_up),
              downIcon: const Icon(Icons.keyboard_arrow_down),
              upSemanticLabel: keyLabel(l10n, KeyCodes.channelUp),
              downSemanticLabel: keyLabel(l10n, KeyCodes.channelDown),
              longPressDuration: kHoldThreshold,
              onUp: () => input.tap(KeyCodes.channelUp),
              onDown: () => input.tap(KeyCodes.channelDown),
              onUpLongPressStart: () => input.holdStart(KeyCodes.channelUp),
              onUpLongPressEnd: () => input.holdEnd(KeyCodes.channelUp),
              onDownLongPressStart: () => input.holdStart(KeyCodes.channelDown),
              onDownLongPressEnd: () => input.holdEnd(KeyCodes.channelDown),
            ),
          ],
        ),
      ),
    );
  }
}
