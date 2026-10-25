import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/flavor.dart';

void main() {
  test('flavor_names_and_ids_match_store_config', () {
    expect(
      (Flavor.dev.displayName, Flavor.dev.applicationId),
      (
        'Remotely Dev',
        'com.digitallinked.atvremote.dev',
      ),
    );
    expect(
      (Flavor.prod.displayName, Flavor.prod.applicationId),
      (
        'Remotely for Android TV',
        'com.digitallinked.atvremote',
      ),
    );
  });

  test('flavor_mismatch_is_detected', () {
    expect(flavorMatchesNative(Flavor.dev, null), isTrue);
    expect(flavorMatchesNative(Flavor.dev, 'dev'), isTrue);
    expect(flavorMatchesNative(Flavor.dev, 'prod'), isFalse);
  });
}
