import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/app_shell.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/colour_styles.dart';
import 'package:tv_remote/app/theme/dynamic_color_support.dart';
import 'package:tv_remote/app/theme/dynamic_scheme.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/interstitials.dart';
import 'package:tv_remote/core/analytics/analytics_hooks.dart';
import 'package:tv_remote/core/purchases/premium.dart';
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
    // Starts analytics' own listeners (connection, layout) and keeps them
    // alive; the provider never changes.
    ref
      ..watch(analyticsHooksProvider)
      // Ask now so Settings → Appearance already knows whether to offer the
      // wallpaper-colour switch when it opens (the answer is kept).
      ..read(dynamicColorSupportedProvider)
      // The first read starts the silent consent update (it shows nothing);
      // the consent form itself waits for the remote screen.
      ..read(consentControllerProvider)
      // Starts the interstitial pacing at launch, so it hears about
      // connection trouble from then on and keeps one ad loaded when
      // interstitials are enabled. Watched, not read: Riverpod may pause the
      // listeners inside a provider that nothing listens to.
      ..watch(interstitialsProvider);
    // The first read starts the purchase service, so Premium is known before
    // any banner. Watched, so a purchase or a lapse restyles the app at once.
    final premium = ref.watch(premiumProvider);
    final title = ref.watch(flavorProvider).displayName;
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = settings.dynamicColor;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: title,
          theme: buildSettingsTheme(
            brightness: Brightness.light,
            settings: settings,
            premium: premium,
            dynamicScheme: useDynamic
                ? colorSchemeFromDynamic(lightDynamic)
                : null,
          ),
          darkTheme: buildSettingsTheme(
            brightness: Brightness.dark,
            settings: settings,
            premium: premium,
            dynamicScheme: useDynamic
                ? colorSchemeFromDynamic(darkDynamic)
                : null,
          ),
          themeMode: _themeMode(settings.themePreference),
          // A theme choice shows at once; no cross-fade (also right for
          // reduce motion).
          themeAnimationDuration: Duration.zero,
          locale: localeFromCode(settings.localeCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: buildAppShell,
          routerConfig: router,
        );
      },
    );
  }
}
