import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/purchases/unavailable_purchase_service.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_purchase_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  final tomorrow = now.add(const Duration(days: 1));
  final yesterday = now.subtract(const Duration(days: 1));

  late SettingsStore store;
  late FakePurchaseService fake;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    fake = FakePurchaseService();
  });

  ProviderContainer containerFor([PurchaseService? service]) =>
      ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          purchaseServiceProvider.overrideWithValue(service ?? fake),
        ],
      );

  EntitlementSnapshot active(DateTime? expiresAt) =>
      EntitlementSnapshot(active: true, expiresAt: expiresAt);

  test('entitlement_updates_drive_premium', () async {
    await withClock(Clock.fixed(now), () async {
      final c = containerFor();
      expect(
        c.read(premiumProvider),
        const PremiumState(isPremium: false, known: false),
      );
      // The service is configured in a microtask, never inside build.
      expect(fake.configureCalls, 0);
      await pumpEventQueue();
      expect(fake.configureCalls, 1);

      fake.emit(active(tomorrow));
      await pumpEventQueue();
      expect(
        c.read(premiumProvider),
        PremiumState(isPremium: true, known: true, expiresAt: tomorrow),
      );

      fake.emit(const EntitlementSnapshot(active: false));
      await pumpEventQueue();
      expect(c.read(premiumProvider), PremiumState.free);

      fake.emit(active(null));
      await pumpEventQueue();
      expect(
        c.read(premiumProvider),
        const PremiumState(isPremium: true, known: true, lifetime: true),
      );
    });
  });

  test('offline_uses_cached_entitlement', () async {
    await store.setCachedPremium((active: true, expiresAt: tomorrow));
    fakeAsync((async) {
      withClock(Clock.fixed(now), () {
        final c = containerFor();
        // Premium at once, before the store has said anything.
        expect(
          c.read(premiumProvider),
          PremiumState(isPremium: true, known: false, expiresAt: tomorrow),
        );
        async.elapse(const Duration(seconds: 4, milliseconds: 900));
        expect(c.read(premiumProvider).known, isFalse);
        async.elapse(const Duration(milliseconds: 200));
        // After 5 s the cache stands.
        expect(
          c.read(premiumProvider),
          PremiumState(isPremium: true, known: true, expiresAt: tomorrow),
        );
      });
    });
  });

  test('a_free_user_is_known_after_five_seconds_offline', () {
    fakeAsync((async) {
      final c = containerFor();
      expect(c.read(premiumProvider).known, isFalse);
      async.elapse(const Duration(seconds: 5));
      expect(c.read(premiumProvider), PremiumState.free);
    });
  });

  test('cached_entitlement_expires', () async {
    await store.setCachedPremium((active: true, expiresAt: yesterday));
    withClock(Clock.fixed(now), () {
      final state = containerFor().read(premiumProvider);
      expect(state.isPremium, isFalse);
      expect(state.expiresAt, isNull);
      expect(state.lifetime, isFalse);
    });
  });

  test('lifetime_cache_never_expires', () async {
    await store.setCachedPremium((active: true, expiresAt: null));
    withClock(Clock.fixed(DateTime.utc(2100)), () {
      final state = containerFor().read(premiumProvider);
      expect(state.isPremium, isTrue);
      expect(state.lifetime, isTrue);
      expect(state.expiresAt, isNull);
    });
  });

  test('unconfigured_service_trusts_the_cache_at_once', () async {
    await store.setCachedPremium((active: true, expiresAt: tomorrow));
    withClock(Clock.fixed(now), () {
      expect(
        containerFor(const UnavailablePurchaseService()).read(premiumProvider),
        PremiumState(isPremium: true, known: true, expiresAt: tomorrow),
      );
    });

    await store.setCachedPremium((active: false, expiresAt: null));
    expect(
      containerFor(const UnavailablePurchaseService()).read(premiumProvider),
      PremiumState.free,
    );
  });

  test('every_live_answer_updates_the_cache', () async {
    final c = containerFor()..read(premiumProvider);
    await pumpEventQueue();

    fake.emit(active(tomorrow));
    await pumpEventQueue();
    expect(store.cachedPremium, (active: true, expiresAt: tomorrow));

    fake.emit(active(null));
    await pumpEventQueue();
    expect(store.cachedPremium, (active: true, expiresAt: null));

    fake.emit(const EntitlementSnapshot(active: false));
    await pumpEventQueue();
    expect(store.cachedPremium, (active: false, expiresAt: null));
    expect(c.read(premiumProvider), PremiumState.free);
  });

  test('a_failing_configure_keeps_the_cache', () async {
    await store.setCachedPremium((active: true, expiresAt: tomorrow));
    fakeAsync((async) {
      withClock(Clock.fixed(now), () {
        fake.configureError = Exception('no plugin');
        final c = containerFor();
        expect(c.read(premiumProvider).isPremium, isTrue);
        // The failure happens in the microtask; nothing escapes it.
        async.flushMicrotasks();
        expect(fake.configureCalls, 1);
        expect(c.read(premiumProvider).isPremium, isTrue);
        async.elapse(const Duration(seconds: 5));
        expect(
          c.read(premiumProvider),
          PremiumState(isPremium: true, known: true, expiresAt: tomorrow),
        );
      });
    });
  });

  test('apply_publishes_and_caches_the_answer', () async {
    await withClock(Clock.fixed(now), () async {
      final c = containerFor();
      await c.read(premiumProvider.notifier).apply(active(tomorrow));
      expect(
        c.read(premiumProvider),
        PremiumState(isPremium: true, known: true, expiresAt: tomorrow),
      );
      expect(store.cachedPremium, (active: true, expiresAt: tomorrow));
    });
  });

  test('an_active_answer_that_already_ended_is_not_premium', () async {
    await withClock(Clock.fixed(now), () async {
      final c = containerFor();
      await c.read(premiumProvider.notifier).apply(active(yesterday));
      expect(c.read(premiumProvider).isPremium, isFalse);
      expect(c.read(premiumProvider).known, isTrue);
    });
  });

  test('disposing_stops_listening', () async {
    final c = containerFor()..read(premiumProvider);
    expect(fake.hasListeners, isTrue);
    c.dispose();
    expect(fake.hasListeners, isFalse);
    fake.emit(active(tomorrow));
    await pumpEventQueue();
  });
}
