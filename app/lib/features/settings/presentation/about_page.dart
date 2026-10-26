import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// About this app: name, version, open-source licences and credits.
class AboutPage extends ConsumerWidget {
  /// Creates the screen.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: context.appColors.textSecondary,
    );
    final name = ref.watch(flavorProvider).displayName;
    final info = ref.watch(appInfoProvider).value;
    final failed = ref.watch(appInfoProvider).hasError;
    final versionText = info != null
        ? l10n.aboutVersion(info.version, info.buildNumber)
        : failed
        ? l10n.aboutVersionUnknown
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleAbout)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.l,
        ),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                Text(name, style: theme.textTheme.titleLarge),
                if (versionText != null) Text(versionText, style: secondary),
              ],
            ),
          ),
          SettingsNavTile(
            icon: Icons.description_outlined,
            title: l10n.aboutLicences,
            onTap: () => showLicensePage(
              context: context,
              applicationName: name,
              applicationVersion: info?.version,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.l,
              AppSpacing.l,
              AppSpacing.l,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.m,
              children: [
                Text(l10n.aboutProtocol, style: secondary),
                Text(l10n.aboutTrademark, style: secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
