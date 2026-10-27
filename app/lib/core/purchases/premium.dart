import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// The user's Premium state.
///
/// This is a stub that is always free. Task 6.7 replaces the body of
/// [build] with the real entitlement and keeps this name and [PremiumState].
@Riverpod(keepAlive: true)
class Premium extends _$Premium {
  @override
  PremiumState build() => PremiumState.free;
}
