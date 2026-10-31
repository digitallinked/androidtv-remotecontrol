import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/storage/identity_store.dart';

import 'in_memory_secure_store.dart';

ClientIdentity? _identity;

/// The fixture client identity from `test/fixtures/*.pem` (the same one the
/// `atv_remote` tests use). Loaded once and shared, because parsing PEM is
/// slow and generating a key is slower still.
///
/// On a device (`integration_test/` on Android or iOS) the fixture files
/// aren't there, so a new identity is generated instead, once per run. On the
/// host the fixtures must be found (tests run from `app/`): a missing one
/// throws a [StateError] rather than quietly generating a key.
ClientIdentity testIdentity() => _identity ??= _loadIdentity();

ClientIdentity _loadIdentity() {
  final certificate = File('test/fixtures/client.pem');
  final key = File('test/fixtures/client_key.pem');
  if (!certificate.existsSync() || !key.existsSync()) {
    if (Platform.isAndroid || Platform.isIOS) {
      return ClientIdentity.generate(commonName: 'integration-test-phone');
    }
    throw StateError(
      'The test identity fixtures are missing: expected ${certificate.path} '
      'and ${key.path} under ${Directory.current.path}. Run the tests from '
      'app/.',
    );
  }
  return ClientIdentity.fromPem(
    certificatePem: certificate.readAsStringSync(),
    privateKeyPem: key.readAsStringSync(),
  );
}

/// An [IdentityStore] over empty in-memory storage whose `generate` returns
/// [testIdentity]: on the host no RSA key is ever generated in a test (on a
/// device, [testIdentity] generates one once per run).
IdentityStore testIdentityStore() => IdentityStore(
  InMemorySecureKeyValueStore(),
  generate: () async => testIdentity(),
);
