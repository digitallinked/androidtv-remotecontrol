import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/domain/recommendations.dart';

import '../../helpers/test_catalogue.dart';

AppUsageStat _stat(String package, int count, [int minute = 0]) => AppUsageStat(
  package: package,
  seenCount: count,
  lastSeenAt: DateTime.utc(2026, 10, 27, 9, minute),
);

void main() {
  final catalogue = testCatalogue();

  test('known_packages_use_catalogue_names', () {
    final apps = recommendApps(
      usage: [_stat('com.netflix.ninja', 3)],
      catalogue: catalogue,
      exclude: const {},
    );
    expect(apps.single.name, 'Netflix');
    expect(apps.single.package, 'com.netflix.ninja');
    expect(apps.single.customIcon, isNull);
    expect(apps.single.isCustom, isFalse);
  });

  test('unknown_packages_get_the_generic_icon', () {
    final apps = recommendApps(
      usage: [_stat('com.example.tvapp', 1)],
      catalogue: catalogue,
      exclude: const {},
    );
    expect(apps.single.name, 'Tvapp');
    expect(apps.single.customIcon, 'app');
    expect(apps.single.customIcon, kGenericAppIconId);
    expect(apps.single.launchLink, 'market://launch?id=com.example.tvapp');
  });

  test('recommendations_skip_system_apps_and_shortcuts_and_rank_by_use', () {
    final apps = recommendApps(
      usage: [
        _stat('com.google.android.tvlauncher', 99),
        _stat('android', 50),
        _stat('com.netflix.ninja', 40),
        _stat('com.example.rare', 1, 5),
        _stat('com.example.often', 7),
        _stat('com.example.recent', 7, 30),
      ],
      catalogue: catalogue,
      exclude: {'com.netflix.ninja'},
    );
    expect(
      [for (final a in apps) a.package],
      [
        'com.example.recent',
        'com.example.often',
        'com.example.rare',
      ],
    );
  });

  test('recommendations_stop_at_the_limit', () {
    final usage = [
      for (var i = 0; i < 12; i++) _stat('com.example.app$i', 20 - i),
    ];
    expect(
      recommendApps(usage: usage, catalogue: catalogue, exclude: const {}),
      hasLength(8),
    );
    final three = recommendApps(
      usage: usage,
      catalogue: catalogue,
      exclude: const {},
      limit: 3,
    );
    expect(
      [for (final a in three) a.package],
      [
        'com.example.app0',
        'com.example.app1',
        'com.example.app2',
      ],
    );
  });
}
