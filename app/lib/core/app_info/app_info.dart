import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/no_retry.dart';

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

/// How long [appInfo] waits for the [OsVersionReader] before it uses
/// [fallbackOsVersion] instead.
const Duration osVersionTimeout = Duration(seconds: 3);

/// The name the user knows for [platform]'s operating system, such as
/// `Android` or `iOS`.
String osNameOf(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'Android',
  TargetPlatform.iOS => 'iOS',
  TargetPlatform.macOS => 'macOS',
  TargetPlatform.windows => 'Windows',
  TargetPlatform.linux => 'Linux',
  TargetPlatform.fuchsia => 'Fuchsia',
};

/// The system description when the release can't be read: [platform]'s name
/// and `?`. Never the kernel string `dart:io` reports on Android.
({String os, String version}) fallbackOsVersion(TargetPlatform platform) =>
    (os: osNameOf(platform), version: '?');

/// Reads the release the user knows on [platform]: `Android 12` from
/// [androidRelease], `iOS 17.5` from [iosSystemVersion]. Other platforms
/// read nothing and give [fallbackOsVersion]. A reader that throws makes
/// this throw.
Future<({String os, String version})> readOsVersionFor(
  TargetPlatform platform, {
  required Future<String> Function() androidRelease,
  required Future<String> Function() iosSystemVersion,
}) async => switch (platform) {
  TargetPlatform.android => (os: 'Android', version: await androidRelease()),
  TargetPlatform.iOS => (os: 'iOS', version: await iosSystemVersion()),
  _ => fallbackOsVersion(platform),
};

/// Reads the release from `device_info_plus` (`version.release` on Android,
/// `systemVersion` on iOS), choosing by `defaultTargetPlatform`.
@Riverpod(keepAlive: true)
OsVersionReader osVersionReader(Ref ref) => _readOsVersion;

Future<({String os, String version})> _readOsVersion() {
  final plugin = DeviceInfoPlugin();
  return readOsVersionFor(
    defaultTargetPlatform,
    androidRelease: () async => (await plugin.androidInfo).version.release,
    iosSystemVersion: () async => (await plugin.iosInfo).systemVersion,
  );
}

/// Reads the app's package info and the phone's system version.
///
/// The system version never makes this fail: a reader that throws, or takes
/// longer than [osVersionTimeout], gives [fallbackOsVersion]. Package info
/// that can't be read does fail it. Callers show "unavailable" and carry on;
/// a retry would not help, so there isn't one.
@Riverpod(keepAlive: true, retry: noRetry)
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
    return fallbackOsVersion(defaultTargetPlatform);
  }
}
