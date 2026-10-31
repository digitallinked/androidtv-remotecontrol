/// Test-only helpers for code that talks to an Android TV: an in-process
/// fake TV that speaks the real protocol over loopback TLS.
///
/// Import this only from tests. The app's own `lib/` never imports it (the
/// app checks that with a test), so release builds never contain it. The
/// main library, `package:atv_remote/atv_remote.dart`, doesn't export it.
library;

export 'src/testing/fake_tv_server.dart' show FakeTvServer;
