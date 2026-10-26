@Tags(['golden'])
library;

import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/keyboard/keyboard_sheet.dart';

import '../../helpers/key_input_recorder.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('keyboard_sheet_${b.name}', (t) async {
      t.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final rec = KeyInputRecorder();
      final states = StreamController<TvConnectionState>();
      addTearDown(states.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStateProvider.overrideWith((ref) => states.stream),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(brightness: b),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showKeyboardSheet(context, input: rec),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      states.add(const TvConnectionState(status: ConnectionStatus.connected));
      await t.tap(find.text('Open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.byType(TextField), 'netflix');
      await t.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/keyboard_sheet_${b.name}.png'),
      );
    });
  }
}
