import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_key_button.dart';

/// A vertical pill with an up key, a label (and optional value) and a down key,
/// used for volume and channel.
///
/// The centre text scales down instead of overflowing, so the pill keeps its
/// width at 200% text size.
class Rocker extends StatelessWidget {
  /// Creates a rocker.
  const Rocker({
    required this.label,
    required this.upSemanticLabel,
    required this.downSemanticLabel,
    required this.onUp,
    required this.onDown,
    super.key,
    this.value,
    this.upIcon = const Icon(Icons.add),
    this.downIcon = const Icon(Icons.remove),
    this.onUpLongPressStart,
    this.onUpLongPressEnd,
    this.onDownLongPressStart,
    this.onDownLongPressEnd,
  });

  /// Short caption in the centre, for example "VOL".
  final String label;

  /// Optional line under [label], for example the current level.
  final String? value;

  /// Spoken label of the up key.
  final String upSemanticLabel;

  /// Spoken label of the down key.
  final String downSemanticLabel;

  /// Called when the up key is tapped.
  final VoidCallback onUp;

  /// Called when the down key is tapped.
  final VoidCallback onDown;

  /// Icon of the up key.
  final Widget upIcon;

  /// Icon of the down key.
  final Widget downIcon;

  /// Called when a hold on the up key starts.
  final VoidCallback? onUpLongPressStart;

  /// Called when a hold on the up key ends.
  final VoidCallback? onUpLongPressEnd;

  /// Called when a hold on the down key starts.
  final VoidCallback? onDownLongPressStart;

  /// Called when a hold on the down key ends.
  final VoidCallback? onDownLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final value = this.value;

    return SizedBox(
      width: AppSizes.keyMin + 2 * AppSpacing.xs,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.appColors.surfaceRaised,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppKeyButton(
                semanticLabel: upSemanticLabel,
                icon: upIcon,
                onTap: onUp,
                onLongPressStart: onUpLongPressStart,
                onLongPressEnd: onUpLongPressEnd,
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Center(
                    heightFactor: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: textTheme.labelLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (value != null)
                            Text(
                              value,
                              style: textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AppKeyButton(
                semanticLabel: downSemanticLabel,
                icon: downIcon,
                onTap: onDown,
                onLongPressStart: onDownLongPressStart,
                onLongPressEnd: onDownLongPressEnd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
