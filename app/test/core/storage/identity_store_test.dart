import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/secure_key_value_store.dart';

import '../../helpers/in_memory_secure_store.dart';

void main() {
  late ClientIdentity fixture;
  late ClientIdentity fixture2;

  setUpAll(() {
    fixture = ClientIdentity.generate();
    fixture2 = ClientIdentity.generate();
  });

  test('identity_is_created_once_and_reused', () async {
    final storage = InMemorySecureKeyValueStore();
    var n = 0;
    final a = await IdentityStore(
      storage,
      generate: () async {
        n++;
        return fixture;
      },
    ).loadOrCreate();
    final b = await IdentityStore(
      storage,
      generate: () async {
        n++;
        return fixture2;
      },
    ).loadOrCreate();
    expect(n, 1);
    expect(b.certificatePem, a.certificatePem);
    expect(
      storage.values.keys,
      containsAll([IdentityStore.certificateKey, IdentityStore.privateKeyKey]),
    );
  });

  test('concurrent_calls_generate_once', () async {
    var n = 0;
    final s = IdentityStore(
      InMemorySecureKeyValueStore(),
      generate: () async {
        n++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return fixture;
      },
    );
    final r = await Future.wait([s.loadOrCreate(), s.loadOrCreate()]);
    expect(n, 1);
    expect(identical(r[0], r[1]), isTrue);
  });

  test('regenerates_when_stored_pem_is_corrupt', () async {
    final storage = InMemorySecureKeyValueStore()
      ..values.addAll({
        IdentityStore.certificateKey: 'garbage',
        IdentityStore.privateKeyKey: 'garbage',
      });
    final id = await IdentityStore(
      storage,
      generate: () async => fixture,
    ).loadOrCreate();
    expect(id.certificatePem, fixture.certificatePem);
    expect(
      storage.values[IdentityStore.certificateKey],
      fixture.certificatePem,
    );
    expect(storage.values[IdentityStore.privateKeyKey], fixture.privateKeyPem);
  });

  test('regenerates_when_only_one_half_is_stored', () async {
    final storage = InMemorySecureKeyValueStore()
      ..values[IdentityStore.privateKeyKey] = fixture2.privateKeyPem;
    var n = 0;
    final id = await IdentityStore(
      storage,
      generate: () async {
        n++;
        return fixture;
      },
    ).loadOrCreate();
    expect(n, 1);
    expect(id.certificatePem, fixture.certificatePem);
    expect(
      storage.values[IdentityStore.certificateKey],
      fixture.certificatePem,
    );
    expect(storage.values[IdentityStore.privateKeyKey], fixture.privateKeyPem);
  });

  test('regenerates_when_storage_read_throws', () async {
    final storage = InMemorySecureKeyValueStore()
      ..throwOnRead = PlatformException(code: 'x');
    final id = await IdentityStore(
      storage,
      generate: () async => fixture,
    ).loadOrCreate();
    expect(id.certificatePem, fixture.certificatePem);
    storage.throwOnRead = null;
    expect(
      storage.values.keys,
      containsAll([IdentityStore.certificateKey, IdentityStore.privateKeyKey]),
    );
  });

  test('transient_read_failure_is_retried_once_before_regenerating', () async {
    final storage = InMemorySecureKeyValueStore()
      ..values.addAll({
        IdentityStore.certificateKey: fixture.certificatePem,
        IdentityStore.privateKeyKey: fixture.privateKeyPem,
      })
      ..failNextReads = 1;
    var n = 0;
    final id = await IdentityStore(
      storage,
      generate: () async {
        n++;
        return fixture2;
      },
      readRetryDelay: Duration.zero,
    ).loadOrCreate();
    expect(n, 0);
    expect(id.certificatePem, fixture.certificatePem);
  });

  test('write_failure_throws_and_next_call_retries', () async {
    final storage = InMemorySecureKeyValueStore()
      ..throwOnWrite = PlatformException(code: 'x');
    final s = IdentityStore(storage, generate: () async => fixture);
    await expectLater(
      s.loadOrCreate(),
      throwsA(
        isA<IdentityStoreException>().having(
          (e) => e.message,
          'message',
          isNot(contains('BEGIN')),
        ),
      ),
    );
    storage.throwOnWrite = null;
    expect((await s.loadOrCreate()).certificatePem, fixture.certificatePem);
  });

  // Ruling P9-C8: a fresh database forgets the identity, so a reinstall on
  // the same iPhone (whose keychain outlives the app) gets a new one.
  test(
    'forget_deletes_both_halves_and_the_next_load_makes_a_new_identity',
    () async {
      final storage = InMemorySecureKeyValueStore();
      var n = 0;
      final store = IdentityStore(
        storage,
        generate: () async => n++ == 0 ? fixture : fixture2,
      );
      expect(
        (await store.loadOrCreate()).certificatePem,
        fixture.certificatePem,
      );

      await store.forget();

      expect(storage.values, isEmpty);
      // The same instance doesn't hand back the forgotten identity.
      expect(
        (await store.loadOrCreate()).certificatePem,
        fixture2.certificatePem,
      );
      expect(
        storage.values[IdentityStore.certificateKey],
        fixture2.certificatePem,
      );
    },
  );

  // Re-review Minor A: a keychain delete that never finishes must not leave
  // pairing waiting forever. The load fails like an unreadable store, so
  // pairing shows "identity unavailable" with Try again, and it never makes
  // an identity the late delete could remove.
  test('a_forget_that_never_finishes_fails_the_load_after_its_bound', () {
    fakeAsync((async) {
      final keychain = Completer<void>();
      final storage = InMemorySecureKeyValueStore()
        ..values.addAll({
          IdentityStore.certificateKey: fixture.certificatePem,
          IdentityStore.privateKeyKey: fixture.privateKeyPem,
        })
        ..deleteGate = keychain.future;
      var generated = 0;
      final store = IdentityStore(
        storage,
        generate: () async {
          generated++;
          return fixture2;
        },
      );
      unawaited(store.forget().then<void>((_) {}, onError: (_) {}));

      Object? failure;
      ClientIdentity? loaded;
      unawaited(
        store.loadOrCreate().then(
          (id) => loaded = id,
          onError: (Object e) => failure = e,
        ),
      );
      async.elapse(
        IdentityStore.forgetWaitTimeout - const Duration(milliseconds: 1),
      );
      expect(failure, isNull, reason: 'the delete is given its time');
      expect(loaded, isNull);

      async.elapse(const Duration(milliseconds: 1));
      expect(failure, isA<IdentityStoreException>());
      expect(loaded, isNull);
      expect(generated, 0, reason: 'no identity the late delete could remove');

      // Try again once the keychain answers: the delete finishes, and the
      // load makes a new identity that stays.
      keychain.complete();
      async.flushMicrotasks();
      unawaited(store.loadOrCreate().then((id) => loaded = id));
      async.flushMicrotasks();
      expect(loaded?.certificatePem, fixture2.certificatePem);
      expect(
        storage.values[IdentityStore.certificateKey],
        fixture2.certificatePem,
      );
    });
  });

  test('forget_tries_both_keys_and_rethrows_a_failed_delete', () async {
    final storage = InMemorySecureKeyValueStore()
      ..values.addAll({
        IdentityStore.certificateKey: fixture.certificatePem,
        IdentityStore.privateKeyKey: fixture.privateKeyPem,
      })
      ..throwOnDelete = PlatformException(code: 'x');

    await expectLater(
      IdentityStore(storage).forget(),
      throwsA(isA<PlatformException>()),
    );
    expect(
      storage.deleted,
      unorderedEquals([
        IdentityStore.certificateKey,
        IdentityStore.privateKeyKey,
      ]),
    );
  });

  test('ios_keychain_item_never_leaves_this_device', () {
    final options = FlutterSecureKeyValueStore.defaultStorage.iOptions;
    expect(
      options.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    expect(options.synchronizable, isFalse);
  });
}
