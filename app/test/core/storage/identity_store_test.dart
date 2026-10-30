import 'package:atv_remote/atv_remote.dart';
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

  test('ios_keychain_item_never_leaves_this_device', () {
    final options = FlutterSecureKeyValueStore.defaultStorage.iOptions;
    expect(
      options.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    expect(options.synchronizable, isFalse);
  });
}
