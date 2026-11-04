import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/fresh_database.dart';
import 'package:tv_remote/core/storage/identity_store.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/apps/application/shortcuts.dart';
import 'package:tv_remote/features/apps/data/apps_data_providers.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';
import 'package:tv_remote/features/apps/data/shortcut_repository.dart';

import '../../helpers/failing_preferences.dart';
import '../../helpers/in_memory_secure_store.dart';
import '../../helpers/test_catalogue.dart';
import '../../helpers/test_identity.dart';

/// What an iPhone restore or Quick Start brings back: the old phone's
/// "done" flags, without its database (Ruling P8-R1).
const Map<String, Object> _restoredFlags = {
  'settings.onboarding_complete': true,
  'privacy.att_preprompt_shown': true,
  'apps.shortcuts_seeded': true,
};

/// A value other than the default for every key the reset must keep.
final Map<String, Object> _keptValues = {
  'settings.navigation_style': 'dpad',
  'settings.quick_access_row': 'none',
  'settings.haptics': false,
  'settings.smooth_press': false,
  'settings.keep_screen_awake': false,
  'settings.theater_mode': true,
  'settings.theme': 'dark',
  'settings.dynamic_color': true,
  'settings.locale': 'ms',
  'settings.auto_open_keyboard': false,
  'settings.colour_style': 'ocean',
  'privacy.share_usage': false,
  'privacy.share_crashes': false,
  'privacy.consent_region': 'required',
  'premium.active': true,
  'premium.expires_at': DateTime.utc(2027).millisecondsSinceEpoch,
  'ads.interstitial_last_shown_at': DateTime.utc(
    2026,
    10,
    30,
  ).millisecondsSinceEpoch,
  'review.key_presses': 40,
  'review.launch_count': 7,
  'review.prompt_shown': true,
};

/// A secure store holding the old install's client identity. The values are
/// stand-ins: only their presence matters here.
InMemorySecureKeyValueStore _storedIdentity() =>
    InMemorySecureKeyValueStore()
      ..values.addAll({
        IdentityStore.certificateKey: 'old certificate',
        IdentityStore.privateKeyKey: 'old key',
      });

/// Every stored preference, read afresh from the platform.
Future<Map<String, Object?>> _storedPreferences() async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: SettingsStore.keys,
    ),
  );
  return {for (final key in prefs.keys) key: prefs.get(key)};
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(_restoredFlags);
  });

  test(
    'a_fresh_database_resets_onboarding_the_att_preprompt_and_the_seeded_flag',
    () async {
      final settings = await SettingsStore.open();

      final reset = await forgetPhoneStateIfDatabaseIsNew(
        settings: settings,
        databaseIsNew: () async => true,
      );

      expect(reset, isTrue);
      expect(settings.onboardingComplete, isFalse);
      expect(settings.trackingPrepromptShown, isFalse);
      expect(settings.shortcutsSeeded, isFalse);
      // Written through to the platform, not only to the cache.
      final reopened = await SettingsStore.open();
      expect(reopened.onboardingComplete, isFalse);
      expect(reopened.trackingPrepromptShown, isFalse);
      expect(reopened.shortcutsSeeded, isFalse);
    },
  );

  test('an_existing_database_keeps_every_preference', () async {
    final settings = await SettingsStore.open();

    final reset = await forgetPhoneStateIfDatabaseIsNew(
      settings: settings,
      databaseIsNew: () async => false,
    );

    expect(reset, isFalse);
    expect(await _storedPreferences(), _restoredFlags);
  });

  test(
    'launch_count_review_and_privacy_choices_survive_a_fresh_database',
    () async {
      expect(
        _keptValues.keys.toSet(),
        SettingsStore.keys.difference(SettingsStore.freshDatabaseKeys),
        reason: 'every kept key has a value here',
      );
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            ..._restoredFlags,
            ..._keptValues,
          });
      final settings = await SettingsStore.open();

      await forgetPhoneStateIfDatabaseIsNew(
        settings: settings,
        databaseIsNew: () async => true,
      );

      expect(await _storedPreferences(), {
        ..._keptValues,
        'settings.onboarding_complete': false,
        'privacy.att_preprompt_shown': false,
        'apps.shortcuts_seeded': false,
      });
    },
  );

  test('fresh_database_keys_are_the_three_of_the_ruling', () {
    expect(SettingsStore.freshDatabaseKeys, {
      'settings.onboarding_complete',
      'privacy.att_preprompt_shown',
      'apps.shortcuts_seeded',
    });
    expect(
      SettingsStore.keys.containsAll(SettingsStore.freshDatabaseKeys),
      isTrue,
    );
  });

  test('a_database_that_cannot_open_is_reported_and_changes_nothing', () async {
    final settings = await SettingsStore.open();
    final errors = <Object>[];

    final reset = await forgetPhoneStateIfDatabaseIsNew(
      settings: settings,
      databaseIsNew: () async => throw SqliteException(
        extendedResultCode: 14,
        message: 'unable to open database file',
      ),
      onError: (error, _) => errors.add(error),
    );

    expect(reset, isFalse);
    expect(errors, [isA<SqliteException>()]);
    expect(await _storedPreferences(), _restoredFlags);
  });

  test('a_database_lookup_that_throws_at_once_is_reported_too', () async {
    final settings = await SettingsStore.open();
    final errors = <Object>[];

    final reset = await forgetPhoneStateIfDatabaseIsNew(
      settings: settings,
      databaseIsNew: () => throw StateError('database is locked'),
      onError: (error, _) => errors.add(error),
    );

    expect(reset, isFalse);
    expect(errors, [isA<StateError>()]);
    expect(await _storedPreferences(), _restoredFlags);
  });

  test('a_preference_write_that_hangs_does_not_hold_the_start', () async {
    final platform = FailingSharedPreferencesAsync(failing: false);
    SharedPreferencesAsyncPlatform.instance = platform;
    final settings = await SettingsStore.open();
    await settings.setOnboardingComplete(true);
    await settings.setShortcutsSeeded(true);
    platform.stalling = true;

    fakeAsync((async) {
      final errors = <Object>[];
      bool? reset;
      unawaited(
        forgetPhoneStateIfDatabaseIsNew(
          settings: settings,
          databaseIsNew: () async => true,
          onError: (error, _) => errors.add(error),
        ).then((value) => reset = value),
      );
      async.elapse(freshDatabaseWriteTimeout - const Duration(milliseconds: 1));
      expect(reset, isNull, reason: 'the write is given its time');

      async.elapse(const Duration(milliseconds: 1));
      expect(reset, isFalse);
      expect(errors.single, isA<TimeoutException>());
      // This run already sees the reset: the store's cache has it.
      expect(settings.onboardingComplete, isFalse);
      expect(settings.shortcutsSeeded, isFalse);
    });
  });

  test(
    'a_failing_preference_write_is_reported_and_the_start_continues',
    () async {
      // Installed before the store opens: a store keeps its platform.
      final platform = FailingSharedPreferencesAsync(failing: false);
      SharedPreferencesAsyncPlatform.instance = platform;
      final seeding = await SettingsStore.open();
      await seeding.setOnboardingComplete(true);
      await seeding.setTrackingPrepromptShown(true);
      await seeding.setShortcutsSeeded(true);
      final settings = await SettingsStore.open();
      platform.failing = true;
      final errors = <Object>[];

      final reset = await forgetPhoneStateIfDatabaseIsNew(
        settings: settings,
        databaseIsNew: () async => true,
        onError: (error, _) => errors.add(error),
      );

      expect(reset, isFalse);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    },
  );

  // Ruling P9-C8: the iOS keychain outlives the app, so a reinstall on the
  // same iPhone would reuse the old certificate. A fresh database forgets it
  // before anything can use it.
  test('a_fresh_database_deletes_the_stored_client_identity', () async {
    final settings = await SettingsStore.open();
    final secure = _storedIdentity();

    await forgetPhoneStateIfDatabaseIsNew(
      settings: settings,
      databaseIsNew: () async => true,
      forgetIdentity: IdentityStore(secure).forget,
    );

    expect(secure.values, isEmpty);
  });

  test('an_existing_database_keeps_the_client_identity', () async {
    final settings = await SettingsStore.open();
    final secure = _storedIdentity();

    await forgetPhoneStateIfDatabaseIsNew(
      settings: settings,
      databaseIsNew: () async => false,
      forgetIdentity: IdentityStore(secure).forget,
    );

    expect(secure.deleted, isEmpty);
    expect(secure.values.keys, hasLength(2));
  });

  test('a_database_that_cannot_open_keeps_the_client_identity', () async {
    final settings = await SettingsStore.open();
    final secure = _storedIdentity();

    await forgetPhoneStateIfDatabaseIsNew(
      settings: settings,
      databaseIsNew: () async => throw StateError('database is locked'),
      forgetIdentity: IdentityStore(secure).forget,
      onError: (_, _) {},
    );

    expect(secure.deleted, isEmpty);
  });

  test(
    'a_failing_identity_delete_is_reported_and_the_preferences_still_reset',
    () async {
      final settings = await SettingsStore.open();
      final secure = _storedIdentity()..throwOnDelete = StateError('keychain');
      final errors = <Object>[];

      final reset = await forgetPhoneStateIfDatabaseIsNew(
        settings: settings,
        databaseIsNew: () async => true,
        forgetIdentity: IdentityStore(secure).forget,
        onError: (error, _) => errors.add(error),
      );

      expect(reset, isTrue, reason: 'the preferences were reset');
      expect(errors, [isA<StateError>()]);
      expect(settings.onboardingComplete, isFalse);
    },
  );

  // Review Minor 1: the delete keeps running after its 2 s bound. If the user
  // pairs before it finishes, the identity made then must survive it.
  test('a_late_identity_delete_spares_the_identity_made_after_it', () async {
    final settings = await SettingsStore.open();
    final made = testIdentity();
    final secure = _storedIdentity();
    final store = IdentityStore(secure, generate: () async => made);

    fakeAsync((async) {
      // Made in the fake zone, so its late answer is a fake microtask.
      final keychain = Completer<void>();
      secure.deleteGate = keychain.future;
      unawaited(
        forgetPhoneStateIfDatabaseIsNew(
          settings: settings,
          databaseIsNew: () async => true,
          forgetIdentity: store.forget,
          onError: (_, _) {},
        ),
      );
      async.elapse(freshDatabaseWriteTimeout);
      // The start has gone on; the keychain answers again for new calls,
      // but the first delete is still stuck. The user pairs.
      secure.deleteGate = null;
      ClientIdentity? paired;
      unawaited(store.loadOrCreate().then((id) => paired = id));
      async.flushMicrotasks();

      // The stuck delete finishes late.
      keychain.complete();
      async.flushMicrotasks();

      expect(paired?.certificatePem, made.certificatePem);
      expect(secure.values[IdentityStore.certificateKey], made.certificatePem);
      expect(secure.values[IdentityStore.privateKeyKey], made.privateKeyPem);
    });
  });

  test('an_identity_delete_that_hangs_does_not_hold_the_start', () async {
    final settings = await SettingsStore.open();
    final secure = _storedIdentity()..deleteGate = Completer<void>().future;

    fakeAsync((async) {
      final errors = <Object>[];
      bool? reset;
      unawaited(
        forgetPhoneStateIfDatabaseIsNew(
          settings: settings,
          databaseIsNew: () async => true,
          forgetIdentity: IdentityStore(secure).forget,
          onError: (error, _) => errors.add(error),
        ).then((value) => reset = value),
      );
      async.elapse(freshDatabaseWriteTimeout - const Duration(milliseconds: 1));
      expect(reset, isNull, reason: 'the delete is given its time');

      async.elapse(const Duration(milliseconds: 1));
      expect(reset, isTrue);
      expect(errors.single, isA<TimeoutException>());
    });
  });

  test(
    'try_again_after_a_failed_first_start_still_seeds_the_apps_row',
    () async {
      final dir = Directory.systemTemp.createTempSync('fresh_database_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/remotely.sqlite');

      final secure = _storedIdentity();

      // Run 1 creates the database under restored preferences, resets them,
      // forgets the old identity, and then fails before anything reads the
      // shortcuts.
      final first = AppDatabase(NativeDatabase(file));
      expect(
        await forgetPhoneStateIfDatabaseIsNew(
          settings: await SettingsStore.open(),
          databaseIsNew: first.createdThisRun,
          forgetIdentity: IdentityStore(secure).forget,
        ),
        isTrue,
      );
      await first.close();
      expect(secure.values, isEmpty);
      // The identity made on first use after the failed start.
      secure.values[IdentityStore.certificateKey] = 'new certificate';
      secure.values[IdentityStore.privateKeyKey] = 'new key';

      // Try again builds a new database instance on the file run 1 created,
      // and opens the preferences again, as `buildRootWidget` does: it isn't
      // new to this instance, but the reset flag was persisted.
      final settings = await SettingsStore.open();
      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      expect(await second.createdThisRun(), isFalse);
      expect(
        await forgetPhoneStateIfDatabaseIsNew(
          settings: settings,
          databaseIsNew: second.createdThisRun,
          forgetIdentity: IdentityStore(secure).forget,
        ),
        isFalse,
      );
      expect(secure.values[IdentityStore.certificateKey], 'new certificate');
      final container = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(settings),
          shortcutRepositoryProvider.overrideWithValue(
            DriftShortcutRepository(second),
          ),
          catalogueProvider.overrideWith((ref) async => testCatalogue()),
          deviceRegionProvider.overrideWithValue('MY'),
        ],
      )..listen(shortcutsProvider, (_, _) {});

      final shortcuts = await container.read(shortcutsProvider.future);

      expect(
        [for (final app in shortcuts) app.package],
        [
          for (final app in testCatalogue().defaultShortcutsFor('MY'))
            app.package,
        ],
      );
      expect(settings.shortcutsSeeded, isTrue);
    },
  );
}
