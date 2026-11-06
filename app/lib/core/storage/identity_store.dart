import 'dart:async';
import 'dart:isolate';

import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/storage/secure_key_value_store.dart';

/// Thrown when the client identity cannot be stored.
///
/// The [message] never contains certificate or key text.
class IdentityStoreException implements Exception {
  /// Creates an exception with a user-safe [message].
  const IdentityStoreException(this.message);

  /// What went wrong, without any PEM content.
  final String message;

  @override
  String toString() => 'IdentityStoreException: $message';
}

/// Keeps this install's [ClientIdentity] in secure storage.
///
/// The identity is created on first use and reused afterwards, because the TV
/// remembers the certificate it paired with. Anything unusable in storage
/// (missing, half-written, corrupt or unreadable) is replaced by a new
/// identity, after which the TV asks to pair again.
class IdentityStore {
  /// Creates a store over [storage].
  ///
  /// [generate] makes a new identity; it defaults to running
  /// [ClientIdentity.generate] on a separate isolate, because RSA-2048 key
  /// generation would otherwise freeze the UI.
  ///
  /// A read that throws is tried once more after `readRetryDelay` before
  /// the identity counts as missing: secure storage can fail transiently,
  /// and regenerating would make every paired TV ask to pair again.
  IdentityStore(
    SecureKeyValueStore storage, {
    Future<ClientIdentity> Function()? generate,
    this._readRetryDelay = const Duration(milliseconds: 200),
  }) : _storage = storage,
       _generate = generate ?? _generateOffUiIsolate;

  /// How long [loadOrCreate] waits for an earlier [forget] to finish before
  /// it fails with [IdentityStoreException] (pairing then offers Try again).
  static const forgetWaitTimeout = Duration(seconds: 5);

  /// Storage key of the PEM encoded certificate.
  static const certificateKey = 'client_identity.certificate_pem';

  /// Storage key of the PEM encoded private key.
  static const privateKeyKey = 'client_identity.private_key_pem';

  final SecureKeyValueStore _storage;
  final Future<ClientIdentity> Function() _generate;
  final Duration _readRetryDelay;
  Future<ClientIdentity>? _pending;
  Future<void>? _forgetting;

  static Future<ClientIdentity> _generateOffUiIsolate() =>
      Isolate.run(ClientIdentity.generate);

  /// The stored identity, creating and saving one if there is none.
  ///
  /// Concurrent calls share one load. A failed call is not remembered, so the
  /// next call tries again. Throws [IdentityStoreException] when a new
  /// identity could not be saved; an unsaved identity is never returned.
  Future<ClientIdentity> loadOrCreate() => _pending ??= _loadOrCreate();

  /// Deletes the stored identity, so the next [loadOrCreate] makes a new one.
  ///
  /// Called when this run created the database (Ruling P9-C8): on iOS the
  /// keychain keeps the identity after the app is deleted, and a reinstall
  /// must not present the old phone's certificate. Both keys are tried even
  /// when one delete fails; the first failure is then rethrown.
  ///
  /// The caller may stop waiting (the start bounds it), but the deletes run
  /// on, so [loadOrCreate] waits for them first: a late delete must not
  /// remove an identity made after it. A keychain that never answers would
  /// hold the identity's own reads and writes just the same.
  Future<void> forget() {
    _pending = null;
    return _forgetting = _forget();
  }

  Future<void> _forget() async {
    Object? failure;
    StackTrace? failureStack;
    for (final key in const [certificateKey, privateKeyKey]) {
      try {
        await _storage.delete(key);
      } on Object catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  Future<ClientIdentity> _loadOrCreate() async {
    try {
      await _awaitForget();
      final stored = await _loadStored();
      if (stored != null) return stored;
      await _clear();
      final identity = await _generate();
      await _save(identity);
      return identity;
    } on Object {
      _pending = null;
      rethrow;
    }
  }

  /// Waits up to [forgetWaitTimeout] for an earlier [forget]. A forget that
  /// failed was reported by its caller, and the load copes with what's left.
  /// One that is still running fails this load instead: going on could make
  /// an identity that the late delete then removes.
  Future<void> _awaitForget() async {
    final forgetting = _forgetting;
    if (forgetting == null) return;
    try {
      await forgetting.timeout(forgetWaitTimeout);
    } on TimeoutException {
      throw const IdentityStoreException(
        'The previous client identity is still being deleted',
      );
    } on Object {
      // Reported by forget's caller.
    }
  }

  Future<(String?, String?)> _readPems() async => (
    await _storage.read(certificateKey),
    await _storage.read(privateKeyKey),
  );

  Future<ClientIdentity?> _loadStored() async {
    (String?, String?) pems;
    try {
      pems = await _readPems();
    } on Object {
      await Future<void>.delayed(_readRetryDelay);
      try {
        pems = await _readPems();
      } on Object {
        return null;
      }
    }
    final (certificate, privateKey) = pems;
    if (certificate == null || privateKey == null) return null;
    try {
      return ClientIdentity.fromPem(
        certificatePem: certificate,
        privateKeyPem: privateKey,
      );
      // `fromPem` documents ArgumentError as its failure mode.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _clear() async {
    for (final key in const [certificateKey, privateKeyKey]) {
      try {
        await _storage.delete(key);
      } on Object {
        // Best effort: the writes below replace whatever is left.
      }
    }
  }

  Future<void> _save(ClientIdentity identity) async {
    try {
      // Key first: a crash between the writes leaves a half that
      // `_loadStored` treats as missing.
      await _storage.write(privateKeyKey, identity.privateKeyPem);
      await _storage.write(certificateKey, identity.certificatePem);
    } on Object {
      // Drop the cause: platform errors may quote the stored value.
      throw const IdentityStoreException('Could not save the client identity');
    }
  }
}
