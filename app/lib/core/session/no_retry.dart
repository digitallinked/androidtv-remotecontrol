/// A retry policy that never retries.
///
/// Riverpod 3 retries a failed provider by default (an `Exception` such as
/// drift's `SqliteException` for ~38 s), which would hide the error behind a
/// loading state. Providers whose failure the UI must show (and the user must
/// be able to retry by hand) use this (Ruling P8-R10).
///
/// It lives in its own file so that storage providers can use it without
/// importing the session providers, which import them.
Duration? noRetry(int retryCount, Object error) => null;
