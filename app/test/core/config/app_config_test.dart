import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/config/app_config.dart';
import 'package:tv_remote/core/config/firebase_remote_config_source.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';

import '../../helpers/fake_config_source.dart';

ProviderContainer _container(RemoteConfigSource source) {
  final container = ProviderContainer(
    overrides: [remoteConfigSourceProvider.overrideWithValue(source)],
  );
  addTearDown(container.dispose);
  return container;
}

AppConfigValues _read(Map<String, Object?> raw) =>
    AppConfigValues.read((key) => raw[key]);

void main() {
  test('config_defaults_match_app_services_skill', () {
    expect(AppConfigValues.defaultsMap, {
      'ads_banner_enabled': true,
      'ads_interstitial_enabled': false,
      'ads_interstitial_min_interval_s': 600,
      'review_prompt_min_key_presses': 150,
      'paywall_variant': 'a',
      'min_supported_version': '1.0.0',
      'catalogue_version': 1,
    });
    // The typed defaults say the same as the map.
    expect(AppConfigValues.read((_) => null), AppConfigValues.defaults);
    expect(
      AppConfigValues.read((key) => AppConfigValues.defaultsMap[key]),
      AppConfigValues.defaults,
    );
  });

  test('values_are_read_by_key', () {
    final values = _read(const {
      'ads_banner_enabled': false,
      'ads_interstitial_enabled': true,
      'ads_interstitial_min_interval_s': 120,
      'review_prompt_min_key_presses': 5,
      'paywall_variant': 'b',
      'min_supported_version': '2.1.0',
      'catalogue_version': 7,
    });

    expect(values.adsBannerEnabled, isFalse);
    expect(values.adsInterstitialEnabled, isTrue);
    expect(values.adsInterstitialMinInterval, const Duration(seconds: 120));
    expect(values.reviewPromptMinKeyPresses, 5);
    expect(values.paywallVariant, 'b');
    expect(values.minSupportedVersion, '2.1.0');
    expect(values.catalogueVersion, 7);
  });

  test('bad_types_fall_back_per_key', () {
    final values = _read(const {
      'review_prompt_min_key_presses': 'abc',
      'ads_interstitial_min_interval_s': -5,
      'ads_banner_enabled': 1,
      'ads_interstitial_enabled': 'true',
      'catalogue_version': 2.5,
      'paywall_variant': 3,
      'min_supported_version': '  ',
    });

    expect(values, AppConfigValues.defaults);

    // One bad key does not take the good ones with it.
    final mixed = _read(const {
      'review_prompt_min_key_presses': -1,
      'catalogue_version': 4,
    });
    expect(mixed.reviewPromptMinKeyPresses, 150);
    expect(mixed.catalogueVersion, 4);
  });

  test('a_getter_that_throws_keeps_that_default', () {
    final values = AppConfigValues.read((key) {
      if (key == 'paywall_variant') throw StateError('unreadable');
      return key == 'catalogue_version' ? 3 : null;
    });

    expect(values.paywallVariant, 'a');
    expect(values.catalogueVersion, 3);
  });

  test('load_activates_cached_values_then_fetches_for_next_launch', () async {
    final source = FakeConfigSource(
      {'ads_banner_enabled': false, 'paywall_variant': 'b'},
      fetched: {'ads_banner_enabled': true, 'paywall_variant': 'c'},
    );
    final container = _container(source)..listen(appConfigProvider, (_, _) {});
    expect(container.read(appConfigProvider), AppConfigValues.defaults);

    await container.read(appConfigProvider.notifier).load();
    await pumpEventQueue();

    expect(source.calls, ['activateCached', 'fetchForNextLaunch']);
    final config = container.read(appConfigProvider);
    expect(config.adsBannerEnabled, isFalse);
    expect(config.paywallVariant, 'b');
    // The fetch changed the values for the next launch, not this session.
    expect(source.values['paywall_variant'], 'c');
    expect(container.read(appConfigProvider).paywallVariant, 'b');
  });

  test('a_late_activation_after_the_seal_changes_nothing', () async {
    final slow = Completer<void>();
    final source = FakeConfigSource({
      'min_supported_version': '9.0.0',
      'ads_banner_enabled': false,
    }, activateBlock: slow.future);
    final container = _container(source)..listen(appConfigProvider, (_, _) {});
    final notifier = container.read(appConfigProvider.notifier);

    final loading = notifier.load();
    // Startup gave up on the step and went on.
    notifier.seal();
    slow.complete();
    await loading;
    await pumpEventQueue();

    expect(container.read(appConfigProvider), AppConfigValues.defaults);
    // Only the download for the next launch still starts.
    expect(source.calls, ['activateCached', 'fetchForNextLaunch']);
  });

  test('a_second_load_changes_nothing', () async {
    final source = FakeConfigSource({'paywall_variant': 'b'});
    final container = _container(source)..listen(appConfigProvider, (_, _) {});
    final notifier = container.read(appConfigProvider.notifier);
    await notifier.load();
    await pumpEventQueue();

    source.values['paywall_variant'] = 'c';
    await notifier.load();
    await pumpEventQueue();

    expect(container.read(appConfigProvider).paywallVariant, 'b');
    expect(source.calls, ['activateCached', 'fetchForNextLaunch']);
  });

  test('load_after_the_seal_does_nothing', () async {
    final source = FakeConfigSource({'paywall_variant': 'b'});
    final container = _container(source)..listen(appConfigProvider, (_, _) {});
    container.read(appConfigProvider.notifier).seal();

    await container.read(appConfigProvider.notifier).load();

    expect(source.calls, isEmpty);
    expect(container.read(appConfigProvider), AppConfigValues.defaults);
  });

  test('the_paywall_variant_is_a_trimmed_plain_token', () {
    expect(_read(const {'paywall_variant': 'b '}).paywallVariant, 'b');
    expect(
      _read(const {'paywall_variant': ' v2.1_x '}).paywallVariant,
      'v2.1_x',
    );
    for (final bad in ['new-year', 'a b', 'ä', 'x' * 101, '', '   ']) {
      expect(
        _read({'paywall_variant': bad}).paywallVariant,
        'a',
        reason: bad,
      );
    }
    expect(_read({'paywall_variant': 'x' * 100}).paywallVariant, 'x' * 100);
  });

  test('paywall_variant_that_breaks_the_analytics_rules_falls_back', () {
    // It goes into `paywall_view` as a parameter, so the guard's string
    // rules apply (a debug build would otherwise throw on the paywall).
    for (final bad in [
      '192.168.0.1',
      'aabbccddeeff00',
      'tv.local',
      'x_tcp',
      'manual:x',
      'a b',
    ]) {
      expect(
        _read({'paywall_variant': bad}).paywallVariant,
        'a',
        reason: bad,
      );
    }
    for (final good in ['b', 'v2.1']) {
      expect(_read({'paywall_variant': good}).paywallVariant, good);
    }
  });

  test('numbers_outside_their_range_fall_back', () {
    Duration interval(Object v) => _read({
      'ads_interstitial_min_interval_s': v,
    }).adsInterstitialMinInterval;
    int presses(Object v) =>
        _read({'review_prompt_min_key_presses': v}).reviewPromptMinKeyPresses;

    expect(interval(60), const Duration(seconds: 60));
    expect(interval(604800), const Duration(days: 7));
    for (final bad in [0, 1, 59, 604801, 1000000000000000, -1]) {
      expect(interval(bad), const Duration(seconds: 600), reason: '$bad');
    }
    expect(presses(1), 1);
    expect(presses(10000), 10000);
    for (final bad in [0, 10001, 1000000000000000, -1]) {
      expect(presses(bad), 150, reason: '$bad');
    }
  });

  test('the_download_is_not_waited_for', () async {
    final fetching = Completer<void>();
    final source = _SlowFetchSource(fetching.future);
    final container = _container(source);

    await container.read(appConfigProvider.notifier).load();

    expect(source.fetchStarted, isTrue);
    expect(fetching.isCompleted, isFalse);
  });

  test('without_firebase_only_defaults', () async {
    for (final status in [
      FirebaseStatus.notConfigured,
      FirebaseStatus.unavailable,
    ]) {
      final container = ProviderContainer(
        overrides: [
          firebaseStatusProvider.overrideWithValue(status),
          flavorProvider.overrideWithValue(Flavor.dev),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(remoteConfigSourceProvider),
        isA<DefaultsOnlyConfigSource>(),
      );
      await container.read(appConfigProvider.notifier).load();
      expect(container.read(appConfigProvider), AppConfigValues.defaults);
    }
  });

  test('firebase_ready_uses_the_flavors_fetch_interval', () {
    for (final (flavor, interval) in [
      (Flavor.prod, const Duration(hours: 1)),
      (Flavor.dev, const Duration(minutes: 5)),
    ]) {
      final container = ProviderContainer(
        overrides: [
          firebaseStatusProvider.overrideWithValue(FirebaseStatus.ready),
          flavorProvider.overrideWithValue(flavor),
        ],
      );
      addTearDown(container.dispose);

      final source = container.read(remoteConfigSourceProvider);
      expect(source, isA<FirebaseRemoteConfigSource>());
      expect(
        (source as FirebaseRemoteConfigSource).minimumFetchInterval,
        interval,
        reason: flavor.name,
      );
    }
  });

  test('a_throwing_source_keeps_defaults', () async {
    final source = FakeConfigSource(
      {'paywall_variant': 'b'},
      activateError: StateError('no play services'),
      fetchError: StateError('offline'),
    );
    final container = _container(source);

    await container.read(appConfigProvider.notifier).load();
    await pumpEventQueue();

    expect(container.read(appConfigProvider), AppConfigValues.defaults);
    // The fetch is still tried, and its failure goes nowhere.
    expect(source.calls, ['activateCached', 'fetchForNextLaunch']);
  });

  test('a_failing_fetch_keeps_the_activated_values', () async {
    final source = FakeConfigSource(
      {'paywall_variant': 'b'},
      fetchError: StateError('offline'),
    );
    final container = _container(source);

    await container.read(appConfigProvider.notifier).load();
    await pumpEventQueue();

    expect(container.read(appConfigProvider).paywallVariant, 'b');
  });

  group('parseRemoteConfigText', () {
    test('reads_text_as_the_type_of_the_default', () {
      expect(parseRemoteConfigText(true, 'false'), false);
      expect(parseRemoteConfigText(false, ' TRUE '), true);
      expect(parseRemoteConfigText(true, '0'), false);
      expect(parseRemoteConfigText(600, '45'), 45);
      expect(parseRemoteConfigText(600, '-5'), -5);
      expect(parseRemoteConfigText('a', 'b'), 'b');
    });

    test('text_that_does_not_fit_is_null_so_the_default_applies', () {
      expect(parseRemoteConfigText(true, 'maybe'), isNull);
      expect(parseRemoteConfigText(true, ''), isNull);
      expect(parseRemoteConfigText(600, 'abc'), isNull);
      expect(parseRemoteConfigText(600, '1.5'), isNull);
      expect(parseRemoteConfigText(600, ''), isNull);
    });
  });
}

class _SlowFetchSource extends FakeConfigSource {
  _SlowFetchSource(this._fetch) : super({});

  final Future<void> _fetch;
  bool fetchStarted = false;

  @override
  Future<void> fetchForNextLaunch() {
    fetchStarted = true;
    return _fetch;
  }
}
