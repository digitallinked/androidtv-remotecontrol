import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/app_version.dart';

part 'update_gate.g.dart';

/// Whether this app version is older than the configured
/// `min_supported_version` and must be updated (Ruling P6-R7).
///
/// It compares the compile-time [kAppVersion], so it decides on the first
/// frame: there is no loading window in which the remote shows (Ruling
/// P7-R8). A malformed version gives `false`: the gate never blocks by
/// mistake.
@riverpod
bool updateRequired(Ref ref) => isBelowMinimum(
  kAppVersion,
  ref.watch(appConfigProvider).minSupportedVersion,
);
