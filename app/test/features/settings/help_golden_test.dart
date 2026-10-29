@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations_en.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/links/link_opener.dart';
import 'package:tv_remote/features/settings/presentation/help_page.dart';

import '../../helpers/pump_router_app.dart';
import '../../helpers/recording_link_opener.dart';

void main() {
  testWidgets('help_page_dark', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpRouterApp(
      t,
      initialLocation: AppRoutes.settingsHelp,
      brightness: Brightness.dark,
      overrides: [
        linkOpenerProvider.overrideWithValue(RecordingLinkOpener()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(
            appName: 'Remotely Dev',
            version: '1.0.0',
            buildNumber: '1',
            os: 'Android',
            osVersion: '12',
          ),
        ),
      ],
    );

    await t.tap(find.text(AppLocalizationsEn().faqTvsQ));
    await t.pumpAndSettle();

    await expectLater(
      find.byType(HelpPage),
      matchesGoldenFile('goldens/help_page_dark.png'),
    );
  });
}
