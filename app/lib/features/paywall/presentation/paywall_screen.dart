import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/widgets/placeholder_screen.dart';

/// Where the paywall was opened from (for analytics and for closing).
enum PaywallSource {
  /// The Premium row on the Settings hub.
  settings,

  /// A locked colour style.
  themes,

  /// The Privacy choices page.
  privacy,

  /// No source, or one the app doesn't know.
  unknown;

  /// The source named [name], or [unknown] for `null` and unknown names.
  static PaywallSource parse(String? name) {
    for (final source in values) {
      if (source.name == name) return source;
    }
    return unknown;
  }
}

/// The Premium screen. This is a placeholder until Task 6.7.
class PaywallScreen extends StatelessWidget {
  /// Creates the screen, opened from [source].
  const PaywallScreen({required this.source, super.key});

  /// Where the screen was opened from.
  final PaywallSource source;

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: AppLocalizations.of(context).pageTitlePaywall);
}
