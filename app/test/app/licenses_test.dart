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

  testWidgets('licences_credit_the_app_logos', (t) async {
    registerAppLicenses();

    final entries = (await t.runAsync(
      () => LicenseRegistry.licenses.toList(),
    ))!;
    String textOf(String package) => entries
        .firstWhere((e) => e.packages.contains(package))
        .paragraphs
        .map((p) => p.text)
        .join('\n');

    final simpleIcons = textOf('Simple Icons');
    expect(simpleIcons, contains('16.36.0'));
    expect(simpleIcons, contains('CC0 1.0 Universal'));
    expect(simpleIcons, contains('https://simpleicons.org'));
    expect(
      simpleIcons,
      contains('App names and logos belong to their owners'),
    );

    // What CC BY 4.0 section 3 asks for: who made it, where it comes from,
    // the licence and its link, the disclaimer and the state of the files.
    final selfhst = textOf('selfh.st/icons');
    expect(selfhst, contains('selfh.st'));
    expect(selfhst, contains('https://github.com/selfhst/icons'));
    expect(selfhst, contains('b2378abb1a0c64149bb7621815b849d89602de23'));
    expect(selfhst, contains('https://creativecommons.org/licenses/by/4.0/'));
    expect(selfhst, contains('Attribution 4.0 International'));
    expect(selfhst, contains('Disclaimer of Warranties'));
    expect(selfhst, contains('unmodified'));
    expect(selfhst, contains('App names and logos belong to their owners'));
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
