import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/device/phone_country.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers [regionChannel] with [answer] and records every call.
  List<MethodCall> mockRegion(Future<Object?> Function(MethodCall) answer) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(regionChannel, (call) {
      calls.add(call);
      return answer(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(regionChannel, null));
    return calls;
  }

  test('a_sim_country_comes_back_in_upper_case', () async {
    final calls = mockRegion((_) async => 'my');

    expect(await readPhoneCountry(), 'MY');
    expect(calls.single.method, 'phoneCountry');
  });

  test('a_phone_with_no_sim_has_no_country', () async {
    mockRegion((_) async => null);

    expect(await readPhoneCountry(), isNull);
  });

  test('an_empty_answer_is_no_country', () async {
    mockRegion((_) async => '');

    expect(await readPhoneCountry(), isNull);
  });

  test('a_region_that_is_not_a_country_is_no_country', () async {
    // iOS can report a UN region such as "001" (the world).
    mockRegion((_) async => '001');

    expect(await readPhoneCountry(), isNull);
  });

  test('a_native_error_is_no_country', () async {
    mockRegion((_) async => throw PlatformException(code: 'telephony'));

    expect(await readPhoneCountry(), isNull);
  });

  test('a_channel_nobody_registered_is_no_country', () async {
    expect(await readPhoneCountry(), isNull);
  });

  test('a_native_side_that_never_answers_cannot_hold_up_startup', () async {
    mockRegion((_) => Completer<Object?>().future);

    expect(await readPhoneCountry(timeout: Duration.zero), isNull);
  });

  // The Dart side, Android and iOS must agree on these two names, and no
  // test can run the native code here.
  group('native_channel', () {
    const android =
        'android/app/src/main/kotlin/com/digitallinked/atvremote/'
        'MainActivity.kt';
    const ios = 'ios/Runner/AppDelegate.swift';

    for (final path in [android, ios]) {
      test('$path answers_the_channel', () {
        final source = File(path).readAsStringSync();
        expect(source, contains('"${regionChannel.name}"'));
        expect(source, contains('"phoneCountry"'));
      });
    }

    test('android_trusts_the_sim_before_the_network', () {
      // A phone roaming abroad is on a foreign network, but its owner's
      // streaming apps are still those of the SIM's country.
      final source = File(android).readAsStringSync();
      final sim = source.indexOf('simCountryIso');
      final network = source.indexOf('networkCountryIso');
      expect(sim, isNonNegative);
      expect(network, greaterThan(sim));
    });
  });
}
