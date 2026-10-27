import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/analytics/analytics_events.dart';
import 'package:tv_remote/core/analytics/analytics_guard.dart';
import 'package:tv_remote/core/analytics/key_names.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/features/pairing/application/pairing_state.dart';
import 'package:tv_remote/features/paywall/presentation/paywall_screen.dart';

import '../../helpers/test_catalogue.dart';

/// One event from every factory, with sample input.
List<AnalyticsEvent> _everyFactory() => [
  const AnalyticsEvent.onboardingComplete(),
  AnalyticsEvent.tvDiscovered(3),
  const AnalyticsEvent.pairStart(),
  const AnalyticsEvent.pairSuccess(),
  for (final kind in PairingErrorKind.values) AnalyticsEvent.pairFail(kind),
  const AnalyticsEvent.pairCodeExpired(),
  const AnalyticsEvent.connectSuccess(),
  AnalyticsEvent.connectLost(null),
  for (final reason in RemoteCloseReason.values)
    AnalyticsEvent.connectLost(reason),
  AnalyticsEvent.keyPress(KeyCodes.volumeUp),
  AnalyticsEvent.keyPress(KeyCodes.digit(7)),
  AnalyticsEvent.keyPress(9999),
  AnalyticsEvent.appLaunch('custom'),
  AnalyticsEvent.appLaunch('com.netflix.ninja'),
  for (final style in NavigationStyle.values)
    AnalyticsEvent.layoutChange(snakeCase(style.name)),
  for (final row in QuickAccessRow.values)
    AnalyticsEvent.layoutChange(snakeCase(row.name)),
  for (final source in PaywallSource.values)
    AnalyticsEvent.paywallView(source: source, variant: 'a'),
  AnalyticsEvent.purchaseSuccess('premium_monthly'),
  AnalyticsEvent.purchaseSuccess('premium_yearly'),
  AnalyticsEvent.purchaseSuccess('premium_lifetime'),
  const AnalyticsEvent.restoreSuccess(),
  const AnalyticsEvent.reviewPromptShown(),
];

void main() {
  test('analytics_rejects_params_with_ip_or_mac_pattern', () {
    expect(
      analyticsViolations('app_launch', {'package': '192.168.0.20'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations('app_launch', {'package': 'AA:BB:CC:DD:EE:F0'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations('pair_fail', {'reason': 'fe80::1'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations('key_press', {'key': 'a1b2c3d4e5f6a7b8'}),
      isNotEmpty,
    );
  });

  test('rejects_unknown_events_params_and_free_text', () {
    // An event that is not in the catalogue.
    expect(analyticsViolations('tv_connected', {}), isNotEmpty);
    // A parameter that is not in the catalogue.
    expect(
      analyticsViolations('connect_success', {'tv_name': 'Living_Room'}),
      isNotEmpty,
    );
    // Free text where a value from a list is required.
    expect(
      analyticsViolations('layout_change', {'layout': 'Living Room'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations('layout_change', {'layout': 'Living_Room'}),
      isNotEmpty,
    );
    // A plain token that is not one of the key names.
    expect(
      analyticsViolations('key_press', {'key': 'Living_Room'}),
      isNotEmpty,
    );
    // A required parameter that is missing.
    expect(analyticsViolations('pair_fail', {}), isNotEmpty);
    // The wrong type, and a count below 1.
    expect(analyticsViolations('tv_discovered', {'count': '2'}), isNotEmpty);
    expect(analyticsViolations('tv_discovered', {'count': 0}), isNotEmpty);
    expect(analyticsViolations('tv_discovered', {'count': 2.5}), isNotEmpty);
    // Strings outside the allowed characters.
    expect(
      analyticsViolations('pair_fail', {'reason': 'code expired'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations('pair_fail', {'reason': 'manual:tv'}),
      isNotEmpty,
    );
    // Host and service-name markers.
    expect(
      analyticsViolations('app_launch', {'package': 'living.local'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations('app_launch', {'package': 'x._tcp'}),
      isNotEmpty,
    );
    // A bad value is not repeated in the reason.
    for (final reason in analyticsViolations('layout_change', {
      'layout': 'Living Room',
    })) {
      expect(reason, isNot(contains('Living')));
    }
    // An event with no parameters takes none.
    expect(analyticsViolations('onboarding_complete', {}), isEmpty);
    expect(analyticsViolations('onboarding_complete', {'x': 1}), isNotEmpty);
  });

  test('accepts_every_catalogue_factory', () {
    final events = _everyFactory();
    expect(events.map((e) => e.name).toSet(), analyticsEventNames);
    for (final e in events) {
      expect(
        analyticsViolations(
          e.name,
          e.params,
          cataloguePackages: {'com.netflix.ninja'},
        ),
        isEmpty,
        reason: '${e.name} ${e.params}',
      );
    }
  });

  test('every_key_name_and_catalogue_package_passes_the_string_rules', () {
    for (final code in [
      ...KeyCodes.named,
      for (var n = 0; n <= 9; n++) KeyCodes.digit(n),
      9999,
    ]) {
      expect(
        analyticsViolations('key_press', {'key': analyticsKeyName(code)}),
        isEmpty,
        reason: 'key $code',
      );
    }
    final packages = {for (final app in testCatalogue().apps) app.package};
    for (final package in packages) {
      expect(
        analyticsViolations(
          'app_launch',
          {'package': package},
          cataloguePackages: packages,
        ),
        isEmpty,
        reason: package,
      );
    }
  });

  test('custom_packages_are_rejected_catalogue_packages_pass', () {
    const known = {'com.netflix.ninja'};
    expect(
      analyticsViolations(
        'app_launch',
        {'package': 'com.example.private'},
        cataloguePackages: known,
      ),
      isNotEmpty,
    );
    expect(
      analyticsViolations('app_launch', {'package': 'com.example.private'}),
      isNotEmpty,
    );
    expect(
      analyticsViolations(
        'app_launch',
        {'package': 'com.netflix.ninja'},
        cataloguePackages: known,
      ),
      isEmpty,
    );
    // Without the catalogue, a real package is not known either.
    expect(
      analyticsViolations('app_launch', {'package': 'com.netflix.ninja'}),
      isNotEmpty,
    );
    expect(analyticsViolations('app_launch', {'package': 'custom'}), isEmpty);
  });

  test('screen_names_must_be_plain_route_names', () {
    expect(analyticsScreenViolations('edit_device'), isEmpty);
    expect(analyticsScreenViolations('/devices/Living%20Room'), isNotEmpty);
    expect(analyticsScreenViolations('Living Room'), isNotEmpty);
    expect(analyticsScreenViolations(''), isNotEmpty);
    expect(analyticsScreenViolations('192.168.0.20'), isNotEmpty);
  });

  test('snake_case_converts_enum_names', () {
    expect(snakeCase('cantReachTv'), 'cant_reach_tv');
    expect(snakeCase('pingTimeout'), 'ping_timeout');
    expect(snakeCase('colourKeys'), 'colour_keys');
    expect(snakeCase('dpad'), 'dpad');
  });

  test('events_compare_by_value', () {
    expect(const AnalyticsEvent.pairStart(), const AnalyticsEvent.pairStart());
    expect(
      AnalyticsEvent.tvDiscovered(2),
      isNot(AnalyticsEvent.tvDiscovered(3)),
    );
    expect(
      AnalyticsEvent.tvDiscovered(2).hashCode,
      AnalyticsEvent.tvDiscovered(2).hashCode,
    );
  });
}
