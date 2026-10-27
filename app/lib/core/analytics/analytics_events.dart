import 'package:atv_remote/atv_remote.dart' show RemoteCloseReason;
import 'package:flutter/foundation.dart';
import 'package:tv_remote/core/analytics/key_names.dart';
import 'package:tv_remote/features/pairing/application/pairing_state.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';

/// `camelCase` as `snake_case`: `cantReachTv` becomes `cant_reach_tv`.
String snakeCase(String camel) => camel.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

/// One analytics event: a name and its parameters, exactly as the catalogue
/// of Ruling P6-R6 defines them. The only way to make one is a factory below,
/// so a free-form name or a free-form parameter never reaches the guard from
/// calling code by accident.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent._(this.name, [this.params = const {}]);

  /// The user finished onboarding, either way.
  const AnalyticsEvent.onboardingComplete() : this._('onboarding_complete');

  /// Discovery found its first TVs; [count] is how many.
  AnalyticsEvent.tvDiscovered(int count)
    : this._('tv_discovered', {'count': count});

  /// A pairing started.
  const AnalyticsEvent.pairStart() : this._('pair_start');

  /// Pairing saved the TV.
  const AnalyticsEvent.pairSuccess() : this._('pair_success');

  /// Pairing ended with [kind].
  AnalyticsEvent.pairFail(PairingErrorKind kind)
    : this._('pair_fail', {'reason': snakeCase(kind.name)});

  /// The pairing code ran out before it was entered.
  const AnalyticsEvent.pairCodeExpired()
    : this._('pair_fail', const {'reason': 'code_expired'});

  /// A TV session became connected.
  const AnalyticsEvent.connectSuccess() : this._('connect_success');

  /// A connected session was lost; [reason] is what the connection reported.
  AnalyticsEvent.connectLost(RemoteCloseReason? reason)
    : this._('connect_lost', {
        'reason': reason == null ? 'unknown' : snakeCase(reason.name),
      });

  /// A (sampled) key press; only the key's name is kept, see
  /// [analyticsKeyName].
  AnalyticsEvent.keyPress(int keyCode)
    : this._('key_press', {'key': analyticsKeyName(keyCode)});

  /// An app was launched. [package] must be a catalogue package or `custom`.
  AnalyticsEvent.appLaunch(String package)
    : this._('app_launch', {'package': package});

  /// The navigation style or the quick-access row changed to [layout] (one
  /// of `touchpad`, `dpad`, `apps`, `colour_keys`, `media_keys`, `none`).
  AnalyticsEvent.layoutChange(String layout)
    : this._('layout_change', {'layout': layout});

  /// The premium screen opened from [source], showing paywall [variant].
  AnalyticsEvent.paywallView({
    required PaywallSource source,
    required String variant,
  }) : this._('paywall_view', {'source': source.name, 'variant': variant});

  /// A purchase unlocked Premium; [product] is the store product id.
  AnalyticsEvent.purchaseSuccess(String product)
    : this._('purchase_success', {'product': product});

  /// A restore unlocked Premium.
  const AnalyticsEvent.restoreSuccess() : this._('restore_success');

  /// The store review prompt was requested.
  const AnalyticsEvent.reviewPromptShown() : this._('review_prompt_shown');

  /// The event name.
  final String name;

  /// The parameters; strings and integers only.
  final Map<String, Object> params;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsEvent &&
          other.name == name &&
          mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    name,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  // Parameters are left out: this can reach logs.
  @override
  String toString() => 'AnalyticsEvent($name)';
}
