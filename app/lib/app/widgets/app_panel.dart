import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// A group of rows on one surface, with a hairline between them: settings,
/// TV lists. Rows don't need to know they are in one, and their ink stays
/// inside the panel's corners. It keeps the 16 dp page gutter itself.
class AppPanel extends StatelessWidget {
  /// Creates a panel of [children].
  const AppPanel({required this.children, super.key});

  /// The rows, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const Divider(indent: AppSpacing.l),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
