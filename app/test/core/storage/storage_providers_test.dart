import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/database_location.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('ios_app_database_opens_in_the_backup_excluded_directory', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final root = Directory.systemTemp.createTempSync('remotely_db_');
    addTearDown(() => root.deleteSync(recursive: true));
    final excluded = Directory('${root.path}${Platform.pathSeparator}Database')
      ..createSync();
    final temp = Directory('${root.path}${Platform.pathSeparator}tmp')
      ..createSync();

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(storageChannel, (call) async {
      calls.add(call);
      return excluded.path;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(storageChannel, null));
    // drift asks path_provider for a temporary directory once per process.
    // Every other path_provider answer is null, so a database that skipped
    // the excluded directory and asked for Documents would fail to open.
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(
      pathProvider,
      (call) async => call.method == 'getTemporaryDirectory' ? temp.path : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));

    final container = ProviderContainer();
    final db = container.read(appDatabaseProvider);
    await db.customSelect('SELECT 1').get();
    container.dispose();
    await db.close();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'backupExcludedDatabaseDirectory');
    expect(
      File(
        '${excluded.path}${Platform.pathSeparator}remotely.sqlite',
      ).existsSync(),
      isTrue,
    );
  });
}
