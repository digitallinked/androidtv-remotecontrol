import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/config/app_version.dart';

void main() {
  test('version_compare', () {
    const below = [('1.0.0', '1.0.1'), ('0.9.9', '1.0.0'), ('1.2.9', '1.3')];
    const notBelow = [
      ('1.2', '1.2.0'),
      ('1.10.0', '1.9.9'),
      ('1.0.0+5', '1.0.0'),
      ('1.0.0', '1.0.0+9'),
      ('2.0.0', '1.99.99'),
      ('x', '2.0.0'),
      ('1.0.0', ''),
      ('1.0.0', '2'),
      ('1.0.0-beta', '2.0.0'),
      ('1.0.0', '1.0.0.1'),
    ];
    for (final (current, minimum) in below) {
      expect(
        isBelowMinimum(current, minimum),
        isTrue,
        reason: '$current<$minimum',
      );
    }
    for (final (current, minimum) in notBelow) {
      expect(
        isBelowMinimum(current, minimum),
        isFalse,
        reason: '$current<$minimum',
      );
    }
  });

  test('parse_reads_two_and_three_part_versions_and_ignores_the_build', () {
    expect(parseAppVersion('1.2'), (major: 1, minor: 2, patch: 0));
    expect(parseAppVersion('1.2.3+45'), (major: 1, minor: 2, patch: 3));
    expect(parseAppVersion(' 10.0.7 '), (major: 10, minor: 0, patch: 7));
    for (final bad in [
      '',
      '1',
      'a.b.c',
      '1..2',
      '1.2.3.4',
      '-1.0.0',
      '1.0.0-rc1',
    ]) {
      expect(parseAppVersion(bad), isNull, reason: bad);
    }
  });
}
