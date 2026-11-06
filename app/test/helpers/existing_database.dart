import 'package:drift/native.dart';
import 'package:tv_remote/core/storage/app_database.dart';

/// Returns a factory of in-memory databases that look as if an earlier run
/// created them: the real schema is there and the schema version is set, so
/// drift's `onCreate` doesn't run and `createdThisRun()` is false.
///
/// A plain `AppDatabase(NativeDatabase.memory())` is a database created this
/// run, which resets the preferences that describe the old phone (Ruling
/// P9-R6). Tests of an ordinary relaunch use this instead.
Future<AppDatabase Function()> existingDatabases() async {
  final template = AppDatabase(NativeDatabase.memory());
  final rows = await template
      .customSelect(
        'SELECT sql FROM sqlite_master '
        "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY rowid",
      )
      .get();
  final schema = [for (final row in rows) row.read<String>('sql')];
  final version = template.schemaVersion;
  await template.close();
  return () => AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        schema.forEach(raw.execute);
        raw.execute('PRAGMA user_version = $version');
      },
    ),
  );
}
