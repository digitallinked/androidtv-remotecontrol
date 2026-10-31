/// What drift's `SqliteException` is to Riverpod: an [Exception], which its
/// default retry would re-run for ~38 s behind a spinner. Storage tests throw
/// it to prove an error shows at once (Ruling P8-R10).
class DiskException implements Exception {
  /// Creates the exception.
  const DiskException();
}
