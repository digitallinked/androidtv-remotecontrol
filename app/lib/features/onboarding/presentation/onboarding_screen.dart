import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';

/// First-run screen with a "Get started" button and a "Try demo" button.
/// Phase 7 replaces it with the real onboarding.
class OnboardingScreen extends ConsumerWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.l,
              children: [
                Text(
                  l10n.onboardingTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall,
                ),
                Text(
                  l10n.onboardingBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .update((s) => s.setOnboardingComplete(true));
                    if (!context.mounted) return;
                    context.go(AppRoutes.discover);
                  },
                  child: Text(l10n.onboardingGetStarted),
                ),
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .update((s) => s.setOnboardingComplete(true));
                    if (!context.mounted) return;
                    ref.read(activeTargetProvider.notifier).startDemo();
                    context.go(AppRoutes.remote);
                  },
                  child: Text(l10n.onboardingTryDemo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
