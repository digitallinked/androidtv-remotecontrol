import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/ads/banner_slot.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// The settings hub: the pages that hold every setting, grouped (Ruling
/// P5-R11).
///
/// The banner slot sits at the bottom and the list ends with
/// [BannerSlot.clearance] of space, so an ad never covers a row. There is no
/// bottom-anchored control.
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  // The mail and web links are wired in the help and about task; until then
  // they say the page can't be opened.
  void _linkUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).settingsLinkFailed),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
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
            onTap: () => _linkUnavailable(context),
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
            onTap: () => _linkUnavailable(context),
          ),
          SettingsNavTile(
            icon: Icons.description_outlined,
            title: l10n.settingsTerms,
            external: true,
            onTap: () => _linkUnavailable(context),
          ),
          const SizedBox(height: BannerSlot.clearance),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: BannerSlot(placement: AdPlacement.settings),
      ),
    );
  }
}
