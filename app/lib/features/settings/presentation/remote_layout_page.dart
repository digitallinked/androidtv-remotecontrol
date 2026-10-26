import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/data/starter_apps.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';
import 'package:tv_remote/features/remote/presentation/widgets/pad_pager.dart';
import 'package:tv_remote/features/remote/presentation/widgets/remote_body.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// The size the preview lays the remote out at, in dp: a typical phone in
/// portrait. The preview scales it down to [_previewHeight].
const Size _previewLayoutSize = Size(360, 640);

/// The height of the preview box, in dp.
const double _previewHeight = 280;

/// Settings page for the remote's layout: the navigation style and the row
/// above the pad, over a live preview of the remote with those choices.
class RemoteLayoutPage extends ConsumerWidget {
  /// Creates the screen.
  const RemoteLayoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (navigation, quick) = ref.watch(
      settingsControllerProvider.select(
        (s) => (s.navigationStyle, s.quickAccessRow),
      ),
    );
    final apps = ref.watch(quickAccessAppsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleRemoteLayout)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SettingsSectionHeader(l10n.layoutPreviewTitle),
          _Preview(navigation: navigation, quick: quick, apps: apps),
          SettingsChoiceGroup<NavigationStyle>(
            label: l10n.layoutNavigation,
            value: navigation,
            choices: [
              (
                NavigationStyle.touchpad,
                l10n.remotePadTouchpad,
                l10n.layoutTouchpadSubtitle,
              ),
              (
                NavigationStyle.dpad,
                l10n.remotePadDpad,
                l10n.layoutDpadSubtitle,
              ),
            ],
            onChanged: (value) => unawaited(
              controller.update((store) => store.setNavigationStyle(value)),
            ),
          ),
          SettingsChoiceGroup<QuickAccessRow>(
            label: l10n.layoutQuickAccess,
            value: quick,
            choices: [
              (
                QuickAccessRow.apps,
                l10n.layoutQuickApps,
                l10n.layoutQuickAppsSubtitle,
              ),
              (
                QuickAccessRow.colourKeys,
                l10n.quickAccessColourLabel,
                l10n.layoutQuickColourSubtitle,
              ),
              (
                QuickAccessRow.mediaKeys,
                l10n.quickAccessMediaLabel,
                l10n.layoutQuickMediaSubtitle,
              ),
              (
                QuickAccessRow.none,
                l10n.layoutQuickNone,
                l10n.layoutQuickNoneSubtitle,
              ),
            ],
            onChanged: (value) => unawaited(
              controller.update((store) => store.setQuickAccessRow(value)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The remote drawn small, for the choices above it.
///
/// It is a picture: one screen-reader node, no taps, and a fixed phone-sized
/// layout that is scaled to fit, so it looks the same at any text size.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.navigation,
    required this.quick,
    required this.apps,
  });

  final NavigationStyle navigation;
  final QuickAccessRow quick;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Center(
        child: SizedBox(
          key: const Key('layout_preview'),
          height: _previewHeight,
          child: Semantics(
            label: AppLocalizations.of(context).layoutPreviewSemantics,
            image: true,
            child: ExcludeSemantics(
              // A picture: no taps, and no focus for a keyboard or switch.
              child: ExcludeFocus(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.bg,
                      border: Border.all(color: colors.outline),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: FittedBox(
                        child: SizedBox.fromSize(
                          size: _previewLayoutSize,
                          child: MediaQuery(
                            data: media.copyWith(
                              size: _previewLayoutSize,
                              padding: EdgeInsets.zero,
                              viewPadding: EdgeInsets.zero,
                              viewInsets: EdgeInsets.zero,
                              textScaler: TextScaler.noScaling,
                              disableAnimations: true,
                              accessibleNavigation: false,
                            ),
                            child: RemoteBody(
                              key: ValueKey((navigation, quick)),
                              input: const _NoInput(),
                              enabled: true,
                              quickAccess: quick,
                              apps: apps,
                              currentApp: null,
                              initialPage: navigation == NavigationStyle.dpad
                                  ? PadPage.dpad
                                  : PadPage.touchpad,
                              onPageChanged: (_) {},
                              volume: const VolumeChanged(12, 100, false),
                              onKeyboard: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the preview's keys go: nowhere.
class _NoInput implements RemoteInput {
  const _NoInput();

  @override
  bool tap(int keyCode) => false;

  @override
  void holdStart(int keyCode) {}

  @override
  void holdEnd(int keyCode) {}

  @override
  bool launch(AppEntry app) => false;

  @override
  bool typeText(String text) => false;
}
