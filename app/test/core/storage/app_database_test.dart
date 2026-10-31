import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

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
