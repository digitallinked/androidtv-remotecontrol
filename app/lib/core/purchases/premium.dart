import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/purchases/purchase_service.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'premium.g.dart';

/// Whether the user has Premium (decision #6).
@immutable
class PremiumState {
  /// Creates a state.
  const PremiumState({
    required this.isPremium,
    required this.known,
    this.expiresAt,
    this.lifetime = false,
  });

  /// A free user whose state is known.
  static const free = PremiumState(isPremium: false, known: true);

  /// Whether Premium is active.
  final bool isPremium;

  /// Whether the answer is final. While it is `false`, no ad may show.
  final bool known;

  /// When a subscription ends, or `null` for lifetime and free.
  final DateTime? expiresAt;

  /// Whether Premium never expires.
  final bool lifetime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumState &&
          other.isPremium == isPremium &&
          other.known == known &&
          other.expiresAt == expiresAt &&
          other.lifetime == lifetime;

  @override
  int get hashCode => Object.hash(isPremium, known, expiresAt, lifetime);

  @override
  String toString() =>
      'PremiumState(isPremium: $isPremium, known: $known, '
      'expiresAt: $expiresAt, lifetime: $lifetime)';
}

/// How long Premium stays unknown while the store has not answered. After
/// that the cached entitlement stands (Ruling P6-R10).
const Duration premiumKnownTimeout = Duration(seconds: 5);

/// The user's Premium state (Ruling P6-R10).
///
/// It starts from the last entitlement the phone saw, so a Premium user never
/// sees an ad while offline or before the store answers. With a configured
/// service the answer is [PremiumState.known] on the first live entitlement,
/// or after [premiumKnownTimeout]; with none (a build with no key) the cache
/// is final at once. Every live answer rewrites the cache.
///
/// Nothing here throws into the UI: a failing store leaves the cached state.
@Riverpod(keepAlive: true)
class Premium extends _$Premium {
  Timer? _knownTimer;
  StreamSubscription<EntitlementSnapshot>? _subscription;

  @override
  PremiumState build() {
    final service = ref.watch(purchaseServiceProvider);
    final store = ref.watch(settingsStoreProvider);
    final cached = store.cachedPremium;
    final initial = _stateFor(
      EntitlementSnapshot(active: cached.active, expiresAt: cached.expiresAt),
      known: !service.isConfigured,
    );

    // Subscribed now, so an answer that comes before the microtask isn't lost.
    _subscription = service.entitlements.listen(
      (snapshot) => unawaited(apply(snapshot)),
      onError: (Object error) => _log('entitlement stream failed', error),
    );
    ref.onDispose(() {
      _knownTimer?.cancel();
      unawaited(_subscription?.cancel().catchError((Object _) {}));
    });

    if (service.isConfigured) {
      _knownTimer = Timer(premiumKnownTimeout, _markKnown);
      scheduleMicrotask(() {
        if (ref.mounted) unawaited(_configure(service));
      });
    }
    return initial;
  }

  Future<void> _configure(PurchaseService service) async {
    try {
      await service.configure();
    } on Object catch (error) {
      // The cache stands, and the timer makes it final.
      _log('configure failed', error);
    }
  }

  void _markKnown() {
    if (!ref.mounted || state.known) return;
    state = PremiumState(
      isPremium: state.isPremium,
      known: true,
      expiresAt: state.expiresAt,
      lifetime: state.lifetime,
    );
  }

  /// Takes [snapshot] as the store's live answer: publishes it as known and
  /// writes it to the cache. The paywall calls this after a purchase.
  Future<void> apply(EntitlementSnapshot snapshot) async {
    if (!ref.mounted) return;
    _knownTimer?.cancel();
    final store = ref.read(settingsStoreProvider);
    state = _stateFor(snapshot, known: true);
    try {
      await store.setCachedPremium((
        active: snapshot.active,
        expiresAt: snapshot.expiresAt,
      ));
    } on Object catch (error) {
      // Premium still applies for this session.
      _log('caching the entitlement failed', error);
    }
  }

  PremiumState _stateFor(EntitlementSnapshot snapshot, {required bool known}) {
    final lifetime = snapshot.active && snapshot.expiresAt == null;
    final expiresAt = snapshot.expiresAt;
    final isPremium =
        snapshot.active &&
        (expiresAt == null || expiresAt.isAfter(clock.now()));
    return PremiumState(
      isPremium: isPremium,
      known: known,
      expiresAt: isPremium ? expiresAt : null,
      lifetime: lifetime,
    );
  }

  void _log(String message, Object error) =>
      developer.log(message, name: 'premium', error: error);
}
