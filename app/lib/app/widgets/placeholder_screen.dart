import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// A screen that stands in for one a later phase builds.
///
/// It keeps the route's [params] and [extra] so tests can check what the
/// router passed in.
class PlaceholderScreen extends StatelessWidget {
  /// Creates a placeholder titled [title].
  const PlaceholderScreen({
    required this.title,
    super.key,
    this.params = const {},
    this.extra,
    this.actionLabel,
    this.onAction,
  });

  /// The app bar title.
  final String title;

  /// Path and query parameters of the route that built this screen.
  final Map<String, String> params;

  /// The route's `extra` object, if any.
  final Object? extra;

  /// Label of the optional button; shown only when [onAction] is also set.
  final String? actionLabel;

  /// Called when the optional button is tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = actionLabel;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.l,
              children: [
                Text(
                  l10n.placeholderBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (label != null && onAction != null)
                  FilledButton(onPressed: onAction, child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
