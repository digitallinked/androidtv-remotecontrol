import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tv_remote/core/app_info/app_info.dart';

import '../../helpers/platform_override.dart';

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Remotely Dev',
      packageName: 'app.remotely.dev',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    ),
  );

  Future<AppInfo> readWith(OsVersionReader reader) {
    final container = ProviderContainer.test(
      overrides: [osVersionReaderProvider.overrideWithValue(reader)],
    );
    return container.read(appInfoProvider.future);
  }

  Future<String> unexpected() => fail('this reader must not be called');

  test('os_version_is_the_release_not_the_kernel', () async {
    final info = await readWith(() async => (os: 'Android', version: '12'));

    expect(info.os, 'Android');
    expect(info.osVersion, '12');
    expect(info.appName, 'Remotely Dev');
    expect(info.version, '1.0.0');
    expect(info.buildNumber, '7');
  });

  test('reads_the_android_release_on_android', () async {
    final system = await readOsVersionFor(
      TargetPlatform.android,
      androidRelease: () async => '12',
      iosSystemVersion: unexpected,
    );

    expect(system, (os: 'Android', version: '12'));
  });

  test('reads_the_ios_system_version_on_ios', () async {
    final system = await readOsVersionFor(
      TargetPlatform.iOS,
      androidRelease: unexpected,
      iosSystemVersion: () async => '17.5',
    );

    expect(system, (os: 'iOS', version: '17.5'));
  });

  test('other_platforms_use_the_fallback', () async {
    final names = {
      TargetPlatform.android: 'Android',
      TargetPlatform.iOS: 'iOS',
      TargetPlatform.macOS: 'macOS',
      TargetPlatform.windows: 'Windows',
      TargetPlatform.linux: 'Linux',
      TargetPlatform.fuchsia: 'Fuchsia',
    };
    expect(names.keys, unorderedEquals(TargetPlatform.values));
    for (final MapEntry(key: platform, value: name) in names.entries) {
      expect(osNameOf(platform), name, reason: '$platform');
      expect(fallbackOsVersion(platform), (os: name, version: '?'));
    }

    expect(
      await readOsVersionFor(
        TargetPlatform.windows,
        androidRelease: unexpected,
        iosSystemVersion: unexpected,
      ),
      (os: 'Windows', version: '?'),
    );
    for (final platform in const [
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(
        await readOsVersionFor(
          platform,
          androidRelease: unexpected,
          iosSystemVersion: unexpected,
        ),
        fallbackOsVersion(platform),
      );
    }
  });

  testWidgetsOn(
    TargetPlatform.android,
    'a_failing_or_slow_reader_falls_back_to_the_target_platform',
    (tester) async {
      // A reader whose future fails, and one that throws before it returns
      // a future.
      for (final reader in <OsVersionReader>[
        () => Future.error(StateError('no device info')),
        () => throw StateError('no plugin'),
      ]) {
        final info = await readWith(reader);
        expect(info.os, 'Android');
        expect(info.osVersion, '?');
        expect(info.version, '1.0.0');
      }

      // A reader that never answers: nothing until the timeout, then the
      // target platform's name.
      AppInfo? slow;
      unawaited(
        readWith(
          () => Completer<({String os, String version})>().future,
        ).then((v) => slow = v),
      );
      await tester.pump(osVersionTimeout - const Duration(milliseconds: 100));
      expect(slow, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(slow?.os, 'Android');
      expect(slow?.osVersion, '?');
    },
  );

  testWidgetsOn(
    TargetPlatform.iOS,
    'the_fallback_follows_the_target_platform_not_the_host',
    (tester) async {
      final info = await readWith(
        () => Future.error(StateError('no device info')),
      );
      expect(info.os, 'iOS');
      expect(info.osVersion, '?');
    },
  );

  test('a_device_info_that_never_answers_falls_back_after_3s', () {
    fakeAsync((async) {
      AppInfo? info;
      unawaited(
        readWith(
          () => Completer<({String os, String version})>().future,
        ).then((v) => info = v),
      );
      async.elapse(const Duration(milliseconds: 2900));
      expect(info, isNull);
      async.elapse(const Duration(milliseconds: 200));
      expect(info?.os, fallbackOsVersion(defaultTargetPlatform).os);
      expect(info?.osVersion, '?');
    });
  });
}
