import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_info.g.dart';

/// What the app knows about itself and the phone it runs on.
///
/// Nothing here describes a TV.
@immutable
class AppInfo {
  /// Creates the description.
  const AppInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.os,
    required this.osVersion,
  });

  /// The installed app's name.
  final String appName;

  /// The version, such as `1.0.0`.
  final String version;

  /// The build number, such as `1`.
  final String buildNumber;

  /// The phone's operating system, such as `Android` or `iOS`.
  final String os;

  /// The operating system's release, such as `12` or `17.5`.
  final String osVersion;
}

/// Reads the phone's operating system name and release, such as
/// `(os: 'Android', version: '12')`. It may throw.
typedef OsVersionReader = Future<({String os, String version})> Function();

/// How long [appInfo] waits for the [OsVersionReader] before it uses the
/// platform strings instead.
const Duration osVersionTimeout = Duration(seconds: 3);

/// Reads the release the user knows from `device_info_plus`: `Android 12`
/// (`version.release`), `iOS 17.5` (`systemVersion`). Elsewhere, the
/// platform's own strings.
@Riverpod(keepAlive: true)
OsVersionReader osVersionReader(Ref ref) => _readOsVersion;

Future<({String os, String version})> _readOsVersion() async {
  final plugin = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final info = await plugin.androidInfo;
    return (os: 'Android', version: info.version.release);
  }
  if (Platform.isIOS) {
    final info = await plugin.iosInfo;
    return (os: 'iOS', version: info.systemVersion);
  }
  return _platformOsVersion();
}

/// The `dart:io` strings: on Android the version is the kernel's, which is
/// why it is only the fallback.
({String os, String version}) _platformOsVersion() =>
    (os: Platform.operatingSystem, version: Platform.operatingSystemVersion);

/// Reads the app's package info and the phone's system version.
///
/// The system version never makes this fail: a reader that throws, or takes
/// longer than [osVersionTimeout], gives the platform strings. Package info
/// that can't be read does fail it. Callers show "unavailable" and carry on;
/// a retry would not help, so there isn't one.
@Riverpod(keepAlive: true, retry: _noRetry)
Future<AppInfo> appInfo(Ref ref) async {
  final readOsVersion = ref.watch(osVersionReaderProvider);
  final package = await PackageInfo.fromPlatform();
  final system = await _osVersionOrFallback(readOsVersion);
  return AppInfo(
    appName: package.appName,
    version: package.version,
    buildNumber: package.buildNumber,
    os: system.os,
    osVersion: system.version,
  );
}

Future<({String os, String version})> _osVersionOrFallback(
  OsVersionReader read,
) async {
  try {
    return await read().timeout(osVersionTimeout);
  } on Object {
    return _platformOsVersion();
  }
}

Duration? _noRetry(int retryCount, Object error) => null;
