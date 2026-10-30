import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// Shows a themed modal bottom sheet with a [title], a close button and the
/// content built by [builder].
///
/// The sheet closes with a swipe down, a tap outside or the close button; all
/// three return `null`. Content that does not fit (for example at 200% text
/// size) scrolls. To return a value, call `Navigator.pop(context, value)` from
/// inside [builder]. Under reduce motion it opens and closes without animating
/// (Ruling P7-R4).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      // Lift the content above the keyboard so a text field stays visible.
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.closeAction,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(AppSizes.touchMin),
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.s,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Builder(builder: builder),
              ),
            ),
          ],
        ),
      );
    },
  );
}
