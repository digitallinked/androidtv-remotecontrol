import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/relief.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/fitted_label.dart';

/// The switch above the remote's pad area: a recessed track with one key that
/// slides to the page in use (decision #54).
///
/// It stays quiet on purpose. The pad below it is what the eye and the thumb
/// are after, so the selected tab is a raised key, not a block of accent.
/// Every tab is at least 48 dp high, and a screen reader hears a group of
/// selectable buttons. The key slides for [AppMotion.standard], or moves at
/// once under reduce motion.
class PadTabs<T> extends StatelessWidget {
  /// Creates the tabs, one for each value of [labels], showing [selected].
  const PadTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Each tab's value and label, in order.
  final Map<T, String> labels;

  /// The tab in use.
  final T selected;

  /// Called with the tab the user tapped.
  final ValueChanged<T> onSelect;

  /// Space between the track's edge and the sliding key.
  static const double _inset = 3;

  static const double _radius = 999;

  @override
  Widget build(BuildContext context) {
    final tabs = labels.keys.toList();
    final index = tabs.indexOf(selected);
    final span = tabs.length - 1;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.relief.well,
        shape: StadiumBorder(
          side: BorderSide(color: context.appColors.outline),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_inset),
              child: AnimatedAlign(
                duration: AppMotion.durationOf(context, AppMotion.standard),
                curve: AppMotion.curve,
                alignment: AlignmentDirectional(
                  span == 0 ? 0 : 2 * index / span - 1,
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / tabs.length,
                  heightFactor: 1,
                  child: const KeySurface(
                    radius: _radius,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _Tab(
                    label: labels[tab]!,
                    selected: tab == selected,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: selected ? colors.textPrimary : colors.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: DefaultTextStyle.merge(
                  style: style,
                  child: FittedLabel(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
