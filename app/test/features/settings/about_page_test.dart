import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/app_info/app_info.dart';

import '../../helpers/pump_router_app.dart';

const _info = AppInfo(
  appName: 'Remotely Dev',
  version: '1.0.0',
  buildNumber: '1',
  os: 'android',
  osVersion: '12',
);

void main() {
  Future<void> pumpAbout(
    WidgetTester t, {
    Override? appInfo,
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsAbout,
      textScale: textScale,
      brightness: brightness,
      overrides: [
        flavorProvider.overrideWithValue(Flavor.dev),
        appInfo ?? appInfoProvider.overrideWith((ref) async => _info),
      ],
    );
  }

  testWidgets('about_shows_version_and_build', (t) async {
    await pumpAbout(t);

    expect(find.text('Remotely Dev'), findsOneWidget);
    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    expect(find.textContaining('trademarks of Google LLC'), findsOneWidget);
    expect(find.textContaining('androidtvremote2'), findsOneWidget);
  });

  testWidgets('about_survives_missing_package_info', (t) async {
    await pumpAbout(
      t,
      appInfo: appInfoProvider.overrideWith(
        (ref) => throw StateError('no package info'),
      ),
    );

    expect(find.text('Version unavailable'), findsOneWidget);
    expect(find.text('Remotely Dev'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('licences_row_opens_the_licence_page', (t) async {
    await pumpAbout(t);

    await t.tap(find.text('Open-source licences'));
    await t.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Remotely Dev'), findsWidgets);
  });

  for (final b in Brightness.values) {
    testWidgets('about_fits_320dp_at_200_percent_text_${b.name}', (t) async {
      await pumpAbout(
        t,
        size: const Size(320, 640),
        textScale: 2,
        brightness: b,
      );

      await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.textContaining('trademarks of Google LLC'), findsOneWidget);
    });
  }
}
