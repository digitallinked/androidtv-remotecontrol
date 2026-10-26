import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';

void main() {
  test('filters_system_packages', () {
    for (final p in [
      'android',
      'com.google.android.tvlauncher',
      'com.google.android.apps.tv.launcherx',
      'com.android.tv.settings',
      'com.mediatek.wwtv.tvcenter',
      'com.mediatek.wwtv.mediaplayer',
      'com.example.launcher3',
      'com.google.android.tv.remote.service',
      'com.google.android.leanbacklauncher',
      'com.google.android.apps.mediashell',
      'com.google.android.gms.tv',
      'com.google.android.inputmethod.latin',
    ]) {
      expect(isSystemPackage(p), isTrue, reason: p);
    }
    for (final p in [
      'com.netflix.ninja',
      'com.google.android.youtube.tv',
      'com.example.tvapp',
    ]) {
      expect(isSystemPackage(p), isFalse, reason: p);
    }
  });

  test('unknown_package_gets_pretty_name', () {
    expect(prettyPackageName('com.foo.bar'), 'Bar');
    expect(prettyPackageName('com.example.app.tv'), 'Example');
    expect(prettyPackageName('tv.pluto.android'), 'Pluto');
    expect(prettyPackageName('com.my_videos.tv'), 'My videos');
    // Nothing meaningful left: the package itself.
    expect(prettyPackageName('com.android.tv'), 'com.android.tv');
  });

  test('valid_package_names', () {
    expect(isValidPackageName('com.example.app'), isTrue);
    expect(isValidPackageName('com.example_2.App9'), isTrue);
    for (final p in ['example', '1com.x', 'com..x', 'com.x-y', '', 'com.']) {
      expect(isValidPackageName(p), isFalse, reason: p);
    }
    expect(isValidPackageName('com.${'a' * 251}'), isTrue);
    expect(isValidPackageName('com.${'a' * 252}'), isFalse);
  });
}
