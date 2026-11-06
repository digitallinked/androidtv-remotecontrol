import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file under `test/`.
///
/// Widget tests open a fresh in-memory database per test (through
/// `pumpRouterApp` and the bootstrap tests), so drift's "multiple databases"
/// warning would print on every one of them. Each database is in memory and
/// owned by one test, so the warning never points at a real problem here.
///
/// Secure storage is an in-memory fake, emptied before every test. A
/// database created this run makes bootstrap delete the stored client
/// identity (Ruling P9-C8), and tests that build the whole app without
/// overriding `identityStoreProvider` would otherwise call a platform
/// channel that never answers in a test, holding the start for its 2 s
/// bound.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  FlutterSecureStorage.setMockInitialValues({});
  // Empty again before each test, so no test sees another's writes.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  await testMain();
}
