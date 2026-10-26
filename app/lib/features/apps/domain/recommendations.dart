import 'package:tv_remote/features/apps/data/app_usage_repository.dart';
import 'package:tv_remote/features/apps/domain/app_catalogue.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/apps/domain/package_names.dart';

/// The icon id of the generic app icon, used for apps that are not in the
/// catalogue.
const String kGenericAppIconId = 'app';

/// "Recently used on your TV" (Ruling P5-R6): the apps seen in [usage], most
/// used first and then most recent, without system packages and without the
/// packages in [exclude] (the apps already on the list), at most [limit].
///
/// Catalogue apps use their catalogue name; others get [prettyPackageName]
/// and the generic icon.
List<AppEntry> recommendApps({
  required List<AppUsageStat> usage,
  required AppCatalogue catalogue,
  required Set<String> exclude,
  int limit = 8,
}) {
  final ranked = [...usage]
    ..sort((a, b) {
      final byCount = b.seenCount.compareTo(a.seenCount);
      if (byCount != 0) return byCount;
      return b.lastSeenAt.compareTo(a.lastSeenAt);
    });
  final result = <AppEntry>[];
  final seen = <String>{};
  for (final stat in ranked) {
    if (result.length >= limit) break;
    final package = stat.package;
    if (isSystemPackage(package) ||
        exclude.contains(package) ||
        !seen.add(package)) {
      continue;
    }
    result.add(
      catalogue.byPackage(package)?.toEntry() ??
          AppEntry(
            package: package,
            name: prettyPackageName(package),
            customIcon: kGenericAppIconId,
          ),
    );
  }
  return result;
}
