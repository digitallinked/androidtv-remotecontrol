import 'package:flutter/material.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// One button of an [AppDialog]; tapping it closes the dialog with [value].
@immutable
class AppDialogAction<T> {
  /// Creates an action.
  const AppDialogAction({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  /// Button text.
  final String label;

  /// The value the dialog returns when this action is tapped.
  final T value;

  /// Draws the action as a filled button.
  final bool isPrimary;

  /// Draws the action's text in the danger colour.
  final bool isDestructive;
}

/// A themed confirmation dialog with a title, a message and actions.
///
/// Use [showAppDialog] to open it. Screen readers announce the dialog by its
/// [title] (it names its route) and keep their focus inside it. On a screen
/// narrower than [narrowWidth] it sits 16 dp from the sides instead of
/// 40 dp, so large text still gets a readable line; the body scrolls.
class AppDialog<T> extends StatelessWidget {
  /// Creates a dialog.
  const AppDialog({
    required this.title,
    required this.message,
    required this.actions,
    super.key,
  });

  /// Heading of the dialog.
  final String title;

  /// Body text.
  final String message;

  /// Buttons, laid out at the end of the dialog and wrapping when narrow.
  final List<AppDialogAction<T>> actions;

  /// Screens narrower than this get the narrow side insets.
  static const double narrowWidth = 360;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < narrowWidth;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AppSpacing.l : 40,
        vertical: AppSpacing.xl,
      ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                const SizedBox(height: AppSpacing.m),
                Text(
                  message,
                  style: text.bodyLarge?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    children: [
                      for (final action in actions) _buttonFor(context, action),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonFor(BuildContext context, AppDialogAction<T> action) {
    void onPressed() => Navigator.of(context).pop(action.value);
    final label = Text(action.label);
    if (action.isPrimary) {
      return FilledButton(onPressed: onPressed, child: label);
    }
    return TextButton(
      onPressed: onPressed,
      style: action.isDestructive
          // No styleFrom: its derived overlay would beat reduce motion's.
          ? foregroundOnly(context.appColors.dangerText)
          : null,
      child: label,
    );
  }
}

/// Shows an [AppDialog] and returns the value of the tapped action, or `null`
/// when the dialog is dismissed by tapping outside it.
///
/// With [barrierDismissible] false only an action closes the dialog: neither
/// the barrier nor the system Back button does. Under reduce motion it opens
/// and closes without animating (Ruling P7-R4).
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<AppDialogAction<T>> actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) {
      final dialog = AppDialog<T>(
        title: title,
        message: message,
        actions: actions,
      );
      return barrierDismissible
          ? dialog
          : PopScope(canPop: false, child: dialog);
    },
  );
}
