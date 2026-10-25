import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';

/// Pumps [child] inside a themed [MaterialApp].
///
/// [textScale] and [disableAnimations] override the ambient `MediaQuery`.
/// With [wrapInScaffold] the child is centred in a `Scaffold`; otherwise it is
/// the app's `home` as given.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
  bool wrapInScaffold = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(brightness: brightness),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: app!,
      ),
      home: wrapInScaffold ? Scaffold(body: Center(child: child)) : child,
    ),
  );
}
