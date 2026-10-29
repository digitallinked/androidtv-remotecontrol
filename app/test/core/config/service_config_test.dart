import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/config/service_config.dart';

void main() {
  test('none_has_every_service_off', () {
    const config = ServiceConfig.none;

    expect(config.firebaseEnabled, isFalse);
    expect(config.revenueCatKey(TargetPlatform.android), isNull);
    expect(config.revenueCatKey(TargetPlatform.iOS), isNull);
    for (final key in ServiceConfigKeys.all) {
      expect(config.define(key), isNull, reason: key);
    }
    expect(config.umpDebugEea, isFalse);
    expect(config.umpTestDeviceId, isNull);
  });

  test('empty_defines_count_as_missing', () {
    const config = ServiceConfig(
      // An empty define, as the build passes for an unset value.
      // ignore: avoid_redundant_argument_values
      revenueCatAndroidKey: '',
      revenueCatIosKey: 'ios',
    );

    expect(config.revenueCatKey(TargetPlatform.android), isNull);
    expect(config.define(ServiceConfigKeys.revenueCatAndroidKey), isNull);
    expect(config.revenueCatKey(TargetPlatform.iOS), 'ios');
  });

  test('values_are_returned_per_platform_and_key', () {
    const config = ServiceConfig(
      firebaseEnabled: true,
      revenueCatAndroidKey: 'a',
      revenueCatIosKey: 'i',
      admobBannerAndroid: 'ba',
      umpDebugGeography: 'eea',
      umpTestDeviceId: 'device',
    );

    expect(config.revenueCatKey(TargetPlatform.android), 'a');
    expect(config.revenueCatKey(TargetPlatform.iOS), 'i');
    expect(config.define(ServiceConfigKeys.admobBannerAndroid), 'ba');
    expect(config.define(ServiceConfigKeys.admobBannerIos), isNull);
    expect(config.umpDebugEea, isTrue);
    expect(config.umpTestDeviceId, 'device');
  });

  test('keys_match_the_env_example', () {
    final json =
        jsonDecode(File('env/example.json').readAsStringSync())
            as Map<String, Object?>;

    expect(
      ServiceConfigKeys.all.toSet(),
      json.keys.where((k) => k != '_README').toSet(),
    );
    expect(ServiceConfigKeys.all, hasLength(9));
  });

  test('environment_is_empty_without_dart_defines', () {
    expect(ServiceConfig.environment.firebaseEnabled, isFalse);
    expect(
      ServiceConfig.environment.revenueCatKey(TargetPlatform.android),
      isNull,
    );
  });
}
