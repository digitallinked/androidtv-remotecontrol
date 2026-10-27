import 'dart:async';
import 'dart:io' show Platform;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tv_remote/core/app_info/app_info.dart';

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

  test('os_version_is_the_release_not_the_kernel', () async {
    final info = await readWith(() async => (os: 'Android', version: '12'));

    expect(info.os, 'Android');
    expect(info.osVersion, '12');
    expect(info.appName, 'Remotely Dev');
    expect(info.version, '1.0.0');
    expect(info.buildNumber, '7');
  });

  test('device_info_failure_falls_back_to_platform_strings', () async {
    final info = await readWith(
      () => Future.error(StateError('no device info')),
    );

    expect(info.os, Platform.operatingSystem);
    expect(info.osVersion, Platform.operatingSystemVersion);
    expect(info.version, '1.0.0');

    // A reader that throws before it returns a future falls back too.
    final thrown = await readWith(() => throw StateError('no plugin'));
    expect(thrown.os, Platform.operatingSystem);
    expect(thrown.osVersion, Platform.operatingSystemVersion);
  });

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
      expect(info?.os, Platform.operatingSystem);
      expect(info?.osVersion, Platform.operatingSystemVersion);
    });
  });
}
