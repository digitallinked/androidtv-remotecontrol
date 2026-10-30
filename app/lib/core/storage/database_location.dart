import 'package:flutter/services.dart';

/// The native channel that hands out storage locations (`AppDelegate.swift`).
const MethodChannel storageChannel = MethodChannel(
  'com.digitallinked.atvremote/storage',
);

/// Where the database file lives on [platform], as a
/// `DriftNativeOptions.databaseDirectory` callback.
///
/// `null` keeps drift's default (the app documents directory, `app_flutter`
/// on Android, which the backup rules exclude). On iOS the database lives in
/// `Library/Application Support/Database`, which the app marks as excluded
/// from iCloud and computer backups and from device transfer (Ruling P8-R1).
/// If that directory can't be had, the callback throws a [StateError] and
/// opening the database fails: it never falls back to `Documents`, which is
/// backed up.
Future<Object> Function()? databaseDirectoryFor(
  TargetPlatform platform, {
  MethodChannel channel = storageChannel,
}) {
  if (platform != TargetPlatform.iOS) return null;
  return () async {
    String? path;
    try {
      path = await channel.invokeMethod<String>(
        'backupExcludedDatabaseDirectory',
      );
    } on PlatformException {
      path = null;
    }
    if (path == null) {
      throw StateError('no backup-excluded database directory');
    }
    return path;
  };
}
