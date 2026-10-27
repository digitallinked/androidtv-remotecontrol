import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only `lib/` files allowed to import each vendor SDK (Ruling P6-R2 and
/// the Phase 6 File Structure). Files that do not exist yet simply import
/// nothing.
const _adapters = <String, Set<String>>{
  'firebase_core': {'lib/core/firebase/firebase_bootstrap.dart'},
  'firebase_crashlytics': {'lib/core/crash/crashlytics_reporter.dart'},
  'firebase_analytics': {'lib/core/analytics/firebase_analytics_service.dart'},
  'firebase_remote_config': {'lib/core/config/firebase_app_config.dart'},
  'google_mobile_ads': {
    'lib/core/ads/ads_service.dart',
    'lib/core/ads/banner_slot.dart',
    'lib/core/ads/consent_service.dart',
  },
  'app_tracking_transparency': {'lib/core/ads/tracking_status.dart'},
  'purchases_flutter': {'lib/core/purchases/purchase_service.dart'},
  'in_app_review': {'lib/core/review/review_service.dart'},
  'device_info_plus': {'lib/core/app_info/os_version.dart'},
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

  test('firebase_core_has_exactly_one_importer', () {
    final importers = [
      for (final file in _dartFiles())
        if (file.readAsStringSync().contains('package:firebase_core/'))
          file.path.replaceAll(r'\', '/'),
    ];
    expect(importers, ['lib/core/firebase/firebase_bootstrap.dart']);
  });
}
