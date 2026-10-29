import 'package:tv_remote/core/purchases/premium.dart';

/// A [Premium] notifier that starts as [initial] and can be changed with
/// [set]. Use it as `premiumProvider.overrideWith(() => TestPremium(...))`.
class TestPremium extends Premium {
  /// Creates a notifier that starts as [initial].
  TestPremium(this.initial);

  /// The state the notifier starts with.
  final PremiumState initial;

  @override
  PremiumState build() => initial;

  /// Replaces the state.
  // ignore: use_setters_to_change_properties
  void set(PremiumState s) => state = s;
}
