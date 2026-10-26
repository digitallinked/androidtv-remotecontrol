import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/data/catalogue_repository.dart';

void main() {
  test('catalogue_provider_loads_the_bundled_file', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer.test();
    final catalogue = await container.read(catalogueProvider.future);
    expect(catalogue.apps.length, greaterThanOrEqualTo(50));
    expect(catalogue.defaultRows, contains('*'));
  });

  test('catalogue_provider_surfaces_a_corrupt_asset_as_an_error', () async {
    final container = ProviderContainer.test(
      overrides: [
        catalogueSourceProvider.overrideWith((ref) async => '{ not json'),
      ],
    );
    await expectLater(
      container.read(catalogueProvider.future),
      throwsA(isA<FormatException>()),
    );
    expect(container.read(catalogueProvider).hasError, isTrue);
  });

  testWidgets('device_region_reads_the_first_locale_with_a_country', (
    t,
  ) async {
    t.platformDispatcher.localesTestValue = const [
      Locale('en'),
      Locale('ms', 'my'),
    ];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    expect(ProviderContainer.test().read(deviceRegionProvider), 'MY');
  });

  testWidgets('device_region_is_null_without_a_country', (t) async {
    t.platformDispatcher.localesTestValue = const [Locale('en'), Locale('ms')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    expect(ProviderContainer.test().read(deviceRegionProvider), isNull);
  });
}
