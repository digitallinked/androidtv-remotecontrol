import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only `lib/` files allowed to import each vendor SDK (Ruling P6-R2 and
/// the Phase 6 File Structure). Files that do not exist yet simply import
/// nothing.
const _adapters = <String, Set<String>>{
  'firebase_core': {'lib/core/firebase/firebase_bootstrap.dart'},
  'firebase_crashlytics': {'lib/core/crash/crashlytics_sink.dart'},
  'firebase_analytics': {'lib/core/analytics/firebase_analytics_sink.dart'},
  'firebase_remote_config': {
    'lib/core/config/firebase_remote_config_source.dart',
  },
  'google_mobile_ads': {
    'lib/core/ads/ump_consent_service.dart',
    'lib/core/ads/google_mobile_ads_sdk.dart',
  },
  'app_tracking_transparency': {'lib/core/ads/att_tracking_service.dart'},
  'purchases_flutter': {'lib/core/purchases/revenuecat_purchase_service.dart'},
  'in_app_review': {'lib/core/review/in_app_review_requester.dart'},
  'device_info_plus': {'lib/core/app_info/app_info.dart'},
};

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('vendor_sdks_are_imported_only_by_their_adapters', () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      final path = file.path.replaceAll(r'\', '/');
      final source = file.readAsStringSync();
      for (final entry in _adapters.entries) {
        final import = RegExp(
          '^\\s*(import|export)\\s+[\'"]package:${entry.key}/',
          multiLine: true,
        );
        if (import.hasMatch(source) && !entry.value.contains(path)) {
          offenders.add('$path imports ${entry.key}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
