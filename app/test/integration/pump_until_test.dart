import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_until.dart';

void main() {
  testWidgets('pump_until_reports_what_it_waited_for', (t) async {
    await expectLater(
      pumpUntil(
        t,
        () => false,
        timeout: const Duration(milliseconds: 100),
        reason: 'the fake TV to show a code',
      ),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('the fake TV to show a code'),
            contains('Timed out after'),
          ),
        ),
      ),
    );
  });

  testWidgets('pump_until_returns_once_the_condition_holds', (t) async {
    var checks = 0;
    await pumpUntil(t, () => ++checks >= 3, reason: 'three checks');
    expect(checks, 3);
  });
}
