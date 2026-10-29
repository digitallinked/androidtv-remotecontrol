import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tv_remote/core/ads/consent_controller.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';
import 'package:tv_remote/core/storage/settings_store.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

import '../../helpers/fake_consent_service.dart';

/// A service whose every call throws, as when the plugin is missing.
class _ThrowingConsentService implements ConsentService {
  @override
  Future<ConsentRegion> requestUpdate() async =>
      throw MissingPluginException('ump');

  @override
  Future<ConsentFormOutcome> showFormIfRequired() async =>
      throw StateError('form');

  @override
  Future<bool> canRequestAds() async => throw StateError('can');

  @override
  Future<bool> privacyOptionsRequired() async => throw StateError('options');

  @override
  Future<bool> showPrivacyOptions() async => throw StateError('show');
}

void main() {
  late SettingsStore store;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await SettingsStore.open();
  });

  ProviderContainer containerFor(ConsentService service) {
    return ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          consentServiceProvider.overrideWithValue(service),
        ],
      )
      // Riverpod pauses what nothing listens to.
      ..listen(consentControllerProvider, (_, _) {});
  }

  test('refresh_writes_the_region_and_keeps_it_on_unknown', () async {
    final service = FakeConsentService();
    final first = containerFor(service);
    await first.read(consentControllerProvider.notifier).refresh();
    expect(first.read(consentRegionStateProvider), ConsentRegion.notRequired);
    expect(store.consentRegion, ConsentRegion.notRequired);

    // The next launch: the update fails to say, and the stored value stands.
    service.region = ConsentRegion.unknown;
    final second = containerFor(service);
    await second.read(consentControllerProvider.notifier).refresh();
    expect(second.read(consentRegionStateProvider), ConsentRegion.notRequired);
    expect(store.consentRegion, ConsentRegion.notRequired);

    // A region that needs consent replaces it.
    service.region = ConsentRegion.required;
    final third = containerFor(service);
    await third.read(consentControllerProvider.notifier).refresh();
    expect(store.consentRegion, ConsentRegion.required);
  });

  test('refresh_runs_once_per_launch', () async {
    final service = FakeConsentService();
    final container = containerFor(service);
    final controller = container.read(consentControllerProvider.notifier);
    await controller.refresh();
    await controller.refresh();
    await controller.ensureGathered();
    expect(service.requestUpdateCalls, 1);
  });

  test('the_first_read_starts_the_silent_update', () async {
    final service = FakeConsentService();
    final container = containerFor(service);
    expect(container.read(consentControllerProvider).gathered, isFalse);
    await pumpEventQueue();
    expect(service.requestUpdateCalls, 1);
    expect(service.showFormCalls, 0);
  });

  test('gathering_runs_the_form_once_per_launch', () async {
    final service = FakeConsentService(
      region: ConsentRegion.required,
      formOutcome: ConsentFormOutcome.shown,
      optionsRequired: true,
    );
    final container = containerFor(service);
    final controller = container.read(consentControllerProvider.notifier);

    final results = await Future.wait([
      controller.ensureGathered(),
      controller.ensureGathered(),
    ]);
    final third = await controller.ensureGathered();

    expect(service.showFormCalls, 1);
    expect(results.first, same(results.last));
    expect(third.gathered, isTrue);
    expect(third.canRequestAds, isTrue);
    expect(third.privacyOptionsRequired, isTrue);
    expect(third.region, ConsentRegion.required);
    expect(container.read(consentControllerProvider), third);
  });

  test('the_form_waits_for_the_silent_update', () async {
    final hold = Completer<void>();
    final service = FakeConsentService(holdRequestUpdate: hold);
    final container = containerFor(service);
    final done = container
        .read(consentControllerProvider.notifier)
        .ensureGathered();
    await pumpEventQueue();
    expect(service.showFormCalls, 0);
    hold.complete();
    await done;
    expect(service.showFormCalls, 1);
  });

  test('consent_errors_never_throw', () async {
    final container = containerFor(_ThrowingConsentService());
    final controller = container.read(consentControllerProvider.notifier);

    await controller.refresh();
    final result = await controller.ensureGathered();
    final shown = await controller.showPrivacyOptions();

    expect(result.region, ConsentRegion.unknown);
    expect(result.canRequestAds, isFalse);
    expect(result.privacyOptionsRequired, isFalse);
    expect(result.gathered, isTrue);
    expect(shown, isFalse);
  });

  test('the_privacy_options_form_re_reads_whether_ads_may_load', () async {
    final service = FakeConsentService(canRequest: false);
    final container = containerFor(service);
    final controller = container.read(consentControllerProvider.notifier);
    await controller.ensureGathered();
    expect(container.read(consentControllerProvider).canRequestAds, isFalse);

    service.canRequest = true;
    final shown = await controller.showPrivacyOptions();

    expect(shown, isTrue);
    expect(service.privacyOptionsCalls, 1);
    expect(container.read(consentControllerProvider).canRequestAds, isTrue);
  });

  test('a_failed_privacy_options_form_reports_false', () async {
    final service = FakeConsentService(optionsResult: false);
    final container = containerFor(service);
    final shown = await container
        .read(consentControllerProvider.notifier)
        .showPrivacyOptions();
    expect(shown, isFalse);
  });

  test('the_privacy_options_entry_is_known_after_the_silent_update', () async {
    final service = FakeConsentService(optionsRequired: true);
    final container = containerFor(service);
    await container.read(consentControllerProvider.notifier).refresh();
    final state = container.read(consentControllerProvider);
    expect(state.privacyOptionsRequired, isTrue);
    // Ads still wait for the form.
    expect(state.gathered, isFalse);
    expect(state.canRequestAds, isFalse);
  });

  group('the container is disposed while consent is being gathered', () {
    // The remote screen starts the gather unawaited, so nothing may throw
    // into it, whichever step the disposal interrupts.
    for (final step in ['the_silent_update', 'the_form']) {
      test('nothing_throws_during_$step', () async {
        final hold = Completer<void>();
        final service = step == 'the_silent_update'
            ? FakeConsentService(holdRequestUpdate: hold)
            : FakeConsentService(holdShowForm: hold);
        final container = ProviderContainer(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            consentServiceProvider.overrideWithValue(service),
          ],
        )..listen(consentControllerProvider, (_, _) {});
        final result = container
            .read(consentControllerProvider.notifier)
            .ensureGathered();
        await pumpEventQueue();

        container.dispose();
        hold.complete();

        final done = await result;
        await pumpEventQueue();
        // Nothing was published, and the answer says so.
        expect(done.gathered, isFalse);
        expect(done.canRequestAds, isFalse);
      });
    }
  });
}
