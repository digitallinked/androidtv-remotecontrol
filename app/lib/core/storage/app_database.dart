import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// TVs the user has paired with, keyed by their mDNS service name.
@DataClassName('SavedDevice')
class Devices extends Table {
  /// mDNS service name; stable identity of the TV.
  TextColumn get serviceName => text()();

  /// Name shown for the TV when no nickname is set.
  TextColumn get displayName => text()();

  /// Last known host (IP address or hostname).
  TextColumn get lastHost => text()();

  /// Remote-service TCP port.
  IntColumn get port => integer()();

  /// User-chosen name; `null` means use [displayName].
  TextColumn get nickname => text().nullable()();

  /// MAC address used for Wake-on-LAN, if the user set one.
  TextColumn get wolMac => text().nullable()();

  /// Hex SHA-256 of the TV's server key pinned at pairing; `null` means no
  /// trusted key and the TV must be paired again.
  TextColumn get serverKeyPin => text().nullable()();

  /// When the app last connected to this TV.
  DateTimeColumn get lastConnectedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {serviceName};
}

/// Quick-launch app shortcuts (global, not per TV).
@DataClassName('ShortcutRow')
class Shortcuts extends Table {
  /// Row id.
  IntColumn get id => integer().autoIncrement()();

  /// Android package name.
  TextColumn get package => text()();

  /// Label shown on the shortcut.
  TextColumn get name => text()();

  /// Deep link or market link used to launch the app.
  TextColumn get launchLink => text()();

  /// Icon URL, if known.
  TextColumn get iconUrl => text().nullable()();

  /// Whether the user created this shortcut by hand.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Custom tile colour as ARGB.
  IntColumn get customColor => integer().nullable()();

  /// Custom icon identifier.
  TextColumn get customIcon => text().nullable()();

  /// Sort position in the shortcut row.
  IntColumn get position => integer()();
}

/// How often each app has been seen on a TV (global, not per TV).
@DataClassName('AppUsageRow')
class AppUsage extends Table {
  /// Android package name.
  TextColumn get package => text()();

  /// Number of times the app has been seen.
  IntColumn get seenCount => integer().withDefault(const Constant(0))();

  /// When the app was last seen.
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {package};
}

/// The app's local SQLite database.
@DriftDatabase(tables: [Devices, Shortcuts, AppUsage])
class AppDatabase extends _$AppDatabase {
  /// Creates a database over [e], for example `NativeDatabase.memory()`.
  AppDatabase(super.e);

  /// Opens the on-device database file named `remotely`, in
  /// [databaseDirectory] when given (see `databaseDirectoryFor`), otherwise
  /// in drift's default directory.
  factory AppDatabase.open({Future<Object> Function()? databaseDirectory}) =>
      AppDatabase(
        driftDatabase(
          name: 'remotely',
          native: DriftNativeOptions(databaseDirectory: databaseDirectory),
        ),
      );

  @override
  int get schemaVersion => 1;
}
