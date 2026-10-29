import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/l10n/language_names.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/dynamic_color_support.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// Settings page for theme, wallpaper colours, colour style and language.
///
/// Every choice is applied at once: the app watches the same settings.
class AppearancePage extends ConsumerWidget {
  /// Creates the screen.
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final dynamicSupported =
        ref.watch(dynamicColorSupportedProvider).value ?? false;
    final premium = ref.watch(premiumProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final styleNames = {
      ColourStyle.standard: l10n.appearanceStyleStandard,
      ColourStyle.ocean: l10n.appearanceStyleOcean,
      ColourStyle.ember: l10n.appearanceStyleEmber,
      ColourStyle.midnight: l10n.appearanceStyleMidnight,
    };
    final languages = [
      for (final locale in AppLocalizations.supportedLocales)
        locale.languageCode,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageTitleAppearance)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SettingsChoiceGroup<ThemePreference>(
            label: l10n.appearanceTheme,
            value: settings.themePreference,
            choices: [
              (ThemePreference.system, l10n.appearanceThemeSystem, null),
              (ThemePreference.light, l10n.appearanceThemeLight, null),
              (ThemePreference.dark, l10n.appearanceThemeDark, null),
            ],
            onChanged: (value) => unawaited(
              controller.update(
                (store) => store.setThemePreference(value),
              ),
            ),
          ),
          // `App` asks at start, so the answer is normally here before this
          // page opens and the switch doesn't pop in late.
          if (dynamicSupported)
            SettingsSwitchTile(
              title: l10n.appearanceDynamicColour,
              subtitle: l10n.appearanceDynamicColourSubtitle,
              value: settings.dynamicColor,
              onChanged: (value) => unawaited(
                controller.update(
                  (store) => store.setDynamicColor(value),
                ),
              ),
            ),
          // Colours from the wallpaper win over a style, so say why a choice
          // here shows nothing.
          if (dynamicSupported && settings.dynamicColor)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                0,
              ),
              child: Text(
                l10n.appearanceStyleWallpaperOn,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SettingsChoiceGroup<ColourStyle>(
            label: l10n.appearanceStyle,
            // Without Premium the stored choice is kept but not shown or
            // applied: the app looks standard, so the group says so too.
            value: premium.isPremium
                ? settings.colourStyle
                : ColourStyle.standard,
            choices: [
              for (final style in ColourStyle.values)
                (
                  style,
                  styleNames[style]!,
                  style == ColourStyle.standard || premium.isPremium
                      ? null
                      : l10n.appearanceStyleLocked,
                ),
            ],
            secondary: _StyleSwatch.new,
            onChanged: (style) {
              if (style != ColourStyle.standard && !premium.isPremium) {
                unawaited(
                  context.push(AppRoutes.paywall(source: PaywallSource.themes)),
                );
                return;
              }
              unawaited(
                controller.update((store) => store.setColourStyle(style)),
              );
            },
          ),
          SettingsChoiceGroup<String?>(
            label: l10n.appearanceLanguage,
            // A stored code the app has no translation for shows as
            // "Same as phone", which is what the app does with it.
            value: localeFromCode(settings.localeCode)?.languageCode,
            choices: [
              (null, l10n.appearanceLanguageSystem, null),
              for (final code in languages) (code, languageName(code), null),
            ],
            onChanged: (value) => unawaited(
              controller.update((store) => store.setLocaleCode(value)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 24 dp preview of a colour style: its accent on its background.
///
/// Decoration only: the row's title names the style.
class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch(this.style);

  final ColourStyle style;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = colourStyleColors(style, theme.brightness);
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.bg,
          shape: BoxShape.circle,
          border: Border.all(color: context.appColors.textSecondary),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: _size / 2),
        ),
      ),
    );
  }
}
