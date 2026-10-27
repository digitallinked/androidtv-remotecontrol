import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/data/shortcut_repository.dart';

part 'apps_data_providers.g.dart';

/// The user's app shortcuts, stored in the local database. Widget tests
/// override it with an in-memory fake.
@Riverpod(keepAlive: true)
ShortcutRepository shortcutRepository(Ref ref) =>
    DriftShortcutRepository(ref.watch(appDatabaseProvider));

/// App usage counts, stored in the local database. Widget tests override it
/// with an in-memory fake.
@Riverpod(keepAlive: true)
AppUsageRepository appUsageRepository(Ref ref) =>
    DriftAppUsageRepository(ref.watch(appDatabaseProvider));
