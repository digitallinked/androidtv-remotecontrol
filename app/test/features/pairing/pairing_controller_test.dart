import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import '../../helpers/fake_remote_session.dart';
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

/// A repository in memory (no database, so it works under `fakeAsync`) whose
/// `find` can be held back.
class _MemoryRepository implements DeviceRepository {
  final Map<String, SavedDevice> saved = {};

  /// When set, `find` waits for it.
  Completer<void>? holdFind;

  @override
  Future<SavedDevice?> find(String serviceName) async {
    await holdFind?.future;
    return saved[serviceName];
  }

  @override
  Future<void> upsert(SavedDevice device) async {
    saved[device.serviceName] = device;
  }

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
    expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
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
      expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
      expect(async.pendingTimers, isEmpty);
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
      expect(fakes.created.first.closeCalls, greaterThanOrEqualTo(1));
      expect(read(c), const PairingWaitingForCode(secondsLeft: 60));
      expect(async.pendingTimers, hasLength(1)); // The new countdown only.
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
      expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
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
  });

  test('a_failed_start_closes_the_client', () async {
    fakes.onCreate = (client) =>
        client.startError = const PairingException(PairingFailure.timeout);
    final c = makeContainer();
    await until(c, (s) => s is PairingFailed);
    expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
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
    expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
    hold.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // No error escaped and no second client appeared.
    expect(fakes.created, hasLength(1));
  });

  group('releasing_resources', () {
    ProviderContainer fakeAsyncContainer(_MemoryRepository repo) =>
        ProviderContainer.test(
          overrides: <Override>[
            identityStoreProvider.overrideWithValue(testIdentityStore()),
            pairingClientFactoryProvider.overrideWithValue(fakes.create),
            deviceRepositoryProvider.overrideWithValue(repo),
          ],
        )..listen(pairingControllerProvider(tv0), (_, _) {});

    test('an_error_after_the_code_was_sent_stops_the_countdown', () {
      fakeAsync((async) {
        fakes.onCreate = (client) =>
            client.submitError = const PairingException(
              PairingFailure.badSecret,
            );
        final c = fakeAsyncContainer(_MemoryRepository());
        async.flushMicrotasks();
        expect(async.pendingTimers, hasLength(1));
        unawaited(notifier(c).submit('AB12CD'));
        async.flushMicrotasks();
        expect(read(c), const PairingFailed(PairingErrorKind.codeRejectedByTv));
        expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('success_stops_the_countdown_and_closes_the_client', () {
      fakeAsync((async) {
        final c = fakeAsyncContainer(_MemoryRepository());
        async.flushMicrotasks();
        unawaited(notifier(c).submit('AB12CD'));
        async.flushMicrotasks();
        expect(read(c), isA<PairingSucceeded>());
        expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('leaving_stops_the_countdown_and_closes_the_client', () {
      fakeAsync((async) {
        final c = ProviderContainer.test(
          overrides: <Override>[
            identityStoreProvider.overrideWithValue(testIdentityStore()),
            pairingClientFactoryProvider.overrideWithValue(fakes.create),
          ],
        );
        final subscription = c.listen(
          pairingControllerProvider(tv0),
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(async.pendingTimers, hasLength(1));
        subscription.close();
        // Riverpod disposes an unwatched provider on a zero-length timer.
        async.elapse(Duration.zero);
        expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('a_suspended_timer_still_shows_the_time_that_passed', () {
      fakeAsync((async) {
        var skew = Duration.zero;
        // The wall clock runs ahead of the timers, as after an iOS suspend.
        final shifted = Clock(
          () => async.getClock(DateTime.utc(2026)).now().add(skew),
        );
        withClock(shifted, () {
          final c = fakeAsyncContainer(_MemoryRepository());
          async.flushMicrotasks();
          skew = const Duration(seconds: 45);
          async.elapse(const Duration(seconds: 1));
          expect(read(c), const PairingWaitingForCode(secondsLeft: 14));
          skew = const Duration(seconds: 100);
          async.elapse(const Duration(seconds: 1));
          expect(read(c), const PairingCodeExpired());
          expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
        });
      });
    });

    test('a_clock_set_back_never_shows_more_than_the_code_lifetime', () {
      fakeAsync((async) {
        var skew = Duration.zero;
        final shifted = Clock(
          () => async.getClock(DateTime.utc(2026)).now().add(skew),
        );
        withClock(shifted, () {
          final c = fakeAsyncContainer(_MemoryRepository());
          async.flushMicrotasks();
          // The user (or the network time) sets the clock back 30 s.
          skew = const Duration(seconds: -30);
          async.elapse(const Duration(seconds: 1));
          final state = read(c);
          expect(state, isA<PairingWaitingForCode>());
          expect(
            (state as PairingWaitingForCode).secondsLeft,
            lessThanOrEqualTo(pairingCodeLifetime.inSeconds),
          );
        });
      });
    });

    test(
      'leaving_while_the_tv_checks_closes_the_client_and_saves_nothing',
      () {
        fakeAsync((async) {
          final hold = Completer<void>();
          fakes.onCreate = (client) => client.holdSubmit = hold;
          final repo = _MemoryRepository();
          final c = ProviderContainer.test(
            overrides: <Override>[
              identityStoreProvider.overrideWithValue(testIdentityStore()),
              pairingClientFactoryProvider.overrideWithValue(fakes.create),
              deviceRepositoryProvider.overrideWithValue(repo),
            ],
          );
          final subscription = c.listen(
            pairingControllerProvider(tv0),
            (_, _) {},
          );
          async.flushMicrotasks();
          unawaited(
            c.read(pairingControllerProvider(tv0).notifier).submit('AB12CD'),
          );
          async.flushMicrotasks();
          expect(
            c.read(pairingControllerProvider(tv0)),
            const PairingVerifying(),
          );
          subscription.close();
          // Riverpod disposes an unwatched provider on a zero-length timer.
          async.elapse(Duration.zero);
          // The client was closed, which failed the pending submit.
          expect(fakes.created.single.closeCalls, greaterThanOrEqualTo(1));
          expect(repo.saved, isEmpty);
          expect(c.read(activeTargetProvider), isNull);
          expect(async.pendingTimers, isEmpty);
        });
      },
    );
  });

  group('abandoned_save', () {
    // The TV accepted the code, then the user left while the TV was being
    // saved.
    Future<(_MemoryRepository, ProviderContainer)> abandon({
      String? activeBefore,
    }) async {
      final repo = _MemoryRepository()..holdFind = Completer<void>();
      final c = ProviderContainer.test(
        overrides: <Override>[
          identityStoreProvider.overrideWithValue(testIdentityStore()),
          pairingClientFactoryProvider.overrideWithValue(fakes.create),
          deviceRepositoryProvider.overrideWithValue(repo),
        ],
      );
      if (activeBefore != null) {
        c.read(activeTargetProvider.notifier).activateDevice(activeBefore);
      }
      final subscription = c.listen(pairingControllerProvider(tv0), (_, _) {});
      await until(c, (s) => s is PairingWaitingForCode);
      final done = notifier(c).submit('AB12CD');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      repo.holdFind!.complete();
      await done;
      return (repo, c);
    }

    test('the_pin_is_saved_and_the_idle_session_follows_the_tv', () async {
      final (repo, c) = await abandon();
      expect(repo.saved[tv0.serviceName]?.serverKeyPin, testPin);
      expect(c.read(activeTargetProvider), DeviceTarget(tv0.serviceName));
    });

    test('another_active_tv_is_left_alone', () async {
      final (repo, c) = await abandon(activeBefore: 'Bedroom');
      expect(repo.saved[tv0.serviceName]?.serverKeyPin, testPin);
      expect(c.read(activeTargetProvider), const DeviceTarget('Bedroom'));
    });
  });

  test('re_pairing_the_active_tv_replaces_its_session', () async {
    var built = 0;
    final c = ProviderContainer.test(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        identityStoreProvider.overrideWithValue(testIdentityStore()),
        pairingClientFactoryProvider.overrideWithValue(fakes.create),
        remoteSessionProvider.overrideWith((ref) async {
          built++;
          return FakeRemoteSession();
        }),
      ],
    );
    c.read(activeTargetProvider.notifier).activateDevice(tv0.serviceName);
    final before = await c.read(remoteSessionProvider.future);
    expect(built, 1);

    c.listen(pairingControllerProvider(tv0), (_, _) {});
    await until(c, (s) => s is PairingWaitingForCode);
    await notifier(c).submit('AB12CD');
    expect(read(c), isA<PairingSucceeded>());

    final after = await c.read(remoteSessionProvider.future);
    expect(built, 2);
    expect(after, isNot(same(before)));
  });
}
