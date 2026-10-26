@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/presentation/widgets/quick_access_row.dart';

import '../../../helpers/golden.dart';
import '../../../helpers/key_input_recorder.dart';

/// The five apps the quick row tests show.
const List<AppEntry> _apps = [
  AppEntry(package: 'com.netflix.ninja', name: 'Netflix'),
  AppEntry(package: 'com.google.android.youtube.tv', name: 'YouTube'),
  AppEntry(package: 'com.amazon.amazonvideo.livingroom', name: 'Prime Video'),
  AppEntry(package: 'com.disney.disneyplus', name: 'Disney+'),
  AppEntry(package: 'com.spotify.tv.android', name: 'Spotify'),
];

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
                  apps: _apps,
                  currentApp: 'com.google.android.youtube.tv',
                ),
              // A short list, so the All apps tile after it is in view (with
              // five apps it is the last thing in a scrolling row).
              QuickAccessBar(
                variant: QuickAccessRow.apps,
                input: input,
                apps: _apps.take(3).toList(),
                onAllApps: () {},
              ),
            ],
          ),
        ),
        brightness: b,
        size: const Size(390, 380),
      );
      await expectLater(
        find.byKey(const ValueKey('rows')),
        matchesGoldenFile('goldens/quick_access_rows_${b.name}.png'),
      );
    });
  }
}
