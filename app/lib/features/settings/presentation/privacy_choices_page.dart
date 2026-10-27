import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/app_links.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/tracking_service.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';
import 'package:tv_remote/features/settings/application/feedback.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// Settings → Privacy choices: what the app may share, and the ad choices
/// (Ruling P6-R8).
///
/// The two switches show the effective value (the user's choice, else what
/// the region allows) and a change stores an explicit choice that applies at
/// once. There is no banner here.
class PrivacyChoicesPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const PrivacyChoicesPage({super.key});

  @override
  ConsumerState<PrivacyChoicesPage> createState() => _PrivacyChoicesPageState();
}

class _PrivacyChoicesPageState extends ConsumerState<PrivacyChoicesPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The user may change the tracking answer in the phone's Settings and
    // come back to this page.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(trackingStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _setUsage({required bool value}) => ref
      .read(settingsControllerProvider.notifier)
      .update((store) => store.setShareUsageStats(value));

  Future<void> _setCrashes({required bool value}) => ref
      .read(settingsControllerProvider.notifier)
      .update((store) => store.setShareCrashReports(value));

  /// The privacy-options form is on screen (or loading); a second tap on the
  /// row meanwhile would open another.
  bool _openingAdChoices = false;

  Future<void> _openAdChoices() async {
    if (_openingAdChoices) return;
    _openingAdChoices = true;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bool shown;
    try {
      shown = await ref
          .read(consentControllerProvider.notifier)
          .showPrivacyOptions();
    } finally {
      _openingAdChoices = false;
    }
    if (shown || !mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.privacyAdChoicesFailed)));
  }

  String? _trackingText(AppLocalizations l10n, TrackingStatus status) =>
      switch (status) {
        TrackingStatus.authorized => l10n.privacyTrackingAllowed,
        TrackingStatus.denied => l10n.privacyTrackingDenied,
        TrackingStatus.notDetermined => l10n.privacyTrackingNotDetermined,
        TrackingStatus.restricted => l10n.privacyTrackingRestricted,
        TrackingStatus.notApplicable => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: context.appColors.textSecondary,
    );
    final choices = ref.watch(privacyChoicesProvider);
    final servicesOff =
        ref.watch(firebaseStatusProvider) != FirebaseStatus.ready;
    final premium = ref.watch(premiumProvider).isPremium;
    // Watching also starts the silent consent update, which is what tells
    // whether the privacy-options entry is needed.
    final adChoices = ref.watch(
      consentControllerProvider.select((c) => c.privacyOptionsRequired),
    );
    final onIos = defaultTargetPlatform == TargetPlatform.iOS;
    final tracking = onIos
        ? ref.watch(trackingStatusProvider).value
        : TrackingStatus.notApplicable;
    final trackingText = tracking == null
        ? null
        : _trackingText(l10n, tracking);

    Widget note(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Text(text, style: secondary),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitlePrivacyChoices)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.l,
        ),
        children: [
          note(l10n.privacyIntro),
          SettingsSectionHeader(l10n.privacySectionImprove),
          SettingsSwitchTile(
            title: l10n.privacyUsageTitle,
            subtitle: l10n.privacyUsageSubtitle,
            value: choices.shareUsage,
            onChanged: (value) => unawaited(_setUsage(value: value)),
          ),
          SettingsSwitchTile(
            title: l10n.privacyCrashTitle,
            subtitle: l10n.privacyCrashSubtitle,
            value: choices.shareCrashReports,
            onChanged: (value) => unawaited(_setCrashes(value: value)),
          ),
          if (servicesOff) note(l10n.privacyServicesOff),
          SettingsSectionHeader(l10n.privacySectionAds),
          if (premium)
            note(l10n.privacyAdsPremium)
          else ...[
            note(l10n.privacyAdsInfo),
            SettingsNavTile(
              title: l10n.privacyRemoveAds,
              onTap: () => unawaited(
                context.push(AppRoutes.paywall(source: PaywallSource.privacy)),
              ),
            ),
            if (adChoices)
              SettingsNavTile(
                title: l10n.privacyAdChoices,
                subtitle: l10n.privacyAdChoicesSubtitle,
                onTap: () => unawaited(_openAdChoices()),
              ),
          ],
          if (trackingText != null)
            Semantics(
              hint: l10n.privacyOpensSettings,
              child: SettingsNavTile(
                title: l10n.privacyTrackingTitle,
                subtitle: trackingText,
                onTap: () => unawaited(
                  openExternal(context, ref, Uri.parse('app-settings:')),
                ),
              ),
            ),
          SettingsNavTile(
            icon: Icons.privacy_tip_outlined,
            title: l10n.settingsPrivacy,
            external: true,
            onTap: () => unawaited(
              openExternal(context, ref, AppLinks.privacyPolicy),
            ),
          ),
        ],
      ),
    );
  }
}
