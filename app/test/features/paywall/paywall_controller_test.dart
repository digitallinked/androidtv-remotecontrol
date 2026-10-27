import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/analytics/app_analytics.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/purchases/premium.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/features/paywall/application/paywall_controller.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';

import '../../helpers/fake_purchase_service.dart';
import '../../helpers/recording_analytics_sink.dart';

void main() {
  late SettingsStore store;
  late FakePurchaseService fake;
  late RecordingAnalyticsSink sink;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
    // Sharing is allowed here, so every event reaches the sink.
    await store.setShareUsageStats(true);
    fake = FakePurchaseService(offer: testOffer());
    sink = RecordingAnalyticsSink();
  });

  final provider = paywallControllerProvider(PaywallSource.settings);

  ProviderContainer containerFor({
    PurchaseService? service,
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        purchaseServiceProvider.overrideWithValue(service ?? fake),
        analyticsSinkProvider.overrideWithValue(sink),
        ...overrides,
      ],
    );
    return container..listen(appAnalyticsProvider, (_, _) {});
  }

  Future<PaywallState> settled(ProviderContainer c) async {
    // Hold the subscription: an auto-dispose provider would be thrown away
    // between the reads.
    c.listen(provider, (_, _) {});
    await pumpEventQueue();
    await c.pump();
    await pumpEventQueue();
    return c.read(provider);
  }

  PaywallReady ready(PaywallState s) => s as PaywallReady;

  test('loads_the_offer_and_preselects_yearly_with_a_saving', () async {
    final c = containerFor()..listen(provider, (_, _) {});
    expect(c.read(provider), isA<PaywallLoading>());
    final state = ready(await settled(c));
    expect(state.selected, PremiumPlanKind.yearly);
    expect(state.badgePercent, 49);
    expect(state.busy, isFalse);
    expect(fake.loadOfferCalls, 1);
  });

  test('monthly_is_preselected_when_yearly_is_no_cheaper', () async {
    fake.offer = testOffer(yearly: 59.88);
    final state = ready(await settled(containerFor()));
    expect(state.selected, PremiumPlanKind.monthly);
    expect(state.badgePercent, isNull);
  });

  test('lifetime_is_never_preselected', () async {
    fake.offer = testOffer(hasYearly: false);
    expect(
      ready(await settled(containerFor())).selected,
      PremiumPlanKind.monthly,
    );

    fake.offer = const PremiumOffer(
      plans: [
        PremiumPlan(
          kind: PremiumPlanKind.lifetime,
          priceString: 'RM 59.90',
          price: 59.90,
          currencyCode: 'MYR',
        ),
      ],
    );
    final c = containerFor();
    expect(ready(await settled(c)).selected, isNull);
    c.read(provider.notifier).select(PremiumPlanKind.lifetime);
    expect(ready(c.read(provider)).selected, PremiumPlanKind.lifetime);
  });

  test('no_offer_is_unavailable_and_retry_loads_again', () async {
    fake.offer = null;
    final c = containerFor();
    expect(await settled(c), isA<PaywallUnavailable>());

    fake.offer = testOffer();
    c.read(provider.notifier).retry();
    expect(c.read(provider), isA<PaywallLoading>());
    expect(await settled(c), isA<PaywallReady>());
    expect(fake.loadOfferCalls, 2);
  });

  test('a_throwing_store_is_unavailable_not_an_error', () async {
    fake.loadOfferError = Exception('boom');
    expect(await settled(containerFor()), isA<PaywallUnavailable>());
  });

  test('a_premium_user_sees_the_active_state_without_loading_plans', () async {
    await store.setCachedPremium((active: true, expiresAt: null));
    final state = await settled(containerFor());
    expect(state, isA<PaywallActive>());
    expect((state as PaywallActive).premium.lifetime, isTrue);
    expect(fake.loadOfferCalls, 0);
  });

  test('paywall_view_is_logged_once_with_source_and_variant', () async {
    final c = containerFor();
    await settled(c);
    c.read(provider.notifier)
      ..select(PremiumPlanKind.monthly)
      ..retry();
    await settled(c);
    expect(sink.eventNames, ['paywall_view']);
    expect(sink.events.single.params, {'source': 'settings', 'variant': 'a'});
  });

  test('the_variant_comes_from_remote_config', () async {
    final c = containerFor(
      overrides: [
        appConfigProvider.overrideWith(_VariantConfig.new),
      ],
    );
    await settled(c);
    expect(sink.events.single.params['variant'], 'b');
  });

  test('a_successful_purchase_unlocks_premium_and_logs_the_product', () async {
    fake.nextPurchase = const Purchased(EntitlementSnapshot(active: true));
    final c = containerFor();
    await settled(c);
    final outcome = await c.read(provider.notifier).purchase();
    await pumpEventQueue();

    expect(outcome, isA<Purchased>());
    expect(fake.purchases, [PremiumPlanKind.yearly]);
    expect(c.read(premiumProvider).isPremium, isTrue);
    expect(c.read(premiumProvider).lifetime, isTrue);
    expect(store.cachedPremium, (active: true, expiresAt: null));
    expect(c.read(provider), isA<PaywallActive>());
    expect(sink.eventNames, ['paywall_view', 'purchase_success']);
    expect(sink.events.last.params, {'product': 'premium_yearly'});
  });

  test('busy_while_the_store_is_open_and_a_second_tap_is_ignored', () async {
    final hold = Completer<void>();
    fake
      ..holdPurchase = hold
      ..nextPurchase = const PurchaseCancelled();
    final c = containerFor();
    await settled(c);
    final first = c.read(provider.notifier).purchase();
    await pumpEventQueue();
    expect(ready(c.read(provider)).busy, isTrue);

    await c.read(provider.notifier).purchase();
    expect(fake.purchases, hasLength(1));

    hold.complete();
    expect(await first, isA<PurchaseCancelled>());
    expect(ready(c.read(provider)).busy, isFalse);
    expect(sink.eventNames, ['paywall_view']);
  });

  test('failed_cancelled_and_pending_purchases_change_nothing', () async {
    final c = containerFor();
    await settled(c);
    for (final outcome in const <PurchaseOutcome>[
      PurchaseCancelled(),
      PurchasePending(),
      PurchaseFailed(PurchaseFailure.network),
    ]) {
      fake.nextPurchase = outcome;
      expect(await c.read(provider.notifier).purchase(), outcome);
      expect(ready(c.read(provider)).busy, isFalse);
    }
    expect(c.read(premiumProvider).isPremium, isFalse);
    expect(sink.eventNames, ['paywall_view']);
  });

  test('a_throwing_service_is_a_failed_purchase', () async {
    final c = containerFor(service: _ThrowingService());
    await settled(c);
    final outcome = await c.read(provider.notifier).purchase();
    expect(outcome, const PurchaseFailed(PurchaseFailure.unknown));
    expect(ready(c.read(provider)).busy, isFalse);
  });

  test('a_purchase_that_ends_after_leaving_still_unlocks_premium', () async {
    final hold = Completer<void>();
    fake
      ..holdPurchase = hold
      ..nextPurchase = const Purchased(EntitlementSnapshot(active: true));
    final c = containerFor();
    final subscription = c.listen(provider, (_, _) {});
    await pumpEventQueue();
    final pending = c.read(provider.notifier).purchase();
    await pumpEventQueue();

    // The screen is closed while the store sheet is still open.
    subscription.close();
    await c.pump();
    hold.complete();
    await pending;

    expect(c.read(premiumProvider).isPremium, isTrue);
    expect(sink.eventNames, contains('purchase_success'));
  });

  test('restore_unlocks_premium_and_logs_restore_success', () async {
    fake
      ..nextRestore = RestoreOutcome.restoredPremium
      ..restoreSnapshot = const EntitlementSnapshot(active: true);
    final c = containerFor();
    await settled(c);
    expect(
      await c.read(provider.notifier).restore(),
      RestoreOutcome.restoredPremium,
    );
    await pumpEventQueue();
    expect(c.read(premiumProvider).isPremium, isTrue);
    expect(c.read(provider), isA<PaywallActive>());
    expect(sink.eventNames, ['paywall_view', 'restore_success']);
    expect(sink.events.last.params, isEmpty);
  });

  test('restore_with_nothing_or_a_failure_logs_nothing', () async {
    final c = containerFor();
    await settled(c);
    for (final outcome in [
      RestoreOutcome.nothingToRestore,
      RestoreOutcome.failed,
    ]) {
      fake.nextRestore = outcome;
      expect(await c.read(provider.notifier).restore(), outcome);
    }
    expect(sink.eventNames, ['paywall_view']);
    expect(ready(c.read(provider)).busy, isFalse);
  });

  test('losing_premium_while_open_loads_the_plans_again', () async {
    await store.setCachedPremium((active: true, expiresAt: null));
    final c = containerFor();
    expect(await settled(c), isA<PaywallActive>());
    fake.emit(const EntitlementSnapshot(active: false));
    expect(await settled(c), isA<PaywallReady>());
  });

  test('gaining_premium_while_open_shows_the_active_state', () async {
    final c = containerFor();
    expect(await settled(c), isA<PaywallReady>());
    fake.emit(const EntitlementSnapshot(active: true));
    expect(await settled(c), isA<PaywallActive>());
  });
}

class _VariantConfig extends AppConfig {
  @override
  AppConfigValues build() => AppConfigValues.read(
    (key) => key == 'paywall_variant' ? 'b' : null,
  );
}

class _ThrowingService extends FakePurchaseService {
  _ThrowingService() : super(offer: testOffer());

  @override
  Future<PurchaseOutcome> purchase(PremiumPlanKind kind) =>
      throw StateError('boom');
}
