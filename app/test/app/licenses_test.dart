import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/licenses.dart';

void main() {
  testWidgets('licences_include_androidtvremote2', (t) async {
    registerAppLicenses();

    final entries = await t.runAsync(() => LicenseRegistry.licenses.toList());

    expect(
      entries!.expand((e) => e.packages),
      contains('androidtvremote2'),
    );
    final entry = entries.firstWhere(
      (e) => e.packages.contains('androidtvremote2'),
    );
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('Apache License'));
  });

  test('bundled_licence_matches_the_package_copy', () {
    final bundled = File('assets/licenses/androidtvremote2.txt');
    final original = File(
      '../packages/atv_remote/proto/LICENSE-androidtvremote2',
    );

    expect(bundled.existsSync(), isTrue);
    expect(bundled.readAsBytesSync(), original.readAsBytesSync());
  });
}
