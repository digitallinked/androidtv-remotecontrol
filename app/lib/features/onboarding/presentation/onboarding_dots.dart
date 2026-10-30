import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// The onboarding page indicator: one dot per card, the current one wider
/// and in the accent colour.
///
/// It is a single semantics node that reads "Card N of M"; the dots
/// themselves are hidden from screen readers.
class OnboardingDots extends StatelessWidget {
  /// Creates the indicator for card [index] (from 0) of [count].
  const OnboardingDots({required this.count, required this.index, super.key});

  /// How many cards there are.
  final int count;

  /// The current card, from 0.
  final int index;

  /// The height of a dot, and the width of every dot but the current one.
  static const double dotSize = 8;

  /// The width of the current dot.
  static const double currentWidth = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).onboardingProgress(index + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: i == index ? currentWidth : dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: i == index ? colors.accent : colors.outline,
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
