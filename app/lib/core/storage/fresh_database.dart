import 'dart:async';

import 'package:tv_remote/core/storage/settings_store.dart';

/// How long [forgetPhoneStateIfDatabaseIsNew] waits for the reset to reach
/// the platform before it reports a [TimeoutException] and lets the start
/// carry on. The store's cache has the reset at once, so this run behaves
/// the same either way; a stuck platform write must not hold the first
/// frame (decision #38).
const Duration freshDatabaseWriteTimeout = Duration(seconds: 2);

/// Resets the preferences that describe the old phone or its database
/// ([SettingsStore.freshDatabaseKeys]) when [databaseIsNew] says this run
/// created the database (Ruling P9-R6). Returns whether it reset them.
///
/// On iOS the preferences come back with an iCloud restore or Quick Start
/// and the database doesn't (Ruling P8-R1): the new phone has no TVs, has
/// not been asked about tracking, and has an Apps row that was never seeded.
/// The user's own choices, the launch count and the review flags are kept.
///
/// The reset is written to the preferences, so it outlives the database
/// instance: a first start that fails after this and is retried with a new
/// instance on the same, now existing, file still seeds the Apps row and
/// still opens onboarding.
///
/// Never throws. A database that can't open, a write that fails or one that
/// takes longer than [freshDatabaseWriteTimeout] goes to [onError], and it
/// returns false; the start carries on.
Future<bool> forgetPhoneStateIfDatabaseIsNew({
  required SettingsStore settings,
  required Future<bool> Function() databaseIsNew,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  try {
    if (!await databaseIsNew()) return false;
    await settings.resetForFreshDatabase().timeout(freshDatabaseWriteTimeout);
    return true;
  } on Object catch (error, stack) {
    onError?.call(error, stack);
    return false;
  }
}
