import 'package:atv_remote/atv_remote.dart' show RemoteCloseReason;
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/analytics_strings.dart';
import 'package:tv_remote/core/analytics/key_names.dart';
import 'package:tv_remote/features/pairing/application/pairing_state.dart';
import 'package:tv_remote/features/paywall/domain/paywall_source.dart';

/// An analytics event broke the rules of Ruling P6-R6. Debug builds throw it
/// so a test or a developer sees the mistake; release builds drop the event
/// instead.
///
/// The message names the event and the rule, never the offending value: it
/// could be exactly what must not leave the phone.
final class AnalyticsPolicyError extends Error {
  /// Creates the error.
  AnalyticsPolicyError(this.message);

  /// What was wrong, without the value.
  final String message;

  @override
  String toString() => 'AnalyticsPolicyError: $message';
}

/// How one parameter's value is checked.
class _Param {
  const _Param.oneOf(this.values) : kind = _Kind.oneOf;
  const _Param.count() : values = const {}, kind = _Kind.count;
  const _Param.package() : values = const {}, kind = _Kind.package;
  const _Param.token() : values = const {}, kind = _Kind.token;

  final _Kind kind;
  final Set<String> values;
}

enum _Kind { oneOf, count, package, token }

Set<String> _snakeNames(Iterable<Enum> values) => {
  for (final v in values) snakeCase(v.name),
};

/// The catalogue: each event with its parameters, all required.
final Map<String, Map<String, _Param>> _catalogue = {
  'onboarding_complete': const {},
  'tv_discovered': const {'count': _Param.count()},
  'pair_start': const {},
  'pair_success': const {},
  'pair_fail': {
    'reason': _Param.oneOf({
      ..._snakeNames(PairingErrorKind.values),
      'code_expired',
    }),
  },
  'connect_success': const {},
  'connect_lost': {
    'reason': _Param.oneOf({
      ..._snakeNames(RemoteCloseReason.values),
      'unknown',
    }),
  },
  'key_press': const {'key': _Param.oneOf(analyticsKeyNames)},
  'app_launch': const {'package': _Param.package()},
  'layout_change': const {
    'layout': _Param.oneOf({
      'touchpad',
      'dpad',
      'apps',
      'colour_keys',
      'media_keys',
      'none',
    }),
  },
  'paywall_view': {
    'source': _Param.oneOf({for (final s in PaywallSource.values) s.name}),
    'variant': const _Param.token(),
  },
  'purchase_success': const {
    'product': _Param.oneOf({
      'premium_monthly',
      'premium_yearly',
      'premium_lifetime',
    }),
  },
  'restore_success': const {},
  'review_prompt_shown': const {},
};

/// The names of every event in the catalogue.
Set<String> get analyticsEventNames => _catalogue.keys.toSet();

/// The ways an event named [name] with [params] breaks Ruling P6-R6; empty
/// when it is fine.
///
/// The name and the parameter keys must match the catalogue exactly (every
/// parameter is required). Enumerated parameters must hold one of their
/// values, `count` an integer of at least 1. Every string must be a plain
/// token (letters, digits, `_` and `.`, up to 100 characters) and must not
/// hold an IP or MAC address, a long hex run, `manual:`, `.local` or `_tcp`.
/// A package must be `custom` or one of [cataloguePackages].
///
/// The reasons never contain the offending value.
List<String> analyticsViolations(
  String name,
  Map<String, Object> params, {
  Set<String> cataloguePackages = const {},
}) {
  final spec = _catalogue[name];
  if (spec == null) return ['"$name" is not a catalogue event'];

  final problems = <String>[];
  for (final key in params.keys) {
    if (!spec.containsKey(key)) problems.add('$name has an unknown parameter');
  }
  for (final MapEntry(:key, value: param) in spec.entries) {
    final value = params[key];
    if (value == null) {
      problems.add('$name.$key is missing');
      continue;
    }
    final where = '$name.$key';
    if (param.kind == _Kind.count) {
      if (value is! int || value < 1) {
        problems.add('$where is not a whole number of at least 1');
      }
      continue;
    }
    if (value is! String) {
      problems.add('$where is not a string');
      continue;
    }
    problems.addAll(
      analyticsStringViolations(value).map((p) => '$where $p'),
    );
    switch (param.kind) {
      case _Kind.oneOf:
        if (!param.values.contains(value)) {
          problems.add('$where is not an allowed value');
        }
      case _Kind.package:
        if (value != 'custom' && !cataloguePackages.contains(value)) {
          problems.add('$where is not a catalogue package');
        }
      case _Kind.count || _Kind.token:
        break;
    }
  }
  return problems;
}

final RegExp _screenName = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

/// The ways [name] is not a plain route name; empty when it is fine. Paths
/// (and with them TV names and addresses) never pass.
List<String> analyticsScreenViolations(String name) => [
  ...analyticsStringViolations(name).map((p) => 'screen name $p'),
  if (!_screenName.hasMatch(name)) 'screen name is not a route name',
];
