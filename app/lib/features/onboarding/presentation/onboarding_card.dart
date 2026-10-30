import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';

/// The three onboarding cards, in the order they are shown.
enum OnboardingCardKind {
  /// Finding and pairing a TV on the Wi-Fi network.
  connect,

  /// Controlling the TV from the phone.
  control,

  /// Opening TV apps from the remote.
  apps,
}

/// One onboarding card: an illustration, a title and a body; the connect
/// card adds a note about the network permission.
///
/// Its content scrolls inside the page, so it fits at any text size.
class OnboardingCard extends StatelessWidget {
  /// Creates the card for [kind].
  const OnboardingCard({required this.kind, super.key});

  /// Which card this is.
  final OnboardingCardKind kind;

  /// The diameter of the illustration's circle.
  static const double illustrationSize = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final (icon, title, body) = switch (kind) {
      OnboardingCardKind.connect => (
        Icons.wifi_find_outlined,
        l10n.onboardingConnectTitle,
        l10n.onboardingConnectBody,
      ),
      OnboardingCardKind.control => (
        Icons.touch_app_outlined,
        l10n.onboardingControlTitle,
        l10n.onboardingControlBody,
      ),
      OnboardingCardKind.apps => (
        Icons.apps_outlined,
        l10n.onboardingAppsTitle,
        l10n.onboardingAppsBody,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.l,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 2 * AppSpacing.l).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: illustrationSize,
                  height: illustrationSize,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: colors.accent),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              if (kind == OnboardingCardKind.connect) ...[
                const SizedBox(height: AppSpacing.xl),
                _NetworkNote(text: l10n.onboardingConnectNote),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The connect card's note: the app looks only on the Wi-Fi network.
class _NetworkNote extends StatelessWidget {
  const _NetworkNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.lock_outline,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
