import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/app_info/app_info.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/app_version.dart';

part 'update_gate.g.dart';

/// Whether this app version is older than the configured
/// `min_supported_version` and must be updated (Ruling P6-R7).
///
/// `false` while the app info is loading, when it can't be read, and for a
/// malformed version on either side: the gate never blocks by mistake.
@riverpod
bool updateRequired(Ref ref) {
  final info = ref.watch(appInfoProvider).value;
  final minimum = ref.watch(appConfigProvider).minSupportedVersion;
  return info != null && isBelowMinimum(info.version, minimum);
}
