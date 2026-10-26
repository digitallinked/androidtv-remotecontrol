import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/data/starter_apps.dart';

void main() {
  test('starter_apps_have_unique_packages_and_market_links', () {
    expect(kStarterApps, hasLength(5));
    expect(kStarterApps.map((a) => a.name), [
      'Netflix',
      'YouTube',
      'Prime Video',
      'Disney+',
      'Spotify',
    ]);
    expect(kStarterApps.map((a) => a.package).toSet(), hasLength(5));
    for (final app in kStarterApps) {
      expect(app.launchLink, startsWith('market://launch?id='));
      expect(app.launchLink, 'market://launch?id=${app.package}');
    }
    expect(kStarterApps.map((a) => a.package), [
      'com.netflix.ninja',
      'com.google.android.youtube.tv',
      'com.amazon.amazonvideo.livingroom',
      'com.disney.disneyplus',
      'com.spotify.tv.android',
    ]);
  });

  test('quick_access_apps_provider_returns_the_starter_apps', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(quickAccessAppsProvider), kStarterApps);
  });
}
