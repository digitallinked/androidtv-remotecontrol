import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/app/theme/dynamic_scheme.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/settings_store.dart';

/// The [Locale] for a stored language [code], or `null` (follow the system)
/// when there is none, it is empty, or the app has no translation for it.
Locale? localeFromCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final supported = AppLocalizations.supportedLocales.any(
    (locale) => locale.languageCode == code,
  );
  return supported ? Locale(code) : null;
}

ThemeMode _themeMode(ThemePreference preference) => switch (preference) {
  ThemePreference.system => ThemeMode.system,
  ThemePreference.light => ThemeMode.light,
  ThemePreference.dark => ThemeMode.dark,
};

/// The app: theme, language and routing, driven by the user's settings.
class App extends ConsumerWidget {
  /// Creates the app.
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(appRouterProvider);
    final title = ref.watch(flavorProvider).displayName;
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = settings.dynamicColor;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: title,
          theme: buildAppTheme(
            brightness: Brightness.light,
            dynamicScheme: useDynamic
                ? colorSchemeFromDynamic(lightDynamic)
                : null,
          ),
          darkTheme: buildAppTheme(
            brightness: Brightness.dark,
            dynamicScheme: useDynamic
                ? colorSchemeFromDynamic(darkDynamic)
                : null,
          ),
          themeMode: _themeMode(settings.themePreference),
          locale: localeFromCode(settings.localeCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );
      },
    );
  }
}
