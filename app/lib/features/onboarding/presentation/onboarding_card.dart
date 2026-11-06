import 'package:flutter/material.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/relief.dart';
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
  static const double illustrationSize = 112;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final (icon, title, body) = switch (kind) {
      OnboardingCardKind.connect => (
        Icons.connected_tv,
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
              ExcludeSemantics(child: _BacklitBadge(icon: icon)),
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

/// A card's picture: [icon] on a round key inside the D-pad's backlit ring,
/// so the first thing a new user sees is the control they are about to use.
class _BacklitBadge extends StatelessWidget {
  const _BacklitBadge({required this.icon});

  final IconData icon;

  /// How far in from the key's edge the ring runs, as on the D-pad.
  static const double _ringInset = 9;

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.accent;
    return SizedBox.square(
      dimension: OnboardingCard.illustrationSize,
      child: KeySurface(
        radius: OnboardingCard.illustrationSize,
        child: Padding(
          padding: const EdgeInsets.all(_ringInset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.32),
                width: 2,
              ),
            ),
            child: Center(child: Icon(icon, size: 40, color: accent)),
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
