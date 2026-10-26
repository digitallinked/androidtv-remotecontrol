import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/l10n/language_names.dart';
import 'package:tv_remote/app/theme/dynamic_color_support.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/settings/presentation/widgets/settings_tiles.dart';

/// Settings page for theme, wallpaper colours and language.
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
    final controller = ref.read(settingsControllerProvider.notifier);
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
              controller.update((store) => store.setThemePreference(value)),
            ),
          ),
          if (dynamicSupported)
            SettingsSwitchTile(
              title: l10n.appearanceDynamicColour,
              subtitle: l10n.appearanceDynamicColourSubtitle,
              value: settings.dynamicColor,
              onChanged: (value) => unawaited(
                controller.update((store) => store.setDynamicColor(value)),
              ),
            ),
          SettingsChoiceGroup<String?>(
            label: l10n.appearanceLanguage,
            // A stored code the app no longer has is shown as "Same as phone",
            // which is what the app does with it.
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
