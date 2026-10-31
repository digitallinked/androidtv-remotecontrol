import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;

/// Runs before every test file under `test/`.
///
/// Widget tests open a fresh in-memory database per test (through
/// `pumpRouterApp` and the bootstrap tests), so drift's "multiple databases"
/// warning would print on every one of them. Each database is in memory and
/// owned by one test, so the warning never points at a real problem here.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
