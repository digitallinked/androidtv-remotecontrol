@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/data/starter_apps.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';

import '../../../helpers/golden.dart';
import '../../../helpers/key_input_recorder.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('quick_access_rows_${b.name}', (t) async {
      final input = KeyInputRecorder();
      await pumpForGolden(
        t,
        RepaintBoundary(
          key: const ValueKey('rows'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              for (final variant in [
                QuickAccessRow.apps,
                QuickAccessRow.colourKeys,
                QuickAccessRow.mediaKeys,
              ])
                QuickAccessBar(
                  variant: variant,
                  input: input,
                  apps: kStarterApps,
                  currentApp: 'com.google.android.youtube.tv',
                ),
            ],
          ),
        ),
        brightness: b,
        size: const Size(390, 300),
      );
      await expectLater(
        find.byKey(const ValueKey('rows')),
        matchesGoldenFile('goldens/quick_access_rows_${b.name}.png'),
      );
    });
  }
}
