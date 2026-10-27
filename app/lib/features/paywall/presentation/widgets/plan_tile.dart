import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';

/// One plan of the paywall: a radio, the plan's name, its price and renewal
/// terms, and badge labels.
///
/// It must sit inside a `RadioGroup<PremiumPlanKind>`, which holds the
/// selection. The whole tile is the target and reads to a screen reader as one
/// radio button whose label is all of its text.
class PlanTile extends StatelessWidget {
  /// Creates the tile of the plan [kind].
  const PlanTile({
    required this.kind,
    required this.title,
    required this.price,
    required this.terms,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badges = const [],
    super.key,
  });

  /// Which plan the tile stands for; the radio's value.
  final PremiumPlanKind kind;

  /// The plan's name (`Yearly`).
  final String title;

  /// The price, with its period (`RM 29.99 per year`).
  final String price;

  /// How the plan renews, or that it doesn't.
  final String terms;

  /// Whether the plan is the selected one.
  final bool selected;

  /// Whether the tile can be chosen. It can't while the store is open.
  final bool enabled;

  /// Called when the tile is tapped (and the radio, through the group).
  final VoidCallback onTap;

  /// Short labels shown with the title (`Best value`). They are text, never
  /// only a colour.
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: BorderSide(
        color: selected ? colors.accent : colors.outline,
        width: selected ? 2 : 1,
      ),
    );
    return MergeSemantics(
      child: Material(
        color: selected
            ? Color.alphaBlend(
                colors.accent.withValues(alpha: 0.10),
                colors.surface,
              )
            : colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.s,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<PremiumPlanKind>(value: kind, enabled: enabled),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: AppSpacing.m,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(price, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(terms, style: theme.textTheme.bodySmall),
                          if (badges.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.s),
                            Wrap(
                              spacing: AppSpacing.s,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (var i = 0; i < badges.length; i++)
                                  _Badge(label: badges[i], strong: i == 0),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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

/// A small label. The first one is filled; the others are outlined, so the
/// two differ by more than colour.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.strong});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: strong ? colors.accent : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: strong ? colors.accent : colors.outline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: strong ? colors.onAccent : colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
