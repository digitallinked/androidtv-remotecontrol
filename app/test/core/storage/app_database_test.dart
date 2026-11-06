import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('file_path_is_the_database_file', () async {
    final dir = Directory.systemTemp.createTempSync('app_database_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/remotely.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final path = await db.filePath();

    expect(File(path!).parent.absolute.path, dir.absolute.path);
    expect(File(path).uri.pathSegments.last, 'remotely.sqlite');
  });

  test('a_database_in_memory_has_no_file_path', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.filePath(), isNull);
  });

  test('database_creates_devices_shortcuts_and_app_usage_tables', () async {
    expect(
      db.allTables.map((t) => t.actualTableName),
      containsAll(['devices', 'shortcuts', 'app_usage']),
    );
    await db
        .into(db.shortcuts)
        .insert(
          ShortcutsCompanion.insert(
            package: 'com.netflix.ninja',
            name: 'Netflix',
            launchLink: 'market://launch?id=com.netflix.ninja',
            position: 0,
          ),
        );
    await db
        .into(db.appUsage)
        .insert(
          AppUsageCompanion.insert(
            package: 'com.netflix.ninja',
            lastSeenAt: DateTime.utc(2026),
          ),
        );
    expect((await db.select(db.shortcuts).getSingle()).isCustom, isFalse);
    expect((await db.select(db.appUsage).getSingle()).seenCount, 0);
    expect(db.schemaVersion, 1);
  });
}
