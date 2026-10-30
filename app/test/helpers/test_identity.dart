import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/storage/identity_store.dart';

import 'in_memory_secure_store.dart';

ClientIdentity? _identity;

/// The fixture client identity from `test/fixtures/*.pem` (the same one the
/// `atv_remote` tests use). Loaded once and shared, because parsing PEM is
/// slow and generating a key is slower still.
///
/// On a device (`integration_test/`) the fixture files aren't there, so a new
/// identity is generated instead, once per run.
ClientIdentity testIdentity() => _identity ??= _loadIdentity();

ClientIdentity _loadIdentity() {
  final certificate = File('test/fixtures/client.pem');
  final key = File('test/fixtures/client_key.pem');
  if (!certificate.existsSync() || !key.existsSync()) {
    return ClientIdentity.generate(commonName: 'integration-test-phone');
  }
  return ClientIdentity.fromPem(
    certificatePem: certificate.readAsStringSync(),
    privateKeyPem: key.readAsStringSync(),
  );
}

/// An [IdentityStore] over empty in-memory storage whose `generate` returns
/// [testIdentity], so no RSA key is ever generated in a test.
IdentityStore testIdentityStore() => IdentityStore(
  InMemorySecureKeyValueStore(),
  generate: () async => testIdentity(),
);
