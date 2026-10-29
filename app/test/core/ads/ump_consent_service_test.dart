import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/ads/consent_service.dart';
import 'package:tv_remote/core/ads/ump_consent_service.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/privacy/privacy_choices.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the status maps to a region (Ruling P6-R4)', () {
    test('not_required_and_required_and_obtained', () {
      expect(
        UmpConsentService.regionOf(ConsentStatus.notRequired),
        ConsentRegion.notRequired,
      );
      expect(
        UmpConsentService.regionOf(ConsentStatus.required),
        ConsentRegion.required,
      );
      expect(
        UmpConsentService.regionOf(ConsentStatus.obtained),
        ConsentRegion.required,
      );
      expect(
        UmpConsentService.regionOf(ConsentStatus.unknown),
        ConsentRegion.unknown,
      );
    });
  });

  group('the request parameters', () {
    const config = ServiceConfig(
      umpDebugGeography: 'eea',
      umpTestDeviceId: 'TEST-DEVICE',
    );

    test('dev_with_a_debug_geography_forces_it_for_the_test_device', () {
      final params = UmpConsentService(config, Flavor.dev).buildParameters();
      expect(
        params.consentDebugSettings,
        ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
          testIdentifiers: ['TEST-DEVICE'],
        ),
      );
    });

    test('other_means_a_region_without_regulation', () {
      final params = UmpConsentService(
        const ServiceConfig(umpDebugGeography: 'other'),
        Flavor.dev,
      ).buildParameters();
      expect(
        params.consentDebugSettings?.debugGeography,
        DebugGeography.debugGeographyOther,
      );
      expect(params.consentDebugSettings?.testIdentifiers, isNull);
    });

    test('prod_and_empty_settings_use_the_real_geography', () {
      expect(
        UmpConsentService(
          config,
          Flavor.prod,
        ).buildParameters().consentDebugSettings,
        isNull,
      );
      expect(
        UmpConsentService(
          ServiceConfig.none,
          Flavor.dev,
        ).buildParameters().consentDebugSettings,
        isNull,
      );
    });
  });

  group('with no platform plugin (a test, a desktop build)', () {
    final service = UmpConsentService(ServiceConfig.none, Flavor.dev);

    test('every_call_degrades_instead_of_throwing', () async {
      expect(await service.requestUpdate(), ConsentRegion.unknown);
      expect(await service.showFormIfRequired(), ConsentFormOutcome.failed);
      expect(await service.canRequestAds(), isFalse);
      expect(await service.privacyOptionsRequired(), isFalse);
      expect(await service.showPrivacyOptions(), isFalse);
    });
  });
}
