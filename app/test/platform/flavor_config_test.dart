import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';

String read(String p) => File(p).readAsStringSync();

void main() {
  test('android_flavors_match_dart_flavors', () {
    final g = read('android/app/build.gradle.kts');
    expect(g, contains('applicationId = "${Flavor.prod.applicationId}"'));
    expect(g, contains('applicationIdSuffix = ".dev"'));
    expect(
      g,
      contains('manifestPlaceholders["appName"] = "${Flavor.dev.displayName}"'),
    );
    expect(
      g,
      contains(
        'manifestPlaceholders["appName"] = "${Flavor.prod.displayName}"',
      ),
    );
  });

  test('release_manifest_declares_network_permissions_and_flavor_label', () {
    final m = read('android/app/src/main/AndroidManifest.xml');
    for (final p in [
      'INTERNET',
      'ACCESS_NETWORK_STATE',
      'ACCESS_WIFI_STATE',
      'CHANGE_WIFI_MULTICAST_STATE',
    ]) {
      expect(
        m,
        contains('<uses-permission android:name="android.permission.$p"'),
      );
    }
    expect(m, contains(r'android:label="${appName}"'));
  });

  test('ios_has_six_flavor_configs_with_ids_and_names', () {
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    for (final f in Flavor.values) {
      for (final c in ['Debug', 'Release', 'Profile']) {
        // Project, Runner and RunnerTests each get one.
        expect(RegExp('name = "?$c-${f.name}"?;').allMatches(pbx).length, 3);
      }
      expect(pbx, contains('PRODUCT_BUNDLE_IDENTIFIER = ${f.applicationId};'));
      expect(pbx, contains('APP_DISPLAY_NAME = "${f.displayName}";'));
    }
    expect(
      read('ios/Runner/Info.plist'),
      contains(r'<string>$(APP_DISPLAY_NAME)</string>'),
    );
  });

  test('ios_schemes_use_their_flavor_configs', () {
    for (final f in Flavor.values) {
      final s = read(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/${f.name}.xcscheme',
      );
      for (final c in ['Debug', 'Release', 'Profile']) {
        expect(s, contains('buildConfiguration = "$c-${f.name}"'));
      }
      expect(s, isNot(contains('buildConfiguration = "Debug"')));
    }
  });

  test('default_flavor_is_dev', () {
    expect(read('pubspec.yaml'), contains('default-flavor: dev'));
  });
}
