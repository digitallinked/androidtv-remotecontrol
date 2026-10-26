import 'dart:io' show Platform;

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

  /// The phone's operating system, such as `android` or `ios`.
  final String os;

  /// The operating system's version string.
  final String osVersion;
}

/// Reads the app's package info and the phone's system version.
///
/// Fails when the platform can't answer. Callers show "unavailable" and carry
/// on; a retry would not help, so there isn't one.
@Riverpod(keepAlive: true, retry: _noRetry)
Future<AppInfo> appInfo(Ref ref) async {
  final package = await PackageInfo.fromPlatform();
  return AppInfo(
    appName: package.appName,
    version: package.version,
    buildNumber: package.buildNumber,
    os: Platform.operatingSystem,
    osVersion: Platform.operatingSystemVersion,
  );
}

Duration? _noRetry(int retryCount, Object error) => null;
