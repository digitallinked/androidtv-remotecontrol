import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/pairing/application/pairing_controller.dart';
import 'package:tv_remote/features/pairing/application/pairing_state.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';

import '../../helpers/fake_pairing_client.dart';
import '../../helpers/fake_tv_discovery.dart';
import '../../helpers/in_memory_secure_store.dart';
import '../../helpers/test_devices.dart';
import '../../helpers/test_identity.dart';

/// A repository whose writes fail.
class _FailingRepository implements DeviceRepository {
  @override
  Future<SavedDevice?> find(String serviceName) async => null;

  @override
  Future<void> upsert(SavedDevice device) =>
      Future<void>.error(Exception('disk full'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final tv0 = tv('Living Room TV 3');
  late FakePairingClients fakes;
  late AppDatabase db;

  setUp(() {
    fakes = FakePairingClients();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  ProviderContainer makeContainer({
    IdentityStore? identity,
    DeviceRepository? repository,
  }) {
    final c = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        identityStoreProvider.overrideWithValue(
          identity ?? testIdentityStore(),
        ),
        pairingClientFactoryProvider.overrideWithValue(fakes.create),
        if (repository != null)
          deviceRepositoryProvider.overrideWithValue(repository),
      ],
    )..listen(pairingControllerProvider(tv0), (_, _) {}); // autoDispose
    return c;
  }

  PairingState read(ProviderContainer c) =>
      c.read(pairingControllerProvider(tv0));
  PairingController notifier(ProviderContainer c) =>
      c.read(pairingControllerProvider(tv0).notifier);

  /// Lets the controller's futures run until [done] holds.
  Future<void> until(
    ProviderContainer c,
    bool Function(PairingState) done,
  ) async {
    for (var i = 0; i < 200 && !done(read(c)); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(done(read(c)), isTrue, reason: 'stuck in ${read(c)}');
  }

  Future<ProviderContainer> waiting() async {
    final c = makeContainer();
    await until(c, (s) => s is PairingWaitingForCode);
    return c;
  }

  test('states_compare_by_value', () {
    expect(const PairingStarting(), const PairingStarting());
    expect(
      const PairingWaitingForCode(secondsLeft: 3),
      const PairingWaitingForCode(secondsLeft: 3),
    );
    expect(
      const PairingWaitingForCode(secondsLeft: 3),
      isNot(const PairingWaitingForCode(secondsLeft: 3, codeMismatch: true)),
    );
    expect(const PairingVerifying(), const PairingVerifying());
    expect(const PairingCodeExpired(), const PairingCodeExpired());
    expect(
      const PairingFailed(PairingErrorKind.saveFailed),
      const PairingFailed(PairingErrorKind.saveFailed),
    );
    expect(
      const PairingFailed(PairingErrorKind.saveFailed),
      isNot(const PairingFailed(PairingErrorKind.pairingError)),
    );
    expect(PairingSucceeded(savedTv()), PairingSucceeded(savedTv()));
  });

  test('starts_a_client_for_the_tv_and_waits_for_the_code', () async {
    final c = makeContainer();
    expect(read(c), const PairingStarting());
    await until(c, (s) => s is PairingWaitingForCode);
    expect(read(c), const PairingWaitingForCode(secondsLeft: 60));
    expect(fakes.created.single.host, tv0.host);
  });

  test('code_is_trimmed_and_upper_cased_before_submit', () async {
    final c = await waiting();
    await notifier(c).submit(' ab12cd\n');
    expect(fakes.created.single.submittedCodes, ['AB12CD']);
  });

  test('incomplete_or_non_hex_codes_are_not_submitted', () async {
    final c = await waiting();
    await notifier(c).submit('ab12');
    await notifier(c).submit('zzzzzz');
    expect(fakes.created.single.submittedCodes, isEmpty);
    expect(read(c), isA<PairingWaitingForCode>());
  });

  test('bad_checksum_keeps_the_same_client_and_flags_mismatch', () async {
    final c = await waiting();
    await notifier(c).submit('000000');
    expect(
      read(c),
      const PairingWaitingForCode(secondsLeft: 60, codeMismatch: true),
    );
    expect(fakes.created, hasLength(1));
    expect(fakes.created.single.closed, isFalse);
    // The same client takes the corrected code.
    await notifier(c).submit('AB12CD');
    expect(read(c), isA<PairingSucceeded>());
    expect(fakes.created.single.submittedCodes, ['000000', 'AB12CD']);
  });

  test('success_saves_pin_and_activates_the_tv', () async {
    final c = await waiting();
    await notifier(c).submit('AB12CD');
    final saved = await DriftDeviceRepository(db).find(tv0.serviceName);
    expect(saved?.serverKeyPin, testPin);
    expect(saved?.lastHost, tv0.host);
    expect(saved?.port, tv0.port);
    expect(saved?.displayName, tv0.displayName);
    expect(c.read(activeTargetProvider), DeviceTarget(tv0.serviceName));
    // The database keeps whole seconds, so compare the parts that matter.
    expect(
      read(c),
      isA<PairingSucceeded>()
          .having((s) => s.device.serviceName, 'serviceName', tv0.serviceName)
          .having((s) => s.device.serverKeyPin, 'pin', testPin),
    );
    expect(fakes.created.single.closed, isTrue);
  });

  test('re_pairing_keeps_nickname_and_wol_mac', () async {
    await DriftDeviceRepository(db).upsert(
      savedTv(nickname: 'Lounge', wolMac: 'AA:BB:CC:DD:EE:FF', pin: 'old'),
    );
    final c = await waiting();
    await notifier(c).submit('AB12CD');
    final saved = await DriftDeviceRepository(db).find(tv0.serviceName);
    expect(saved?.nickname, 'Lounge');
    expect(saved?.wolMac, 'AA:BB:CC:DD:EE:FF');
    expect(saved?.serverKeyPin, testPin);
  });

  test('code_expires_after_60s_and_closes_the_client', () {
    fakeAsync((async) {
      final c = makeContainer();
      async.flushMicrotasks();
      expect(read(c), isA<PairingWaitingForCode>());
      async.elapse(const Duration(seconds: 59));
      expect(read(c), const PairingWaitingForCode(secondsLeft: 1));
      expect(fakes.created.single.closed, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(read(c), const PairingCodeExpired());
      expect(fakes.created.single.closed, isTrue);
    });
  });

  test('restart_starts_a_fresh_client', () {
    fakeAsync((async) {
      final c = makeContainer();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 60));
      expect(read(c), const PairingCodeExpired());
      unawaited(notifier(c).restart());
      expect(read(c), const PairingStarting());
      async.flushMicrotasks();
      expect(fakes.created, hasLength(2));
      expect(fakes.created.first.closed, isTrue);
      expect(read(c), const PairingWaitingForCode(secondsLeft: 60));
    });
  });

  test('restart_after_an_error_tries_again', () async {
    fakes.onCreate = (client) {
      if (fakes.created.length == 1) {
        client.startError = const PairingException(
          PairingFailure.connectionFailed,
        );
      }
    };
    final c = makeContainer();
    await until(c, (s) => s is PairingFailed);
    await notifier(c).restart();
    expect(fakes.created, hasLength(2));
    expect(read(c), isA<PairingWaitingForCode>());
  });

  test('maps_pairing_failures_to_error_kinds', () async {
    Future<PairingState> failWith({
      PairingFailure? onStart,
      PairingFailure? onSubmit,
    }) async {
      fakes = FakePairingClients()
        ..onCreate = (client) {
          if (onStart != null) client.startError = PairingException(onStart);
          if (onSubmit != null) {
            client.submitError = PairingException(onSubmit);
          }
        };
      final c = makeContainer();
      await until(c, (s) => s is PairingFailed || s is PairingWaitingForCode);
      if (onSubmit != null) await notifier(c).submit('AB12CD');
      return read(c);
    }

    expect(
      await failWith(onStart: PairingFailure.connectionFailed),
      const PairingFailed(PairingErrorKind.cantReachTv),
    );
    expect(
      await failWith(onStart: PairingFailure.timeout),
      const PairingFailed(PairingErrorKind.tvDidNotRespond),
    );
    expect(
      await failWith(onStart: PairingFailure.protocolError),
      const PairingFailed(PairingErrorKind.pairingError),
    );
    expect(
      await failWith(onStart: PairingFailure.invalidCode),
      const PairingFailed(PairingErrorKind.pairingError),
    );
    expect(
      await failWith(onSubmit: PairingFailure.badSecret),
      const PairingFailed(PairingErrorKind.codeRejectedByTv),
    );
    expect(
      await failWith(onSubmit: PairingFailure.timeout),
      const PairingFailed(PairingErrorKind.tvDidNotRespond),
    );
    expect(fakes.created.single.closed, isTrue);
  });

  test('a_failed_start_closes_the_client', () async {
    fakes.onCreate = (client) =>
        client.startError = const PairingException(PairingFailure.timeout);
    final c = makeContainer();
    await until(c, (s) => s is PairingFailed);
    expect(fakes.created.single.closed, isTrue);
  });

  test('identity_failure_offers_try_again', () async {
    final store = InMemorySecureKeyValueStore()..throwOnWrite = Exception('x');
    final c = makeContainer(
      identity: IdentityStore(store, generate: () async => testIdentity()),
    );
    await until(c, (s) => s is PairingFailed);
    expect(read(c), const PairingFailed(PairingErrorKind.identityUnavailable));
    expect(fakes.created, isEmpty);
  });

  test('save_failure_offers_try_again', () async {
    final c = makeContainer(repository: _FailingRepository());
    await until(c, (s) => s is PairingWaitingForCode);
    await notifier(c).submit('AB12CD');
    expect(read(c), const PairingFailed(PairingErrorKind.saveFailed));
    expect(c.read(activeTargetProvider), isNull);
  });

  test('leaving_during_start_does_not_update_state_after_dispose', () async {
    final hold = Completer<void>();
    fakes.onCreate = (client) => client.holdStart = hold;
    final c = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        identityStoreProvider.overrideWithValue(testIdentityStore()),
        pairingClientFactoryProvider.overrideWithValue(fakes.create),
      ],
    );
    final subscription = c.listen(pairingControllerProvider(tv0), (_, _) {});
    for (var i = 0; i < 20 && fakes.created.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fakes.created, hasLength(1));
    subscription.close();
    await Future<void>.delayed(Duration.zero);
    expect(fakes.created.single.closed, isTrue);
    hold.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // No error escaped and no second client appeared.
    expect(fakes.created, hasLength(1));
  });
}
