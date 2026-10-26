import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
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

  test('a_throwing_source_fails_the_catalogue_at_once_without_retry', () {
    fakeAsync((async) {
      final container = ProviderContainer.test(
        overrides: [
          // An exception, not an Error: Riverpod never retries Errors.
          catalogueSourceProvider.overrideWith(
            (ref) async => throw Exception('asset missing'),
          ),
        ],
      );
      Object? error;
      unawaited(
        container
            .read(catalogueProvider.future)
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      async.flushMicrotasks();
      expect(error, isA<Exception>());
      expect(container.read(catalogueProvider).hasError, isTrue);
      // A bundled file never fixes itself: no retry timer is left.
      expect(async.pendingTimers, isEmpty);
    });
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
