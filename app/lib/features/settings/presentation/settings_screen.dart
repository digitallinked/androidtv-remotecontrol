import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/core/ads/interstitials.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/settings/application/feedback.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// The settings hub: the pages that hold every setting, grouped (Ruling
/// P5-R11).
///
/// The banner slot sits at the bottom and the list ends with
/// [BannerSlot.clearance] of space, so an ad never covers a row. There is no
/// bottom-anchored control.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({this.fromSetup = false, super.key});

  /// Whether the hub was opened before pairing (from discovery or the no-TV
  /// remote). Leaving it then never shows an interstitial (Ruling P7-R7).
  final bool fromSetup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final premium = ref.watch(premiumProvider.select((p) => p.isPremium));
    // Leaving the hub is the one place an interstitial may show (Ruling
    // P6-R9); the sub-pages are routes of their own and don't count. Not
    // before pairing: no ad lands on discovery (decision #6).
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !fromSetup) {
          unawaited(
            ref
                .read(interstitialsProvider.notifier)
                .maybeShow(InterstitialTrigger.leftSettings),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.pageTitleSettings)),
        body: ListView(
          children: [
            SettingsSectionHeader(l10n.settingsSectionRemote),
            SettingsNavTile(
              icon: Icons.dashboard_customize_outlined,
              title: l10n.pageTitleRemoteLayout,
              subtitle: l10n.settingsRemoteLayoutSubtitle,
              onTap: () => context.push(AppRoutes.settingsRemoteLayout),
            ),
            SettingsNavTile(
              icon: Icons.tune,
              title: l10n.pageTitleRemoteBehaviour,
              subtitle: l10n.settingsRemoteBehaviourSubtitle,
              onTap: () => context.push(AppRoutes.settingsRemoteBehaviour),
            ),
            SettingsNavTile(
              icon: Icons.apps,
              title: l10n.pageTitleApps,
              subtitle: l10n.settingsAppsSubtitle,
              onTap: () => context.push(AppRoutes.manageApps),
            ),
            SettingsNavTile(
              icon: Icons.tv,
              title: l10n.pageTitleDevices,
              subtitle: l10n.settingsDevicesSubtitle,
              onTap: () => context.push(AppRoutes.devices),
            ),
            SettingsSectionHeader(l10n.settingsSectionApp),
            SettingsNavTile(
              icon: Icons.palette_outlined,
              title: l10n.pageTitleAppearance,
              subtitle: l10n.settingsAppearanceSubtitle,
              onTap: () => context.push(AppRoutes.settingsAppearance),
            ),
            SettingsNavTile(
              icon: Icons.workspace_premium_outlined,
              title: l10n.pageTitlePaywall,
              subtitle: premium
                  ? l10n.settingsPremiumActiveSubtitle
                  : l10n.settingsPremiumSubtitle,
              onTap: () => context.push(
                AppRoutes.paywall(source: PaywallSource.settings),
              ),
            ),
            SettingsNavTile(
              icon: Icons.shield_outlined,
              title: l10n.pageTitlePrivacyChoices,
              subtitle: l10n.settingsPrivacyChoicesSubtitle,
              onTap: () => context.push(AppRoutes.settingsPrivacy),
            ),
            SettingsSectionHeader(l10n.settingsSectionSupport),
            SettingsNavTile(
              icon: Icons.help_outline,
              title: l10n.pageTitleHelp,
              subtitle: l10n.settingsHelpSubtitle,
              onTap: () => context.push(AppRoutes.settingsHelp),
            ),
            SettingsNavTile(
              icon: Icons.mail_outline,
              title: l10n.settingsFeedback,
              subtitle: l10n.settingsFeedbackSubtitle,
              onTap: () => unawaited(sendFeedback(context, ref)),
            ),
            SettingsSectionHeader(l10n.settingsSectionAbout),
            SettingsNavTile(
              icon: Icons.info_outline,
              title: l10n.pageTitleAbout,
              subtitle: l10n.settingsAboutSubtitle,
              onTap: () => context.push(AppRoutes.settingsAbout),
            ),
            SettingsNavTile(
              icon: Icons.privacy_tip_outlined,
              title: l10n.settingsPrivacy,
              external: true,
              onTap: () => unawaited(
                openExternal(context, ref, AppLinks.privacyPolicy),
              ),
            ),
            SettingsNavTile(
              icon: Icons.description_outlined,
              title: l10n.settingsTerms,
              external: true,
              onTap: () =>
                  unawaited(openExternal(context, ref, AppLinks.terms)),
            ),
            const SizedBox(height: BannerSlot.clearance),
          ],
        ),
        bottomNavigationBar: const SafeArea(
          child: BannerSlot(placement: AdPlacement.settings),
        ),
      ),
    );
  }
}
